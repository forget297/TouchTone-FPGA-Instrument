`timescale 1ns/1ps
module tb_notes32;
reg clk=0,rst=1,tick=0,rx=1,down=0;
always #5 clk=~clk;
wire tx;wire [31:0] remote;wire overflow;wire [7:0] event_word;
wire enabled,restart;wire [59:0] map;
reg [11:0] physical=0;wire [31:0] mapped,notes,gates;
reg ensemble=0;
assign notes=mapped|remote;
ble_notes dut(clk,rst,tick,rx,tx,remote,overflow,5'd0,event_word,enabled,restart,down,map,8'd0,1'b0,1'b0,);
key_remap remapper(physical,map,mapped);
note_layers layers(notes,ensemble,gates);
reg [7:0] injected;integer n,k;reg [31:0] expected;
reg [59:0] custom;
wire [31:0] exhaustive_keys;
key_remap exhaustive(physical,custom,exhaustive_keys);
task byte_in;input [7:0] b;begin
 @(negedge clk);injected=b;force dut.data=injected;force dut.valid=1;
 @(negedge clk);force dut.valid=0;@(negedge clk);
end endtask
task frame;input [7:0] cmd,key,lo,hi;begin
 byte_in(8'ha5);byte_in(1);byte_in(cmd);byte_in(key);byte_in(lo);byte_in(hi);
 byte_in(8'ha5^1^cmd^key^lo^hi);byte_in(8'h5a);
end endtask
task drain;begin repeat(21000) @(negedge clk);end endtask
task ms;input integer count;begin repeat(count)begin @(negedge clk);tick=1;@(negedge clk);tick=0;end end endtask
task serial_byte;input [7:0] value;integer bitnum;begin
 rx=0;repeat(234)@(negedge clk);
 for(bitnum=0;bitnum<8;bitnum=bitnum+1)begin rx=value[bitnum];repeat(234)@(negedge clk);end
 rx=1;repeat(234)@(negedge clk);
end endtask
initial begin
 repeat(4) @(negedge clk);rst=0;force dut.valid=0;
 for(k=0;k<12;k=k+1)begin
  if(map[k*5+:5]!==k) $fatal(1,"default map");
  for(n=0;n<32;n=n+1)begin
   custom=0;custom[k*5+:5]=n;physical=12'b1<<k;#1;
   if(exhaustive_keys!==(32'b1<<n))$fatal(1,"mapping bit %d note %d",k,n);
  end
 end
 physical=0;
 frame(8'h23,0,0,0);if(dut.status!=0 || dut.reply_lo!=32 || dut.reply_hi!=1)$fatal(1,"capability");drain;
 // Every pitch can be played alone, not just as an octave layer.
 for(n=0;n<32;n=n+1)begin
  frame(3,n,0,0);expected=32'b1<<n;
  if(remote!==expected || gates!==expected)$fatal(1,"single remote %d",n);
  ensemble=1;#1;if(gates!==(expected|(expected<<12)|(expected<<24)))$fatal(1,"layers %d",n);ensemble=0;
  drain;frame(4,n,0,0);if(remote!==0)$fatal(1,"release %d",n);drain;
 end
 frame(3,32,0,0);if(dut.status!=2 || remote!=0)$fatal(1,"range32");drain;
 frame(3,255,0,0);if(dut.status!=2 || remote!=0)$fatal(1,"range255");drain;
 frame(8'h20,0,31,0);if(map[4:0]!=31)$fatal(1,"map highest");drain;
 frame(8'h21,0,0,0);if(dut.reply_lo!=31 || dut.reply_hi!=1)$fatal(1,"map read high");drain;
 frame(8'h20,1,31,0);drain;
 physical=3;#1;if(mapped!==32'h80000000)$fatal(1,"duplicate owners");
 frame(3,31,0,0);drain;frame(4,31,0,0);#1;if(gates!==32'h80000000)$fatal(1,"remote release must preserve physical owner");drain;
 down=1;frame(8'h20,0,24,0);if(dut.status!=3 || map[4:0]!=31)$fatal(1,"held config blocked");drain;
 down=0;physical=0;
 frame(8'h20,0,32,0);if(dut.status!=2 || map[4:0]!=31)$fatal(1,"map range");drain;
 frame(8'h22,0,0,0);if(map[4:0]!=0 || map[9:5]!=1)$fatal(1,"map defaults");drain;
 frame(1,31,10,0);ms(9);if(remote!==32'h80000000)$fatal(1,"timed high early");ms(1);if(remote!=0)$fatal(1,"timed high expiry");drain;
 frame(3,31,0,0);ms(3000);drain;frame(3,31,0,0);ms(4999);if(remote!==32'h80000000)$fatal(1,"high keepalive");ms(1);if(remote!=0)$fatal(1,"high watchdog");drain;
 frame(3,0,0,0);drain;frame(3,31,0,0);if(remote!==32'h80000001)$fatal(1,"low high polyphony");drain;
 frame(2,0,0,0);if(remote!=0)$fatal(1,"panic all32");drain;
 if(overflow)$fatal(1,"unexpected overflow");
 // Also exercise the physical UART receiver with a high-note frame.
 release dut.valid;release dut.data;
 serial_byte(8'ha5);serial_byte(1);serial_byte(3);serial_byte(31);serial_byte(0);serial_byte(0);serial_byte(8'hb8);serial_byte(8'h5a);
 repeat(500)@(negedge clk);
 if(remote!==32'h80000000)$fatal(1,"physical UART high-note path");
 $display("PASS R11: all 32 independent pitches, 384 key maps, octave bounds, high-note UART, duplicate owners, range rejection, expiry/keepalive, config safety, panic");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
