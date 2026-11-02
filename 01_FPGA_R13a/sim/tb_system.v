`timescale 1ns/1ps
module tb_system;
    reg clk=0; always #5 clk=~clk;
    reg reset_button=0,disconnect=0;
    tri1 scl,sda;
    wire ser,srclk,rclk,bclk,ws,sd,pa;
    wire [5:0] led;
    wire dbg_gate,dbg_audio;
    top dut(clk,reset_button,1'b0,scl,sda,1'b1,1'b1,1'b1,1'b1,
        ser,srclk,rclk,bclk,ws,sd,pa,led,dbg_gate,dbg_audio);
    sensor_model model(clk,dut.rst,disconnect,scl,sda);
    initial begin
        wait(dut.ready);
        $display("system: ready at %t",$time);
        wait(dut.pressure==1024 && dut.joy_x==825 && dut.joy_y==1280);
        $display("system: ADC and keys received at %t",$time);
        if(dut.keys!==12'h091) $fatal(1,"MPR endian/key mapping %h",dut.keys);
        if(model.mpr[8'h5e]!==8'h8c || model.mpr[8'h5d]!==8'h20)
            $fatal(1,"MPR configuration");
        if(model.mpr[8'h41]!==12 || model.mpr[8'h58]!==6)
            $fatal(1,"MPR thresholds");
        if(model.config_reg[11:0]!==12'h3e3) $fatal(1,"ADC config");
        repeat(100) @(posedge dut.ce);
        if(dut.bank.active[0]!==1 || dut.bank.active[4]!==1 || dut.bank.active[7]!==1)
            $fatal(1,"sensor to voice path");
        disconnect=1;
        $display("system: disconnect at %t",$time);
        wait(dut.keys==0);
        // This test targets bus recovery, not musical release duration.
        // Expanded release endpoints are verified separately; accelerate this tail.
        force dut.release_step=16'd1024;
        // A whole-bus disconnect can fail the MPR transaction first and restart
        // initialization before an ADC read occurs. Test key release here;
        // do not require the ADC-specific fallback on this path.
        repeat(1200) @(posedge dut.ce);
        if(dut.audio!==0) $fatal(1,"disconnect stuck sound %d",dut.audio);
        release dut.release_step;
        disconnect=0;
        $display("system: reconnect at %t",$time);
        wait(dut.ready && dut.keys==12'h091);
        $display("PASS system: power-on, sensor init, real I2C keys/ADC, sound, disconnect/recovery");
        $finish;
    end
    initial begin #100000000;
        $display("state=%d init=%d ready=%b error=%b keys=%h adc=%d,%d,%d modeladdr=%h ptr=%h cfg=%h",
            dut.sensors.state,dut.sensors.init_index,dut.ready,dut.sensors.error,
            dut.keys,dut.pressure,dut.joy_x,dut.joy_y,model.address,model.ptr,model.config_reg);
        $fatal(1,"system timeout"); end
endmodule
