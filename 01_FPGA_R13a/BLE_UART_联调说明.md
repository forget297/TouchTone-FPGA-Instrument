# R5 BLE-UART 联调说明

本工程由 `fpga_instrument_r4` 原样复制后增加 UART 联调通道。原有音频、传感器、灯光和调试输出保持不变。

## 接口

- 串口：115200 bit/s，8 数据位，1 停止位，无校验（8N1）。
- FPGA `ble_uart_rx`：丝印/封装脚 52（官方 J5 pin 20），连接 ESP32-S3 TX。
- FPGA `ble_uart_tx`：丝印/封装脚 53（官方 J5 pin 19），连接 ESP32-S3 RX。
- 两块板必须共地，数字电平均为 3.3V。
- 52/53 与 HDMI 的 EDID/DDC 电路复用，使用此版本时不要插 HDMI 线。
- 初次联调时两块板各自用 USB 供电，不连接彼此的 3V3 或 5V。

本阶段 FPGA 会逐字节回送收到的数据，用于验证“手机→BLE→ESP32→UART→FPGA→UART→ESP32→BLE→手机”链路。UART 与音频实时路径相互独立。

## 构建

在本工程根目录、可调用 Gowin `gw_sh` 的终端执行：

```text
gw_sh build.tcl
```

预期主要输出：

```text
impl/pnr/fpga_instrument_r5_ble.fs
impl/pnr/fpga_instrument_r5_ble.rpt.txt
```

先用 SRAM Program 下载测试。联调通过前不要覆盖 R4 的 Flash 启动固件。
