`timescale 1ns/1ps
module tb_effect;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,ce=0;
    reg signed [15:0] dry=0;
    wire signed [15:0] out;
    audio_effect dut(clk,rst,ce,1'b1,2'd3,dry,out);
    integer n;
    task sample(input integer v); begin
        @(negedge clk); dry=v; ce=1;
        @(negedge clk); ce=0;
        repeat(3) @(negedge clk);
    end endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        sample(20000); if(out!=20000) $fatal(1,"dry impulse");
        for(n=1;n<4096;n=n+1) begin sample(0); if(out!==0) $fatal(1,"uninitialized delay %d",n); end
        sample(0); if(out!=10000) $fatal(1,"echo offset/gain %d",out);
        sample(0); if(out!=0) $fatal(1,"echo width");
        $display("PASS effect: no uninitialized audio, 4096-sample echo"); $finish;
    end
endmodule
