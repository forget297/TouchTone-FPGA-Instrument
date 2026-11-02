`timescale 1ns/1ps
// Actual 576-clock audio cadence; excludes analog sensors and DAC latency.
module tb_latency;
    reg clk=0; always #5 clk=~clk;
    reg rst=1; reg [31:0] gates=0;
    wire ce,bclk,ws,sd,done,overrun;
    wire [31:0] active;
    wire signed [15:0] dry,audio;
    engine32 bank(clk,rst,ce,gates,1'b0,2'b0,9'sd0,16'd8192,16'd32,16'd50000,
        16'd1024,8'd192,dry,done,overrun,active,,,,);
    audio_effect effect(clk,rst,ce,1'b1,2'd3,dry,audio);
    i2s_tx tx(clk,rst,audio,bclk,ws,sd,ce);
    integer offset,elapsed,minimum=100000,maximum=0,fd;
    initial begin
        fd=$fopen("build/digital_latency.csv","w");
        $fdisplay(fd,"offset_clocks,latency_clocks,latency_us");
        for(offset=0;offset<576;offset=offset+37) begin
            rst=1; gates=0; repeat(5) @(negedge clk); rst=0;
            repeat(3) @(posedge ce); @(negedge clk);
            repeat(offset) @(negedge clk);
            gates=32'hffffffff; elapsed=0;
            // frame is the exact sample snapshot serialized by i2s_tx.
            while(tx.frame==0 && elapsed<3000) begin @(negedge clk); elapsed=elapsed+1; end
            if(tx.frame==0 || overrun || ^audio===1'bx) $fatal(1,"digital onset/deadline");
            if(elapsed<minimum) minimum=elapsed;
            if(elapsed>maximum) maximum=elapsed;
            $fdisplay(fd,"%0d,%0d,%f",offset,elapsed,elapsed/27.0);
        end
        if(maximum>2304 || maximum-minimum>576) $fatal(1,"digital latency bound");
        $fclose(fd);
        $display("PASS digital latency: %0d..%0d clocks (%f..%f us), excludes sensor/DAC",minimum,maximum,minimum/27.0,maximum/27.0);
        $finish;
    end
    initial begin #10000000; $fatal(1,"latency timeout"); end
endmodule
