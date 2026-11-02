`timescale 1ns/1ps
module tb_fade;
    reg clk=0; always #5 clk=~clk;
    reg rst=1; reg [1:0] requested=1; reg [7:0] target=192;
    wire [1:0] selected; wire [7:0] gain;
    reg [1:0] old_selected; reg [7:0] old_gain;
    integer i;
    timbre_fade dut(clk,rst,1'b1,requested,target,selected,gain);
    initial begin
        repeat(4) @(negedge clk); rst=0;
        repeat(60) @(negedge clk);
        if(gain!==192) $fatal(1,"fade up");
        requested=2;
        for(i=0;i<110;i=i+1) begin
            old_selected=selected; old_gain=gain; @(negedge clk);
            if(selected!=old_selected && gain!=0) $fatal(1,"nonzero switch");
            if(gain>old_gain+4 || old_gain>gain+4) $fatal(1,"abrupt gain");
        end
        if(selected!==2 || gain!==192) $fatal(1,"switch completion");
        $display("PASS fade: zero-gain timbre switch and bounded ramp"); $finish;
    end
endmodule
