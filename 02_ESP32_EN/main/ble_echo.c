/* BLE <-> UART bridge for ESP-IDF 6.0.2 / ESP32-S3. */
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/uart.h"
#include "recorder.h"
#include "lcd_display.h"
#include "visual_protocol.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nimble/nimble_port.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#define DEVICE_NAME "FPGA_BLE_UART"
#define BRIDGE_MAX 20
#define FPGA_UART UART_NUM_1
#define FPGA_UART_TX_GPIO 17
#define FPGA_UART_RX_GPIO 18
#define FPGA_UART_BAUD 115200

static const char *TAG = "BLE_UART";
static const ble_uuid128_t service_uuid = BLE_UUID128_INIT(
    0xf0,0xde,0xbc,0x9a,0x78,0x56,0x34,0x12,
    0x78,0x56,0x34,0x12,0x78,0x56,0x34,0x12);
static const ble_uuid128_t bridge_uuid = BLE_UUID128_INIT(
    0xf1,0xde,0xbc,0x9a,0x78,0x56,0x34,0x12,
    0x78,0x56,0x34,0x12,0x78,0x56,0x34,0x12);
static const ble_uuid128_t recorder_uuid = BLE_UUID128_INIT(
    0xf2,0xde,0xbc,0x9a,0x78,0x56,0x34,0x12,
    0x78,0x56,0x34,0x12,0x78,0x56,0x34,0x12);
static uint8_t own_addr_type;
static uint16_t bridge_handle;
static uint16_t peer = BLE_HS_CONN_HANDLE_NONE;
static bool notify_enabled;
static uint8_t last_value[BRIDGE_MAX] = "READY";
static uint16_t last_len = 5;
static portMUX_TYPE state_mux = portMUX_INITIALIZER_UNLOCKED;

static void notify_uart_reply(const uint8_t *data, uint16_t len)
{
    uint16_t conn;
    bool enabled;
    taskENTER_CRITICAL(&state_mux);
    memcpy(last_value, data, len);
    last_len = len;
    conn = peer;
    enabled = notify_enabled;
    taskEXIT_CRITICAL(&state_mux);
    if (!enabled || conn == BLE_HS_CONN_HANDLE_NONE) return;
    struct os_mbuf *om = ble_hs_mbuf_from_flat(data, len);
    if (!om) {
        ESP_LOGW(TAG, "Notification buffer unavailable");
        return;
    }
    int rc = ble_gatts_notify_custom(conn, bridge_handle, om);
    ESP_LOGI(TAG, "FPGA reply %u bytes, notify rc=%d", (unsigned)len, rc);
}

static void visual_reply(const uint8_t *data,size_t len) { notify_uart_reply(data,(uint16_t)len); }

static void uart_rx_task(void *arg)
{
    (void)arg;
    uint8_t data[BRIDGE_MAX];
    for (;;) {
        int len = uart_read_bytes(FPGA_UART, data, sizeof(data), pdMS_TO_TICKS(100));
        if (len > 0) {
            visual_protocol_feed(data, (size_t)len);
        }
    }
}

static int bridge_access(uint16_t conn, uint16_t attr,
                         struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn; (void)attr; (void)arg;
    if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
        uint8_t snapshot[BRIDGE_MAX];
        uint16_t len;
        taskENTER_CRITICAL(&state_mux);
        len = last_len;
        memcpy(snapshot, last_value, len);
        taskEXIT_CRITICAL(&state_mux);
        return os_mbuf_append(ctxt->om, snapshot, len) == 0
            ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
    }
    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR)
        return BLE_ATT_ERR_UNLIKELY;
    uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
    if (len == 0 || len > BRIDGE_MAX)
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    uint8_t data[BRIDGE_MAX];
    uint16_t copied = 0;
    if (ble_hs_mbuf_to_flat(ctxt->om, data, sizeof(data), &copied) != 0 || copied != len)
        return BLE_ATT_ERR_UNLIKELY;
    int written = uart_write_bytes(FPGA_UART, data, len);
    ESP_LOGI(TAG, "BLE -> FPGA: %u bytes, UART accepted %d", (unsigned)len, written);
    return written == len ? 0 : BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def services[] = {
    {.type = BLE_GATT_SVC_TYPE_PRIMARY, .uuid = &service_uuid.u,
     .characteristics = (struct ble_gatt_chr_def[]) {
         {.uuid = &bridge_uuid.u, .access_cb = bridge_access,
          .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_NOTIFY,
          .val_handle = &bridge_handle},
         {.uuid=&recorder_uuid.u,.access_cb=recorder_access,
          .flags=BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE},
         {0}
     }},
    {0}
};

static void advertise(void);
static int gap_event(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            taskENTER_CRITICAL(&state_mux);
            peer = event->connect.conn_handle;
            notify_enabled = false;
            taskEXIT_CRITICAL(&state_mux);
            ESP_LOGI(TAG, "CONNECTED handle=%u", (unsigned)peer);
        } else advertise();
        break;
    case BLE_GAP_EVENT_DISCONNECT:
        recorder_disconnect();
        taskENTER_CRITICAL(&state_mux);
        peer = BLE_HS_CONN_HANDLE_NONE;
        notify_enabled = false;
        taskEXIT_CRITICAL(&state_mux);
        advertise();
        break;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == bridge_handle) {
            taskENTER_CRITICAL(&state_mux);
            notify_enabled = event->subscribe.cur_notify;
            taskEXIT_CRITICAL(&state_mux);
            recorder_notify_link(event->subscribe.conn_handle,bridge_handle,event->subscribe.cur_notify);
            ESP_LOGI(TAG, "NOTIFY %s", notify_enabled ? "ON" : "OFF");
        }
        break;
    case BLE_GAP_EVENT_ADV_COMPLETE:
        advertise();
        break;
    default:
        break;
    }
    return 0;
}

static void advertise(void)
{
    struct ble_hs_adv_fields fields = {0};
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.uuids128 = (ble_uuid128_t *)&service_uuid;
    fields.num_uuids128 = 1;
    fields.uuids128_is_complete = 1;
    int rc = ble_gap_adv_set_fields(&fields);
    if (rc) { ESP_LOGE(TAG, "Advertising fields failed: %d", rc); return; }
    struct ble_hs_adv_fields response = {0};
    response.name = (uint8_t *)DEVICE_NAME;
    response.name_len = strlen(DEVICE_NAME);
    response.name_is_complete = 1;
    rc = ble_gap_adv_rsp_set_fields(&response);
    if (rc) { ESP_LOGE(TAG, "Scan response failed: %d", rc); return; }
    struct ble_gap_adv_params params = {0};
    params.conn_mode = BLE_GAP_CONN_MODE_UND;
    params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    params.itvl_min = BLE_GAP_ADV_ITVL_MS(100);
    params.itvl_max = BLE_GAP_ADV_ITVL_MS(120);
    rc = ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER, &params, gap_event, NULL);
    if (rc) { ESP_LOGE(TAG, "Advertising start failed: %d", rc); return; }
    ESP_LOGI(TAG, "ADVERTISING as %s", DEVICE_NAME);
}

static void on_sync(void)
{
    int rc = ble_hs_util_ensure_addr(0);
    if (!rc) rc = ble_hs_id_infer_auto(0, &own_addr_type);
    if (rc) { ESP_LOGE(TAG, "BLE address failed: %d", rc); return; }
    advertise();
}

static void on_reset(int reason)
{
    taskENTER_CRITICAL(&state_mux);
    peer = BLE_HS_CONN_HANDLE_NONE;
    notify_enabled = false;
    taskEXIT_CRITICAL(&state_mux);
    ESP_LOGW(TAG, "BLE host reset reason=%d", reason);
}

static void host_task(void *arg)
{
    (void)arg;
    nimble_port_run();
    vTaskDelete(NULL);
}

void app_main(void)
{
    const uart_config_t uart_cfg = {
        .baud_rate = FPGA_UART_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(FPGA_UART, 1024, 1024, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(FPGA_UART, &uart_cfg));
    ESP_ERROR_CHECK(uart_set_pin(FPGA_UART, FPGA_UART_TX_GPIO, FPGA_UART_RX_GPIO,
                                 UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));

    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);
    ESP_ERROR_CHECK(nimble_port_init());
    ble_hs_cfg.reset_cb = on_reset;
    ble_hs_cfg.sync_cb = on_sync;
    ble_svc_gap_init();
    ble_svc_gatt_init();
    int rc = ble_svc_gap_device_name_set(DEVICE_NAME);
    assert(rc == 0);
    rc = ble_gatts_count_cfg(services);
    assert(rc == 0);
    rc = ble_gatts_add_svcs(services);
    assert(rc == 0);
    ESP_LOGI(TAG, "UART1 TX=GPIO%d RX=GPIO%d, %d 8N1",
             FPGA_UART_TX_GPIO, FPGA_UART_RX_GPIO, FPGA_UART_BAUD);
    recorder_init();
    visual_protocol_init(visual_reply,lcd_display_submit);
    assert(xTaskCreate(uart_rx_task, "uart_rx", 4096, NULL, 6, NULL) == pdPASS);
    assert(xTaskCreate(host_task, "ble_host", 4096, NULL, 5, NULL) == pdPASS);
}
