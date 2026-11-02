// Read/capture/write/publish on different clocks. Requires >=4 clocks per ce.
// Never depend on FPGA RAM read-during-write behaviour.
module audio_effect #(parameter DELAY_BITS=12,parameter STRONG_WET=0)(input clk, input rst, input ce, input enable,
    input [1:0] wet, input signed [15:0] dry,
    output reg signed [15:0] sample);
    localparam DELAY_SAMPLES=1<<DELAY_BITS;
    reg signed [15:0] delay_mem[0:DELAY_SAMPLES-1];
    reg signed [15:0] ram_q,delayed;
    reg [DELAY_BITS-1:0] ptr;
    reg [DELAY_BITS:0] filled;
    reg [1:0] state;
    reg valid_delay,held_enable;
    reg [1:0] held_wet;
    reg signed [15:0] held_dry;
    reg signed [17:0] combined;
    wire ram_rd_en=!rst && state==0 && ce;
    wire ram_wr_en=!rst && state==2;
    // No bulk reset on RAM. Invalid startup contents masked by filled.
    always @(posedge clk) begin
        if(ram_rd_en) ram_q<=delay_mem[ptr];
        if(ram_wr_en) delay_mem[ptr]<=held_dry;
    end
    always @* begin
        combined = $signed(held_dry);
        if(held_enable && valid_delay)
            case(held_wet)
                1: combined=$signed(held_dry)+($signed(delayed)>>>(STRONG_WET?1:3));
                2: if(STRONG_WET) combined=$signed(held_dry)+($signed(delayed)>>>1)+($signed(delayed)>>>2);
                   else combined=$signed(held_dry)+($signed(delayed)>>>2);
                3: combined=$signed(held_dry)+($signed(delayed)>>>(STRONG_WET?0:1));
                default: combined=$signed(held_dry);
            endcase
    end
    always @(posedge clk) begin
        if(rst) begin ptr<=0; filled<=0; state<=0; sample<=0; held_dry<=0;
            delayed<=0; valid_delay<=0; held_enable<=0; held_wet<=0; end
        else case(state)
            0: if(ce) begin
                held_dry<=dry; held_enable<=enable; held_wet<=wet;
                valid_delay<=filled>=DELAY_SAMPLES; state<=1;
            end
            1: begin delayed<=ram_q; state<=2; end
            2: begin
                ptr<=ptr+1'b1;
                if(filled<DELAY_SAMPLES) filled<=filled+1'b1;
                state<=3;
            end
            3: begin
                if(combined>32767) sample<=32767;
                else if(combined < -32768) sample<=-32768;
                else sample<=combined[15:0];
                state<=0;
            end
        endcase
    end
endmodule
