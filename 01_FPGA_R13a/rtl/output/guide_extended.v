// ROM entries are {duration_in_beats[3:0], note[3:0]}; 15 means rest.
// Three public-domain exercises; no PCM or automatic audio triggering.
module guide_extended(input clk,input rst,input tick_ms,input enable,
    input playing,input practice,input restart,input [1:0] song,input [7:0] bpm,
    input [11:0] keys,output reg [11:0] lights,output reg [5:0] step,
    output reg correct_pulse,input remote_enabled,input [7:0] remote_event);
    reg [7:0] score[0:191];
    initial $readmemh("rtl/audio/songs.hex",score);
    reg [16:0] beat_acc;
    reg [3:0] beats;
    reg [11:0] old_keys;
    reg [7:0] event_word;
    reg [11:0] expected;
    reg [6:0] blink_ms;
    wire [17:0] next_acc={1'b0,beat_acc}+bpm;
    always @* begin
        event_word=(remote_enabled && song==0)?remote_event:score[{song,step}];
        expected=event_word[3:0]<12 ? (12'b1<<event_word[3:0]):12'b0;
        // Performance: show touched keys. Guide: only show the score target.
        lights=enable ? 12'b0 : keys;
        if(enable && playing && (practice || beat_acc<42000)) lights=expected;
        // A short all-off pulse acknowledges a correct note in practice mode.
        if(enable && practice && blink_ms!=0) lights=0;
    end
    task advance;
        begin step<=step==31?0:step+1'b1; beats<=0; beat_acc<=0; end
    endtask
    always @(posedge clk) begin
        if(rst || !enable || restart) begin
            step<=0; beat_acc<=0; beats<=0; old_keys<=keys; correct_pulse<=0; blink_ms<=0;
        end else begin
            old_keys<=keys; correct_pulse<=0;
            if(tick_ms && blink_ms!=0) blink_ms<=blink_ms-1'b1;
            if(playing) begin
                if(practice && expected!=0) begin
                    if((keys & ~old_keys & expected)!=0) begin
                        advance; correct_pulse<=1; blink_ms<=80;
                    end
                end else if(tick_ms) begin
                    if(next_acc>=60000) begin
                        beat_acc<=next_acc-60000;
                        if(beats+1>=event_word[7:4]) advance;
                        else beats<=beats+1'b1;
                    end else beat_acc<=next_acc;
                end
            end
        end
    end
endmodule
