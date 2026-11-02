// Single synchronous clock domain. No fabric-generated internal clocks.
module clock_gen(input clk, input reset_button, output rst, output reg tick_ms);
    reg [1:0] reset_sync=0;
    reg [19:0] startup=0;
    reg [14:0] ms_count=0;
    always @(posedge clk) begin
        reset_sync<={reset_sync[0],reset_button};
        if(!(&startup)) startup<=startup+1'b1;
        if(rst) begin ms_count<=0; tick_ms<=0; end
        else begin
            tick_ms<=0;
            if(ms_count==26999) begin ms_count<=0; tick_ms<=1; end
            else ms_count<=ms_count+1'b1;
        end
    end
    assign rst = !(&startup) | reset_sync[1];
endmodule
