/* FPGA I2S slave capture: 46875Hz, duplicate L/R 16-bit -> mono WAV payload. */
#include <string.h>
#include <stdint.h>
#include "recorder.h"
#include "lcd_display.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "driver/i2s_std.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_timer.h"

#define RATE 46875u
#define CAPACITY (RATE*2u*30u) /* 30 seconds in PSRAM; internal fallback keeps 1s tests usable. */
#define PACKET_MAX 244u
static const char *TAG="RECORDER";
static i2s_chan_handle_t rx;
static TaskHandle_t task;
static SemaphoreHandle_t lock;
static uint8_t *pcm;
static uint32_t length,crc,capacity,target;
static bool stop_requested;
static uint8_t state; /* 0 idle, 1 capturing, 2 ready, 3 error */
static uint8_t response[PACKET_MAX];
static uint16_t response_len;
static TaskHandle_t send_task;
static uint16_t notify_conn=BLE_HS_CONN_HANDLE_NONE,notify_handle;
static bool stream_busy;
static uint32_t stream_offset,stream_end,stream_epoch;
static uint8_t stream_seq;
static volatile uint32_t drops;
static portMUX_TYPE drop_mux=portMUX_INITIALIZER_UNLOCKED;

static uint32_t crc32(const uint8_t *p,uint32_t n){
    uint32_t c=0xffffffffu;
    while(n--){c^=*p++;for(int i=0;i<8;i++)c=(c>>1)^((c&1)?0xedb88320u:0);if((n&4095u)==0)vTaskDelay(1);}
    return ~c;
}
static void put32(uint8_t *p,uint32_t n){for(int i=0;i<4;i++)p[i]=(uint8_t)(n>>(8*i));}
static uint32_t chunk_size(uint16_t conn){
    uint16_t mtu=ble_att_mtu(conn);
    uint32_t n=mtu>11?mtu-11:1; /* ATT(3) + stream header/checksum(8). */
    return n>PACKET_MAX-8?PACKET_MAX-8:n;
}
static void stream_worker(void *arg){
    (void)arg;uint8_t packet[PACKET_MAX];
    for(;;){
        ulTaskNotifyTake(pdTRUE,portMAX_DELAY);
        xSemaphoreTake(lock,portMAX_DELAY);
        uint32_t epoch=stream_epoch,offset=stream_offset,end=stream_end;
        uint16_t conn=notify_conn,handle=notify_handle;uint8_t seq=stream_seq;
        xSemaphoreGive(lock);
        int64_t deadline=esp_timer_get_time()+2000000;
        while(offset<end){
            xSemaphoreTake(lock,portMAX_DELAY);
            bool valid=stream_busy && epoch==stream_epoch && conn==notify_conn && state==2;
            uint32_t n=chunk_size(conn);if(n>end-offset)n=end-offset;
            if(valid){
                packet[0]=0xa7;packet[1]=seq;packet[2]=offset;packet[3]=offset>>8;packet[4]=offset>>16;packet[5]=n;
                memcpy(packet+6,pcm+offset,n);uint8_t sum=0;for(int i=0;i<n+6;i++)sum^=packet[i];
                packet[n+6]=sum;packet[n+7]=0x5a;
            }
            xSemaphoreGive(lock);
            if(!valid)break;
            struct os_mbuf *om=ble_hs_mbuf_from_flat(packet,n+8);
            int rc=om?ble_gatts_notify_custom(conn,handle,om):BLE_HS_ENOMEM;
            /* NimBLE consumes om on success or failure; allocate anew on retry. */
            if(rc==0){offset+=n;deadline=esp_timer_get_time()+2000000;}
            else if(esp_timer_get_time()>deadline)break;
            else vTaskDelay(pdMS_TO_TICKS(5));
        }
        xSemaphoreTake(lock,portMAX_DELAY);if(epoch==stream_epoch)stream_busy=false;xSemaphoreGive(lock);
    }
}
void recorder_notify_link(uint16_t conn,uint16_t handle,bool enabled){
    if(!lock)return;
    xSemaphoreTake(lock,portMAX_DELAY);
    notify_conn=enabled?conn:BLE_HS_CONN_HANDLE_NONE;notify_handle=handle;
    if(!enabled){stream_epoch++;stream_busy=false;}
    xSemaphoreGive(lock);
}
static bool overflow(i2s_chan_handle_t h,i2s_event_data_t *e,void *ctx){
    (void)h;(void)e;(void)ctx;
    portENTER_CRITICAL_ISR(&drop_mux);drops++;portEXIT_CRITICAL_ISR(&drop_mux);return false;
}
/* One owner for I2S: idle snapshots and recording cannot race over DMA. */
static void preview_once(void){
    int16_t stereo[512];lcd_display_reset_window();
    if(i2s_channel_enable(rx)!=ESP_OK)return;
    for(int n=0;n<8;n++){
        size_t got=0;esp_err_t rc=i2s_channel_read(rx,stereo,sizeof(stereo),&got,100);
        if((rc!=ESP_OK && rc!=ESP_ERR_TIMEOUT) || got%4 || !got)break;
        lcd_display_feed(stereo,got);
    }
    i2s_channel_disable(rx);
}
static void worker(void *arg){
    (void)arg;int16_t stereo[512];
    for(;;){
        if(!ulTaskNotifyTake(pdTRUE,pdMS_TO_TICKS(120))){preview_once();continue;}
        lcd_display_reset_window();
        uint32_t pos=0;esp_err_t error=ESP_OK;
        xSemaphoreTake(lock,portMAX_DELAY);uint32_t limit=target;xSemaphoreGive(lock);
        portENTER_CRITICAL(&drop_mux);drops=0;portEXIT_CRITICAL(&drop_mux);
        error=i2s_channel_enable(rx);
        int64_t deadline=esp_timer_get_time()+3000000;
        while(error==ESP_OK && pos<limit){
            xSemaphoreTake(lock,portMAX_DELAY);bool stop=stop_requested;xSemaphoreGive(lock);
            if(stop && pos>0)break; /* Immediate stop still yields at least one real PCM block. */
            size_t got=0;
            esp_err_t rc=i2s_channel_read(rx,stereo,sizeof(stereo),&got,100);
            if(rc!=ESP_OK && rc!=ESP_ERR_TIMEOUT){error=rc;break;}
            if(got%4){error=ESP_FAIL;break;}
            lcd_display_feed(stereo,got);
            for(size_t i=0;i<got/sizeof(int16_t) && pos<limit;i+=2){
                uint16_t sample=(uint16_t)stereo[i];pcm[pos++]=sample&255;pcm[pos++]=sample>>8;
            }
            xSemaphoreTake(lock,portMAX_DELAY);length=pos;xSemaphoreGive(lock);
            if(got)deadline=esp_timer_get_time()+3000000;
            if(esp_timer_get_time()>deadline && pos<limit){error=ESP_ERR_TIMEOUT;break;}
        }
        i2s_channel_disable(rx);
        portENTER_CRITICAL(&drop_mux);uint32_t lost=drops;portEXIT_CRITICAL(&drop_mux);
        uint32_t hash=error==ESP_OK && !lost?crc32(pcm,pos):0;
        xSemaphoreTake(lock,portMAX_DELAY);
        length=pos;crc=hash;state=error==ESP_OK && !lost && pos>0?2:3;
        xSemaphoreGive(lock);
        ESP_LOGI(TAG,"Capture state=%u bytes=%lu crc=%08lx dropped=%lu err=%s",state,(unsigned long)pos,(unsigned long)hash,(unsigned long)lost,esp_err_to_name(error));
    }
}
void recorder_init(void){
    lcd_display_init();
    lock=xSemaphoreCreateMutex();assert(lock);
    capacity=CAPACITY;pcm=heap_caps_malloc(capacity,MALLOC_CAP_SPIRAM|MALLOC_CAP_8BIT);
    if(!pcm){capacity=RATE*2u;pcm=heap_caps_malloc(capacity,MALLOC_CAP_INTERNAL|MALLOC_CAP_8BIT);ESP_LOGW(TAG,"PSRAM unavailable: recording limited to 1 second");}
    if(!pcm){capacity=0;state=3;ESP_LOGE(TAG,"No capture buffer; UART/BLE remain available");return;}
    i2s_chan_config_t ch=I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0,I2S_ROLE_SLAVE);
    ch.dma_desc_num=8;ch.dma_frame_num=256;
    esp_err_t err=i2s_new_channel(&ch,NULL,&rx);
    i2s_std_config_t cfg={
        .clk_cfg=I2S_STD_CLK_DEFAULT_CONFIG(RATE),
        .slot_cfg=I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT,I2S_SLOT_MODE_STEREO),
        .gpio_cfg={.mclk=I2S_GPIO_UNUSED,.bclk=GPIO_NUM_4,.ws=GPIO_NUM_5,
            .dout=I2S_GPIO_UNUSED,.din=GPIO_NUM_6,.invert_flags={0}},
    };
    if(err==ESP_OK)err=i2s_channel_init_std_mode(rx,&cfg);
    i2s_event_callbacks_t callbacks={.on_recv_q_ovf=overflow};
    if(err==ESP_OK)err=i2s_channel_register_event_callback(rx,&callbacks,NULL);
    if(err!=ESP_OK){state=3;ESP_LOGE(TAG,"I2S init: %s",esp_err_to_name(err));return;}
    if(xTaskCreate(worker,"record_i2s",6144,NULL,7,&task)!=pdPASS){state=3;task=NULL;return;}
    if(xTaskCreate(stream_worker,"record_send",4096,NULL,4,&send_task)!=pdPASS)send_task=NULL;
    ESP_LOGI(TAG,"I2S slave BCLK=4 WS=5 DIN=6, mono %uHz /16bit, capacity=%lu bytes (%lus)",(unsigned)RATE,(unsigned long)capacity,(unsigned long)(capacity/(RATE*2u)));
}
void recorder_disconnect(void){
    if(!lock)return;
    xSemaphoreTake(lock,portMAX_DELAY);if(state==1)stop_requested=true;
    notify_conn=BLE_HS_CONN_HANDLE_NONE;stream_epoch++;stream_busy=false;xSemaphoreGive(lock);
}
int recorder_access(uint16_t conn,uint16_t attr,struct ble_gatt_access_ctxt *ctxt,void *arg){
    (void)attr;(void)arg;
    if(ctxt->op==BLE_GATT_ACCESS_OP_READ_CHR){
        xSemaphoreTake(lock,portMAX_DELAY);
        int rc=os_mbuf_append(ctxt->om,response,response_len);
        xSemaphoreGive(lock);return rc==0?0:BLE_ATT_ERR_INSUFFICIENT_RES;
    }
    if(ctxt->op!=BLE_GATT_ACCESS_OP_WRITE_CHR || OS_MBUF_PKTLEN(ctxt->om)!=8)return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    uint8_t req[8];uint16_t n=0;
    if(ble_hs_mbuf_to_flat(ctxt->om,req,8,&n)!=0 || n!=8)return BLE_ATT_ERR_UNLIKELY;
    uint8_t x=0;for(int i=0;i<6;i++)x^=req[i];
    if(req[0]!=0xa5 || req[7]!=0x5a || req[6]!=x)return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    xSemaphoreTake(lock,portMAX_DELAY);
    uint8_t status=0,payload=0;bool start=false,send=false;
    switch(req[2]){
    case 0x40:
        if(req[3]>1 || req[4] || req[5])status=2; /* 0 manual, 1 legacy fixed 1s */
        else if(state==1 || stream_busy)status=3;
        else if(!task || !pcm)status=6;
        else {state=1;length=0;crc=0;stop_requested=false;target=req[3]?RATE*2u:capacity;start=true;}
        break;
    case 0x41:
        if(req[3] || req[4] || req[5]){status=2;break;}
        payload=14;response[5]=state;response[6]=1;
        put32(response+7,length);put32(response+11,RATE);put32(response+15,crc);break;
    case 0x42:{
        uint32_t offset=req[3]|((uint32_t)req[4]<<8)|((uint32_t)req[5]<<16);
        if(state!=2){status=3;break;}
        if(offset>=length){status=2;break;}
        uint32_t count=length-offset;
        uint16_t mtu=ble_att_mtu(conn);uint32_t max=mtu>8?mtu-8:14;
        if(max>PACKET_MAX-7)max=PACKET_MAX-7;
        if(count>max)count=max;
        payload=count;memcpy(response+5,pcm+offset,count);break;}
    case 0x43:
        if(req[3] || req[4] || req[5])status=2;
        else if(state==1 || stream_busy)status=3;
        else {state=0;length=0;crc=0;}break;
    case 0x44: /* Stop is idempotent after a capacity/previous stop completion. */
        if(req[3] || req[4] || req[5])status=2;
        else if(state==1)stop_requested=true;
        else if(state!=2)status=3;
        break;
    case 0x45:
        if(req[3] || req[4] || req[5])status=2;
        else {payload=4;put32(response+5,task?capacity:0);}break;
    case 0x46:{
        uint32_t offset=req[3]|((uint32_t)req[4]<<8)|((uint32_t)req[5]<<16);
        if(state!=2 || stream_busy){status=3;break;}
        if(offset>=length){status=2;break;}
        if(!send_task || notify_conn!=conn){status=5;break;}
        uint32_t end=offset+chunk_size(conn)*16u;if(end>length)end=length;
        stream_offset=offset;stream_end=end;stream_seq=req[1];stream_epoch++;stream_busy=true;send=true;
        payload=4;put32(response+5,end);break;}
    default:status=1;break;
    }
    response[0]=0xa6;response[1]=req[1];response[2]=req[2]|0x80;response[3]=status;response[4]=payload;
    uint8_t sum=0;for(int i=0;i<5+payload;i++)sum^=response[i];
    response[5+payload]=sum;response[6+payload]=0x5a;response_len=payload+7;
    xSemaphoreGive(lock);
    if(start)xTaskNotifyGive(task);
    if(send)xTaskNotifyGive(send_task);
    return 0;
}
