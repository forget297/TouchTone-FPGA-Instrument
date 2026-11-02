// ADS1015 default: +/-4.096V, 3300 SPS, single-shot, comparator disabled.
// ADS1115 uses 860 SPS (same DR=111), >=1.5ms wait in hub.
module ads1015_ctrl #(parameter ADC_IS_ADS1115=0)(input [1:0] channel,
    input [15:0] raw, output [15:0] config_word, output [11:0] value);
    assign config_word=16'hc3e3 | ({14'b0,channel}<<12);
    // Normalize both devices to positive 12-bit left-aligned scale /16.
    // 3.3V -> about 1650 counts with +/-4.096V full scale.
    assign value=raw[15]?12'd0:raw[15:4];
endmodule
