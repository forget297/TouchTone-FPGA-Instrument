// Real audio analysis, no synthetic graph. 1024-point Hann-windowed DFT,
// bins 0..127, Fs=46875, spacing=45.776367Hz. Sequential MAC reuses DSPs.
// Magnitude approximation max(|Re|,|Im|)+3/8*min, normalized to peak PCM.
// Visual work never stalls synthesis. Frozen snapshots sent every >=250ms.
module visual_monitor(input clk,input rst,input ce,input signed [15:0] audio,
    input [3:0] voice_valid,input [11:0] voice_slot,
    input [63:0] voice_sample,input [127:0] voice_fcw,
    input [31:0] active,input [3:0] menu,input [1:0] mode,timbre,view,note_page,
    input [4:0] audition_note,input audition_on,input audition_all,input fault,
    output reg [7:0] tx_data,output reg tx_valid,output tx_last,input tx_ready);
    parameter PERIOD_CLOCKS=6750000;
    reg signed [15:0] raw_mem[0:1023],win_mem[0:1023];
    reg signed [15:0] hann[0:1023],sin_rom[0:1023],cos_rom[0:1023];
    reg [7:0] payload[0:735];
    reg pwe=0; reg [9:0] paddr; reg [7:0] pdata;
    always @(posedge clk) if(pwe) payload[paddr]<=pdata;
    initial begin
        $readmemh("rtl/visual/hann.hex",hann);
        $readmemh("rtl/visual/sin.hex",sin_rom);
        $readmemh("rtl/visual/cos.hex",cos_rom);
    end
    localparam CAP=0,DREAD=1,DMUL=2,DACC=3,DNEXT=4,MAG=5,
        MAGLO=6,MAGHI=7,META=8,WREAD=9,WSTORE=10,XREAD=11,XSTORE=12,
        YREAD=13,YSTORE=14,VOICE=15,LOAD=16,SEND=17,WAIT=18;
    reg [4:0] state;
    reg [22:0] period;
    reg [9:0] cap_index,cap_addr,n,phase,trigger_index;
    reg [1:0] cap_pipe;
    reg signed [15:0] cap_sample,hann_q,raw_q,sample_q,cos_q,sin_q;
    reg signed [31:0] window_product,pr,pi;
    reg signed [41:0] re,im;
    reg [6:0] bin,point;
    wire [41:0] abs_re=re[41]?-re:re,abs_im=im[41]?-im:im;
    wire [42:0] magnitude=(abs_re>=abs_im)?{1'b0,abs_re}+(({1'b0,abs_im}*3)>>3):
        {1'b0,abs_im}+(({1'b0,abs_re}*3)>>3);
    wire [42:0] normalized=magnitude>>(bin==0?24:23);
    reg [15:0] mag;
    reg [9:0] addr;
    reg armed,trigger_found;
    reg [15:0] output_peak;
    wire [15:0] audio_abs=audio[15]?-audio:audio;
    reg [31:0] snapshot_active;
    reg [3:0] snapshot_menu;
    reg [1:0] snapshot_mode,snapshot_timbre,snapshot_view,snapshot_page;
    reg [4:0] snapshot_note;
    reg snapshot_on,snapshot_all,snapshot_fault;
    reg [7:0] sequence_id;
    reg [5:0] byte_index;
    reg [9:0] offset;
    reg [15:0] crc;
    reg [4:0] note;
    reg [2:0] field;
    reg [31:0] fcw_latched;
    reg [15:0] peak_latched;
    reg [5:0] meta_index;
    reg [15:0] peak0[0:7],peak1[0:7],peak2[0:7],peak3[0:7];
    reg [31:0] fcw0[0:7],fcw1[0:7],fcw2[0:7],fcw3[0:7];
    wire [15:0] v0=voice_sample[15]?-voice_sample[15:0]:voice_sample[15:0];
    wire [15:0] v1=voice_sample[31]?-voice_sample[31:16]:voice_sample[31:16];
    wire [15:0] v2=voice_sample[47]?-voice_sample[47:32]:voice_sample[47:32];
    wire [15:0] v3=voice_sample[63]?-voice_sample[63:48]:voice_sample[63:48];
    assign tx_last=byte_index==41;
    function [15:0] crc_byte;
        input [15:0] c;input [7:0] d;reg [15:0] v;integer j;
        begin v=c^{d,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end
    endfunction
    function [7:0] pixel;
        input signed [15:0] v;
        begin pixel=v[15:8]^8'h80;end
    endfunction
    integer i;
    always @(posedge clk) begin
        pwe<=0;
        hann_q<=hann[cap_index];
        // Dedicated synchronous reads permit block RAM inference.
        raw_q<=raw_mem[addr];
        if(state==DREAD) begin sample_q<=win_mem[n];cos_q<=cos_rom[phase];sin_q<=sin_rom[phase];end
        if(rst) begin
            state<=CAP;period<=0;cap_index<=0;cap_addr<=0;cap_pipe<=0;tx_valid<=0;
            tx_data<=0;sequence_id<=0;trigger_index<=0;trigger_found<=0;armed<=0;
            output_peak<=0;point<=0;addr<=0;n<=0;phase<=0;bin<=0;re<=0;im<=0;
            for(i=0;i<8;i=i+1) begin peak0[i]<=0;peak1[i]<=0;peak2[i]<=0;peak3[i]<=0;
                fcw0[i]<=0;fcw1[i]<=0;fcw2[i]<=0;fcw3[i]<=0;end
        end else begin
            if(period<PERIOD_CLOCKS)period<=period+1'b1;
            if(state==CAP) begin
                if(voice_valid[0])begin fcw0[voice_slot[2:0]]<=voice_fcw[31:0];if(v0>peak0[voice_slot[2:0]])peak0[voice_slot[2:0]]<=v0;end
                if(voice_valid[1])begin fcw1[voice_slot[5:3]]<=voice_fcw[63:32];if(v1>peak1[voice_slot[5:3]])peak1[voice_slot[5:3]]<=v1;end
                if(voice_valid[2])begin fcw2[voice_slot[8:6]]<=voice_fcw[95:64];if(v2>peak2[voice_slot[8:6]])peak2[voice_slot[8:6]]<=v2;end
                if(voice_valid[3])begin fcw3[voice_slot[11:9]]<=voice_fcw[127:96];if(v3>peak3[voice_slot[11:9]])peak3[voice_slot[11:9]]<=v3;end
            end
            case(state)
            CAP: begin
                if(ce && cap_pipe==0)begin
                    raw_mem[cap_index]<=audio;cap_sample<=audio;cap_addr<=cap_index;cap_pipe<=1;
                    if(audio_abs>output_peak)output_peak<=audio_abs;
                    if(audio < -128)armed<=1;
                    if(armed && audio>=0 && !trigger_found && cap_index<496)begin trigger_index<=cap_index;trigger_found<=1;end
                end
                if(cap_pipe==1)begin window_product<=cap_sample*hann_q;cap_pipe<=2;end
                if(cap_pipe==2)begin
                    win_mem[cap_addr]<=window_product>>>15;cap_pipe<=0;
                    if(cap_index==1023)begin
                        snapshot_active<=active;snapshot_menu<=menu;snapshot_mode<=mode;snapshot_timbre<=timbre;
                        snapshot_view<=view;snapshot_page<=note_page;snapshot_note<=audition_note;
                        snapshot_on<=audition_on;snapshot_all<=audition_all;snapshot_fault<=fault;
                        bin<=0;n<=0;phase<=0;re<=0;im<=0;state<=DREAD;
                    end else cap_index<=cap_index+1'b1;
                end
            end
            DREAD:state<=DMUL;
            DMUL:begin pr<=sample_q*cos_q;pi<=sample_q*sin_q;state<=DACC;end
            DACC:begin re<=re+pr;im<=im+pi;state<=DNEXT;end
            DNEXT:if(n==1023)state<=MAG;else begin n<=n+1'b1;phase<=phase+bin;state<=DREAD;end
            MAG:begin mag<=normalized>65535?16'hffff:normalized[15:0];state<=MAGLO;end
            MAGLO:begin begin paddr<=288+{bin,1'b0}; pdata<=mag[7:0]; pwe<=1; end state<=MAGHI;end
            MAGHI:begin
                begin paddr<=289+{bin,1'b0}; pdata<=mag[15:8]; pwe<=1; end
                if(bin==127)begin meta_index<=0;state<=META;end
                else begin bin<=bin+1'b1;n<=0;phase<=0;re<=0;im<=0;state<=DREAD;end
            end
            META:begin
                case(meta_index)
                0:begin paddr<=meta_index; pdata<=13; pwe<=1; end 1:begin paddr<=meta_index; pdata<=snapshot_menu; pwe<=1; end
                2:begin paddr<=meta_index; pdata<={6'b0,snapshot_mode}; pwe<=1; end 3:begin paddr<=meta_index; pdata<={6'b0,snapshot_timbre}; pwe<=1; end
                4:begin paddr<=meta_index; pdata<={6'b0,snapshot_view}; pwe<=1; end 5:begin paddr<=meta_index; pdata<={6'b0,snapshot_page}; pwe<=1; end
                6:begin paddr<=meta_index; pdata<={3'b0,snapshot_note}; pwe<=1; end 7:begin paddr<=meta_index; pdata<={5'b0,snapshot_all,snapshot_fault,snapshot_on}; pwe<=1; end
                8:begin paddr<=meta_index; pdata<=snapshot_active[7:0]; pwe<=1; end 9:begin paddr<=meta_index; pdata<=snapshot_active[15:8]; pwe<=1; end
                10:begin paddr<=meta_index; pdata<=snapshot_active[23:16]; pwe<=1; end 11:begin paddr<=meta_index; pdata<=snapshot_active[31:24]; pwe<=1; end
                12:begin paddr<=meta_index; pdata<=output_peak[7:0]; pwe<=1; end 13:begin paddr<=meta_index; pdata<=output_peak[15:8]; pwe<=1; end
                14:begin paddr<=meta_index; pdata<=8'h1b; pwe<=1; end 15:begin paddr<=meta_index; pdata<=8'hb7; pwe<=1; end // Fs 46875 LE
                16:begin paddr<=meta_index; pdata<=10; pwe<=1; end 17:begin paddr<=meta_index; pdata<=128; pwe<=1; end 18:begin paddr<=meta_index; pdata<=16; pwe<=1; end // log2(N),bins,XY lag
                default:begin paddr<=meta_index; pdata<=0; pwe<=1; end
                endcase
                if(meta_index==31)begin point<=0;addr<=trigger_index;state<=WREAD;end
                else meta_index<=meta_index+1'b1;
            end
            WREAD:state<=WSTORE;
            WSTORE:begin
                begin paddr<=32+point; pdata<=pixel(raw_q); pwe<=1; end
                if(point==127)begin point<=0;addr<=trigger_index;state<=XREAD;end
                else begin point<=point+1'b1;addr<=trigger_index+((point+10'd1)<<2);state<=WREAD;end
            end
            XREAD:state<=XSTORE;
            XSTORE:begin begin paddr<=160+{point,1'b0}; pdata<=pixel(raw_q); pwe<=1; end addr<=trigger_index+({3'b0,point}<<3)+16;state<=YREAD;end
            YREAD:state<=YSTORE;
            YSTORE:begin
                begin paddr<=161+{point,1'b0}; pdata<=pixel(raw_q); pwe<=1; end
                if(point==63)begin note<=0;field<=0;state<=VOICE;end
                else begin point<=point+1'b1;addr<=trigger_index+((point+10'd1)<<3);state<=XREAD;end
            end
            VOICE:begin
                if(field==0)begin
                    case(note[4:3])
                    0:begin fcw_latched<=fcw0[note[2:0]];peak_latched<=peak0[note[2:0]];end
                    1:begin fcw_latched<=fcw1[note[2:0]];peak_latched<=peak1[note[2:0]];end
                    2:begin fcw_latched<=fcw2[note[2:0]];peak_latched<=peak2[note[2:0]];end
                    3:begin fcw_latched<=fcw3[note[2:0]];peak_latched<=peak3[note[2:0]];end
                    endcase
                    field<=1;
                end else begin
                    case(field)
                    1:begin paddr<=544+note*6; pdata<=fcw_latched[7:0]; pwe<=1; end 2:begin paddr<=545+note*6; pdata<=fcw_latched[15:8]; pwe<=1; end
                    3:begin paddr<=546+note*6; pdata<=fcw_latched[23:16]; pwe<=1; end 4:begin paddr<=547+note*6; pdata<=fcw_latched[31:24]; pwe<=1; end
                    5:begin paddr<=548+note*6; pdata<=peak_latched[7:0]; pwe<=1; end 6:begin paddr<=549+note*6; pdata<=peak_latched[15:8]; pwe<=1; end
                    endcase
                    if(field==6)begin
                        field<=0;
                        if(note==31)begin offset<=0;byte_index<=0;crc<=16'hffff;state<=LOAD;end
                        else note<=note+1'b1;
                    end else field<=field+1'b1;
                end
            end
            LOAD:begin
                case(byte_index)
                0:tx_data<=8'ha8;1:tx_data<=1;2:tx_data<=sequence_id;3:tx_data<=1;
                4:tx_data<=offset[7:0];5:tx_data<={6'b0,offset[9:8]};6:tx_data<=32;
                39:tx_data<=crc[7:0];40:tx_data<=crc[15:8];41:tx_data<=8'h5a;
                default:tx_data<=payload[offset+byte_index-7];
                endcase
                tx_valid<=1;state<=SEND;
            end
            SEND:if(tx_ready)begin
                tx_valid<=0;
                if(byte_index<39)crc<=crc_byte(crc,tx_data);
                if(byte_index==41)begin
                    if(offset==704)begin sequence_id<=sequence_id+1'b1;state<=WAIT;end
                    else begin offset<=offset+32;byte_index<=0;crc<=16'hffff;state<=LOAD;end
                end else begin byte_index<=byte_index+1'b1;state<=LOAD;end
            end
            WAIT:if(period>=PERIOD_CLOCKS)begin
                period<=0;cap_index<=0;trigger_index<=0;trigger_found<=0;armed<=0;output_peak<=0;
                for(i=0;i<8;i=i+1)begin peak0[i]<=0;peak1[i]<=0;peak2[i]<=0;peak3[i]<=0;end
                state<=CAP;
            end
            default:state<=CAP;
            endcase
        end
    end
endmodule


