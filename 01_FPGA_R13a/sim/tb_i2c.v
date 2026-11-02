`timescale 1ns/1ps
module tb_i2c;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,start=0,reading=0,two=1;
    reg [6:0] address=7'h48;
    reg [7:0] ptr=1;
    reg [15:0] wd=16'hc3e3;
    wire busy,done,error;
    wire [15:0] rd;
    tri1 scl,sda;
    reg slave_low=0,stretch=0;
    assign sda=slave_low?1'b0:1'bz;
    assign scl=stretch?1'b0:1'bz;
    i2c_master #(.DIV(8),.TIMEOUT(3000)) dut(clk,rst,start,address,ptr,reading,two,wd,
        busy,done,error,rd,scl,sda);
    task receive(output reg [7:0] v,input reg ack);
        integer i;
        begin
            v=0;
            for(i=0;i<8;i=i+1) begin @(posedge scl); v={v[6:0],sda}; end
            @(negedge scl); slave_low=ack;
            @(posedge scl); @(negedge scl); slave_low=0;
        end
    endtask
    task send(input [7:0] v,input expected_nack);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin
                slave_low=~v[i]; @(posedge scl); @(negedge scl);
            end
            slave_low=0; @(posedge scl);
            if(sda!==expected_nack) $fatal(1,"master ACK/NACK incorrect");
            @(negedge scl);
        end
    endtask
    task wait_start; begin @(negedge sda); if(scl!==1) $fatal(1,"bad start"); end endtask
    task wait_stop; begin @(posedge scl); @(posedge sda); if(scl!==1) $fatal(1,"bad stop"); end endtask
    task launch; begin @(negedge clk); start=1; @(negedge clk); start=0; end endtask
    reg [7:0] b;
    initial begin
        repeat(5) @(negedge clk); rst=0;
        fork
            begin launch; @(posedge done); if(error) $fatal(1,"write failed"); end
            begin
                wait_start; receive(b,1); if(b!=8'h90) $fatal(1,"address");
                receive(b,1); if(b!=1) $fatal(1,"pointer");
                receive(b,1); if(b!=8'hc3) $fatal(1,"write high");
                receive(b,1); if(b!=8'he3) $fatal(1,"write low"); wait_stop;
            end
        join
        reading=1; ptr=0;
        fork
            begin launch; @(posedge done); if(error || rd!=16'h67a0) $fatal(1,"read %h err %b",rd,error); end
            begin
                wait_start; receive(b,1); receive(b,1);
                wait_start; receive(b,1); if(b!=8'h91) $fatal(1,"read address");
                // Stretch the first read low phase.
                stretch=1; repeat(40) @(posedge clk); stretch=0;
                send(8'h67,0); send(8'ha0,1); wait_stop;
            end
        join
        fork
            begin launch; @(posedge done); if(!error) $fatal(1,"NACK not reported"); end
            begin wait_start; receive(b,0); wait_stop; end
        join
        stretch=1; launch; @(posedge done);
        if(!error) $fatal(1,"stuck SCL not timed out");
        stretch=0;
        $display("PASS I2C: write, repeated-start read, ACK/NACK, stretching, timeout"); $finish;
    end
    initial begin #1000000; $fatal(1,"I2C test timeout"); end
endmodule
