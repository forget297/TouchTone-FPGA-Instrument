`timescale 1ns/1ps
module tb_adsr_expanded;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,gate=0;
 reg [15:0] astep=1,dstep=1,sustain=0,rstep=1;
 wire [15:0] level;
 adsr dut(clk,rst,1'b1,gate,astep,dstep,sustain,rstep,level);
 integer n;
 initial begin
  repeat(3) @(negedge clk); rst=0; gate=1;
  @(negedge clk);
  for(n=1;n<=65535;n=n+1) begin @(negedge clk); if(level!==n) $fatal(1,"slow attack %d %d",n,level); end
  for(n=65534;n>=0;n=n-1) begin @(negedge clk); if(level!==n) $fatal(1,"slow decay"); end
  gate=0; repeat(3) @(negedge clk); astep=32768; sustain=65535; gate=1;
  repeat(5) @(negedge clk); if(level!==65535) $fatal(1,"fast attack");
  gate=0; @(negedge clk);
  for(n=65534;n>=0;n=n-1) begin @(negedge clk); if(level!==n) $fatal(1,"slow release"); end
  $display("PASS expanded ADSR: step1 full-scale 65535 samples attack/decay/release, fast step32768"); $finish;
 end
endmodule
