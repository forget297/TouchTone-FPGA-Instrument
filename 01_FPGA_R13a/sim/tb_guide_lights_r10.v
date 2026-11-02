
`timescale 1ns/1ps
module tb_guide_lights_r10;
reg clk=0; always #5 clk=~clk;
reg rst=1,tick=0,enable=0,playing=1,practice=0,restart=0;
reg [11:0] keys=12'h204;
reg [7:0] event_word=8'h13;
wire [11:0] lights; wire [5:0] step; wire correct;
guide_extended dut(clk,rst,tick,enable,playing,practice,restart,2'd0,8'd120,keys,lights,step,correct,1'b1,event_word);
task expect_lights; input [11:0] value; begin #1; if(lights!==value) $fatal(1,"lights got %h expected %h",lights,value); end endtask
task ms; input integer n; begin tick=1;repeat(n) @(negedge clk);tick=0;end endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 expect_lights(12'h204); // Normal mode follows physical keys.
 enable=1;expect_lights(12'h008); // Wrong held keys never obscure target.
 keys=12'hfff;expect_lights(12'h008);
 playing=0;expect_lights(0);playing=1;
 event_word=8'h1f;expect_lights(0); // Rest stays dark even with all keys held.
 event_word=8'h13;ms(350);expect_lights(0); // Last 30% of beat is off.
 ms(150);expect_lights(12'h008);
 practice=1;keys=0;repeat(3) @(negedge clk);expect_lights(12'h008);
 keys=12'h001;repeat(3) @(negedge clk);expect_lights(12'h008);
 if(step!==1) $fatal(1,"wrong key advanced score");
 keys=12'h008;repeat(3) @(negedge clk);expect_lights(0);
 if(step!==2) $fatal(1,"correct key did not advance");
 ms(80);expect_lights(12'h008);
 playing=0;expect_lights(0);
 enable=0;expect_lights(12'h008);keys=12'h810;expect_lights(12'h810);
 $display("PASS R10 lights: normal touch, guide target-only, pause, rest, beat gap, practice correct acknowledgement");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
