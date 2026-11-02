#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
typedef int esp_err_t;
typedef void *QueueHandle_t;
#define ESP_OK 0
#define pdMS_TO_TICKS(x) (x)
#define pdTRUE 1
#define pdPASS 1
#define UART_NUM_2 2
#define UART_DATA_8_BITS 8
#define UART_PARITY_DISABLE 0
#define UART_STOP_BITS_1 1
#define UART_HW_FLOWCTRL_DISABLE 0
#define UART_SCLK_DEFAULT 0
#define UART_PIN_NO_CHANGE -1
#define ESP_LOGI(...) ((void)0)
#define ESP_LOGW(...) ((void)0)
#define ESP_LOGE(...) ((void)0)
typedef struct {int baud_rate,data_bits,parity,stop_bits,flow_ctrl,source_clk;} uart_config_t;
int uart_write_bytes(int,const void *,size_t);
static int uart_wait_tx_done(int a,int b){return 0;}
static int uart_read_bytes(int a,void*b,size_t c,int d){return 0;}
static int uart_flush_input(int a){return 0;}
static int uart_set_baudrate(int a,int b){return 0;}
static int uart_driver_install(int a,int b,int c,int d,void*e,int f){return 0;}
static int uart_param_config(int a,const uart_config_t*b){return 0;}
static int uart_set_pin(int a,int b,int c,int d,int e){return 0;}
static const char*esp_err_to_name(int a){return "stub";}
static int64_t esp_timer_get_time(void){static int64_t t;t+=1000;return t;}
static void vTaskDelay(int a){}
static QueueHandle_t xQueueCreate(int a,size_t b){return (void*)1;}
static int xQueueReceive(QueueHandle_t a,void*b,int c){return 0;}
static int xQueueOverwrite(QueueHandle_t a,const void*b){return 1;}
static void vQueueDelete(QueueHandle_t a){}
static int xTaskCreate(void(*a)(void*),const char*b,int c,void*d,int e,void*f){return 1;}
