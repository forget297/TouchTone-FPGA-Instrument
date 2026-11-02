module led_guide(input clk, input rst, input [15:0] lights,
    output reg ser, output reg srclk, output reg rclk);
    reg [15:0] shift;
    reg [15:0] divider;
    reg [5:0] step;
    always @(posedge clk) begin
        if(rst) begin ser<=0; srclk<=0; rclk<=0; shift<=0; divider<=0; step<=0; end
        else if(divider==269) begin
            divider<=0;
            if(step==0) begin shift<=lights; rclk<=0; step<=1; end
            else if(step<=32) begin
                if(step[0]) begin ser<=shift[15]; srclk<=0; end
                else begin srclk<=1; shift<={shift[14:0],1'b0}; end
                step<=step+1'b1;
            end else if(step==33) begin srclk<=0; rclk<=1; step<=34; end
            else begin rclk<=0; step<=0; end
        end else divider<=divider+1'b1;
    end
endmodule
