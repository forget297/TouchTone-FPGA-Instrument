`timescale 1ns/1ps
module tb_timbre_comp;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,ce=0,test_mode=0;
 reg [31:0] gates=1;
 reg [1:0] timbre=0;
 wire signed [15:0] audio,reference_audio;
 wire done,rdone,overrun,roverrun;
 wire [31:0] active,ractive;
 engine32 #(.NORMAL_SHIFT(10),.PITCH_SHIFT(9),.TIMBRE_COMP(1)) dut(clk,rst,ce,gates,test_mode,timbre,9'sd0,
  16'd8192,16'd2,16'd49152,16'd4,8'd192,audio,done,overrun,active,,,,);
 engine32 #(.NORMAL_SHIFT(10),.PITCH_SHIFT(9)) reference_engine(clk,rst,ce,gates,test_mode,timbre,9'sd0,
  16'd8192,16'd2,16'd49152,16'd4,8'd192,reference_audio,rdone,roverrun,ractive,,,,);
 integer i,t,peak,ref_peak,factor,mag,clips=0;
 reg signed [63:0] expected;
 task frame; begin
  @(negedge clk); ce=1; @(negedge clk); ce=0;
  repeat(60) @(negedge clk);
  if(overrun || roverrun || ^audio===1'bx) $fatal(1,"deadline/unknown");
  expected=$signed(dut.product);
  if(!test_mode) case(timbre)
   0: expected=expected*3;
   1: expected=expected+(expected>>>2);
   2: expected=expected*2;
   3: expected=expected*4+(expected>>>1);
  endcase
  expected=expected>>>(test_mode?13:10);
  if(expected>32767) begin expected=32767; clips=clips+1; end
  if(expected< -32768) begin expected=-32768; clips=clips+1; end
  if(audio!==expected) $fatal(1,"gain/saturation");
 end endtask
 initial begin
  repeat(4) @(negedge clk); rst=0;
  for(t=0;t<4;t=t+1) begin
   rst=1; repeat(4) @(negedge clk); rst=0; timbre=t; peak=0; ref_peak=0;
   for(i=0;i<1024;i=i+1) begin
    frame;
    
    mag=audio<0?-audio:audio; if(mag>peak) peak=mag;
    mag=reference_audio<0?-reference_audio:reference_audio; if(mag>ref_peak) ref_peak=mag;
   end
   factor=t==3?18:(t==1?5:(t==0?12:8));
   if(peak<ref_peak*factor/4-factor || peak>ref_peak*factor/4+factor) $fatal(1,"timbre ratio %d",t);
   $display("timbre %0d peak %0d reference %0d quarter-factor %0d",t,peak,ref_peak,factor);
  end
  if(clips!=0) $fatal(1,"single note clipped");
  gates=32'hffffffff;
  repeat(2048) frame;
  if(clips==0) $fatal(1,"stress saturation not exercised");
  test_mode=1;
  repeat(1024) begin frame; if(audio!==reference_audio) $fatal(1,"test gain changed"); end
  $display("PASS timbre compensation: sine3x organ1.25x pluck2x triangle4.5x, stress saturation, test unchanged"); $finish;
 end
endmodule
