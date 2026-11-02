#pragma once
#include <stdint.h>
#define VIEW_SAMPLES 2048
#define VIEW_POINTS 760
#define VIEW_HEIGHT 200
/* Fixed vertical scale: full signed PCM range -> 0..199, no normalization. */
void wave_view(const int16_t samples[VIEW_SAMPLES],uint8_t pixels[VIEW_POINTS]);

void wave_view_reset(void);
