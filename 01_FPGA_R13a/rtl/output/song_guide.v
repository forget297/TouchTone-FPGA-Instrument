// Note/control ROM only, never audio samples. 120 BPM C-major exercise.
module song_guide(input clk,input rst,input tick_ms,input enable,
    input [11:0] keys,output reg [11:0] lights);
    reg [8:0] timer;
    reg [3:0] step;
    reg [3:0] note;
    always @* begin
        case(step)
            0,1,8,9: note=0;
            2,3: note=7;
            4,5: note=9;
            6: note=7;
            7: note=5;
            10,11: note=4;
            12,13: note=2;
            default: note=0;
        endcase
        lights=keys;
        if(enable && timer<350) lights=keys|(12'b1<<note);
    end
    always @(posedge clk) begin
        if(rst || !enable) begin timer<=0; step<=0; end
        else if(tick_ms) begin
            if(timer==499) begin timer<=0; step<=step+1'b1; end
            else timer<=timer+1'b1;
        end
    end
endmodule
