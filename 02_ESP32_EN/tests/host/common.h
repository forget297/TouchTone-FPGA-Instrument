
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <setjmp.h>
typedef int esp_err_t;
#define BLE_HS_CONN_HANDLE_NONE 65535
#define BLE_HS_ENOMEM 12
#define pdMS_TO_TICKS(n) (n)
#define ESP_OK 0
#define ESP_FAIL 1
#define ESP_ERR_TIMEOUT 2
typedef void* i2s_chan_handle_t;
typedef void* TaskHandle_t;
typedef void* SemaphoreHandle_t;
typedef int portMUX_TYPE;
#define portMUX_INITIALIZER_UNLOCKED 0
#define pdTRUE 1
#define pdPASS 1
#define portMAX_DELAY 0
#define portENTER_CRITICAL(x) ((void)0)
#define portEXIT_CRITICAL(x) ((void)0)
#define portENTER_CRITICAL_ISR(x) ((void)0)
#define portEXIT_CRITICAL_ISR(x) ((void)0)
#define ESP_LOGI(...) ((void)0)
#define ESP_LOGW(...) ((void)0)
#define ESP_LOGE(...) ((void)0)
#define MALLOC_CAP_INTERNAL 1
#define MALLOC_CAP_8BIT 2
#define MALLOC_CAP_SPIRAM 4
#define I2S_NUM_0 0
#define I2S_ROLE_SLAVE 0
#define I2S_CHANNEL_DEFAULT_CONFIG(a,b) {0}
#define I2S_STD_CLK_DEFAULT_CONFIG(a) 0
#define I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(a,b) 0
#define I2S_GPIO_UNUSED -1
#define GPIO_NUM_4 4
#define GPIO_NUM_5 5
#define GPIO_NUM_6 6
typedef struct {int dma_desc_num,dma_frame_num;} i2s_chan_config_t;
typedef struct {int clk_cfg,slot_cfg;struct {int mclk,bclk,ws,dout,din;struct {int unused;} invert_flags;} gpio_cfg;} i2s_std_config_t;
typedef struct {int unused;} i2s_event_data_t;
typedef struct {bool (*on_recv_q_ovf)(i2s_chan_handle_t,i2s_event_data_t*,void*);} i2s_event_callbacks_t;
struct os_mbuf {uint8_t data[244];int length;};
struct ble_gatt_access_ctxt {int op;struct os_mbuf *om;};
#define BLE_GATT_ACCESS_OP_READ_CHR 1
#define BLE_GATT_ACCESS_OP_WRITE_CHR 2
#define BLE_ATT_ERR_INSUFFICIENT_RES 3
#define BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN 4
#define BLE_ATT_ERR_UNLIKELY 5
#define OS_MBUF_PKTLEN(m) ((m)->length)
static int fake_mtu=247,packet_count,fail_send;
static uint8_t sent_packets[32][244];
static int packet_lengths[32];
static int64_t clock_us;
static int reads,stop_after,no_clock,lose,busy_checked,fail_external,notifications;
static jmp_buf finished;
static bool (*overflow_cb)(i2s_chan_handle_t,i2s_event_data_t*,void*);
static void stop_from_read(void);
static void busy_from_read(void);
static int64_t esp_timer_get_time(void){return clock_us;}
static void vTaskDelay(int t){clock_us+=1000*t;}
static void* xSemaphoreCreateMutex(void){return (void*)1;}
static int xSemaphoreTake(void*p,int t){return 1;}
static int xSemaphoreGive(void*p){return 1;}
static void* heap_caps_malloc(size_t n,int c){return fail_external && (c&4)?NULL:malloc(n);}
static int xTaskCreate(void(*f)(void*),const char*n,int s,void*a,int p,void**t){*t=(void*)1;return 1;}
static void xTaskNotifyGive(void*t){notifications=0;}
static int ulTaskNotifyTake(int a,int b){if(notifications++)longjmp(finished,1);return 1;}
static int i2s_new_channel(void*c,void*a,void**r){*r=(void*)1;return 0;}
static int i2s_channel_init_std_mode(void*r,void*c){return 0;}
static int i2s_channel_register_event_callback(void*r,i2s_event_callbacks_t*c,void*a){overflow_cb=c->on_recv_q_ovf;return 0;}
static int i2s_channel_enable(void*r){return 0;}
static int i2s_channel_disable(void*r){return 0;}
static int i2s_channel_read(void*r,void*b,size_t n,size_t*got,int t){
 reads++;if(no_clock){*got=0;clock_us+=100000;return ESP_ERR_TIMEOUT;}
 for(int i=0;i<n/2;i++)((int16_t*)b)[i]=(int16_t)(i+reads);
 *got=n;clock_us+=5461;
 if(!busy_checked){busy_checked=1;busy_from_read();}
 if(lose && reads==3)overflow_cb(r,NULL,NULL);
 if(stop_after && reads==stop_after)stop_from_read();
 return 0;
}
static const char* esp_err_to_name(int e){return "mock";}
static int ble_att_mtu(int c){return fake_mtu;}
static struct os_mbuf* ble_hs_mbuf_from_flat(const void*p,int n){struct os_mbuf*m=malloc(sizeof(*m));memcpy(m->data,p,n);m->length=n;return m;}
static int ble_gatts_notify_custom(int conn,int handle,struct os_mbuf*m){
 if(fail_send){if(fail_send>0)fail_send--;free(m);return 12;}
 assert(packet_count<32);memcpy(sent_packets[packet_count],m->data,m->length);packet_lengths[packet_count++]=m->length;free(m);return 0;
}
static int ble_hs_mbuf_to_flat(struct os_mbuf*m,void*b,int n,uint16_t*l){memcpy(b,m->data,m->length);*l=m->length;return 0;}
static int os_mbuf_append(struct os_mbuf*m,const void*b,int n){memcpy(m->data,b,n);m->length=n;return 0;}
