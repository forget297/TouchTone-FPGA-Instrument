module voice_bank(input clk, input rst, input ce, input [11:0] gates,
    input test_mode, input timbre, input signed [8:0] pitch,
    input [15:0] attack_step, decay_step, sustain, release_step,
    output [191:0] samples);
    reg [31:0] fcw_rom [0:11];
    initial $readmemh("rtl/audio/fcw.hex",fcw_rom);
    genvar k;
    generate for(k=0;k<12;k=k+1) begin: voices
        // Test frequencies 300,400,...1400 Hz. All twelve are independent voices.
        localparam [31:0] TEST_FCW = (64'd4294967296*(300+k*100))/46875;
        wire [31:0] base = test_mode ? TEST_FCW : fcw_rom[k];
        wire signed [40:0] delta = $signed({1'b0,base}) * pitch;
        wire [31:0] tuned = test_mode ? base : base + (delta >>> 11);
        voice v(clk,rst,ce,test_mode|gates[k],tuned,test_mode?1'b0:timbre,
            attack_step,decay_step,sustain,release_step,samples[k*16+:16]);
    end endgenerate
endmodule
