module top #(parameter ADC_IS_ADS1115=0,parameter I2C_DIV=18,
    parameter MPR_ADDRESS=7'h5a,parameter PRESSURE_INVERT=1,
    parameter JOY_CENTER_X=825,parameter JOY_CENTER_Y=825)(input clk,input reset_button,input mode_button,
    inout i2c_scl,inout i2c_sda,input enc_a,input enc_b,input enc_sw,input joy_sw,
    output led_ser,output led_srclk,output led_rclk,
    output i2s_bclk,output i2s_ws,output i2s_data,output pa_en,
    output [5:0] led_n,output debug_gate,output debug_audio,
    input ble_uart_rx,output ble_uart_tx);
    wire rst,tick_ms,ce;
    wire [11:0] keys,pressure,joy_x,joy_y,lights;
    wire ready,fault,pressure_enable,ensemble,playing,practice,restart;
    wire [3:0] menu;
    wire [4:0] audition_note; wire audition_gate,audition_all;
    wire [1:0] display_view,note_page;
    wire [3:0] voice_valid; wire [11:0] voice_slot;
    wire [63:0] voice_sample; wire [127:0] voice_fcw;
    wire [7:0] visual_data; wire visual_valid,visual_last,visual_ready;
    wire [1:0] mode,wet,timbre,song,selected_timbre;
    wire [15:0] attack_step,decay_step,sustain,release_step;
    wire [7:0] gain,fade_gain,bpm;
    // Reduce ensemble gain BEFORE smoothing, keeping stacked chords manageable.
    wire [7:0] performance_gain;
    wire signed [8:0] pitch;
    wire [31:0] gates,active;
    wire done,overrun,correct;
    wire [5:0] guide_step;
    wire signed [15:0] dry,audio;
    wire ble_uart_overflow;
    wire [31:0] remote_keys;
    wire [7:0] remote_event;
    wire score_enabled,score_restart;
    wire [11:0] valid_keys=ready?keys:12'b0;
    wire [59:0] keymap;
    wire [31:0] mapped_keys;
    key_remap remapper(valid_keys,keymap,mapped_keys);
    wire local_audition=mode==0 && (menu==8 || audition_all) && audition_gate;
    wire local_all=local_audition && audition_all;
    wire [31:0] play_keys=mapped_keys | remote_keys | (local_audition?(audition_all?32'hffffffff:(32'b1<<audition_note)):32'b0);
    wire test_mode=mode==1;
    assign performance_gain=local_all?8'd8:(!test_mode && ensemble)?(gain>>2):gain;

    // Fixed note/octave ownership, no voice stealing.
    note_layers layering(play_keys,ensemble,gates);
    clock_gen clocks(clk,reset_button,rst,tick_ms);
    sensor_hub #(.ADC_IS_ADS1115(ADC_IS_ADS1115),.I2C_DIV(I2C_DIV),.MPR_ADDRESS(MPR_ADDRESS),
        .PRESSURE_IDLE(PRESSURE_INVERT?1650:0)) sensors(clk,rst,i2c_scl,i2c_sda,
        keys,pressure,joy_x,joy_y,ready,fault);
    controls_extended controls(clk,rst,tick_ms,ce,enc_a,enc_b,enc_sw,joy_sw,mode_button,
        timbre,menu,mode,pressure_enable,ensemble,attack_step,decay_step,sustain,release_step,
        wet,song,bpm,playing,practice,restart,audition_note,audition_gate,audition_all,display_view,note_page);
    input_mapper #(.PRESSURE_INVERT(PRESSURE_INVERT),.CENTER_X(JOY_CENTER_X),.CENTER_Y(JOY_CENTER_Y),
        .MIN_GAIN(128),.GAIN_SHIFT(4))
        mapper(clk,rst,ce,pressure,joy_x,joy_y,pressure_enable,test_mode,gain,pitch);
    timbre_fade fade(clk,rst,ce,(test_mode || local_all)?2'b0:timbre,performance_gain,selected_timbre,fade_gain);
    engine32 #(.NORMAL_SHIFT(10),.PITCH_SHIFT(9),.TIMBRE_COMP(1)) bank(clk,rst,ce,gates,test_mode,selected_timbre,local_audition?9'sd0:pitch,
        (test_mode || local_all)?16'd8192:attack_step,(test_mode || local_all)?16'd32:decay_step,
        (test_mode || local_all)?16'd50000:sustain,(test_mode || local_all)?16'd1024:release_step,
        (local_all && fade_gain>8)?8'd8:fade_gain,dry,done,overrun,active,voice_valid,voice_slot,voice_sample,voice_fcw);
    audio_effect #(.DELAY_BITS(14),.STRONG_WET(1)) effect(clk,rst,ce,!(test_mode || local_all),wet,dry,audio);
    i2s_tx tx(clk,rst,audio,i2s_bclk,i2s_ws,i2s_data,ce);
    guide_extended guide(clk,rst,tick_ms,mode==2,playing,practice,restart|score_restart,song,bpm,
        valid_keys,lights,guide_step,correct,score_enabled,remote_event);
    led_guide leds(clk,rst,{practice,playing && mode==2,ensemble,overrun,lights},led_ser,led_srclk,led_rclk);
    // Active-low LEDs: ready, fault, menu low 3 bits; last LED = menu bit3 OR non-normal mode.
    assign led_n=~{(mode!=0 || menu[3]),menu[2:0],fault|overrun|ble_uart_overflow,ready};
    assign pa_en=!rst; // stays on during silence; no 7ms wakeup per note
    assign debug_gate=|play_keys;
    assign debug_audio=audio>16'sd128 || audio < -16'sd128;
    // Remote commands add gates; timed release is independent of BLE connectivity.
    ble_notes ble_link(clk,rst,tick_ms,ble_uart_rx,ble_uart_tx,remote_keys,ble_uart_overflow,guide_step[4:0],remote_event,score_enabled,score_restart,|valid_keys,keymap,visual_data,visual_valid,visual_last,visual_ready);
    visual_monitor monitor(clk,rst,ce,audio,voice_valid,voice_slot,voice_sample,voice_fcw,
        active,menu,mode,selected_timbre,display_view,note_page,audition_note,local_audition,local_all,
        overrun|ble_uart_overflow,visual_data,visual_valid,visual_last,visual_ready);
endmodule


