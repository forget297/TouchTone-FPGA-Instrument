#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include "../../main/wave_view.h"
static int16_t pcm[VIEW_SAMPLES];
static uint8_t reference[VIEW_POINTS],old_reference[VIEW_POINTS];
static void old_view(const int16_t *s,uint8_t *p){unsigned at=0;for(unsigned i=1;i<=1024-760;i++)if(s[i-1]<=0 && s[i]>0){at=i;break;}for(unsigned j=0;j<760;j++)p[j]=(uint32_t)((int32_t)s[at+j]+32768)*199/65535;}
static int difference(const uint8_t *a,const uint8_t *b){int n=0;for(int i=0;i<VIEW_POINTS;i++){int d=(int)a[i]-b[i];n+=d<0?-d:d;}return n;}
static int maximum(const uint8_t *p){int n=0;for(int i=0;i<VIEW_POINTS;i++)if(p[i]>n)n=p[i];return n;}
int main(void){
 struct {uint8_t before[16],pixels[VIEW_POINTS],after[16];} out;
 memset(&out,0xa5,sizeof(out));wave_view_reset();wave_view(pcm,out.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(out.pixels[i]==99);
 for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=-32768;wave_view(pcm,out.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(out.pixels[i]==0);
 for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=32767;wave_view(pcm,out.pixels);for(int i=0;i<VIEW_POINTS;i++)assert(out.pixels[i]==199);
 wave_view_reset();for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=i<1288?-10000:10000;wave_view(pcm,out.pixels);assert(out.pixels[0]==99 && out.pixels[759]==129);
 long new_error=0,old_error=0;
 wave_view_reset();
 for(int f=0;f<120;f++){
  for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=(int16_t)(18000*sin(6.283185307179586*160*i/46875+.073*f));
  wave_view(pcm,out.pixels);uint8_t old[VIEW_POINTS];old_view(pcm,old);
  if(f){new_error+=difference(reference,out.pixels);old_error+=difference(old_reference,old);}
  memcpy(reference,out.pixels,VIEW_POINTS);memcpy(old_reference,old,VIEW_POINTS);
 }
 printf("160Hz moving-phase pixel error: old=%ld new=%ld\n",old_error,new_error);assert(new_error*4<old_error);
 // Multiple zero crossings per fundamental cycle plus low-level noise.
 wave_view_reset();long harmonic_error=0;
 for(int f=0;f<120;f++){
  for(int i=0;i<VIEW_SAMPLES;i++){double p=6.283185307179586*261.625565*i/46875+.11*f;pcm[i]=(int16_t)(7000*(sin(p)+.9*sin(3*p)+.6*sin(5*p)))+(i%7-3)*8;}
  wave_view(pcm,out.pixels);if(f)harmonic_error+=difference(reference,out.pixels);memcpy(reference,out.pixels,VIEW_POINTS);
 }
 printf("Multi-crossing/noise average inter-frame pixel error=%g\n",harmonic_error/(119.*VIEW_POINTS));assert(harmonic_error<119L*VIEW_POINTS*2);
 wave_view_reset();for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=(int16_t)(8000*sin(.04*i));wave_view(pcm,out.pixels);int low=maximum(out.pixels);
 for(int i=0;i<VIEW_SAMPLES;i++)pcm[i]=(int16_t)(16000*sin(.04*i+.7));wave_view(pcm,out.pixels);assert(maximum(out.pixels)>low+20);
 for(int i=0;i<16;i++)assert(out.before[i]==0xa5 && out.after[i]==0xa5);
 puts("PASS wave v06: signed endpoints, silence, late trigger bounds, low-frequency phase stability, multiple crossings/noise, fresh amplitude preserved");return 0;
}
