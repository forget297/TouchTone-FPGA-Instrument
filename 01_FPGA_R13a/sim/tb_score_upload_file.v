`timescale 1ns/1ps
module tb_score_upload_file;
 reg clk=0;always #5 clk=~clk;reg rst=1,rx=1;wire tx,overflow,enabled,restart;wire [31:0] keys;reg [4:0] index=0;wire [7:0] event_data;
 ble_notes dut(clk,rst,1'b0,rx,tx,keys,overflow,index,event_data,enabled,restart,1'b0,,8'd0,1'b0,1'b0,);
 wire [7:0] decoded;wire valid;uart_rx decoder(clk,rst,tx,decoded,valid);
 reg [7:0] score[0:31],reply[0:7];integer received=0,seq=0,total=0,i;
 always @(posedge clk)if(valid)begin if(received>=8)$fatal(1,"extra reply byte");reply[received]=decoded;received=received+1;end
 task send_byte(input [7:0] b);integer k;begin
 @(negedge clk);rx=0;repeat(234)@(negedge clk);
 for(k=0;k<8;k=k+1)begin rx=b[k];repeat(234)@(negedge clk);end
 rx=1;repeat(234)@(negedge clk);
 end endtask
 task command(input [7:0] cmd,arg,lo,hi,status,expectlo,expecthi);reg [7:0] check;integer j;begin
 received=0;seq=seq+1;
 send_byte(8'ha5);send_byte(seq);send_byte(cmd);send_byte(arg);send_byte(lo);send_byte(hi);send_byte(8'ha5^seq^cmd^arg^lo^hi);send_byte(8'h5a);
 wait(received==8);@(negedge clk);check=0;for(j=0;j<6;j=j+1)check=check^reply[j];
 if(reply[0]!=8'ha5 || reply[1]!=seq || reply[2]!=(cmd|8'h80) || reply[3]!=status || reply[4]!=expectlo || reply[5]!=expecthi || reply[6]!=check || reply[7]!=8'h5a)$fatal(1,"reply failed seq=%d cmd=%h status=%h",seq,cmd,reply[3]);
 end endtask
 initial begin
 $readmemh("sim/score_upload_test.hex",score);for(i=0;i<32;i=i+1)total=total+score[i];
 repeat(8)@(negedge clk);rst=0;
 command('h10,0,0,0,0,0,0);
 command('h11,0,score[0],score[1],0,0,0);
 command('h12,0,total&255,total>>8,3,0,0);if(enabled)$fatal(1,"partial score activated");
 for(i=2;i<32;i=i+2)command('h11,i,score[i],score[i+1],0,0,0);
 command('h12,0,(total+1)&255,total>>8,4,0,0);if(enabled)$fatal(1,"bad sum activated");
 command('h12,0,total&255,total>>8,0,0,0);if(!enabled)$fatal(1,"commit failed");
 for(i=0;i<32;i=i+1)begin
 command('h14,i,0,0,0,score[i],1);index=i;#20;if(event_data!==score[i])$fatal(1,"guide output mismatch");end
 command('h10,0,0,0,0,0,0);command('h11,0,8'h2b,8'h2a,0,0,0);
 command('h14,0,0,0,0,score[0],1);
 if(!enabled || overflow)$fatal(1,"active score disrupted or FIFO overflow");
 command('h13,0,0,0,0,0,0);if(enabled)$fatal(1,"restore default");
 $display("PASS JSON-derived score: UART upload, incomplete/bad-sum rejected,32 replies+guide events match, uncommitted upload preserves score, default restore");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule

