`timescale 1ns/1ps
module tb_effect_expanded;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,ce=0,enable=1;
 reg [1:0] wet=3;
 reg signed [15:0] dry=0;
 wire signed [15:0] audio;
 audio_effect #(.DELAY_BITS(14),.STRONG_WET(1)) dut(clk,rst,ce,enable,wet,dry,audio);
 integer i;
 task frame(input integer value); begin
  @(negedge clk); ce=1; dry=value;
  @(negedge clk); ce=0; repeat(3) @(negedge clk);
 end endtask
 initial begin
  repeat(4) @(negedge clk); rst=0;
  frame(20000); if(audio!==20000) $fatal(1,"dry");
  for(i=1;i<16384;i=i+1) begin frame(0); if(audio!==0) $fatal(1,"early/uninitialized echo"); end
  frame(20000); if(audio!==32767) $fatal(1,"positive saturation");
  for(i=0;i<16384;i=i+1) frame(-30000);
  frame(-30000); if(audio!==-32768) $fatal(1,"negative saturation");
  wet=1; frame(0); if(audio!==-15000) $fatal(1,"half echo");
  wet=2; frame(0); if(audio!==-22500) $fatal(1,"three-quarter echo");
  wet=3; frame(0); if(audio!==-30000) $fatal(1,"unity echo");
  enable=0; frame(1234); if(audio!==1234) $fatal(1,"test bypass");
  $display("PASS expanded delay: 16384 samples, .5/.75/1 wet, both saturation polarities, bypass"); $finish;
 end
endmodule
