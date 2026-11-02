module phase_accumulator(input clk, input rst, input ce,
    input [31:0] fcw, output reg [31:0] phase);
    always @(posedge clk) begin
        if (rst) phase <= 0;
        else if (ce) phase <= phase + fcw;
    end
endmodule
