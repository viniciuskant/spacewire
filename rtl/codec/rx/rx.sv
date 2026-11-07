module rx(
    input i_sys_clk,
    input i_sys_rstn, // async system reset
    input i_rx_enable, // FSM signal
    input i_link_run, // if the links is in Run

    // Data-Strobe inputs
    input i_D,
    input i_S,

    // fifo interface
    input i_fifo_full,
    output o_nchar_wr,
    output [8:0] o_nchar,

    // timecode interface
    output o_tick,
    output [7:0] o_timecode,

    // credit interface
    output [3:0] o_fct_delta,
    output o_rx_write,

    // FSM signals
    input i_has_credit,
    output o_got_null,
    output o_got_bit,
    output o_got_fct,
    output o_got_nchar,
    output o_got_timecode,
    output o_disconnect,
    output o_parity_error,
    output o_esc_error,
    output o_afifo_overflow,
    output o_credit_error
);

// functional RX reset. Driven straight from a flop so it can't
// glitch: it feeds async resets in the recovered clock domain.
// Asserts with `i_sys_rstn`, releases one cycle after `i_rx_enable`.
(* dont_touch *) logic rx_rstn;
always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
    if (!i_sys_rstn) rx_rstn <= 0;
    else rx_rstn <= i_rx_enable;
end

// ---- clock recovery and data capture ----
wire rx_clk, rx_clk_n;
rx_clk_rec clk_rec (
    .i_D(i_D),
    .i_S(i_S),
    .o_rx_clk(rx_clk),
    .o_rx_clk_n(rx_clk_n)
);
wire [1:0] dpair;
wire dpair_valid;
rx_ds_capture cap (
    .i_rx_clk(rx_clk),
    .i_rx_rstn(rx_rstn),
    .i_D(i_D),
    .o_pair(dpair),
    .o_pair_valid(dpair_valid)
);

// ---- RX decoder ----
wire cdc_rx_got_null, cdc_rx_got_nchar, cdc_rx_got_timecode;
wire cdc_rx_parity_error, cdc_rx_esc_error, cdc_rx_afifo_error;
wire cdc_rx_inc_fct;
wire cdc_rx_nchar_full, cdc_rx_nchar_wr;
wire [8:0] cdc_rx_nchar_data;
wire cdc_rx_timecode_full, cdc_rx_timecode_wr;
wire [7:0] cdc_rx_timecode_data;
rx_decoder dec (
    .i_rx_clk(rx_clk), // recovered clock
    .i_rx_rstn(rx_rstn), // functional reset
    .i_dpair(dpair), // D pair from ds_capture
    .i_pair_valid(dpair_valid),
    // sticky flags
    .o_got_null(cdc_rx_got_null),
    .o_got_nchar(cdc_rx_got_nchar),
    .o_got_timecode(cdc_rx_got_timecode),
    // sticky errors
    .o_parity_error(cdc_rx_parity_error),
    .o_esc_error(cdc_rx_esc_error),
    // this error happens if the NCHAR FIFO gets full.
    // It shouldn't happen in normal operation but better
    // safe than sorry. TIMECODE FIFO doesn't get an error signal
    // because we can just drop excess timecodes.
    .o_fifo_error(cdc_rx_afifo_error), 

    // pulses, can be combinational
    .o_inc_fct(cdc_rx_inc_fct), // feeds into gray counter

    // NCHAR async FIFO (outputs not registered)
    .i_nchar_full(cdc_rx_nchar_full), // if the NCHAR fifo is full
    .o_nchar_wr(cdc_rx_nchar_wr), // feeds into async FIFO
    .o_nchar_data(cdc_rx_nchar_data), // feeds into async FIFO

    // TIMECODE async FIFO (outputs not registered)
    .i_timecode_full(cdc_rx_timecode_full), // if the timecode fifo is full
    .o_timecode_wr(cdc_rx_timecode_wr),
    .o_timecode_data(cdc_rx_timecode_data)
);

// ---- CDC boundary ----
wire [3:0] cdc_sys_fct_delta, cdc_sys_act_pos_cnt, cdc_sys_act_neg_cnt; 
// async FIFO
wire cdc_sys_nchar_read;
wire cdc_sys_nchar_valid;
wire [8:0] cdc_sys_nchar_data;

wire cdc_sys_timecode_read;
wire cdc_sys_timecode_valid;
wire [7:0] cdc_sys_timecode_data;
cdc_sys_rx cdc0 (
    // ----- RX domain ----- 
    .i_rx_clk(rx_clk), // recovered rising edge
    .i_rx_clk_n(rx_clk_n), // recovered falling edge
    // RX hard reset (global reset). Used to reset
    // CDC primitives.
    .i_rx_hard_rstn(i_sys_rstn), 

    // FSM signals, all sticky
    .i_rx_got_null(cdc_rx_got_null), 
    .i_rx_got_nchar(cdc_rx_got_nchar), 
    .i_rx_got_timecode(cdc_rx_got_timecode), 
    .i_rx_parity_error(cdc_rx_parity_error),
    .i_rx_esc_error(cdc_rx_esc_error),
    .i_rx_fifo_overflow(cdc_rx_afifo_error),

    // pulsed when FCT is received
    .i_rx_inc_fct(cdc_rx_inc_fct),

    // NCHAR async FIFO
    .i_rx_nchar_wr(cdc_rx_nchar_wr),
    .i_rx_nchar(cdc_rx_nchar_data),
    .o_rx_nchar_full(cdc_rx_nchar_full), // asynchronous FIFO full, RX must generate error
    // TIMECODE async FIFO
    .i_rx_timecode_wr(cdc_rx_timecode_wr),
    .i_rx_timecode(cdc_rx_timecode_data),
    .o_rx_timecode_full(cdc_rx_timecode_full),


    // ----- System domain -----
    .i_sys_clk(i_sys_clk),
    .i_sys_rstn(i_sys_rstn),

    .o_sys_fct_delta(cdc_sys_fct_delta), // 4 bits, can have 2 FCTs in one system cycle
    .o_sys_activity_pos_count(cdc_sys_act_pos_cnt), // how many RX clock rising edges since last system clock
    .o_sys_activity_neg_count(cdc_sys_act_neg_cnt), // how many RX clock falling edges since last system clock
    // separate signals for state-machine, sticky levels
    .o_sys_got_null(o_got_null),
    .o_sys_got_nchar(o_got_nchar),
    .o_sys_got_timecode(o_got_timecode),
    .o_sys_parity_error(o_parity_error),
    .o_sys_esc_error(o_esc_error),
    .o_sys_fifo_overflow(o_afifo_overflow),

    // NCHAR async FIFO
    .i_sys_nchar_read(cdc_sys_nchar_read), // assert to pop nchar from FIFO
    .o_sys_nchar_valid(cdc_sys_nchar_valid), // FIFO not empty
    .o_sys_nchar(cdc_sys_nchar_data),
    // TIMECODE async FIFO
    .i_sys_timecode_read(cdc_sys_timecode_read), // assert to pop nchar from FIFO
    .o_sys_timecode_valid(cdc_sys_timecode_valid), // FIFO not empty
    .o_sys_timecode(cdc_sys_timecode_data)
);

rx_buffer_wr bufwr (
    .i_sys_clk(i_sys_clk),
    .i_sys_rstn(i_sys_rstn),
    .i_rx_enable(i_rx_enable),
    .i_has_rx_credit(i_has_credit),
    .o_rx_write(o_rx_write),
    .o_rx_credit_err(o_credit_error),
    .i_afifo_valid(cdc_sys_nchar_valid),
    .i_afifo_rdata(cdc_sys_nchar_data),
    .o_afifo_pop(cdc_sys_nchar_read),
    .i_buf_full(i_fifo_full),
    .o_buf_wr(o_nchar_wr),
    .o_buf_wdata(o_nchar)
);

// these go into the FSM
rx_link_mon mon(
    .i_sys_clk(i_sys_clk),
    .i_sys_rstn(i_sys_rstn),
    .i_rx_enable(i_rx_enable),
    .i_fct_delta(cdc_sys_fct_delta),
    .i_act_pos_delta(cdc_sys_act_pos_cnt),
    .i_act_neg_delta(cdc_sys_act_neg_cnt),
    .o_got_bit(o_got_bit),
    .o_got_fct(o_got_fct),
    .o_disconnect(o_disconnect)
);

// Timecode interface. We're reading the TC fifo
// every system cycle and popping, giving out
// `tick_in` pulses

// loopback to pop it as soon as available
assign cdc_sys_timecode_read = cdc_sys_timecode_valid;
// we're gating `tick_in` to only provide a timecode
// if the link is in Run. Without this, the FSM would
// treat the timecode as an error but the host would
// still see the timecode.
assign o_tick = cdc_sys_timecode_valid && i_link_run;
assign o_timecode = cdc_sys_timecode_data;

// module outputs
assign o_fct_delta = cdc_sys_fct_delta;

endmodule
