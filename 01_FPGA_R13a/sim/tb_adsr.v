`timescale 1ns/1ps
module tb_adsr;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,gate=0;
    wire [15:0] level;
    adsr dut(clk,rst,1'b1,gate,16'd10000,16'd5000,16'd20000,16'd3000,level);
    integer i;
    task cycles(input integer n); begin repeat(n) @(negedge clk); end endtask
    initial begin
        cycles(3); rst=0; gate=1; cycles(8);
        if(level!=65535) $fatal(1,"attack saturation: %d",level);
        cycles(12); if(level!=20000) $fatal(1,"sustain");
        gate=0; cycles(9); if(level!=0) $fatal(1,"release");
        gate=1; cycles(4); gate=0; cycles(2); gate=1; cycles(20);
        if(level!=20000) $fatal(1,"retrigger");
        $display("PASS ADSR: attack/decay/sustain/release/retrigger"); $finish;
    end
endmodule
