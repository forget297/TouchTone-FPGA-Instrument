`timescale 1ns/1ps
module tb_sensors;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    tri1 scl,sda;
    wire [11:0] keys,p,x,y;
    wire ready,fault;
    sensor_hub dut(clk,rst,scl,sda,keys,p,x,y,ready,fault);
    sensor_model model(clk,rst,1'b0,scl,sda);
    initial begin
        repeat(5) @(negedge clk); rst=0;
        wait(ready); $display("sensor ready at %t",$time);
        wait(p==1024 && x==825 && y==1280);
        $display("PASS sensors: init and three ADC channels"); $finish;
    end
    initial begin #30000000;
        $display("state=%d init=%d ready=%b error=%b keys=%h adc=%d,%d,%d modeladdr=%h ptr=%h cfg=%h count=%d bstate=%d",
            dut.state,dut.init_index,ready,dut.error,keys,p,x,y,model.address,model.ptr,model.config_reg,model.count,model.state);
        $fatal(1,"sensors timeout"); end
endmodule
