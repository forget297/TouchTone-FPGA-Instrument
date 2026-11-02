module uart_rx #(
    parameter CLOCK_HZ = 27000000,
    parameter BAUD = 115200
)(
    input clk,
    input rst,
    input rx,
    output reg [7:0] data,
    output reg valid
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam integer HALF_BIT = CLKS_PER_BIT / 2;
    localparam [1:0] IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;

    reg rx_meta, rx_sync;
    reg [1:0] state;
    reg [15:0] count;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
            state <= IDLE;
            count <= 16'd0;
            bit_index <= 3'd0;
            shift <= 8'd0;
            data <= 8'd0;
            valid <= 1'b0;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
            valid <= 1'b0;
            case (state)
                IDLE: if (!rx_sync) begin
                    count <= HALF_BIT-1;
                    state <= START;
                end
                START: if (count != 0)
                    count <= count-1'b1;
                else if (!rx_sync) begin
                    count <= CLKS_PER_BIT-1;
                    bit_index <= 3'd0;
                    state <= DATA;
                end else
                    state <= IDLE;
                DATA: if (count != 0)
                    count <= count-1'b1;
                else begin
                    shift[bit_index] <= rx_sync;
                    count <= CLKS_PER_BIT-1;
                    if (bit_index == 3'd7)
                        state <= STOP;
                    else
                        bit_index <= bit_index+1'b1;
                end
                STOP: if (count != 0)
                    count <= count-1'b1;
                else begin
                    if (rx_sync) begin
                        data <= shift;
                        valid <= 1'b1;
                    end
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
