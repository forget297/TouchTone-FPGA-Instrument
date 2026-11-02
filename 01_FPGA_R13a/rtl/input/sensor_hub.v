module sensor_hub #(parameter ADC_IS_ADS1115=0,parameter I2C_DIV=18,parameter MPR_ADDRESS=7'h5a,
    parameter PRESSURE_IDLE=0)(input clk,input rst,
    inout scl,inout sda,output reg [11:0] keys,
    output reg [11:0] pressure,joy_x,joy_y,
    output reg ready,output reg fault);
    reg start;
    reg [6:0] address;
    reg [7:0] reg_addr;
    reg reading,two_bytes;
    reg [15:0] wdata;
    wire busy,done,error;
    wire [15:0] rdata;
    reg [3:0] state;
    reg [5:0] init_index;
    wire [7:0] init_addr,init_data;
    wire init_last;
    reg [1:0] channel;
    reg adc_config_ok;
    wire [15:0] adc_config;
    wire [11:0] adc_value;
    integer wait_count,conversion_wait;
    reg [3:0] touch_failures,adc_failures;
    mpr121_ctrl init_table(init_index,init_addr,init_data,init_last);
    ads1015_ctrl #(.ADC_IS_ADS1115(ADC_IS_ADS1115)) adc(channel,rdata,adc_config,adc_value);
    i2c_master #(.DIV(I2C_DIV),.TIMEOUT(27000)) bus(clk,rst,start,address,reg_addr,reading,two_bytes,wdata,
        busy,done,error,rdata,scl,sda);
    always @(posedge clk) begin
        if(rst) begin
            start<=0; address<=0; reg_addr<=0; reading<=0; two_bytes<=0;
            wdata<=0; state<=0; init_index<=0; channel<=0;
            keys<=0; pressure<=PRESSURE_IDLE; joy_x<=825; joy_y<=825;
            ready<=0; fault<=0; wait_count<=270000; conversion_wait<=0;
            touch_failures<=0; adc_failures<=0; adc_config_ok<=0;
        end else begin
            start<=0;
            if(conversion_wait>0) conversion_wait<=conversion_wait-1;
            case(state)
                0: if(wait_count>0) wait_count<=wait_count-1; else state<=1;
                1: begin address<=MPR_ADDRESS; reg_addr<=init_addr; reading<=0;
                    two_bytes<=0; wdata<={8'b0,init_data}; start<=1; state<=2; end
                2: if(done) begin
                    if(error) begin fault<=1; init_index<=0; wait_count<=2700000; state<=0; end
                    else if(init_last) begin ready<=1; fault<=0; touch_failures<=0; state<=3; end
                    else begin init_index<=init_index+1'b1; wait_count<=27000; state<=0; end
                end
                3: begin address<=7'h48; reg_addr<=1; reading<=0; two_bytes<=1;
                    wdata<=adc_config; start<=1; state<=4; end
                4: if(done) begin
                    adc_config_ok<=!error;
                    if(error) begin
                        fault<=1;
                        if(adc_failures<15) adc_failures<=adc_failures+1'b1;
                        pressure<=PRESSURE_IDLE; joy_x<=825; joy_y<=825;
                    end
                    conversion_wait<=ADC_IS_ADS1115?40500:13500; state<=5;
                end
                5: begin address<=MPR_ADDRESS; reg_addr<=0; reading<=1; two_bytes<=1;
                    start<=1; state<=6; end
                6: if(done) begin
                    if(error) begin
                        fault<=1;
                        if(touch_failures<15) touch_failures<=touch_failures+1'b1;
                        keys<=0; // fail silent, never leave a stuck note
                    end else begin keys<={rdata[3:0],rdata[15:8]}; touch_failures<=0; end
                    if(error && touch_failures>=2) begin ready<=0; init_index<=0;
                        wait_count<=2700000; state<=0; end
                    else if(conversion_wait==0) state<=7; else state<=5;
                end
                7: begin address<=7'h48; reg_addr<=0; reading<=1; two_bytes<=1;
                    start<=1; state<=8; end
                8: if(done) begin
                    if(error || !adc_config_ok) begin fault<=1; pressure<=PRESSURE_IDLE; joy_x<=825; joy_y<=825; end
                    else begin
                        adc_failures<=0;
                        if(touch_failures==0) fault<=0;
                        case(channel) 0:pressure<=adc_value; 1:joy_x<=adc_value; 2:joy_y<=adc_value; endcase
                    end
                    channel<=channel==2?0:channel+1'b1; state<=9;
                end
                9: begin address<=MPR_ADDRESS; reg_addr<=0; reading<=1; two_bytes<=1;
                    start<=1; state<=10; end
                10: if(done) begin
                    if(error) begin keys<=0; fault<=1; end
                    else keys<={rdata[3:0],rdata[15:8]};
                    state<=3;
                end
                default: state<=0;
            endcase
        end
    end
endmodule
