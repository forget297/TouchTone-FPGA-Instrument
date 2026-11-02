`timescale 1ns/1ps
module tb_mixer;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg [191:0] samples;
    wire signed [15:0] sample;
    mixer dut(clk,rst,samples,8'd255,sample);
    initial begin
        samples={12{16'h7fff}}; repeat(3) @(negedge clk); rst=0;
        repeat(4) @(negedge clk);
        if(sample!=24479) $fatal(1,"positive sum %d",sample);
        samples={12{16'h8000}}; repeat(4) @(negedge clk);
        if(sample!=-24480) $fatal(1,"negative sum %d",sample);
        samples={6{32'h7fff8001}}; repeat(4) @(negedge clk);
        if(sample!=0) $fatal(1,"signed cancellation");
        $display("PASS mixer: twelve full-scale voices, negative sign, cancellation"); $finish;
    end
endmodule
