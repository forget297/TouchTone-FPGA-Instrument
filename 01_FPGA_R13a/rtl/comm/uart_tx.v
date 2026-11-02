module uart_tx #(
    parameter CLOCK_HZ = 27000000,
    parameter BAUD = 115200
)(
    input clk,
    input rst,
    input [7:0] data,
    input start,
    output reg tx,
    output ready
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam [1:0] IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;

    reg [1:0] state;
    reg [15:0] count;
    reg [2:0] bit_index;
    reg [7:0] shift;
    assign ready = (state == IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            count <= 16'd0;
            bit_index <= 3'd0;
            shift <= 8'd0;
            tx <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (start) begin
                        shift <= data;
                        count <= CLKS_PER_BIT-1;
                        tx <= 1'b0;
                        state <= START;
                    end
                end
                START: if (count != 0)
                    count <= count-1'b1;
                else begin
                    bit_index <= 3'd0;
                    tx <= shift[0];
                    count <= CLKS_PER_BIT-1;
                    state <= DATA;
                end
                DATA: if (count != 0)
                    count <= count-1'b1;
                else if (bit_index == 3'd7) begin
                    tx <= 1'b1;
                    count <= CLKS_PER_BIT-1;
                    state <= STOP;
                end else begin
                    bit_index <= bit_index+1'b1;
                    shift <= {1'b0,shift[7:1]};
                    tx <= shift[1];
                    count <= CLKS_PER_BIT-1;
                end
                STOP: if (count != 0)
                    count <= count-1'b1;
                else begin
                    tx <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
