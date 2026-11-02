module input_mapper #(parameter CENTER_X=825,parameter CENTER_Y=825,parameter PRESSURE_INVERT=0,
    parameter MIN_GAIN=32,parameter GAIN_SHIFT=3)(input clk,input rst,input ce,input [11:0] pressure,joy_x,joy_y,
    input pressure_enable,input test_mode,output reg [7:0] gain,
    output reg signed [8:0] pitch);
    reg [31:0] lfo_phase;
    wire [7:0] lfo_triangle=lfo_phase[31]?~lfo_phase[30:23]:lfo_phase[30:23];
    wire signed [8:0] lfo=$signed({1'b0,lfo_triangle})-9'sd128;
    reg signed [12:0] dx,dy;
    reg signed [8:0] bend,depth;
    reg signed [17:0] vib;
    reg signed [9:0] target_pitch;
    reg [7:0] target_gain;
    wire [11:0] calibrated_pressure=PRESSURE_INVERT ? (pressure>=1650?12'd0:12'd1650-pressure):pressure;
    always @* begin
        dx=$signed({1'b0,joy_x})-CENTER_X;
        dy=$signed({1'b0,joy_y})-CENTER_Y;
        if(dx>825) dx=825; if(dx < -825) dx=-825;
        if(dy>825) dy=825; if(dy < -825) dy=-825;
        bend=(dx>35 || dx < -35)?(dx>>>2):0;
        depth=(dy>35)?(dy>>>5):0;
        vib=lfo*depth;
        target_pitch=test_mode?0:bend+(vib>>>7);
        if(test_mode || !pressure_enable) target_gain=192;
        else if(calibrated_pressure>=1536) target_gain=224;
        else target_gain=MIN_GAIN+(calibrated_pressure>>GAIN_SHIFT);
    end
    always @(posedge clk) begin
        if(rst) begin lfo_phase<=0; gain<=MIN_GAIN; pitch<=0; end
        else if(ce) begin
            lfo_phase<=lfo_phase+32'd458130; // 5Hz
            if(gain<target_gain) gain<=gain+1'b1;
            else if(gain>target_gain) gain<=gain-1'b1;
            if(pitch<target_pitch) pitch<=pitch+1'b1;
            else if(pitch>target_pitch) pitch<=pitch-1'b1;
        end
    end
endmodule
