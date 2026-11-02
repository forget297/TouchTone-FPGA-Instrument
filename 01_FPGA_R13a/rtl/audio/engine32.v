// 32 independent oscillator/envelope states, four parallel 8-slot pipelines.
// Every lane finishes in 49 clocks, independent of the number of active notes.
module engine32 #(parameter NORMAL_SHIFT=13, parameter PITCH_SHIFT=11, parameter TIMBRE_COMP=0)(input clk,input rst,input ce,input [31:0] gates,
    input test_mode,input [1:0] timbre,input signed [8:0] pitch,
    input [15:0] attack_step,decay_step,sustain,release_step,
    input [7:0] gain,output reg signed [15:0] sample,
    output reg frame_done,output reg overrun,output [31:0] active,
    output [3:0] voice_valid,output [11:0] voice_slot,
    output [63:0] voice_sample,output [127:0] voice_fcw);
    wire signed [18:0] sums[0:3];
    wire [3:0] done,busy;
    reg signed [20:0] total;
    reg signed [29:0] product;
    reg [2:0] publish;
    reg [7:0] held_gain;
    reg held_test;
    reg [1:0] held_timbre;
    reg signed [31:0] compensated,scaled;
    always @* begin
        compensated={{2{product[29]}},product};
        if(TIMBRE_COMP && !held_test) begin
            // R12: sine x3, organ x1.25, pluck x2, triangle x4.5.
            // Each expression fits signed 32 bits even for 32 maximum voices.
            case(held_timbre)
                0: compensated=(compensated<<<1)+compensated;
                1: compensated=compensated+(compensated>>>2);
                2: compensated=compensated<<<1;
                3: compensated=(compensated<<<2)+(compensated>>>1);
            endcase
        end
        scaled = compensated >>> (held_test ? 13 : NORMAL_SHIFT);
    end
    genvar k;
    generate for(k=0;k<4;k=k+1) begin: lanes
        synth_lane #(.BASE(k*8),.PITCH_SHIFT(PITCH_SHIFT)) lane(clk,rst,ce,gates[k*8+:8],test_mode,timbre,pitch,
            attack_step,decay_step,sustain,release_step,sums[k],done[k],busy[k],active[k*8+:8],
            voice_valid[k],voice_slot[k*3+:3],voice_sample[k*16+:16],voice_fcw[k*32+:32]);
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin sample<=0; frame_done<=0; overrun<=0; publish<=0;
            total<=0; product<=0; held_gain<=0; held_test<=0; held_timbre<=0; end
        else begin
            frame_done<=0;
            if(ce) begin held_gain<=gain; held_test<=test_mode; held_timbre<=timbre;
                if(|busy || publish!=0) overrun<=1; end
            if(&done) begin
                total<=$signed({{2{sums[0][18]}},sums[0]})+
                       $signed({{2{sums[1][18]}},sums[1]})+
                       $signed({{2{sums[2][18]}},sums[2]})+
                       $signed({{2{sums[3][18]}},sums[3]});
                publish<=1;
            end else if(publish==1) begin product<=total*$signed({1'b0,held_gain}); publish<=2; end
            else if(publish==2) begin
                // Test retains /32 headroom. Normal gain is configurable;
                // saturate before narrowing so loud chords never wrap sign.
                if(scaled>32767) sample<=32767;
                else if(scaled < -32768) sample<=-32768;
                else sample<=scaled[15:0];
                frame_done<=1; publish<=0;
            end
        end
    end
endmodule

module synth_lane #(parameter BASE=0,parameter PITCH_SHIFT=11)(input clk,input rst,input ce,input [7:0] gates,
    input test_mode,input [1:0] timbre,input signed [8:0] pitch,
    input [15:0] attack_step,decay_step,sustain,release_step,
    output reg signed [18:0] sum_out,output reg done,output reg busy,output [7:0] active,
    output sample_valid,output [2:0] sample_slot,output signed [15:0] voice_sample,output [31:0] voice_fcw);
    reg [31:0] phases[0:7];
    wire [15:0] envelopes[0:7];
    reg [31:0] frequencies[0:31];
    reg [31:0] test_frequencies[0:31];
    reg signed [15:0] wavetable[0:1023];
    initial begin
        $readmemh("rtl/audio/notes32.hex",frequencies);
        $readmemh("rtl/audio/test32.hex",test_frequencies);
        $readmemh("rtl/audio/instruments.hex",wavetable);
    end
    genvar v;
    generate for(v=0;v<8;v=v+1) begin: voices
        adsr env(clk,rst,ce,gates[v]|test_mode,attack_step,decay_step,sustain,release_step,envelopes[v]);
        assign active[v]=envelopes[v]!=0;
    end endgenerate
    reg [2:0] slot,stage;
    reg [1:0] held_timbre;
    reg held_test;
    reg signed [8:0] held_pitch;
    reg [31:0] base_word;
    reg signed [41:0] delta;
    reg signed [15:0] wave;
    reg signed [32:0] product;
    reg signed [18:0] accumulator;
    assign sample_valid=busy && stage==5;
    assign sample_slot=slot;
    assign voice_sample=product>>>16;
    assign voice_fcw=base_word+(delta>>>PITCH_SHIFT);
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<8;i=i+1) phases[i]<=0;
            slot<=0; stage<=0; busy<=0; done<=0; sum_out<=0;
            held_timbre<=0; held_test<=0; held_pitch<=0;
            base_word<=0; delta<=0; wave<=0; product<=0; accumulator<=0;
        end else begin
            done<=0;
            if(ce) begin
                slot<=0; stage<=0; accumulator<=0; busy<=1;
                held_test<=test_mode; held_timbre<=test_mode?0:timbre;
                held_pitch<=test_mode?0:pitch;
            end else if(busy) case(stage)
                0: begin base_word<=held_test?test_frequencies[BASE+slot]:frequencies[BASE+slot]; stage<=1; end
                1: begin delta<=$signed({1'b0,base_word})*held_pitch; stage<=2; end
                2: begin phases[slot]<=phases[slot]+base_word+(delta>>>PITCH_SHIFT); stage<=3; end
                3: begin wave<=wavetable[{held_timbre,phases[slot][31:24]}]; stage<=4; end
                4: begin product<=wave*$signed({1'b0,envelopes[slot]}); stage<=5; end
                5: begin accumulator<=accumulator+(product>>>16);
                    if(slot==7) stage<=6; else begin slot<=slot+1'b1; stage<=0; end end
                6: begin sum_out<=accumulator; busy<=0; done<=1; end
                default: begin busy<=0; end
            endcase
        end
    end
endmodule
