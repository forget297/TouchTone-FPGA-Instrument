`timescale 1ns/1ps
module tb_encoder_diagnostic;
    reg clk=0; always #5 clk=~clk;
    reg reset_button=0; reg [1:0] ab=3;
    wire [5:0] led_n; wire pa,bclk,ws,sd;
    encoder_diagnostic dut(clk,reset_button,ab[1],ab[0],led_n,pa,bclk,ws,sd);
    task state; input [1:0] value; begin ab=value; repeat(600) @(negedge clk); end endtask
    task clear; begin reset_button=1; repeat(8) @(negedge clk);
        reset_button=0; repeat(600) @(negedge clk); end endtask
    initial begin
        wait(!dut.rst); repeat(600) @(negedge clk);
        if(led_n!==6'b111100 || pa || bclk || ws || sd) $fatal(1,"startup/audio mute");
        state(1); state(0); state(2); state(3);
        if(led_n!==6'b100000) $fatal(1,"forward indicators %b",led_n);
        repeat(4000) @(negedge clk);
        if(led_n!==6'b100000) $fatal(1,"history not sticky");
        clear;
        if(led_n!==6'b111100) $fatal(1,"S2 clear");
        state(2); state(0); state(1); state(3);
        if(led_n!==6'b010000) $fatal(1,"reverse indicators");
        $display("PASS diagnostic: raw levels, sticky A/B and direction history, S2 clear, amp disabled"); $finish;
    end
    initial begin #20000000; $fatal(1,"diagnostic timeout"); end
endmodule
