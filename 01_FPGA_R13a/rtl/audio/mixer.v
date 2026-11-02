module mixer(input clk, input rst, input [191:0] samples,
    input [7:0] gain, output reg signed [15:0] sample);
    integer i;
    reg signed [19:0] sum;
    reg signed [28:0] scaled;
    always @* begin
        sum=0;
        for(i=0;i<12;i=i+1) sum=sum+$signed(samples[i*16+:16]);
    end
    always @(posedge clk) begin
        if(rst) begin scaled<=0; sample<=0; end
        else begin
            scaled<=sum*$signed({1'b0,gain});
            // /16 headroom for twelve voices, /256 gain. No wraparound.
            sample<=scaled>>>12;
        end
    end
endmodule
