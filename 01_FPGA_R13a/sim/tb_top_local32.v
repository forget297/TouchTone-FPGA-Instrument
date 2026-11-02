`timescale 1ns/1ps
module tb_top_local32;
 reg clk=0;always #5 clk=~clk;tri1 scl,sda;
 top dut(.clk(clk),.reset_button(1'b0),.mode_button(1'b0),.i2c_scl(scl),.i2c_sda(sda),
 .enc_a(1'b1),.enc_b(1'b1),.enc_sw(1'b1),.joy_sw(1'b1),.ble_uart_rx(1'b1));
 reg [31:0] expected[0:31];integer frames=0,k,idx;reg [31:0] seen=0;
 always @(posedge clk)if(!dut.rst && dut.local_all)begin
  if(dut.bank.gain>8)$fatal(1,"all32 headroom during gain transition");
  for(k=0;k<4;k=k+1)if(dut.voice_valid[k])begin
   idx=k*8+dut.voice_slot[k*3+:3];
   if(dut.voice_fcw[k*32+:32]!==expected[idx])$fatal(1,"incorrect fixed pitch %d",idx);
   seen[idx]=1;
  end
  if(dut.done)begin
   frames=frames+1;
   if(dut.dry==32767 || dut.dry==-32768)$fatal(1,"all32 startup clipping");
   if(frames==300)begin
    if(dut.active!==32'hffffffff || seen!==32'hffffffff || dut.overrun)$fatal(1,"32 voice concurrency");
    $display("PASS integrated local32: all active, C4-G6 FCWs, no frame overrun/clipping, gain capped during startup");$finish;
   end
  end
 end
 initial begin
 $readmemh("rtl/audio/notes32.hex",expected);
 force dut.rst=1;force dut.clocks.startup=20'hfffff;
 repeat(10)@(negedge clk);release dut.rst;
 force dut.controls.menu=8;force dut.controls.audition_gate=1;force dut.controls.audition_all=1;
 end
 initial begin #3000000;$fatal(1,"local32 top timeout");end
endmodule
