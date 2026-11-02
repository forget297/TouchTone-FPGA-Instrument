#pragma once
#include "host/ble_hs.h"
void recorder_init(void);
void recorder_disconnect(void);
void recorder_notify_link(uint16_t conn,uint16_t handle,bool enabled);
int recorder_access(uint16_t conn,uint16_t attr,struct ble_gatt_access_ctxt *ctxt,void *arg);
