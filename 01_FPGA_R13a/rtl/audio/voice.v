module voice(input clk, input rst, input ce, input gate,
    input [31:0] fcw, input timbre,
    input [15:0] attack_step, decay_step, sustain, release_step,
    output reg signed [15:0] sample);
    wire [31:0] phase;
    wire [15:0] env;
    wire signed [15:0] wave;
    reg signed [32:0] product;
    phase_accumulator osc(clk,rst,ce,fcw,phase);
    adsr envelope(clk,rst,ce,gate,attack_step,decay_step,sustain,release_step,env);
    waveform_generator waveform(clk,phase,timbre,wave);
    // Pipeline runs at system clock; settles well before the next sample strobe.
    always @(posedge clk) begin
        if (rst) begin product<=0; sample<=0; end
        else begin product<=wave*$signed({1'b0,env}); sample<=product>>>16; end
    end
endmodule
