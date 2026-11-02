// 27MHz / (18 * 32) = 46875 stereo frames/s; 16-bit slots.
// WS changes one bit BEFORE each MSB; data changes only on falling BCLK.
module i2s_tx(input clk, input rst, input signed [15:0] sample,
    output reg bclk, output reg ws, output reg sd, output reg sample_ce);
    reg [3:0] div;
    reg [4:0] bit_index;
    reg [15:0] frame;
    always @(posedge clk) begin
        if(rst) begin div<=0; bit_index<=31; bclk<=0; ws<=1;
            sd<=0; sample_ce<=0; frame<=0; end
        else begin
            sample_ce<=0;
            if(div==8) begin
                div<=0; bclk<=~bclk;
                if(bclk) begin
                    bit_index<=bit_index+1'b1;
                    // old index 31 -> next is left MSB (0).
                    if(bit_index==30) begin ws<=0; frame<=sample; sample_ce<=1; end
                    if(bit_index==14) ws<=1;
                    if(bit_index==31 || bit_index==15) sd<=frame[15];
                    else sd<=frame[14-bit_index[3:0]];
                end
            end else div<=div+1'b1;
        end
    end
endmodule
