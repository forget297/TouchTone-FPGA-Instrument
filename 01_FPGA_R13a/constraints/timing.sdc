create_clock -name sys_clk -period 37.037 [get_ports {clk}]
# Asynchronous physical inputs are synchronized inside RTL.
# Keep timing analysis enabled; inspect all unconstrained paths in Gowin reports.
