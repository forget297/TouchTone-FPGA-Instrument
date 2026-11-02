#include "visual_protocol.h"
#include <string.h>
static uint8_t input[VISUAL_PACKET],snapshot[VISUAL_BYTES],seq;
static size_t used,expected;
static visual_reply_fn reply_callback;
static visual_frame_fn frame_callback;
uint16_t visual_crc16(const uint8_t *data,size_t length){
    uint16_t c=0xffff;
    while(length--){c^=(uint16_t)*data++<<8;for(unsigned j=0;j<8;j++)c=(c&0x8000)?(uint16_t)((c<<1)^0x1021):(uint16_t)(c<<1);}
    return c;
}
void visual_protocol_init(visual_reply_fn reply,visual_frame_fn frame){
    used=expected=0;reply_callback=reply;frame_callback=frame;
}
static void consume(void){
    while(used){
        if(input[0]!=0xa5 && input[0]!=0xa8){memmove(input,input+1,--used);continue;}
        size_t need=input[0]==0xa5?8:VISUAL_PACKET;
        if(used<need)return;
        int valid=0;
        if(need==8){
            uint8_t c=0;for(unsigned j=0;j<6;j++)c^=input[j];
            valid=input[7]==0x5a && input[6]==c;
            if(valid && reply_callback)reply_callback(input,8);
        }else{
            unsigned offset=input[4]|((unsigned)input[5]<<8);
            valid=input[1]==1 && input[3]==1 && input[6]==32 && input[41]==0x5a &&
                offset<=VISUAL_BYTES-32 && offset%32==0 &&
                visual_crc16(input,39)==(uint16_t)(input[39]|((uint16_t)input[40]<<8));
            if(valid){
                if(offset==0){seq=input[2];expected=0;}
                if(input[2]==seq && offset==expected){
                    memcpy(snapshot+offset,input+7,32);expected+=32;
                    if(expected==VISUAL_BYTES && frame_callback)frame_callback(snapshot);
                }else expected=VISUAL_BYTES; // discard incomplete frame until next offset zero
            }else expected=VISUAL_BYTES;
        }
        size_t drop=valid?need:1;
        used-=drop;memmove(input,input+drop,used);
    }
}
void visual_protocol_feed(const uint8_t *data,size_t length){
    while(length--){input[used++]=*data++;consume();}
}
