`timescale 1ns/1ps
module tb_local_visual_controls;
 reg clk=0;always #5 clk=~clk;reg rst=1;
 wire [3:0] menu;wire [4:0] note;wire gate;wire [1:0] view,page;
 controls_extended dut(.clk(clk),.rst(rst),.tick_ms(1'b1),.ce(1'b1),.enc_a(1'b1),.enc_b(1'b1),.enc_sw(1'b1),.joy_sw(1'b1),.mode_button(1'b0),
 .menu(menu),.audition_note(note),.audition_gate(gate),.display_view(view),.note_page(page));
 task turn(input integer direction);begin
 @(negedge clk);if(direction)force dut.up=1;else force dut.down=1;
 @(negedge clk);release dut.up;release dut.down;repeat(2)@(negedge clk);
 end endtask
 task click;begin
 @(negedge clk);force dut.enc_level=1;repeat(3)@(negedge clk);
 force dut.enc_level=0;repeat(3)@(negedge clk);release dut.enc_level;
 end endtask
 task joy;begin
 @(negedge clk);force dut.joy_press=1;@(negedge clk);release dut.joy_press;repeat(2)@(negedge clk);
 end endtask
 integer i;
 initial begin
 repeat(4)@(negedge clk);rst=0;repeat(20)@(negedge clk);
 for(i=0;i<8;i=i+1)click;
 if(menu!=8 || note!=0)$fatal(1,"menu8 reset selection");
 for(i=1;i<=32;i=i+1)begin turn(1);if(note!=(i%32)||!gate)$fatal(1,"32 ascending notes");end
 turn(0);if(note!=31)$fatal(1,"down wrap G6");
 repeat(805)@(negedge clk);if(gate)$fatal(1,"auto release");
 joy;repeat(810)@(negedge clk);if(!gate)$fatal(1,"hold");
 click;if(menu!=9 || gate)$fatal(1,"exit release");
 for(i=1;i<=4;i=i+1)begin turn(1);if(view!=i%4)$fatal(1,"view wrap");end
 turn(0);if(view!=3)$fatal(1,"view reverse");
 for(i=1;i<=4;i=i+1)begin joy;if(page!=i%4)$fatal(1,"page wrap");end
 click;if(menu!=0)$fatal(1,"10 menu wrap");
 for(i=0;i<8;i=i+1)click;
 @(negedge clk);force dut.enc_level=1;repeat(805)@(negedge clk);force dut.enc_level=0;repeat(3)@(negedge clk);release dut.enc_level;
 if(!dut.audition_all || !gate || menu!=8)$fatal(1,"all32 long press");
 click;if(menu!=9 || !gate || !dut.audition_all)$fatal(1,"all32 persists during view choice");
 @(negedge clk);force dut.mode_press=1;@(negedge clk);release dut.mode_press;repeat(3)@(negedge clk);
 if(gate || dut.audition_all)$fatal(1,"mode exit stops all32");
 $display("PASS all32 hold/persist/stop; 32 notes, timeout, hold, exit, 4 views, 4 pages, 10 menus");$finish;
 end
endmodule
