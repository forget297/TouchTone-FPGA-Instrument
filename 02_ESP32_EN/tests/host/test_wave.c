#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../main/wave_view.h"
static int16_t mono[VIEW_SAMPLES];
int main(void){
 struct {unsigned char before[16];uint8_t pixels[VIEW_POINTS];unsigned char after[16];} b;
 memset(&b,0xa5,sizeof(b));wave_view(mono,b.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(b.pixels[i]==99);
 for(int i=0;i<VIEW_SAMPLES;i++)mono[i]=-32768;wave_view(mono,b.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(b.pixels[i]==0);
 for(int i=0;i<VIEW_SAMPLES;i++)mono[i]=32767;wave_view(mono,b.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(b.pixels[i]==199);
 // Last possible rising crossing still leaves exactly 760 valid samples.
 for(int i=0;i<VIEW_SAMPLES;i++)mono[i]=i<264?-10000:10000;wave_view(mono,b.pixels);assert(b.pixels[0]==129);
 // Earlier trigger has priority and original amplitude is retained.
 for(int i=0;i<VIEW_SAMPLES;i++)mono[i]=(i%100<50)?-10000:10000;wave_view(mono,b.pixels);assert(b.pixels[0]==129 && b.pixels[50]==69);
 for(int i=0;i<16;i++)assert(b.before[i]==0xa5 && b.after[i]==0xa5);
 puts("PASS wave_view: silence, signed full scale, fixed gain, first/last trigger and buffer bounds");return 0;
}
