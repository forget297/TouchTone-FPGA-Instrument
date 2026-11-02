`timescale 1ns/1ps
// Simulation-only oversampled I2C peripheral model for both selected addresses.
module sensor_model(input clk,input rst,input disconnect,inout scl,inout sda);
    reg drive_low=0;
    assign sda=drive_low?1'b0:1'bz;
    reg old_scl=1,old_sda=1;
    reg [7:0] shift=0,tx=0,ptr=0;
    reg [7:0] mpr[0:127];
    // Testbench-controlled status, default keeps existing regression fixtures.
    // Changes here mean the sensor has ALREADY detected a touch: no analog model.
    reg [11:0] touch_status=12'h091;
    reg [15:0] config_reg=0;
    reg [6:0] address=0;
    reg [3:0] count=0;
    reg [1:0] state=0; // 0 address, 1 pointer, 2 write, 3 read
    reg active=0,selected=0,read_direction=0,ack=0;
    reg second_byte=0;
    reg was_reset=0;
    integer i;
    function [7:0] data_at;
        input [6:0] dev;
        input [7:0] regptr;
        input second;
        reg [15:0] analog_value;
        begin
            case(config_reg[13:12])
                0: analog_value=16'h4000;
                1: analog_value=16'h3390;
                2: analog_value=16'h5000;
                default: analog_value=0;
            endcase
            if(dev==7'h5a) begin
                if(regptr==0) data_at=touch_status[7:0];
                else if(regptr==1) data_at={4'b0,touch_status[11:8]};
                else data_at=mpr[regptr[6:0]];
            end else if(regptr==0) data_at=second?analog_value[7:0]:analog_value[15:8];
            else data_at=second?config_reg[7:0]:config_reg[15:8];
        end
    endfunction
    always @(posedge clk) begin
        was_reset<=rst;
        old_scl<=scl; old_sda<=sda;
        if(rst) begin
            active<=0; drive_low<=0; state<=0; count<=0; config_reg<=0;
            if(!was_reset) for(i=0;i<128;i=i+1) mpr[i]<=0;
        end else if(old_sda && !sda && scl && old_scl) begin
            active<=1; state<=0; count<=0; shift<=0; drive_low<=0; selected<=0;
        end else if(!old_sda && sda && scl && old_scl) begin
            active<=0; drive_low<=0;
        end else if(active) begin
            if(!old_scl && scl) begin
                if(count<8) begin
                    shift<={shift[6:0],sda};
                    if(count==7 && state==0) begin
                        address<=shift[6:0]; read_direction<=sda;
                        selected<=!disconnect && (shift[6:0]==7'h48 || shift[6:0]==7'h5a);
                    end
                end else ack<=!sda;
                count<=count+1'b1;
            end
            if(old_scl && !scl) begin
                if(count==8) drive_low<=state==3?0:selected;
                else if(count==9) begin
                    count<=0; drive_low<=0;
                    case(state)
                        0: if(read_direction && selected) begin
                            state<=3; second_byte<=0;
                            tx<=data_at(address,ptr,0);
                            drive_low<=!((data_at(address,ptr,0)>>7)&1);
                        end else state<=1;
                        1: begin ptr<=shift; second_byte<=0; state<=2; end
                        2: if(selected) begin
                            if(address==7'h5a) begin mpr[ptr[6:0]]<=shift; ptr<=ptr+1'b1; end
                            else if(ptr==1) begin
                                if(!second_byte) config_reg[15:8]<=shift; else config_reg[7:0]<=shift;
                                second_byte<=1;
                            end
                        end
                        3: if(ack) begin
                            if(address==7'h5a) begin
                                ptr<=ptr+1'b1; tx<=data_at(address,ptr+1'b1,0);
                                drive_low<=!((data_at(address,ptr+1'b1,0)>>7)&1);
                            end else begin
                                second_byte<=1; tx<=data_at(address,ptr,1);
                                drive_low<=!((data_at(address,ptr,1)>>7)&1);
                            end
                        end else begin state<=0; drive_low<=0; end
                    endcase
                end else if(state==3) drive_low<=~tx[7-count];
            end
        end
    end
endmodule
