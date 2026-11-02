`timescale 1ns/1ps
module tb_audio;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,gate=0;
    reg [11:0] gates=0;
    reg test_mode=0;
    reg [15:0] a=1024,d=32,s=40000,r=64;
    wire ce,bclk,ws,sd;
    wire [191:0] samples;
    wire signed [15:0] mix,out;
    voice_bank bank(clk,rst,ce,gates,test_mode,1'b0,9'sd0,a,d,s,r,samples);
    mixer mixer0(clk,rst,samples,8'd192,mix);
    audio_effect effect(clk,rst,ce,1'b0,2'b0,mix,out);
    i2s_tx tx(clk,rst,out,bclk,ws,sd,ce);
    integer fd,n;
    initial begin
        fd=$fopen("build/audio_samples.txt","w");
        repeat(8) @(negedge clk); rst=0;
        repeat(5) @(posedge ce);
        if(out!==0) $fatal(1,"startup not silent");
        test_mode=1;
        for(n=0;n<24000;n=n+1) begin
            @(posedge ce); #1;
            if(^out===1'bx) $fatal(1,"unknown audio");
            $fdisplay(fd,"%0d",out);
        end
        test_mode=0;
        repeat(1200) @(posedge ce);
        if(out!==0) $fatal(1,"release not silent");
        gates=12'h091; // C,E,G
        repeat(100) @(posedge ce);
        if(bank.voices[0].v.env==0 || bank.voices[4].v.env==0 || bank.voices[7].v.env==0)
            $fatal(1,"independent chord voices missing");
        if(bank.voices[1].v.env!==0) $fatal(1,"ungated voice active");
        $fclose(fd); $display("PASS audio: 12-voice capture, chord independence, release"); $finish;
    end
    initial begin #160000000; $fatal(1,"audio timeout"); end
endmodule
