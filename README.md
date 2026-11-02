触韵多音色交互电子乐器

基于 Sipeed Tang Nano 20K 的实时多音色 FPGA 电子乐器。

项目功能

- 电容触摸选音、压力控制和摇杆表情控制
- FPGA HDL 实时音频合成
- 32声部合成架构与多音色切换
- ADSR包络、实时混音与延迟效果
- I2S数字音频输出
- 英文串口屏波形、频谱、XY轨迹及声部状态显示
- 手机App蓝牙演奏、键位设置和曲谱传输
- 数字音频录制与回传
- LED曲目指引

工程组成

- 01_FPGA_R13a：FPGA工程
- 02_ESP32_EN：ESP32英文屏固件
- 03_Android_v05：Android应用
- 04_Serial_Display：串口屏工程资料
- 05_Firmware：烧录文件
- 06_Score_Test：曲谱测试文件
- 07_Verification：验证资料
- 08_Documentation：项目文档
- 09_Visual_Tests：可视化测试

具体编译与使用方法见《README_代码总览与编译说明.md》。
性能测试条件及结果以仓库内验证资料为准。
