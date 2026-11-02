// Complete legacy replies (8 bytes) and visual packets (42 bytes) never interleave.
// Control replies win between visual packets. At 115200, blocking is <=3.7ms.
module uart_packet_mux(input clk,input rst,input [7:0] cmd_data,input cmd_start,
    output tx,output cmd_ready,input cmd_pending,
    input [7:0] visual_data,input visual_valid,input visual_last,output visual_ready);
    wire ready; reg start,locked; reg [7:0] data;
    uart_tx physical(clk,rst,data,start,tx,ready);
    assign cmd_ready=ready && !start && !locked && !(visual_valid && !cmd_pending);
    assign visual_ready=ready && !start && !cmd_start && (locked || !cmd_pending);
    always @(posedge clk) begin
        if(rst) begin start<=0; locked<=0; data<=0; end
        else begin
            start<=0;
            if(cmd_start && !locked) begin data<=cmd_data;start<=1;end
            else if(visual_valid && visual_ready) begin
                data<=visual_data;start<=1;locked<=!visual_last;
            end
        end
    end
endmodule
