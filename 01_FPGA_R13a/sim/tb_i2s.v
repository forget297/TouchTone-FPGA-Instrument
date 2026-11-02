`timescale 1ns/1ps
module tb_i2s;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg [15:0] sample=16'ha53c;
    wire bclk,ws,sd,ce;
    i2s_tx dut(clk,rst,sample,bclk,ws,sd,ce);
    reg old_ws=1;
    reg [15:0] received=0;
    integer left=0,right=0,count=0,cycles=0,last_ce=0;
    reg channel=0,started=0;
    always @(posedge clk) begin
        cycles<=cycles+1;
        if(ce) begin
            if(last_ce!=0 && cycles-last_ce!=576) $fatal(1,"wrong frame period");
            last_ce<=cycles;
        end
    end
    // Receiver samples at rising BCLK and treats WS transition bit as previous LSB.
    always @(posedge bclk) if(!rst) begin
        if(started) begin
            received={received[14:0],sd}; count=count+1;
            if(count==16) begin
                if(received!==sample) $fatal(1,"I2S word %h expected %h",received,sample);
                if(channel) right=right+1; else left=left+1;
                started=0;
            end
        end
        if(ws!=old_ws) begin started=1; count=0; channel=ws; end
        old_ws=ws;
        if(left>=8 && right>=8) begin $display("PASS I2S: bit delay, signed stereo words, 576 clocks/frame"); $finish; end
    end
    initial begin repeat(5) @(negedge clk); rst=0; #1000000; $fatal(1,"I2S timeout"); end
endmodule
