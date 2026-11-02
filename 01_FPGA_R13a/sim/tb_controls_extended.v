`timescale 1ns/1ps
module tb_controls_extended;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,a=1,b=1,enc=1,joy=1,mode_pin=0;
    wire [1:0] timbre,mode,wet,song;
    wire [3:0] menu;
    wire pressure,ensemble,playing,practice,restart;
    wire [15:0] attack,decay,sustain,release_step;
    wire [7:0] bpm;
    controls_extended dut(clk,rst,1'b1,1'b1,a,b,enc,joy,mode_pin,
        timbre,menu,mode,pressure,ensemble,attack,decay,sustain,release_step,wet,
        song,bpm,playing,practice,restart,,,,,);
    task wait20; begin repeat(20) @(negedge clk); end endtask
    task click; begin enc=0; wait20; enc=1; wait20; end endtask
    task rotate; begin a=0; b=1; repeat(600) @(negedge clk); b=0; repeat(600) @(negedge clk);
        a=1; repeat(600) @(negedge clk); b=1; repeat(600) @(negedge clk); end endtask
    task mode_click; begin mode_pin=1; wait20; mode_pin=0; wait20; end endtask
    integer i;
    initial begin
        wait20; rst=0; repeat(600) @(negedge clk);
        rotate; if(timbre!==2 || sustain!==0) $fatal(1,"pluck preset");
        for(i=0;i<6;i=i+1) click;
        if(menu!==6) $fatal(1,"menu6");
        rotate; if(!ensemble) $fatal(1,"ensemble");
        mode_click; if(mode!==1) $fatal(1,"test mode");
        mode_click; if(mode!==2) $fatal(1,"guide mode");
        click; if(song!==1) $fatal(1,"song click");
        rotate; if(bpm!==130) $fatal(1,"tempo turn");
        enc=0; repeat(850) @(negedge clk); enc=1; wait20;
        if(!practice || song!==1) $fatal(1,"long press also selected song");
        joy=0; wait20; joy=1; wait20;
        if(playing) $fatal(1,"pause");
        mode_click; if(mode!==0) $fatal(1,"normal mode");
        joy=0; wait20; joy=1; wait20;
        if(pressure) $fatal(1,"pressure toggle");
        $display("PASS extended controls: presets, ensemble, song/tempo, long press, pause"); $finish;
    end
endmodule
