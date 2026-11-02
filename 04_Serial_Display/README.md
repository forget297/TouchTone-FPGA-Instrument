# TJC串口屏当前工程入口

更新日期：2026-10-16。型号TJC8048X550_011C，800×480横屏，page0/s0曲线760×200、通道0；工程[instrument_display.HMI](instrument_display.HMI)。
当前屏幕连接ESP32 v06：GPIO8/TX→屏RX，GPIO9/RX←屏TX，GND共地，屏幕稳定5V供电；断开USB转TTL的TX/RX。自动识别9600/115200，运行115200。
完整接线和限制见[引脚速查](D:/FPGA创新赛/fpga_instrument_r12_balance/当前接线与引脚占用速查.md)，操作见[完整说明第16节](D:/FPGA创新赛/fpga_instrument_r12_balance/使用说明书.md)。
Nano55是音频WS，不用于LED，LED仍用31/48/49。当前是真实音频波形原型；李萨如和频谱尚未实现。
旧ESP32实时波形接线说明保留作历史参考；以本入口、主说明和v06_音量与波形稳定性.md为当前依据。本次未修改HMI或下载屏幕程序。
