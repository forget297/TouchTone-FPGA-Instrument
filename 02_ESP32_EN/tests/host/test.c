
#include "common.h"
#include "../../main/recorder.c"
static unsigned display_blocks,display_reset,display_init;
void lcd_display_init(void){display_init++;}
void lcd_display_reset_window(void){display_reset++;}
void lcd_display_feed(const int16_t *stereo,size_t bytes){assert(stereo && bytes%4==0);display_blocks++;}
static int command(int cmd,int arg){
 struct os_mbuf m={.length=8};uint8_t q[]={0xa5,7,cmd,arg,0,0,0,0x5a};for(int i=0;i<6;i++)q[6]^=q[i];memcpy(m.data,q,8);
 struct ble_gatt_access_ctxt c={BLE_GATT_ACCESS_OP_WRITE_CHR,&m};assert(recorder_access(1,1,&c,NULL)==0);
 return response[3];
}
static void stop_from_read(void){if(stop_after<0)recorder_disconnect();else assert(command(0x44,0)==0);}
static void busy_from_read(void){assert(command(0x40,0)==3);assert(command(0x43,0)==3);}
static void capture(int fixed,int blocks,int missing,int lost){
 reads=0;stop_after=blocks;no_clock=missing;lose=lost;busy_checked=0;clock_us=0;
 assert(command(0x40,fixed)==0);if(blocks<0)recorder_disconnect();
 if(!setjmp(finished))worker(NULL);
}
int main(void){
 recorder_init();assert(capacity==2812500);assert(command(0x45,0)==0 && response[4]==4);
 assert(command(0x44,0)==3);assert(command(0x40,2)==2);
 capture(0,20,0,0);assert(state==2 && length==20*512);assert(crc==crc32(pcm,length));assert(command(0x44,0)==0);
 assert(command(0x42,0)==0 && response[4]==237);uint8_t sum=0;for(int i=0;i<response_len-2;i++)sum^=response[i];assert(sum==response[response_len-2]);
 capture(1,0,0,0);assert(state==2 && length==93750);
 capture(0,0,0,0);assert(state==2 && length==2812500);
 capture(0,-1,0,0);assert(state==2 && length==512);
 capture(0,20,0,1);assert(state==3 && command(0x42,0)==3);
 capture(0,0,1,0);assert(state==3 && reads<=32);
 assert(command(0x43,0)==0 && state==0);
 capture(1,0,0,0);recorder_notify_link(1,9,true);packet_count=0;fail_send=3;
 assert(command(0x46,0)==0 && response[4]==4);assert(command(0x40,0)==3 && command(0x43,0)==3);
 if(!setjmp(finished))stream_worker(NULL);
 assert(!stream_busy && packet_count==16);uint32_t sent=0;
 for(int j=0;j<packet_count;j++){uint8_t*p=sent_packets[j];int n=p[5];uint32_t at=p[2]|(p[3]<<8)|(p[4]<<16);assert(p[0]==0xa7 && p[1]==7 && at==sent && n==236 && packet_lengths[j]==n+8);uint8_t sum=0;for(int i=0;i<n+6;i++)sum^=p[i];assert(sum==p[n+6] && p[n+7]==0x5a && !memcmp(p+6,pcm+at,n));sent+=n;}
 fake_mtu=23;packet_count=0;assert(command(0x46,0)==0);if(!setjmp(finished))stream_worker(NULL);assert(packet_count==16 && packet_lengths[0]==20);
 packet_count=0;assert(command(0x46,0)==0);recorder_disconnect();if(!setjmp(finished))stream_worker(NULL);assert(packet_count==0 && !stream_busy);
 assert(command(0x46,0)==5);recorder_notify_link(1,9,true);fail_send=-1;assert(command(0x46,0)==0);if(!setjmp(finished))stream_worker(NULL);assert(!stream_busy && state==2);fail_send=0;
 free(pcm);fail_external=1;recorder_init();assert(capacity==93750);capture(0,0,0,0);assert(state==2 && length==93750);
 // Idle preview must not overwrite or change a completed recording.
 uint32_t saved_length=length,saved_crc=crc;uint8_t saved_state=state,saved_bytes[32];memcpy(saved_bytes,pcm,32);
 reads=0;busy_checked=1;stop_after=0;no_clock=0;lose=0;unsigned before=display_blocks;
 preview_once();assert(reads==8 && display_blocks==before+8);assert(length==saved_length && crc==saved_crc && state==saved_state && !memcmp(saved_bytes,pcm,32));
 no_clock=1;reads=0;preview_once();assert(reads==1 && state==saved_state && length==saved_length);no_clock=0;
 assert(display_init==2 && display_blocks>0 && display_reset>0);
 puts("PASS actual recorder.c: idle preview ownership/cache preservation/no-clock bounded wait; manual stop, variable length/CRC, 1s compatibility, 30s capacity, disconnect stop, overflow/no-clock failure, busy rejection, PSRAM fallback; notification windows, MTU23/247, send retries, capture overwrite protection, cancellation and stuck queue timeout");
 return 0;
}
