`timescale 1ns/1ps
module tb_expression_update;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,ce=0,test_mode=0;
 reg [31:0] gates=0;
 reg signed [8:0] pitch=0;
 wire signed [15:0] audio,old_audio;
 wire done,old_done,overrun,old_overrun;
 wire [31:0] active,old_active;
 engine32 #(.NORMAL_SHIFT(10),.PITCH_SHIFT(9)) dut(clk,rst,ce,gates,test_mode,2'd0,pitch,
  16'd8192,16'd32,16'd50000,16'd1024,8'd192,audio,done,overrun,active,,,,);
 engine32 old(clk,rst,ce,gates,test_mode,2'd0,pitch,
  16'd8192,16'd32,16'd50000,16'd1024,8'd192,old_audio,old_done,old_overrun,old_active,,,,);
 integer i,expected,clipped=0,peak=0,old_peak=0,mag;
 reg [31:0] before_phase,expected_inc;
 reg signed [41:0] delta;
 task frame; begin
  @(negedge clk); ce=1; @(negedge clk); ce=0;
  repeat(60) @(negedge clk);
  if(overrun || old_overrun || ^audio===1'bx) $fatal(1,"deadline/unknown");
  expected=$signed(dut.product)>>>(test_mode?13:10);
  if(expected>32767) begin expected=32767; clipped=clipped+1; end
  if(expected< -32768) begin expected=-32768; clipped=clipped+1; end
  if(audio!==expected) $fatal(1,"saturating scale %d %d",audio,expected);
 end endtask
 initial begin
  repeat(4) @(negedge clk); rst=0; gates=1;
  for(i=0;i<1024;i=i+1) begin
   frame;
   mag=audio<0?-audio:audio; if(mag>peak) peak=mag;
   mag=old_audio<0?-old_audio:old_audio; if(mag>old_peak) old_peak=mag;
  end
  if(peak<old_peak*8-8 || peak>old_peak*8+8) $fatal(1,"single voice gain");
  if(clipped!=0) $fatal(1,"single voice clipped");
  pitch=-207; frame; before_phase=dut.lanes[0].lane.phases[0];
  delta=$signed({1'b0,dut.lanes[0].lane.frequencies[0]})*pitch;
  expected_inc=dut.lanes[0].lane.frequencies[0]+(delta>>>9);
  frame; if(dut.lanes[0].lane.phases[0]-before_phase!==expected_inc) $fatal(1,"expanded bend");
  pitch=0; gates=32'hffffffff;
  for(i=0;i<2000;i=i+1) frame;
  // Align both engines again; test mode must be bit-identical to legacy.
  rst=1; repeat(4) @(negedge clk); rst=0; test_mode=1; pitch=200;
  for(i=0;i<2048;i=i+1) begin frame; if(audio!==old_audio) $fatal(1,"test tone changed"); end
  $display("PASS expression: 8x single amplitude peak=%0d old=%0d, signed wider bend, saturated mix, unchanged test audio; clipped frames=%0d",peak,old_peak,clipped);
  $finish;
 end
 initial begin #10000000; $fatal(1,"timeout"); end
endmodule
