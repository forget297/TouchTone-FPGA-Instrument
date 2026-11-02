`timescale 1ns/1ps
module tb_guide_extended;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,tick=0,enable=1,playing=1,practice=0,restart=0;
    reg [1:0] song=0;
    reg [7:0] bpm=120;
    reg [11:0] keys=0;
    wire [11:0] lights; wire [5:0] step; wire correct;
    guide_extended dut(clk,rst,tick,enable,playing,practice,restart,song,bpm,keys,lights,step,correct,1'b0,8'd0);
    task ms; input integer n; begin
        tick=1; repeat(n) @(negedge clk); tick=0;
    end endtask
    task reset_score; begin restart=1; @(negedge clk); restart=0; end endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        #1; if(lights!==1) $fatal(1,"first note");
        ms(499); if(step!==0) $fatal(1,"early beat");
        ms(1); if(step!==1) $fatal(1,"120 BPM");
        playing=0; ms(1000); if(step!==1) $fatal(1,"pause");
        playing=1; song=1; reset_score;
        #1; if(lights!==16) $fatal(1,"song select");
        bpm=60; ms(999); if(step!==0) $fatal(1,"slow early");
        ms(1); if(step!==1) $fatal(1,"60 BPM");
        practice=1; reset_score; ms(2000);
        if(step!==0) $fatal(1,"practice must wait");
        keys=1; repeat(3) @(negedge clk);
        if(step!==0) $fatal(1,"wrong note advanced");
        keys=16; repeat(3) @(negedge clk);
        if(step!==1) $fatal(1,"correct note did not advance");
        ms(1000); if(step!==1) $fatal(1,"held repeated note advanced");
        keys=0; repeat(3) @(negedge clk); keys=16; repeat(3) @(negedge clk);
        if(step!==2) $fatal(1,"repeated note needs new edge");
        practice=0; song=2; bpm=180; reset_score;
        ms(11000); if(step>31) $fatal(1,"score bounds");
        $display("PASS guide: three scores, tempo, pause, restart, correct-note practice"); $finish;
    end
endmodule
