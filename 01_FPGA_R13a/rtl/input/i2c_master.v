// Register transaction, 1 or 2 bytes. Data MSB is transmitted/received first.
module i2c_master #(parameter DIV=34, parameter TIMEOUT=270000)(
    input clk,input rst,input start,input [6:0] address,input [7:0] reg_addr,
    input reading,input two_bytes,input [15:0] wdata,
    output reg busy,output reg done,output reg error,output reg [15:0] rdata,
    inout scl,inout sda);
    reg go, waiting;
    reg [1:0] op;
    reg [7:0] tx;
    reg nack;
    wire bbusy,bdone,berror;
    wire [7:0] rx;
    reg [3:0] step;
    reg [6:0] addr;
    reg [7:0] ptr;
    reg rd,two;
    reg [15:0] wd;
    i2c_byte #(.DIV(DIV),.TIMEOUT(TIMEOUT)) bytes(clk,rst,go,op,tx,nack,
        bbusy,bdone,berror,rx,scl,sda);
    always @* begin
        op=2; tx=0; nack=1;
        case(step)
            0: op=0;
            1: tx={addr,1'b0};
            2: tx=ptr;
            3: if(rd) op=0; else tx=two?wd[15:8]:wd[7:0];
            4: if(rd) tx={addr,1'b1}; else tx=wd[7:0];
            5: begin op=3; nack=!two; end
            6: begin op=3; nack=1; end
            7: op=1;
            default: op=1;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin go<=0; waiting<=0; busy<=0; done<=0; error<=0;
            step<=0; addr<=0; ptr<=0; rd<=0; two<=0; wd<=0; rdata<=0; end
        else begin
            done<=0; go<=0;
            if(!busy) begin
                if(start) begin addr<=address; ptr<=reg_addr; rd<=reading;
                    two<=two_bytes; wd<=wdata; busy<=1; error<=0; step<=0;
                    waiting<=0; rdata<=0; end
            end else if(!waiting && !bbusy && !go) begin go<=1; waiting<=1; end
            else if(bdone) begin
                waiting<=0;
                if(berror) begin
                    error<=1;
                    if(step==7) begin busy<=0; done<=1; end
                    else step<=7;
                end else if(step==7) begin busy<=0; done<=1; end
                else case(step)
                    0,1,2: step<=step+1'b1;
                    3: if(!rd && !two) step<=7; else step<=4;
                    4: if(rd) step<=5; else step<=7;
                    5: begin rdata<=two?{rx,8'b0}:{8'b0,rx}; step<=two?6:7; end
                    6: begin rdata[7:0]<=rx; step<=7; end
                    default: step<=7;
                endcase
            end
        end
    end
endmodule
