// Physical keys map to any of 32 fixed pitch owners. Duplicates share a voice.
module key_remap(input [11:0] physical_keys,input [59:0] keymap,
    output reg [31:0] note_keys);
    integer k;
    always @* begin
        note_keys=0;
        for(k=0;k<12;k=k+1)
            if(physical_keys[k]) note_keys=note_keys | (32'b1 << keymap[k*5+:5]);
    end
endmodule

// Upward octave layers stop at G6; never wrap into a lower octave.
module note_layers(input [31:0] notes,input ensemble,output [31:0] gates);
    assign gates=ensemble ? (notes | (notes<<12) | (notes<<24)) : notes;
endmodule
