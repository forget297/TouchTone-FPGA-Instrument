#pragma once
#include <stdint.h>
#include <stddef.h>
enum { VISUAL_BYTES=736, VISUAL_PACKET=42 };
typedef void (*visual_reply_fn)(const uint8_t *,size_t);
typedef void (*visual_frame_fn)(const uint8_t *);
void visual_protocol_init(visual_reply_fn reply,visual_frame_fn frame);
void visual_protocol_feed(const uint8_t *data,size_t length);
uint16_t visual_crc16(const uint8_t *data,size_t length);
