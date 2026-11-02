`timescale 1ns/1ps
// Measures digital register availability -> sensor_hub publication only.
// Does NOT model MPR analog scan/filter latency or I2C electrical rise times.
module tb_poll_latency;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    tri1 scl,sda;
    wire [11:0] keys,p,x,y;
    wire ready,fault;
    sensor_hub dut(clk,rst,scl,sda,keys,p,x,y,ready,fault);
    sensor_model model(clk,rst,1'b0,scl,sda);
    integer i,elapsed,minimum=1000000,maximum=0,fd;
    reg [11:0] target;
    reg [31:0] rng=32'h19a5603d;
    initial begin
        fd=$fopen("build/poll_latency.csv","w");
        $fdisplay(fd,"trial,publication_clocks,publication_us");
        repeat(5) @(negedge clk); rst=0;
        wait(ready && p==1024 && x==825 && y==1280);
        model.touch_status=0; wait(keys==0); @(negedge clk);
        for(i=0;i<100;i=i+1) begin
            // Sample different phases of ADC/touch bus transactions.
            rng=(rng<<1)^((rng[31])?32'h04c11db7:0);
            repeat(100+(rng%11000)) @(negedge clk);
            target=i[0]?12'h000:12'h001;
            model.touch_status=target; elapsed=0;
            while(keys!==target && elapsed<27000) begin
                @(negedge clk); elapsed=elapsed+1;
            end
            if(keys!==target || !ready || fault) $fatal(1,"polling stalled or faulted");
            if(elapsed<minimum) minimum=elapsed;
            if(elapsed>maximum) maximum=elapsed;
            $fdisplay(fd,"%0d,%0d,%f",i,elapsed,elapsed/27.0);
        end
        $fclose(fd);
        $display("PASS poll latency: 100 register changes under ADC polling, %0d..%0d clocks (%f..%f us); excludes physical sensing",minimum,maximum,minimum/27.0,maximum/27.0);
        $finish;
    end
    initial begin #100000000; $fatal(1,"poll latency timeout"); end
endmodule
