// Initialization table. ADC/touch scheduling lives in sensor_hub.
module mpr121_ctrl(input [5:0] index, output reg [7:0] addr, value,
    output last);
    assign last=index==40;
    always @* begin
        addr=0; value=0;
        case(index)
            0: begin addr=8'h80; value=8'h63; end
            1: begin addr=8'h5e; value=0; end
            2: begin addr=8'h2b; value=1; end
            3: begin addr=8'h2c; value=1; end
            4: begin addr=8'h2d; value=0; end
            5: begin addr=8'h2e; value=0; end
            6: begin addr=8'h2f; value=1; end
            7: begin addr=8'h30; value=1; end
            8: begin addr=8'h31; value=8'hff; end
            9: begin addr=8'h32; value=2; end
            10: begin addr=8'h33; value=0; end
            11: begin addr=8'h34; value=0; end
            12: begin addr=8'h35; value=0; end
            13: begin addr=8'h5b; value=0; end // no extra debounce scan
            14: begin addr=8'h5c; value=8'h10; end
            15: begin addr=8'h5d; value=8'h20; end // ESI=1ms, SFI=4
            40: begin addr=8'h5e; value=8'h8c; end // baseline init, 12 electrodes
            default: if(index>=16 && index<40) begin
                addr=8'h41+index-16;
                value=index[0]?8'd6:8'd12;
            end
        endcase
    end
endmodule
