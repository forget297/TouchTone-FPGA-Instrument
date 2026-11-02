`timescale 1ns/1ps
module tb_led_menu_r13a;
 reg clk=0;always #5 clk=~clk;tri1 scl,sda;wire [5:0] led;
 top dut(.clk(clk),.reset_button(1'b0),.mode_button(1'b0),.i2c_scl(scl),.i2c_sda(sda),.enc_a(1'b1),.enc_b(1'b1),.enc_sw(1'b1),.joy_sw(1'b1),.ble_uart_rx(1'b1),.led_n(led));
 integer m;
 initial begin
 force dut.ready=1;force dut.fault=0;force dut.overrun=0;force dut.ble_uart_overflow=0;
 force dut.mode=0;
 for(m=0;m<10;m=m+1)begin force dut.menu=m;#20;if((~led[5:2])!==m[3:0] || led[1:0]!==2'b10)$fatal(1,"menu LED mapping %d %b",m,led);end
 force dut.menu=0;force dut.mode=1;#20;if(led[5]!==0)$fatal(1,"test indicator");
 force dut.mode=2;#20;if(led[5]!==0)$fatal(1,"guide indicator");
 $display("PASS normal menus0..9 binary LEDs, ready/fault preserved, test/guide indicator preserved");$finish;
 end
endmodule
