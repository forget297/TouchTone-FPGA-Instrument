# 触韵多音色交互电子乐器 全部代码提交包

整理日期：2026-10-28。FPGA选用R13a，ESP32选用R13英文版 v0.7.0，手机App为v0.5.0。
本文件是提交包的版本入口。模块内历史README用于追溯；若与当前功能描述冲突，以本文件、实际源码及最新验证记录为准。

## 目录

|目录|内容|入口|
|---|---|---|
|01_FPGA_R13a|Verilog源码、约束、波表、仿真及生成脚本|rtl/top.v、fpga_instrument.gprj、build.tcl|
|02_ESP32_EN|BLE桥接、I2S录音、英文显示及协议解析|main/ble_echo.c、CMakeLists.txt|
|03_Android_v05|Android Java源码、资源、测试与原构建脚本|src、AndroidManifest.xml、build.py|
|04_Serial_Display|原配套串口屏HMI工程及接线说明|instrument_display.HMI|
|05_Firmware|实际生成的FPGA码流与ESP32合并固件|.fs与.bin|
|06_Score_Test|32事件曲谱及串口调试数据|score_upload_test_32.json|
|07_Verification|现有仿真、布局布线、时序及目标构建报告|按模块分目录|
|08_Documentation|操作、32音频率及英文屏说明|Markdown文件|

## FPGA代码总结

- rtl/top.v：连接传感器、控制器、音频引擎、I2S、通信、曲谱与可视化模块。
- rtl/input：MPR121触摸和ADS1015采样、I2C、按键去抖、旋转编码器、键位映射及10项菜单。
- rtl/audio/engine32.v：32组独立相位、频率及包络状态；4条并行通路，每条处理8声部。
- rtl/audio：波表合成、ADSR、音色补偿、混音与16,384采样点延迟；.hex是必需的ROM数据，应保留。
- rtl/output：I2S实时音频发送及脱机曲谱LED指引。
- rtl/comm：UART接收发送、BLE指令处理、控制回复和可视化数据包复用。
- rtl/visual/visual_monitor.v：最终PCM波形、1024点Hann窗DFT、延时XY图和声部参数快照。
- sim与tools：自检测试平台、波表生成、音频分析和构建辅助脚本。

音频采样率46,875 Hz，系统时钟27 MHz；4种音色；支持C4～G6本地32音试听与同时发声。
所有实时音频由FPGA合成；ESP32和手机不承担逐样本声音合成。

## ESP32与手机代码总结

- ble_echo.c：BLE服务与UART控制桥接。
- recorder.c：监听FPGA I2S，缓存录音并回传。
- visual_protocol.c：快照分包、CRC、丢包及重组处理。
- lcd_display.c：四种英文显示视图与ASCII绘图。
- wave_view.c：配套波形处理逻辑。
- Android src：蓝牙交互、音符控制、曲谱上传读回、键位设置及WAV录音处理；具体界面与协议均可查阅Java源文件。
- HMI采用原配套page0/s0工程；屏幕英文标题和图形由ESP32实时绘制。

## 编译与运行

### FPGA
安装Gowin V1.9.11.03 Education或兼容版本，器件GW2AR-LV18QN88C8/I7。
进入01_FPGA_R13a，打开fpga_instrument.gprj，或在Gowin命令环境运行：

    gw_sh build.tcl

仿真需要Python和Icarus Verilog；从FPGA目录执行：

    python tools/run_tests.py tb_led_menu_r13a tb_score_upload_file

其他测试可按sim目录的testbench名称传入。Windows若Icarus需要后端位置，可设置IVERILOG_BASE。
脚本会生成build目录；原有构建缓存已剔除。历史工具脚本可能引用原开发机路径，请优先使用以上入口。

### ESP32
使用ESP-IDF v6.0.2，目标ESP32-S3；在已激活IDF环境的终端进入02_ESP32_EN：

    idf.py set-target esp32s3
    idf.py build

保留sdkconfig和sdkconfig.defaults，硬件为N16R8。烧录前检查Flash 16MB、DIO 40MHz和八线PSRAM设置。
已生成的合并.bin从0x0写入；详情见05_Firmware/ESP32_FLASH_README.md。
本包不包含ESP-IDF、工具链及第三方SDK安装文件。

### Android
原工程使用Python构建脚本、JDK17及Android SDK34，不依赖Gradle/Maven。
设置FPGA_JAVA_HOME和FPGA_ANDROID_SDK后，从03_Android_v05运行python build.py。
原脚本期望SDK布局为build-tools/android-14及platform/android-34/android.jar；标准SDK目录名称不同，应按本机安装修改build.py中TOOLS和ANDROID两行。
本地机器路径配置local_tools.json和签名私钥未打包。构建脚本首次运行会生成新的本地调试签名，重新构建APK可能无法覆盖安装原签名版本。
原有APK保留在03_Android_v05，供与此前已生成版本核对。

### 串口屏
使用对应淘晶驰编辑器打开04_Serial_Display/instrument_display.HMI，按原800×480屏型号生成屏幕工程。
ESP32英文界面源代码位于02_ESP32_EN/main；不要把HMI工程和ESP32固件混为同一烧录对象。

## 现有验证范围
R13基线12项HDL测试、R13a新增LED及曲谱2项测试通过；ESP32英文界面主机测试和本次目标编译通过。
本次未修改产品逻辑源码；重新构建英文ESP32固件并执行英文显示主机测试，未执行硬件烧录测试。归档的FPGA报告为对应版本的既有记录。
整机延迟、32音实际频谱、英文实屏和BLE录音并发仍应按实物验收记录判定。
上传曲谱为32事件，保存在易失性存储，断电不保留；不等同于已实现云端曲库。

## 文件完整性
MANIFEST_SHA256.json记录除该清单自身之外的每个文件的大小和SHA256。
RAR使用标准RAR4存储方式（不压缩），仍是真正RAR格式，文件大小低于200MB；已做独立解包及逐文件SHA256核对。
不包含编译缓存、SDK、签名私钥及版本库历史；包含重建本项目所需的产品源码和ROM资源。
