// Linear saturating ADSR; steps are amplitude units per sample, not milliseconds.
module adsr(input clk, input rst, input ce, input gate,
    input [15:0] attack_step, decay_step, sustain, release_step,
    output reg [15:0] level);
    localparam IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;
    reg [2:0] state;
    reg old_gate;
    wire [16:0] raised = {1'b0,level}+{1'b0,attack_step};
    always @(posedge clk) begin
        if (rst) begin level<=0; state<=IDLE; old_gate<=0; end
        else if (ce) begin
            old_gate <= gate;
            if (gate && !old_gate) state<=ATTACK;
            else if (!gate && old_gate) state<=RELEASE;
            else case (state)
                IDLE: level<=0;
                ATTACK: if (raised>=65535) begin level<=65535; state<=DECAY; end
                        else level<=raised[15:0];
                DECAY: if (level<=sustain || level-sustain<=decay_step)
                           begin level<=sustain; state<=SUSTAIN; end
                       else level<=level-decay_step;
                SUSTAIN: level<=sustain;
                RELEASE: if (level<=release_step) begin level<=0; state<=IDLE; end
                         else level<=level-release_step;
                default: begin state<=IDLE; level<=0; end
            endcase
        end
    end
endmodule
