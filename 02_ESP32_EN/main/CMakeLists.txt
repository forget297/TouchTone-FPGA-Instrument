idf_component_register(SRCS "ble_echo.c" "recorder.c" "lcd_display.c" "wave_view.c" "visual_protocol.c"
                       PRIV_REQUIRES bt nvs_flash esp_driver_uart esp_driver_i2s esp_timer
                       INCLUDE_DIRS ".")
