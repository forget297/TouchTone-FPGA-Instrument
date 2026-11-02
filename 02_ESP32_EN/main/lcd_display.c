#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "lcd_display.h"
#include "visual_protocol.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"

#define LCD_UART UART_NUM_2
#define LCD_TX 8
#define LCD_RX 9
static const char *TAG="LCD_VISUAL";
typedef struct { int64_t time; uint8_t data[VISUAL_BYTES]; } snapshot_t;
static QueueHandle_t snapshots;
static char previous[20][68];
static bool command(const char *text){
    static const uint8_t end[3]={255,255,255};size_t n=strlen(text);
    return uart_write_bytes(LCD_UART,text,n)==(int)n && uart_write_bytes(LCD_UART,end,3)==3
       ;
}
static bool number(const char *text,uint32_t *result){
    uart_flush_input(LCD_UART);if(!command(text))return false;
    uint8_t data[128];int len=0;int64_t until=esp_timer_get_time()+220000;
    while(esp_timer_get_time()<until && len<(int)sizeof(data)){
        int got=uart_read_bytes(LCD_UART,data+len,sizeof(data)-len,pdMS_TO_TICKS(20));
        if(got<0)return false;
        len+=got;
        for(int i=0;i+8<=len;i++)if(data[i]==0x71 && data[i+5]==255 && data[i+6]==255 && data[i+7]==255){
            *result=(uint32_t)data[i+1]|((uint32_t)data[i+2]<<8)|((uint32_t)data[i+3]<<16)|((uint32_t)data[i+4]<<24);return true;
        }
    }
    return false;
}
/* Built-in 5x7 Latin glyphs: no particular HMI font resource is required. */
static const char alphabet[]="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.-:/#%+ ()";
static const uint8_t glyph[][7]={
 {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},{30,1,1,14,1,1,30},
 {2,6,10,18,31,2,2},{31,16,16,30,1,1,30},{14,16,16,30,17,17,14},{31,1,2,4,8,8,8},
 {14,17,17,14,17,17,14},{14,17,17,15,1,1,14},
 {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},
 {30,17,17,17,17,17,30},{31,16,16,30,16,16,31},{31,16,16,30,16,16,16},
 {14,17,16,23,17,17,15},{17,17,17,31,17,17,17},{14,4,4,4,4,4,14},
 {7,2,2,2,2,18,12},{17,18,20,24,20,18,17},{16,16,16,16,16,16,31},
 {17,27,21,21,17,17,17},{17,25,21,19,17,17,17},{14,17,17,17,17,17,14},
 {30,17,17,30,16,16,16},{14,17,17,17,21,18,13},{30,17,17,30,20,18,17},
 {15,16,16,14,1,1,30},{31,4,4,4,4,4,4},{17,17,17,17,17,17,14},
 {17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},
 {17,17,10,4,4,4,4},{31,1,2,4,8,16,31},
 {0,0,0,0,0,12,12},{0,0,0,31,0,0,0},{0,12,12,0,12,12,0},
 {1,2,2,4,8,8,16},{10,31,10,10,31,10,0},{25,26,2,4,8,11,19},
 {0,4,4,31,4,4,0},{0,0,0,0,0,0,0},{2,4,8,8,8,4,2},{8,4,2,2,2,4,8}
};
static void fill(int x,int y,int w,int h,unsigned color){
 char s[64];snprintf(s,sizeof(s),"fill %d,%d,%d,%d,%u",x,y,w,h,color);command(s);
}
static void line(int x,int y,int x1,int y1,unsigned color){
 char s[64];snprintf(s,sizeof(s),"line %d,%d,%d,%d,%u",x,y,x1,y1,color);command(s);
}
static void label(unsigned slot,int y,const char *s){
 if(slot>=20)return;
 size_t n=strlen(s),old=strlen(previous[slot]);if(n>65)n=65;
 for(size_t i=0;i<n || i<old;i++){
  char ch=i<n?s[i]:' ';
  if(i<old && ch==previous[slot][i])continue;
  int x=10+(int)i*12;fill(x,y,12,16,0);
  const char *g=strchr(alphabet,ch);if(!g)continue;
  unsigned k=(unsigned)(g-alphabet);
  for(int row=0;row<7;row++)for(int col=0;col<5;){
   if(!(glyph[k][row]&(16>>col))){col++;continue;}
   int from=col;while(col<5 && (glyph[k][row]&(16>>col)))col++;
   fill(x+2*from,y+2*row,2*(col-from),2,65535);
  }
 }
 memcpy(previous[slot],s,n);previous[slot][n]=0;
}
static bool connect_screen(void){
 const int baud[]={115200,9600};uint32_t id;
 for(unsigned i=0;i<2;i++){
  uart_set_baudrate(LCD_UART,baud[i]);uart_write_bytes(LCD_UART,"\xff\xff\xff",3);
  if(!number("get s0.id",&id)){
   uint8_t pad[64];memset(pad,255,sizeof(pad));for(int k=0;k<16;k++)uart_write_bytes(LCD_UART,pad,64);
   uart_wait_tx_done(LCD_UART,pdMS_TO_TICKS(1500));
   if(!number("get s0.id",&id))continue;
  }
  if(baud[i]!=115200){command("baud=115200");uart_wait_tx_done(LCD_UART,pdMS_TO_TICKS(300));vTaskDelay(pdMS_TO_TICKS(80));uart_set_baudrate(LCD_UART,115200);if(!number("get s0.id",&id))continue;}
  command("bkcmd=0");command("vis 255,0");fill(0,0,800,480,0);memset(previous,0,sizeof(previous));
  ESP_LOGI(TAG,"FPGA visualization online; screen 800x480");return true;
 }
 return false;
}
static unsigned u16(const uint8_t *p){return p[0]|((unsigned)p[1]<<8);}
static uint32_t u32(const uint8_t *p){return (uint32_t)u16(p)|((uint32_t)u16(p+2)<<16);}
static void note_name(unsigned n,char *out,size_t size){
 static const char *names[]={"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
 snprintf(out,size,"%s%u",names[n%12],4+n/12);
}
static void draw(const uint8_t *p,int *oldview){
 unsigned view=p[4]&3,fs=u16(p+14);char s[80],name[8];
 if((int)view!=*oldview){fill(0,0,800,480,0);memset(previous,0,sizeof(previous));*oldview=(int)view;}
 snprintf(s,sizeof(s),"FPGA R13  MENU %u  MODE %u  TIMBRE %u  FS %u",p[1],p[2],p[3],fs);label(0,8,s);
 static const char *views[]={"WAVEFORM - FINAL AUDIO","SPECTRUM - FPGA HANN DFT","LISSAJOUS - AUDIO VS DELAYED AUDIO","VOICE FREQUENCY AND PRE-MIX PEAK"};
 label(1,30,views[view]);
 snprintf(s,sizeof(s),"OUTPUT PEAK %5u /32768   FAULT %u",u16(p+12),(p[7]>>1)&1);label(2,52,s);
 note_name(p[6]&31,name,sizeof(name));snprintf(s,sizeof(s),"SELECT %02u %s  GATE %u ALL %u M8:TURN M9:VIEW",p[6],name,p[7]&1,(p[7]>>2)&1);label(3,74,s);
 label(4,96,view==3?"HZ:PHASE INCREMENT   AMP:PRE-MIX /32768":"PLOTS USE FINAL FPGA AUDIO SAMPLES");
 if(view==3){
  unsigned page=p[5]&3;uint32_t active=u32(p+8);
  for(unsigned row=0;row<8;row++){
   unsigned n=page*8+row;const uint8_t *v=p+544+n*6;
   double hz=(double)u32(v)*fs/4294967296.0;
   note_name(n,name,sizeof(name));
   snprintf(s,sizeof(s),"%02u %-3s  %8.2f HZ  AMP %5u  ACTIVE %u",n,name,hz,u16(v+4),(unsigned)((active>>n)&1));
   label(5+row,140+row*32,s);
  }
  snprintf(s,sizeof(s),"PAGE %u/4 - MENU9 JOYSTICK CLICK NEXT PAGE",page+1);label(13,432,s);
 }else{
  fill(20,136,760,278,0);line(20,274,779,274,16904);
  if(view==0){
   for(int i=1;i<128;i++)line(20+(i-1)*759/127,402-p[32+i-1],20+i*759/127,402-p[32+i],2016);
   label(5,432,"TIME 0..10.84 MS   VERTICAL -32768..32767");
  }else if(view==1){
   unsigned max=1,peakbin=0;
   for(unsigned i=0;i<128;i++){unsigned m=u16(p+288+2*i);if(m>max){max=m;peakbin=i;}}
   for(int i=0;i<128;i++){unsigned h=u16(p+288+2*i)*260/max;if(h)fill(20+i*760/128,408-h,4,h,2016);}
   snprintf(s,sizeof(s),"0..5813.6 HZ  BIN 45.78 HZ  AUTO MAX %u",max);label(5,432,s);
   snprintf(s,sizeof(s),"MAX BIN %u: %.2f HZ  APPROX PEAK %u",peakbin,(double)peakbin*fs/1024,max);label(6,454,s);
  }else{
   for(int i=1;i<64;i++)line(272+p[160+2*(i-1)],402-p[161+2*(i-1)],272+p[160+2*i],402-p[161+2*i],2047);
   label(5,432,"X:AUDIO  Y:AUDIO +16 SAMPLES (0.341 MS)");
   label(6,454,"DELAY PORTRAIT - NOT INDEPENDENT STEREO CHANNELS");
  }
 }
}
static void screen_worker(void *arg){
 (void)arg;bool linked=false,stale=false;int oldview=-1;int64_t seen=0,last_ping=0;snapshot_t frame;
 for(;;){
  if(!linked){linked=connect_screen();if(!linked){vTaskDelay(pdMS_TO_TICKS(2000));continue;}oldview=-1;seen=last_ping=esp_timer_get_time();}
  if(xQueueReceive(snapshots,&frame,pdMS_TO_TICKS(250))==pdTRUE && esp_timer_get_time()-frame.time<1500000){
   if(stale){oldview=-1;stale=false;}draw(frame.data,&oldview);seen=frame.time;
   if(uart_wait_tx_done(LCD_UART,pdMS_TO_TICKS(1500))!=ESP_OK)linked=false;
  }else if(!stale && esp_timer_get_time()-seen>1800000){
   fill(0,136,800,344,0);memset(previous,0,sizeof(previous));label(7,230,"WAITING FOR FPGA R13 DATA");stale=true;
  }
  if(esp_timer_get_time()-last_ping>5000000){uint32_t id;if(!number("get s0.id",&id))linked=false;last_ping=esp_timer_get_time();}
 }
}
void lcd_display_submit(const uint8_t *data){
 if(!snapshots || data[0]!=13 || u16(data+14)!=46875 || data[16]!=10 || data[17]!=128)return;
 snapshot_t s;s.time=esp_timer_get_time();memcpy(s.data,data,VISUAL_BYTES);xQueueOverwrite(snapshots,&s);
}
/* I2S owner remains dedicated to recording. Visualization comes from FPGA UART. */
void lcd_display_reset_window(void){}
void lcd_display_feed(const int16_t *stereo,size_t bytes){(void)stereo;(void)bytes;}
void lcd_display_init(void){
 uart_config_t cfg={.baud_rate=115200,.data_bits=UART_DATA_8_BITS,.parity=UART_PARITY_DISABLE,
 .stop_bits=UART_STOP_BITS_1,.flow_ctrl=UART_HW_FLOWCTRL_DISABLE,.source_clk=UART_SCLK_DEFAULT};
 esp_err_t err=uart_driver_install(LCD_UART,2048,8192,0,NULL,0);
 if(err==ESP_OK)err=uart_param_config(LCD_UART,&cfg);
 if(err==ESP_OK)err=uart_set_pin(LCD_UART,LCD_TX,LCD_RX,UART_PIN_NO_CHANGE,UART_PIN_NO_CHANGE);
 if(err!=ESP_OK){ESP_LOGE(TAG,"Screen init failed: %s",esp_err_to_name(err));return;}
 snapshots=xQueueCreate(1,sizeof(snapshot_t));if(!snapshots)return;
 if(xTaskCreate(screen_worker,"screen_uart",8192,NULL,2,NULL)!=pdPASS){vQueueDelete(snapshots);snapshots=NULL;}
}
