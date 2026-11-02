// One-period mathematical lookup, never a recorded PCM phrase.
module waveform_generator(input clk, input [31:0] phase,
    input timbre, output reg signed [15:0] wave);
    reg signed [15:0] sine_rom [0:255];
    initial $readmemh("rtl/audio/sine.hex", sine_rom);
    wire [15:0] ramp = phase[31] ? ~phase[30:15] : phase[30:15];
    always @(posedge clk)
        if (timbre) wave <= $signed(ramp ^ 16'h8000);
        else wave <= sine_rom[phase[31:24]];
endmodule
