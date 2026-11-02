`timescale 1ns/1ps
module tb_led;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    wire ser,srclk,rclk;
    reg [15:0] received=0;
    led_guide dut(clk,rst,16'h05a3,ser,srclk,rclk);
    always @(posedge srclk) received={received[14:0],ser};
    always @(posedge rclk) begin
        if(received!==16'h05a3) $fatal(1,"LED cascade order %h",received);
        $display("PASS LED: sixteen-bit chain/latch mapping"); $finish;
    end
    initial begin repeat(3) @(negedge clk); rst=0; #1000000; $fatal(1,"LED timeout"); end
endmodule
