`timescale 1ns/1ps
module tb_visual_uart_mux;
 reg clk=0;always #5 clk=~clk;reg rst=1;
 reg [7:0] cmd_data=0;reg cmd_start=0;wire cmd_ready,tx,visual_ready;
 reg [7:0] visual_data=8'h40;reg visual_valid=1;reg [5:0] vi=0;
 integer sent=0,remaining=0,ci=0,received=0;wire [7:0] rxdata;wire rxvalid;
 uart_packet_mux dut(clk,rst,cmd_data,cmd_start,tx,cmd_ready,remaining!=0,visual_data,visual_valid,vi==41,visual_ready);
 uart_rx decode(clk,rst,tx,rxdata,rxvalid);
 always @(posedge clk)if(!rst)begin
  cmd_start<=0;
  if(sent==5 && remaining==0 && ci==0)remaining<=8;
  if(cmd_ready && !cmd_start && remaining!=0)begin cmd_data<=8'ha0+ci;ci<=ci+1;cmd_start<=1;remaining<=remaining-1;end
  if(visual_valid && visual_ready)begin
   sent<=sent+1;
   if(vi==41)begin vi<=0;visual_data<=8'h40;end
   else begin vi<=vi+1;visual_data<=visual_data+1;end
   if(sent==83)visual_valid<=0;
  end
  if(rxvalid)begin
   if(received<42)begin if(rxdata!==8'h40+received)$fatal(1,"first visual interleaved %d %h",received,rxdata);end
   else if(received<50)begin if(rxdata!==8'ha0+received-42)$fatal(1,"reply corrupted %d %h",received,rxdata);end
   else if(rxdata!==8'h40+received-50)$fatal(1,"second visual corrupted");
   received=received+1;if(received==92)begin $display("PASS UART wire decode:42 visual +8 reply +42 visual, pending control priority, no interleave");$finish;end
  end
 end
 initial begin repeat(5)@(negedge clk);rst=0;end
 initial begin #5000000;$fatal(1,"UART timeout %d",received);end
endmodule
