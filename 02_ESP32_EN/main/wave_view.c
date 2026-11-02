#include <stdbool.h>
#include <limits.h>
#include "wave_view.h"
#define FEATURES 64
static int16_t previous[FEATURES];
static bool previous_valid;
void wave_view_reset(void){previous_valid=false;}
static int sample_at(const int16_t *s,unsigned base,unsigned fraction,unsigned offset){
    int a=s[base+offset],b=s[base+offset+1];
    return a+(int)(((int64_t)(b-a)*fraction)>>16);
}
void wave_view(const int16_t samples[VIEW_SAMPLES],uint8_t pixels[VIEW_POINTS]){
    int peak=0;
    for(unsigned i=0;i<VIEW_SAMPLES;i++){int v=samples[i];if(v<0)v=-v;if(v>peak)peak=v;}
    int threshold=peak/12;if(threshold<32)threshold=32;
    unsigned chosen=0,chosen_fraction=0,cross=0;
    unsigned long best=ULONG_MAX;bool armed=false,found=false;
    for(unsigned i=1;i<=VIEW_SAMPLES-VIEW_POINTS;i++){
        if(samples[i-1]<=-threshold){armed=true;cross=0;}
        if(armed && samples[i-1]<=0 && samples[i]>0)cross=i;
        if(!armed || !cross || samples[i]<threshold)continue;
        unsigned base=cross-1;
        unsigned fraction=(unsigned)((-(int64_t)samples[base]*65536)/(samples[cross]-(int)samples[base]));
        if(fraction>65535)fraction=65535;
        unsigned long score=0;
        if(previous_valid && peak>=128){
            for(unsigned j=0;j<FEATURES;j++){
                int feature=sample_at(samples,base,fraction,j*12)*1024/peak;
                int difference=feature-previous[j];score+=(unsigned long)(difference*difference);
            }
        }
        if(!found || score<best){chosen=base;chosen_fraction=fraction;best=score;found=true;}
        armed=false;cross=0;
        if(!previous_valid)break;
    }
    /* Only phase selection uses history: output always consists of fresh PCM. */
    previous_valid=found && peak>=128;
    if(previous_valid)for(unsigned j=0;j<FEATURES;j++)
        previous[j]=sample_at(samples,chosen,chosen_fraction,j*12)*1024/peak;
    for(unsigned j=0;j<VIEW_POINTS;j++){
        int value=sample_at(samples,chosen,chosen_fraction,j);
        pixels[j]=(uint32_t)(value+32768)*(VIEW_HEIGHT-1)/65535u;
    }
}
