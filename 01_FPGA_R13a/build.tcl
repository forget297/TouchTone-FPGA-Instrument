# Run from the project root with Gowin gw_sh build.tcl
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
# Explicit list avoids Tcl glob resolving Windows Documents junction incorrectly.
foreach f {
rtl/audio/adsr.v rtl/audio/audio_effect.v rtl/audio/engine32.v
rtl/audio/mixer.v rtl/audio/phase_accumulator.v rtl/audio/timbre_fade.v
rtl/audio/voice.v rtl/audio/voice_bank.v rtl/audio/waveform_generator.v
rtl/clock/clock_gen.v rtl/input/ads1015_ctrl.v rtl/input/controls_extended.v
rtl/input/debounce.v rtl/input/encoder.v rtl/input/i2c_byte.v
rtl/input/i2c_master.v rtl/input/key_remap.v rtl/input/input_mapper.v rtl/input/mpr121_ctrl.v
rtl/input/sensor_hub.v rtl/input/user_controls.v rtl/output/guide_extended.v
rtl/comm/uart_rx.v rtl/comm/uart_tx.v rtl/comm/ble_notes.v
rtl/output/i2s_tx.v rtl/output/led_guide.v rtl/output/song_guide.v rtl/top.v
} { add_file -type verilog $f }
add_file -type cst constraints/tang_nano_20k.cst
add_file -type sdc constraints/timing.sdc
set_option -top_module top
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -output_base_name fpga_instrument_r13a_led
add_file -type verilog rtl/visual/visual_monitor.v
add_file -type verilog rtl/comm/uart_packet_mux.v
run all
