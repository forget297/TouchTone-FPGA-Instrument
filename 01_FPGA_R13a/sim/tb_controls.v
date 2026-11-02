`timescale 1ns/1ps
module tb_controls;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg [11:0] pressure=0,x=825,y=825;
    reg pressure_enable=1,test_mode=0;
    wire [7:0] gain;
    wire signed [8:0] pitch;
    input_mapper map0(clk,rst,1'b1,pressure,x,y,pressure_enable,test_mode,gain,pitch);
    reg enc_sw=1,joy_sw=1,mode_button=0;
    wire timbre,pe;
    wire [3:0] menu;
    wire [1:0] mode,wet;
    wire [15:0] a,d,s,r;
    user_controls ui(clk,rst,1'b1,1'b1,1'b1,enc_sw,joy_sw,mode_button,
        timbre,menu,mode,pe,a,d,s,r,wet);
    task cycles(input integer n); begin repeat(n) @(negedge clk); end endtask
    initial begin
        cycles(4); rst=0; cycles(300);
        if(gain!=32 || pitch!=0) $fatal(1,"center/default");
        pressure=1600; x=1650; cycles(300);
        if(gain!=224 || pitch!=206) $fatal(1,"positive expression %d %d",gain,pitch);
        x=0; cycles(500); if(pitch!=-207) $fatal(1,"signed negative bend %d",pitch);
        test_mode=1; cycles(300); if(pitch!=0 || gain!=192) $fatal(1,"test override");
        enc_sw=0; cycles(3); enc_sw=1; cycles(20);
        if(menu!=0) $fatal(1,"debounce noise");
        enc_sw=0; cycles(15); if(menu!=1) $fatal(1,"menu press");
        cycles(20); if(menu!=1) $fatal(1,"held button repeating");
        enc_sw=1; cycles(15); mode_button=1; cycles(15);
        if(mode!=1) $fatal(1,"mode high-active");
        joy_sw=0; cycles(15); if(pe!=0) $fatal(1,"pressure toggle");
        $display("PASS controls: signed bend/gain/test override/debounce/menu/mode"); $finish;
    end
endmodule
