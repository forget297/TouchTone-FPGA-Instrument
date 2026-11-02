// Clock-rate quadrature capture, joint-state 20us stability filter at 27MHz.
// Four legal net transitions make one event, independent of resting AB state.
// tick_ms retained for interface compatibility; rotation no longer samples at 1kHz.
module encoder #(parameter FILTER_CYCLES=540)(input clk,input rst,input tick_ms,input a,input b,
    output reg up,output reg down);
    reg [1:0] a_sync,b_sync,last,candidate;
    reg [15:0] stable_count;
    reg armed;
    reg signed [3:0] movement;
    reg signed [2:0] delta;
    wire [1:0] now={a_sync[1],b_sync[1]};
    wire signed [4:0] next_movement=$signed(movement)+$signed(delta);
    always @* begin
        case({last,now})
            4'b1101,4'b0100,4'b0010,4'b1011: delta=1;
            4'b1110,4'b1000,4'b0001,4'b0111: delta=-1;
            default: delta=0;
        endcase
    end
    always @(posedge clk) begin
        a_sync<={a_sync[0],a}; b_sync<={b_sync[0],b}; up<=0; down<=0;
        if(rst) begin a_sync<=3; b_sync<=3; last<=3; candidate<=3;
            stable_count<=0; armed<=0; movement<=0; end
        else if(now!=candidate) begin candidate<=now; stable_count<=0; end
        else if(stable_count<FILTER_CYCLES-1) stable_count<=stable_count+1'b1;
        else if(!armed) begin last<=now; movement<=0; armed<=1; end
        else if(now!=last) begin
            last<=now;
            if((last^now)==3) movement<=0; // ambiguous simultaneous transition
            else if(next_movement>=4) begin up<=1; movement<=0; end
            else if(next_movement<=-4) begin down<=1; movement<=0; end
            else movement<=next_movement[3:0];
        end
    end
endmodule
