`timescale 1ns/1ps
module tb_encoder_r2;
    reg clk=0; always #5 clk=~clk;
    reg rst=1; reg [1:0] ab=3;
    wire up,down;
    integer ups=0,downs=0,k;
    // tick_ms is always zero: rotation must not depend on the old 1kHz poll.
    encoder dut(clk,rst,1'b0,ab[1],ab[0],up,down);
    always @(posedge clk) begin
        if(rst) begin ups<=0; downs<=0; end
        else begin if(up) ups<=ups+1; if(down) downs<=downs+1; end
    end
    task state; input [1:0] value; begin ab=value; repeat(600) @(negedge clk); end endtask
    task restart; input [1:0] value; begin rst=1; ab=value;
        repeat(5) @(negedge clk); rst=0; repeat(600) @(negedge clk); end endtask
    initial begin
        restart(3);
        state(1); state(0); state(2); state(3);
        if(ups!=1 || downs!=0) $fatal(1,"forward full cycle");
        state(2); state(0); state(1); state(3);
        if(ups!=1 || downs!=1) $fatal(1,"reverse full cycle");
        restart(0);
        state(2); state(3); state(1); state(0);
        if(ups!=1 || downs!=0) $fatal(1,"00 resting state");
        restart(3);
        // Accepted contact bounces cancel algebraically, not double-counted.
        state(1); state(3); state(1); state(0); state(2); state(3);
        if(ups!=1 || downs!=0) $fatal(1,"bounce cancellation");
        restart(3);
        ab=1; repeat(100) @(negedge clk); ab=3; repeat(600) @(negedge clk);
        if(ups!=0 || downs!=0 || dut.movement!=0) $fatal(1,"short glitch filter");
        state(0); // illegal two-bit jump, no invented direction
        if(ups!=0 || downs!=0) $fatal(1,"illegal jump");
        repeat(4000) @(negedge clk);
        if(ups!=0 || downs!=0) $fatal(1,"stationary event");
        $display("PASS encoder R2: both directions, 00/11 rest, sub-ms transitions, bounce, glitch, invalid transition"); $finish;
    end
endmodule
