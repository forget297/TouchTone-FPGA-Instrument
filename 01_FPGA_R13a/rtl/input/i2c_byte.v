// Single-master open-drain byte engine. SCL stretching supported with timeout.
// op: 0 START/repeated START, 1 STOP, 2 WRITE byte, 3 READ byte.
module i2c_byte #(parameter DIV=34, parameter TIMEOUT=270000)(
    input clk, input rst, input go, input [1:0] op,
    input [7:0] tx, input read_nack,
    output reg busy, output reg done, output reg error,
    output reg [7:0] rx, inout scl, inout sda);
    reg scl_low,sda_low;
    assign scl=scl_low?1'b0:1'bz;
    assign sda=sda_low?1'b0:1'bz;
    reg [1:0] scl_sync,sda_sync;
    reg [1:0] cmd;
    reg [7:0] data;
    reg nack;
    reg [3:0] bitno;
    reg [2:0] phase;
    integer divider,watchdog;
    wire tick=divider==DIV-1;
    always @(posedge clk) begin
        scl_sync<={scl_sync[0],scl}; sda_sync<={sda_sync[0],sda};
        if(rst) begin
            scl_low<=0; sda_low<=0; busy<=0; done<=0; error<=0;
            rx<=0; divider<=0; watchdog<=0; phase<=0; bitno<=0;
            scl_sync<=3; sda_sync<=3; cmd<=0; data<=0; nack<=1;
        end else begin
            done<=0;
            if(tick) divider<=0; else divider<=divider+1;
            if(!busy) begin
                watchdog<=0;
                if(go) begin busy<=1; error<=0; cmd<=op; data<=tx;
                    nack<=read_nack; phase<=0; bitno<=0; rx<=0; divider<=0; end
            end else if(watchdog>=TIMEOUT) begin
                scl_low<=0; sda_low<=0; busy<=0; done<=1; error<=1;
            end else begin
                watchdog<=watchdog+1;
                if(tick) case(cmd)
                    0: case(phase)
                        0: begin sda_low<=0; phase<=1; end
                        1: begin scl_low<=0; phase<=2; end
                        2: if(scl_sync[1] && sda_sync[1]) phase<=3;
                        3: begin sda_low<=1; phase<=4; end
                        4: begin scl_low<=1; busy<=0; done<=1; end
                    endcase
                    1: case(phase)
                        0: begin scl_low<=1; sda_low<=1; phase<=1; end
                        1: begin scl_low<=0; phase<=2; end
                        2: if(scl_sync[1]) phase<=3;
                        3: begin sda_low<=0; phase<=4; end
                        4: begin busy<=0; done<=1; end
                    endcase
                    default: case(phase)
                        0: begin
                            scl_low<=1;
                            if(cmd==2) sda_low<=bitno<8 ? ~data[7-bitno] : 1'b0;
                            else sda_low<=bitno<8 ? 1'b0 : ~nack;
                            phase<=1;
                        end
                        1: begin scl_low<=0; phase<=2; end
                        2: if(scl_sync[1]) begin
                            if(cmd==3 && bitno<8) rx<={rx[6:0],sda_sync[1]};
                            if(cmd==2 && bitno==8 && sda_sync[1]) error<=1;
                            phase<=3;
                        end
                        3: begin
                            scl_low<=1;
                            if(bitno==8) begin busy<=0; done<=1; end
                            else begin bitno<=bitno+1'b1; phase<=0; end
                        end
                    endcase
                endcase
            end
        end
    end
endmodule
