// Fade to zero before changing a live wavetable, then restore expression gain.
module timbre_fade(input clk,input rst,input ce,input [1:0] requested,
    input [7:0] gain_in,output reg [1:0] selected,output reg [7:0] gain_out);
    always @(posedge clk) begin
        if(rst) begin selected<=1; gain_out<=0; end
        else if(ce) begin
            if(selected!=requested) begin
                if(gain_out>4) gain_out<=gain_out-4;
                else begin gain_out<=0; selected<=requested; end
            end else if(gain_out<gain_in) begin
                if(gain_in-gain_out>4) gain_out<=gain_out+4; else gain_out<=gain_in;
            end else if(gain_out>gain_in) begin
                if(gain_out-gain_in>4) gain_out<=gain_out-4; else gain_out<=gain_in;
            end
        end
    end
endmodule
