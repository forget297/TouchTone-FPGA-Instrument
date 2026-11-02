`timescale 1ns/1ps
module tb_engine32;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,ce=0,test_mode=0;
    reg [31:0] gates=0;
    reg [1:0] timbre=0;
    reg signed [8:0] pitch=0;
    reg [7:0] gain=192;
    wire signed [15:0] sample;
    wire done,overrun;
    wire [31:0] active;
    engine32 dut(clk,rst,ce,gates,test_mode,timbre,pitch,16'd8192,16'd32,16'd50000,16'd1024,
        gain,sample,done,overrun,active,,,,);
    integer i,j,fd,latency,first_latency=-1;
    reg [31:0] phase_before;
    reg signed [41:0] delta_expected;
    reg [31:0] increment_expected;
    task frame;
        begin
            @(negedge clk); ce=1;
            @(negedge clk); ce=0; latency=0;
            while(!done && latency<80) begin @(negedge clk); latency=latency+1; end
            if(!done || overrun || ^sample===1'bx) $fatal(1,"frame deadline/unknown");
            if(first_latency<0) first_latency=latency;
            if(latency!=first_latency) $fatal(1,"non-deterministic compute latency");
            repeat(5) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        frame; if(sample!==0) $fatal(1,"startup silence");
        // Each of all 32 gates independently excites exactly one envelope.
        for(i=0;i<32;i=i+1) begin
            gates=32'b1<<i;
            repeat(12) frame;
            if(active!==(32'b1<<i)) $fatal(1,"gate independence %d %h",i,active);
            gates=0; repeat(70) frame;
            if(active!==0 || sample!==0) $fatal(1,"release %d",i);
        end
        gates=32'hffffffff;
        repeat(20) frame;
        if(active!==32'hffffffff) $fatal(1,"32 voices not active");
        pitch=-100; frame;
        phase_before=dut.lanes[0].lane.phases[0];
        delta_expected=$signed({1'b0,dut.lanes[0].lane.frequencies[0]})*pitch;
        increment_expected=dut.lanes[0].lane.frequencies[0]+(delta_expected>>>11);
        frame;
        if(dut.lanes[0].lane.phases[0]-phase_before!==increment_expected) $fatal(1,"negative tuning");
        for(j=0;j<4;j=j+1) begin timbre=j; repeat(30) frame; end
        test_mode=1; timbre=2; pitch=200;
        repeat(1024) frame;
        fd=$fopen("build/audio32_samples.txt","w");
        for(i=0;i<16384;i=i+1) begin frame; $fdisplay(fd,"%0d",sample); end
        $fclose(fd);
        test_mode=0; gates=0; repeat(80) frame;
        if(sample!==0 || active!==0) $fatal(1,"test mode release");
        $display("PASS engine32: 32 independent gates, signed pitch, four timbres, 32-tone capture, fixed %0d-clock compute latency",first_latency);
        $finish;
    end
    initial begin #100000000; $fatal(1,"timeout"); end
endmodule
