// Normal: press encoder cycles ten menus. Guide: press selects song, turn tempo.
// Hold encoder 800ms in guide toggles wait-for-correct-note practice mode.
module controls_extended(input clk,input rst,input tick_ms,input ce,
    input enc_a,input enc_b,input enc_sw,input joy_sw,input mode_button,
    output reg [1:0] timbre,output reg [3:0] menu,output reg [1:0] mode,
    output reg pressure_enable,output reg ensemble,
    output reg [15:0] attack_step,decay_step,sustain,release_step,
    output reg [1:0] wet,output reg [1:0] song,
    output reg [7:0] bpm,output reg playing,output reg practice,
    output reg restart, output reg [4:0] audition_note,
    output reg audition_gate, output reg audition_all, output reg [1:0] display_view, output reg [1:0] note_page);
    wire up,down,enc_level,enc_press,joy_press,mode_press;
    wire jlevel,mlevel;
    reg [9:0] hold_ms;
    reg previous_level,long_seen;
    reg [9:0] audition_ms; reg audition_hold;
    encoder knob(clk,rst,tick_ms,enc_a,enc_b,up,down);
    debounce de(clk,rst,tick_ms,enc_sw,enc_level,enc_press);
    debounce dj(clk,rst,tick_ms,joy_sw,jlevel,joy_press);
    debounce #(.ACTIVE_LOW(0)) dm(clk,rst,tick_ms,mode_button,mlevel,mode_press);
    always @(posedge clk) begin
        if(rst) begin
            timbre<=1; menu<=0; mode<=0; pressure_enable<=1; ensemble<=0;
            attack_step<=256; decay_step<=2; sustain<=49152; release_step<=4;
            wet<=0; song<=0; bpm<=120; playing<=1; practice<=0; restart<=0;
            hold_ms<=0; previous_level<=0; long_seen<=0;
            audition_note<=0; audition_gate<=0; audition_all<=0; audition_ms<=0; audition_hold<=0; display_view<=0; note_page<=0;
        end else begin
            restart<=0; previous_level<=enc_level;
            if(mode!=0 || (menu!=8 && !audition_all)) begin audition_gate<=0; audition_all<=0; audition_ms<=0; audition_hold<=0; end
            else if(tick_ms && audition_ms!=0 && !audition_hold) begin
                audition_ms<=audition_ms-1'b1;
                if(audition_ms==1) audition_gate<=0;
            end
            if(!enc_level) begin hold_ms<=0; long_seen<=0; end
            else if(tick_ms && hold_ms<800) begin
                hold_ms<=hold_ms+1'b1;
                if(hold_ms==799) begin
                    long_seen<=1;
                    if(mode==2) begin practice<=!practice; restart<=1; end
                    else if(mode==0 && menu==8) begin audition_all<=!audition_all; audition_gate<=!audition_all; audition_hold<=!audition_all; audition_ms<=0; end
                end
            end
            if(mode_press) begin mode<=mode==2?0:mode+1'b1; restart<=1; playing<=1; end
            if(joy_press) begin
                if(mode==2) playing<=!playing;
                else if(mode==0 && menu==8) begin
                    audition_all<=0; audition_hold<=!audition_hold; audition_gate<=!audition_hold; audition_ms<=0;
                end else if(mode==0 && menu==9 && display_view==3) note_page<=note_page+1'b1;
                else pressure_enable<=!pressure_enable;
            end
            // Short click acts on release so a long click never also selects a song.
            if(previous_level && !enc_level && !long_seen) begin
                if(mode==2) begin song<=song==2?0:song+1'b1; restart<=1; end
                else menu<=menu==9?0:menu+1'b1;
            end
            if(up||down) begin
                if(mode==2) begin
                    if(up && bpm<180) bpm<=bpm+10;
                    if(down && bpm>60) bpm<=bpm-10;
                end else case(menu)
                    0: begin
                        timbre<=up?(timbre==3?0:timbre+1'b1):(timbre==0?3:timbre-1'b1);
                        // Presets: selecting timbre resets ADSR; subsequent menus override it.
                        if((up && timbre==1) || (down && timbre==3)) begin
                            attack_step<=8192; decay_step<=2; sustain<=0; release_step<=4;
                        end else begin attack_step<=256; decay_step<=2; sustain<=49152; release_step<=4; end
                    end
                    // Up means MORE time; step is inversely proportional to time.
                    1: if(up && attack_step>1) attack_step<=attack_step>>1;
                       else if(down && attack_step<32768) attack_step<=attack_step<<1;
                    2: if(up && decay_step>1) decay_step<=decay_step>>1;
                       else if(down && decay_step<32768) decay_step<=decay_step<<1;
                    3: if(up) sustain<=sustain>=57343?16'd65535:sustain+16'd8192;
                       else if(down) sustain<=sustain<=8192?16'd0:sustain-16'd8192;
                    4: if(up && release_step>1) release_step<=release_step>>1;
                       else if(down && release_step<32768) release_step<=release_step<<1;
                    5: wet<=up?wet+1'b1:wet-1'b1;
                    6: ensemble<=!ensemble;
                    8: if(mode==0) begin
                        audition_note<=up?audition_note+1'b1:audition_note-1'b1;
                        audition_gate<=1; audition_all<=0; audition_hold<=0; audition_ms<=800;
                    end
                    9: display_view<=up?display_view+1'b1:display_view-1'b1;
                    7: begin song<=up?(song==2?0:song+1'b1):(song==0?2:song-1'b1); restart<=1; end
                endcase
            end
        end
    end
endmodule
