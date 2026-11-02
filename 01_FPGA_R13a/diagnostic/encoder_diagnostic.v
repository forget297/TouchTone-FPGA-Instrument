// Temporary SRAM diagnostic: no audio synthesis; amplifier explicitly disabled.
module encoder_diagnostic(input clk,input reset_button,input enc_a,input enc_b,
    output [5:0] led_n,output pa_en,output i2s_bclk,output i2s_ws,output i2s_data);
    wire rst,tick_ms,up,down;
    reg [1:0] as=3,bs=3,previous=3;
    reg [3:0] arm_count=0;
    reg a_seen=0,b_seen=0,up_seen=0,down_seen=0;
    clock_gen clocks(clk,reset_button,rst,tick_ms);
    encoder decoder(clk,rst,tick_ms,enc_a,enc_b,up,down);
    always @(posedge clk) begin
        as<={as[0],enc_a}; bs<={bs[0],enc_b}; previous<={as[1],bs[1]};
        if(rst) begin arm_count<=0; a_seen<=0; b_seen<=0; up_seen<=0; down_seen<=0; end
        else begin
            if(arm_count<8) arm_count<=arm_count+1'b1;
            else begin
                if(as[1]!=previous[1]) a_seen<=1;
                if(bs[1]!=previous[0]) b_seen<=1;
            end
            if(up) up_seen<=1;
            if(down) down_seen<=1;
        end
    end
    // LED0=A level; LED1=B level; LED2/3=edge history; LED4/5=direction history.
    assign led_n=rst?6'b111111:~{down_seen,up_seen,b_seen,a_seen,bs[1],as[1]};
    assign pa_en=0;
    assign i2s_bclk=0;
    assign i2s_ws=0;
    assign i2s_data=0;
endmodule
