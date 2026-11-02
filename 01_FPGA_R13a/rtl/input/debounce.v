module debounce #(parameter ACTIVE_LOW=1)(input clk,input rst,input tick_ms,
    input pin,output reg pressed,output reg pulse);
    reg [1:0] sync;
    reg [3:0] count;
    wire active=ACTIVE_LOW ? !sync[1] : sync[1];
    always @(posedge clk) begin
        sync<={sync[0],pin}; pulse<=0;
        if(rst) begin sync<=ACTIVE_LOW?3:0; pressed<=0; count<=0; pulse<=0; end
        else if(tick_ms) begin
            if(active==pressed) count<=0;
            else if(count==9) begin pressed<=active; pulse<=active; count<=0; end
            else count<=count+1'b1;
        end
    end
endmodule
