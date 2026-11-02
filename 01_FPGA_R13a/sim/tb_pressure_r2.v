`timescale 1ns/1ps
module tb_pressure_r2;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,test_mode=0,en=1;
    reg [11:0] p=1650;
    wire [7:0] gain; wire signed [8:0] pitch;
    input_mapper #(.PRESSURE_INVERT(1),.MIN_GAIN(128),.GAIN_SHIFT(4))
        dut(clk,rst,1'b1,p,12'd825,12'd825,en,test_mode,gain,pitch);
    task settle; begin repeat(300) @(negedge clk); end endtask
    initial begin
        repeat(5) @(negedge clk); rst=0; settle;
        if(gain!=128) $fatal(1,"idle floor");
        p=882; settle; if(gain!=176) $fatal(1,"mid force inverse");
        p=0; settle; if(gain!=224) $fatal(1,"full force inverse");
        p=4095; settle; if(gain!=128) $fatal(1,"input clamp");
        en=0; settle; if(gain!=192) $fatal(1,"pressure bypass");
        en=1; test_mode=1; settle; if(gain!=192) $fatal(1,"test override");
        $display("PASS pressure R2: reverse voltage mapping, 128 floor, 224 ceiling, bypass/test"); $finish;
    end
endmodule
