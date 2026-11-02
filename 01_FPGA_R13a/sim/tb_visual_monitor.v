`timescale 1ns/1ps
module tb_visual_monitor;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ce=0;reg signed [15:0] audio=0;
 wire [7:0] data;wire valid,last;reg ready=0;
 reg [11:0] slot=0;integer cycle=0,fd,count=0;real v;
 visual_monitor #(.PERIOD_CLOCKS(1)) dut(clk,rst,ce,audio,4'b1111,slot,
   {16'd4000,16'd3000,16'd2000,16'd1000},{32'd400000000,32'd300000000,32'd200000000,32'd100000000},
   32'hffffffff,4'd8,2'd0,2'd0,2'd1,2'd2,5'd31,1'b1,1'b0,1'b0,data,valid,last,ready);
 always @(negedge clk)begin
  cycle=cycle+1;ce=(cycle%8)==0;ready=(cycle%5)!=0;
  slot={4{cycle[2:0]}};
  if(dut.sequence_id==0) v=12000.0*$sin(6.283185307179586*6*dut.cap_index/1024.0)+4000.0*$cos(6.283185307179586*17*dut.cap_index/1024.0);
  else v=0;
  audio=$rtoi(v);
 end
 always @(posedge clk)if(!rst && valid && ready)begin
  $fdisplay(fd,"%02x",data);count=count+1;
  if(last !== (count%42==0))$fatal(1,"packet last mismatch");
  if(count==1932)begin $fclose(fd);$display("PASS 2 FPGA snapshots serialized under backpressure");$finish;end
 end
 initial begin fd=$fopen("build/visual_packets.hex","w");repeat(5)@(posedge clk);@(negedge clk);rst=0;end
 initial begin #30000000;$fatal(1,"monitor timeout");end
endmodule
