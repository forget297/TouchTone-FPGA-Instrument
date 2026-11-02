> 最终英文屏版本更新：2026-10-28已重新完成ESP32 v0.7.0目标编译及镜像校验。以下历史记录中“尚未编译”的说明仅适用于当时状态。最终提交以根目录说明及07_Verification/ESP32_EN新日志为准。

> R13新增功能和当前验证状态请先阅读上一级 `README_使用与验收.md`。以下为原版本参考说明。ESP32 v07本次尚未完成目标固件编译。

# ESP32-S3 v06：BLE桥接、录音与串口屏波形

更新日期：2026-10-16。配套FPGA R12、App v0.5.0、TJC8048X550_011C；板卡N16R8，ESP-IDF v6.0.2。
完整操作以[FPGA R12使用说明书](D:/FPGA创新赛/fpga_instrument_r12_balance/使用说明书.md)为准；焊接时看[万能板焊接接线表](万能板焊接接线表.md)。

## 接线

| ESP32-S3脚号 | 对端 | 方向与用途 |
|---|---|---|
| GPIO17 | Nano52 | ESP TX→Nano RX，UART1，115200 8N1 |
| GPIO18 | Nano53 | ESP RX←Nano TX，UART1 |
| GPIO4 | Nano56 | 输入I²S BCLK |
| GPIO5 | Nano55 | 输入I²S WS/LRCLK |
| GPIO6 | Nano54 | 输入I²S DATA |
| GPIO8 | 屏幕RX | ESP UART2 TX→屏幕RX |
| GPIO9 | 屏幕TX | ESP UART2 RX←屏幕TX |
| GND | Nano GND、屏幕GND、相关供电地 | 公共信号地 |

## 电源与信号电平

- Nano、ESP32可分别USB供电，共GND；不要额外并联两块板的3V3或5V输出。
- MPR121、ADS1015、兼容摇杆/编码器及74HC595按本说明使用Nano侧3.3V；数字信号保持兼容3.3V。
- 串口屏使用稳定5V供电，不能用ESP32的3V3给屏幕供电；屏幕与ESP32共地。可保留已验证的USB转TTL供电和GND，但断开其TX/RX，或者使用独立稳定5V电源。
- 不把屏幕5V接入ESP GPIO、Nano GPIO或3V3；本文使用已验证TTL接口，不使用RS232电平。
- 喇叭接口J4为功放OUTP/OUTN，两端都不是GND。ESP32音频接Nano54/55/56数字信号，不能接J4。

Nano55已用于板载功放I²S WS和ESP GPIO5，不能移作595数据；LED仍为Nano31/48/49。屏幕GPIO8/9属于ESP，不是Nano编号。不把USB转TTL和ESP的TX同时接到屏幕RX。

## 屏幕与波形

已有HMI：`D:/ESP32_S3_N16R8/tjc_display_v01/instrument_display.HMI`，800×480横屏，page0/s0，760×200、通道0。v06自动识别9600/115200并运行于115200，不改HMI永久配置。
显示FPGA实际I²S输出，2048采样窗口选择760点约16.21ms；带滞回、亚采样插值和帧间形状匹配，幅度不自动归一化、不复用旧帧。实际刷新为若干帧/秒，不能把它当音频采样率。
屏幕支持ref_stop/ref_star的成功应答、addt握手和实时传输已验证，不宣称真正双缓冲。单音应较稳定，和弦/滑音/包络的真实变化仍会显示；无新PCM约1.2秒清图，有时钟但静音则显示中线。
当前由ESP抽取绘图点，尚未实现FPGA内部图形生成、李萨如或FFT。完整边界见主说明第16节。

## 录音与蓝牙

沿用32音BLE控制桥接及App v0.5协议。I²S输入Philips格式、左右各16位、46,875帧/秒、BCLK1.5MHz，左右相同，录左声道单声道WAV。
正常PSRAM缓存最长30秒；内部RAM回退约1秒。支持手动停止、CRC32、最多16包/窗口通知及兼容下载，App可播放/导出/删除。
唯一I²S任务管理空闲预览与连续录音，显示任务只消费最新窗口；预览恰逢录音请求可能多等待约44ms，无时钟单次读100ms超时，CRC计算时显示可暂时暂停。
断开BLE会请求停止并保留ESP最近缓存，ESP复位/掉电或新录音会覆盖该缓存；App已经保存的WAV不受影响。详细操作见主说明第15节。

## 构建、烧录与验证

```powershell
cd D:/ESP32_S3_N16R8/ble_display_bridge_v06
python ../idf_local.py -B build_local build
python ../idf_local.py -B build_local -p COM6 flash
```

COM6是此前识别端口，需以实际枚举为准。新输出在build_local；交付build_direct为预编译文件，原缓存含工作区路径，因此后续改源码用build_local。应用名仍为ble_uart_bridge.bin，要与本目录bootloader、partition_table配套。
本版复用了工作区缓存增量构建；主机测试覆盖真实recorder.c和波形边界/相位稳定性，见reports/host_tests_v06.log、build_v06.log。实际烧录和启动见reports/flash_v06.log、startup_v06.log，确认版本0.6.0、PSRAM自检、30秒缓存、广播、屏幕应答与实时帧。
新稳定性观感、30秒边界、断线取回和App删除管理专项仍待用户验收；完整状态见主说明第17节。需要回退时使用原ble_display_bridge_v05完整配套产物。
