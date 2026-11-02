module user_controls(input clk,input rst,input tick_ms,
    input enc_a,input enc_b,input enc_sw,input joy_sw,input mode_button,
    output reg timbre,output reg [2:0] menu,output reg [1:0] mode,
    output reg pressure_enable,output reg [15:0] attack_step,decay_step,sustain,release_step,
    output reg [1:0] wet);
    wire up,down,enc_press,joy_press,mode_press;
    wire unused0,unused1,unused2;
    encoder knob(clk,rst,tick_ms,enc_a,enc_b,up,down);
    debounce d0(clk,rst,tick_ms,enc_sw,unused0,enc_press);
    debounce d1(clk,rst,tick_ms,joy_sw,unused1,joy_press);
    debounce #(.ACTIVE_LOW(0)) d2(clk,rst,tick_ms,mode_button,unused2,mode_press);
    always @(posedge clk) begin
        if(rst) begin timbre<=0; menu<=0; mode<=0; pressure_enable<=1;
            attack_step<=1024; decay_step<=32; sustain<=40000; release_step<=64; wet<=0; end
        else begin
            if(enc_press) menu<=menu==5?0:menu+1'b1;
            if(joy_press) pressure_enable<=!pressure_enable;
            if(mode_press) mode<=mode==2?0:mode+1'b1;
            if(up||down) case(menu)
                0: timbre<=!timbre;
                1: if(up && attack_step<8192) attack_step<=attack_step<<1;
                   else if(down && attack_step>16) attack_step<=attack_step>>1;
                2: if(up && decay_step<1024) decay_step<=decay_step<<1;
                   else if(down && decay_step>4) decay_step<=decay_step>>1;
                3: if(up && sustain<=57343) sustain<=sustain+4096;
                   else if(down && sustain>=8192) sustain<=sustain-4096;
                4: if(up && release_step<1024) release_step<=release_step<<1;
                   else if(down && release_step>4) release_step<=release_step>>1;
                5: wet<=up?wet+1'b1:wet-1'b1;
            endcase
        end
    end
endmodule
