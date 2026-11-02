`timescale 1ns/1ps
module tb_menu_ranges;
 reg clk=0; always #5 clk=~clk;
 reg rst=1;
 wire [1:0] timbre,mode,wet,song;
 wire [3:0] menu; wire pe,en,playing,practice,restart;
 wire [15:0] a,d,s,r; wire [7:0] bpm;
 controls_extended dut(clk,rst,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,
  timbre,menu,mode,pe,en,a,d,s,r,wet,song,bpm,playing,practice,restart,,,,,);
 integer i,m;
 task turn(input integer up); begin
  @(negedge clk);
  if(up) begin force dut.up=1; force dut.down=0; end
  else begin force dut.up=0; force dut.down=1; end
  @(negedge clk); release dut.up; release dut.down;
  repeat(2) @(negedge clk);
 end endtask
 initial begin
  repeat(3) @(negedge clk); rst=0;
  if(a!=256 || d!=2 || s!=49152 || r!=4) $fatal(1,"defaults");
  for(m=1;m<=4;m=m+1) begin
   // Decoder is separately tested; inject events to test UI endpoint arithmetic.
   @(negedge clk); dut.menu=m;
   repeat(18) turn(1);
   if((m==1 && a!=1)||(m==2 && d!=1)||(m==3 && s!=65535)||(m==4 && r!=1)) $fatal(1,"upper effect endpoint %d",m);
   repeat(18) turn(0);
   if((m==1 && a!=32768)||(m==2 && d!=32768)||(m==3 && s!=0)||(m==4 && r!=32768)) $fatal(1,"lower effect endpoint %d",m);
  end
  $display("PASS menu ranges: defaults, time direction, steps1..32768, sustain0..65535, no wrap"); $finish;
 end
endmodule
