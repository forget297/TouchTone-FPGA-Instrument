#pragma once
#include <stddef.h>
#include <stdint.h>
void lcd_display_init(void);
/* Called only by the single I2S owner; never waits for screen UART. */
void lcd_display_reset_window(void);
void lcd_display_feed(const int16_t *stereo,size_t bytes);

/* Latest complete FPGA snapshot; copies without waiting for UART2. */
void lcd_display_submit(const uint8_t *frame);
