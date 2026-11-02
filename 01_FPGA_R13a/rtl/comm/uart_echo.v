module uart_echo #(
    parameter CLOCK_HZ = 27000000,
    parameter BAUD = 115200
)(
    input clk,
    input rst,
    input uart_rx_i,
    output uart_tx_o,
    output reg overflow
);
    wire [7:0] rx_data;
    wire rx_valid;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_ready;

    reg [7:0] fifo [0:15];
    reg [3:0] write_ptr, read_ptr;
    reg [4:0] fifo_count;
    wire push = rx_valid && (fifo_count != 5'd16);
    // Hold off for one cycle after raising start: uart_tx samples start on the
    // following edge while ready is still combinationally high.
    wire pop = tx_ready && !tx_start && (fifo_count != 0);

    uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) receiver(
        clk,rst,uart_rx_i,rx_data,rx_valid);
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) transmitter(
        clk,rst,tx_data,tx_start,uart_tx_o,tx_ready);

    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= 4'd0;
            read_ptr <= 4'd0;
            fifo_count <= 5'd0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            overflow <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            if (rx_valid && !push)
                overflow <= 1'b1;
            if (push) begin
                fifo[write_ptr] <= rx_data;
                write_ptr <= write_ptr+1'b1;
            end
            if (pop) begin
                tx_data <= fifo[read_ptr];
                read_ptr <= read_ptr+1'b1;
                tx_start <= 1'b1;
            end
            case ({push,pop})
                2'b10: fifo_count <= fifo_count+1'b1;
                2'b01: fifo_count <= fifo_count-1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule
