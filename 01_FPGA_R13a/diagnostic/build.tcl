# Run gw_sh build.tcl with this diagnostic directory as current directory.
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
add_file -type verilog encoder_diagnostic.v
add_file -type verilog ../rtl/input/encoder.v
add_file -type verilog ../rtl/clock/clock_gen.v
add_file -type cst encoder_diagnostic.cst
add_file -type sdc ../constraints/timing.sdc
set_option -top_module encoder_diagnostic
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -output_base_name encoder_diagnostic_a77_b41
run all
