// Protocol v1: A5 seq cmd key duration_lo duration_hi XOR(bytes0..5) 5A.
// cmd 0=ping, 1=timed key, 2=stop remote keys; reply cmd|80, status, 00,00.
module ble_notes(input clk,input rst,input tick_ms,input rx,output tx,
    output reg [31:0] remote_keys,output reg overflow,
    input [4:0] score_index,output [7:0] score_event,
    output reg score_enabled,output reg score_restart,
    input keys_down,output reg [59:0] keymap,
    input [7:0] visual_data,input visual_valid,input visual_last,output visual_ready);
    reg [7:0] frame[0:6];
    reg [7:0] scores[0:63];
    reg active_bank,uploading;
    reg [31:0] received;
    reg [15:0] score_sum;
    wire [5:0] write_index={~active_bank,frame[3][4:0]};
    assign score_event=scores[{active_bank,score_index}];
    wire valid_events=frame[4][7:4]!=0 && frame[5][7:4]!=0 &&
        (frame[4][3:0]<12 || frame[4][3:0]==15) &&
        (frame[5][3:0]<12 || frame[5][3:0]==15);

    reg [5:0] count;
    wire [7:0] data; wire valid,tx_ready;
    reg [7:0] tx_data; reg tx_start;
    uart_rx receiver(clk,rst,rx,data,valid);
    uart_packet_mux transmitter(clk,rst,tx_data,tx_start,tx,tx_ready,
        count!=0,visual_data,visual_valid,visual_last,visual_ready);
    reg [2:0] pos;
    reg [7:0] checksum; reg [5:0] age;
    reg [12:0] remaining[0:31];
    reg [7:0] fifo[0:31]; reg [4:0] wr,rd;
    wire pop=tx_ready && !tx_start && count!=0;
    wire complete=valid && pos==7 && data==8'h5a && checksum==frame[6];
    wire enqueue=complete && count<=24;
    wire [15:0] duration={frame[5],frame[4]};
    wire good_note=frame[3]<32 && duration>=10 && duration<=5000;
    wire good_empty=frame[3]==0 && duration==0;
    reg [7:0] status;
    always @* begin
        status=1;
        case(frame[2])
            0,2,8'h10,8'h13: status=good_empty?0:2;
            1: status=good_note?0:2;
            3,4: status=(frame[3]<32 && duration==0)?0:2;
            8'h11: begin
                if(!uploading) status=3;
                else if(frame[3]<32 && !frame[3][0] && valid_events) status=0;
                else status=2;
            end
            8'h12: begin
                if(!uploading || received!=32'hffffffff) status=3;
                else if(frame[3]!=0) status=2;
                else status=duration==score_sum?0:4;
            end
            8'h14: begin
                if(frame[3]>=32 || duration!=0) status=2;
                else status=score_enabled?0:3;
            end
            8'h20: begin
                if(frame[3]>=12 || frame[4]>=32 || frame[5]!=0) status=2;
                else status=keys_down?3:0;
            end
            8'h21: status=(frame[3]<12 && duration==0)?0:2;
            8'h23: status=good_empty?0:2;
            8'h22: status=!good_empty?2:(keys_down?3:0);
            default:status=1;
        endcase
    end
    wire [7:0] reply_lo=(frame[2]==8'h23 && status==0)?8'd32:
        (frame[2]==8'h14 && status==0)?scores[{active_bank,frame[3][4:0]}]:
        (frame[2]==8'h21 && status==0)?{3'd0,keymap[frame[3]*5+:5]}:8'd0;
    wire [7:0] reply_hi=((frame[2]==8'h14 || frame[2]==8'h21 || frame[2]==8'h23) && status==0)?8'd1:8'd0;
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            keymap<=60'h5a928398a418820;
            remote_keys<=0; overflow<=0; score_enabled<=0; score_restart<=0;
            active_bank<=0; uploading<=0; received<=0; score_sum<=0; pos<=0; checksum<=0; age<=0;
            wr<=0; rd<=0; count<=0; tx_start<=0; tx_data<=0;
            for(i=0;i<32;i=i+1) remaining[i]<=0;
            for(i=0;i<7;i=i+1) frame[i]<=0;
        end else begin
            tx_start<=0; score_restart<=0;
            if(tick_ms) begin
                if(pos!=0) begin
                    if(age==49) begin pos<=0; age<=0; end else age<=age+1'b1;
                end
                for(i=0;i<32;i=i+1) if(remaining[i]!=0) begin
                    remaining[i]<=remaining[i]-1'b1;
                    if(remaining[i]==1) remote_keys[i]<=0;
                end
            end
            if(valid) begin
                age<=0;
                if(pos==0) begin
                    if(data==8'ha5) begin frame[0]<=data; checksum<=data; pos<=1; end
                end else if(pos==7) begin
                    pos<=0;
                    if(!complete && data==8'ha5) begin
                        frame[0]<=data; checksum<=data; pos<=1;
                    end
                end else begin
                    frame[pos]<=data;
                    if(pos<6) checksum<=checksum^data;
                    pos<=pos+1'b1;
                end
            end
            if(complete && !enqueue) overflow<=1;
            if(enqueue) begin
                if(status==0 && frame[2]==8'h20)
                    keymap[frame[3]*5+:5]<=frame[4][4:0];
                if(status==0 && frame[2]==8'h22) keymap<=60'h5a928398a418820;
                fifo[wr]<=8'ha5; fifo[(wr+1)&31]<=frame[1];
                fifo[(wr+2)&31]<=frame[2]|8'h80; fifo[(wr+3)&31]<=status;
                fifo[(wr+4)&31]<=reply_lo; fifo[(wr+5)&31]<=reply_hi;
                fifo[(wr+6)&31]<=8'ha5^frame[1]^(frame[2]|8'h80)^status^reply_lo^reply_hi;
                fifo[(wr+7)&31]<=8'h5a; wr<=wr+8;
                if(status==0 && frame[2]==1) begin
                    remote_keys[frame[3]]<=1; remaining[frame[3]]<=duration[12:0];
                end
                if(status==0 && frame[2]==8'h10) begin
                    uploading<=1; received<=0; score_sum<=0;
                end
                if(status==0 && frame[2]==8'h11) begin
                    scores[write_index]<=frame[4]; scores[write_index+6'd1]<=frame[5];
                    score_sum<=score_sum+{8'd0,frame[4]}+{8'd0,frame[5]}-
                        (received[frame[3][4:0]]?{8'd0,scores[write_index]}:16'd0)-
                        (received[frame[3][4:0]+5'd1]?{8'd0,scores[write_index+6'd1]}:16'd0);
                    received[frame[3][4:0]]<=1;
                    received[frame[3][4:0]+5'd1]<=1;
                end
                if(status==0 && frame[2]==8'h12) begin
                    active_bank<=~active_bank; score_enabled<=1;
                    uploading<=0; score_restart<=1;
                end
                if(status==0 && frame[2]==8'h13) begin
                    score_enabled<=0; score_restart<=1;
                end
                if(status==0 && frame[2]==3) begin
                    remote_keys[frame[3]]<=1; remaining[frame[3]]<=13'd5000;
                end
                if(status==0 && frame[2]==4) begin
                    remote_keys[frame[3]]<=0; remaining[frame[3]]<=0;
                end
                if(status==0 && frame[2]==2) begin
                    remote_keys<=0;
                    for(i=0;i<32;i=i+1) remaining[i]<=0;
                end
            end
            if(pop) begin tx_data<=fifo[rd]; rd<=rd+1'b1; tx_start<=1; end
            case({enqueue,pop})
                2'b10:count<=count+8;
                2'b01:count<=count-1'b1;
                2'b11:count<=count+7;
                default:count<=count;
            endcase
        end
    end
endmodule


