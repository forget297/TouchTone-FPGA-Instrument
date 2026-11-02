`timescale 1ns/1ps
module tb_delay_schedule;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,ce=0,enable=1; reg [1:0] wet=3;
 reg signed [15:0] dry=0;
 wire signed [15:0] audio;
 audio_effect #(.DELAY_BITS(4),.STRONG_WET(1)) dut(clk,rst,ce,enable,wet,dry,audio);
 reg signed [15:0] history[0:15];
 integer n,pass,index,expected,reads=0,writes=0;
 reg [3:0] read_address;
 reg awaiting_write=0;
 always @(posedge clk) begin
  if(dut.ram_rd_en && dut.ram_wr_en) $fatal(1,"RAM same-clock read/write collision");
  if(rst) awaiting_write=0;
  else begin
   if(dut.ram_rd_en) begin
    if(awaiting_write) $fatal(1,"read before previous write");
    read_address=dut.ptr; awaiting_write=1; reads=reads+1;
   end
   if(dut.ram_wr_en) begin
    if(!awaiting_write || read_address!==dut.ptr) $fatal(1,"write address/order");
    awaiting_write=0; writes=writes+1;
   end
  end
 end
 initial begin
  for(pass=0;pass<2;pass=pass+1) begin
   rst=1; ce=0; repeat(4) @(negedge clk); rst=0;
   // Second pass intentionally leaves old RAM contents: validity must mask them.
   index=0;
   for(n=0;n<160;n=n+1) begin
    dry=(n*127)%12000-6000; enable=(n%11!=0); wet=n%4;
    expected=dry;
    if(enable && n>=16) case(wet)
     1: expected=expected+($signed(history[index])>>>1);
     2: expected=expected+($signed(history[index])>>>1)+($signed(history[index])>>>2);
     3: expected=expected+$signed(history[index]);
    endcase
    history[index]=dry; index=(index+1)%16;
    ce=1; @(negedge clk); ce=0;
    // Change live controls mid-transaction: effect must use captured controls.
    enable=!enable; wet=wet+1'b1; dry=30000;
    repeat(3) @(negedge clk);
    if(audio!==expected) $fatal(1,"scoreboard pass=%d n=%d got=%d expected=%d",pass,n,audio,expected);
   end
  end
  if(reads!=320 || writes!=320) $fatal(1,"lost transactions");
  $display("PASS delay schedule: nonoverlapping read/write strobes, address hold, 4-clock cadence, wrap/reset masking, latched controls"); $finish;
 end
endmodule
