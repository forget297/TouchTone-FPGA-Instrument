#define _CRT_SECURE_NO_WARNINGS
#include <assert.h>
#include <stdlib.h>
#include "../02_ESP32_EN/main/lcd_display.c"
static FILE *drawing;
static unsigned commands;
int uart_write_bytes(int uart,const void *buf,size_t n){
 static char text[200];static size_t used;static int ff;
 const unsigned char*p=buf;
 for(size_t i=0;i<n;i++){
  if(p[i]==255){if(++ff==3){text[used]=0;ff=0;used=0;
   int x,y,w,h,c;commands++;
   if(sscanf(text,"fill %d,%d,%d,%d,%d",&x,&y,&w,&h,&c)==5)assert(x>=0 && y>=0 && w>0 && h>0 && x+w<=800 && y+h<=480);
   if(sscanf(text,"line %d,%d,%d,%d,%d",&x,&y,&w,&h,&c)==5)assert(x>=0 && x<800 && y>=0 && y<480 && w>=0 && w<800 && h>=0 && h<480);
   if(drawing)fprintf(drawing,"%s\n",text);
  }}else {ff=0;assert(used+1<sizeof(text));text[used++]=(char)p[i];}
 }
 return (int)n;
}
static unsigned frames,replies;static uint8_t saved[VISUAL_BYTES];
static void reply(const uint8_t*p,size_t n){assert(n==8 && p[0]==0xa5);replies++;}
static void frame(const uint8_t*p){assert(p[0]==13);if(!frames)memcpy(saved,p,VISUAL_BYTES);frames++;}
int main(void){
 FILE*f=fopen("visual_packets.hex","r");assert(f);uint8_t b[1932];unsigned v,n=0;
 while(fscanf(f,"%x",&v)==1){assert(n<sizeof(b));b[n++]=(uint8_t)v;}fclose(f);assert(n==1932);
 visual_protocol_init(reply,frame);
 uint8_t ack[]={0xa5,1,0x81,0,0,0,0,0x5a};for(int j=0;j<6;j++)ack[6]^=ack[j];
 for(unsigned i=0;i<n;i++){visual_protocol_feed(b+i,1);if(i%42==41)visual_protocol_feed(ack,8);}
 assert(frames==2 && replies==46);
 frames=0;replies=0;visual_protocol_init(reply,frame);b[10]^=1;visual_protocol_feed(b,n);assert(frames==1);b[10]^=1;
 frames=0;visual_protocol_init(reply,frame);visual_protocol_feed(b,42);visual_protocol_feed(b+84,n-84);assert(frames==1);
 frames=0;visual_protocol_init(reply,frame);uint8_t noise[]={5,255,0xa8,0xa5,0,0,0,0,0,0,0,0,0};visual_protocol_feed(noise,sizeof(noise));visual_protocol_feed(b,n);assert(frames==2);
 int old=-1;
 for(unsigned view=0;view<4;view++){
  char path[32];snprintf(path,sizeof(path),"view%u.commands",view);drawing=fopen(path,"w");assert(drawing);
  saved[4]=(uint8_t)view;saved[5]=0;draw(saved,&old);fclose(drawing);drawing=NULL;
  draw(saved,&old);
 }
 saved[4]=3;for(unsigned page=0;page<4;page++){saved[5]=(uint8_t)page;draw(saved,&old);}
 memset(saved+288,0,256);saved[4]=1;draw(saved,&old);
 puts("PASS C parser: fragmentation, interleaved replies, CRC rejection, lost packet, noise recovery");
 printf("PASS four display views, all note pages, silence; %u screen commands within 800x480\n",commands);
 return 0;
}
