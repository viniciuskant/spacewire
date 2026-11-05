`default_nettype none

module cdc_sys_rx (
    // ----- RX domain ----- 
    input i_rx_clk, // recovered rising edge
    input i_rx_clk_n, // recovered falling edge
    // RX hard reset (global reset). Used to reset
    // CDC primitives.
    input i_rx_hard_rstn, 
    // RX reset derived from global reset OR rx_enable.
    // Feed this into the RX module rstn.
    output o_rx_rstn, 

    // FSM signals, all sticky
    input i_rx_got_null, 
    input i_rx_got_nchar, 
    input i_rx_got_timecode, 
    input i_rx_parity_error,
    input i_rx_esc_error,
    input i_rx_fifo_overflow,

    // pulsed when FCT is received
    input i_rx_inc_fct,

    // NCHAR async FIFO
    input i_rx_nchar_wr,
    input [8:0] i_rx_nchar,
    output o_rx_nchar_full, // asynchronous FIFO full, RX must generate error
    // TIMECODE async FIFO
    input i_rx_timecode_wr,
    input [7:0] i_rx_timecode,
    output o_rx_timecode_full,


    // ----- System domain -----
    input i_sys_clk,
    input i_sys_rstn,
    input i_sys_enable_rx, // Enable RX from FSM. Must be registered to avoid glitches

    output [3:0] o_fct_delta, // 4 bits, can have 2 FCTs in one system cycle
    output [3:0] o_activity_pos_count, // how many RX clock rising edges since last system clock
    output [3:0] o_activity_neg_count, // how many RX clock falling edges since last system clock
    // separate signals for state-machine, sticky levels
    output o_sys_got_null,
    output o_sys_got_nchar,
    output o_sys_got_timecode,
    output o_sys_parity_error,
    output o_sys_esc_error,
    output o_sys_fifo_overflow,

    // NCHAR async FIFO
    input i_sys_nchar_read, // assert to pop nchar from FIFO
    output o_sys_nchar_valid, // FIFO not empty
    output [8:0] o_sys_nchar,
    // TIMECODE async FIFO
    input i_sys_timecode_read, // assert to pop nchar from FIFO
    output o_sys_timecode_valid, // FIFO not empty
    output [7:0] o_sys_timecode
);
// asynchronous reset because the line is probably silent on error/initialization
assign o_rx_rstn = i_sys_rstn && i_sys_enable_rx;


sync_gray_counter #(.WIDTH(4)) fct_counter (
    .i_w_clk(i_rx_clk),
    .i_w_rstn(i_rx_hard_rstn),
    .i_inc(i_rx_inc_fct),
    .i_r_clk(i_sys_clk),
    .i_r_rstn(i_sys_rstn),
    .o_delta(o_fct_delta)
);
// if RX is clocked, we got a bit, so
// `i_inc` can be 1
sync_gray_counter #(.WIDTH(4)) activity_pos_counter (
    .i_w_clk(i_rx_clk),
    .i_w_rstn(i_rx_hard_rstn),
    .i_inc(1'b1),
    .i_r_clk(i_sys_clk),
    .i_r_rstn(i_sys_rstn),
    .o_delta(o_activity_pos_count)
);
sync_gray_counter #(.WIDTH(4)) activity_neg_counter (
    .i_w_clk(i_rx_clk_n),
    .i_w_rstn(i_rx_hard_rstn),
    .i_inc(1'b1),
    .i_r_clk(i_sys_clk),
    .i_r_rstn(i_sys_rstn),
    .o_delta(o_activity_neg_count)
);

sync_2ff got_null_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_got_null),
    .sync_data(o_sys_got_null)
);
sync_2ff got_nchar_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_got_nchar),
    .sync_data(o_sys_got_nchar)
);
sync_2ff got_timecode_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_got_timecode),
    .sync_data(o_sys_got_timecode)
);
sync_2ff parity_error_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_parity_error),
    .sync_data(o_sys_parity_error)
);
sync_2ff esc_error_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_esc_error),
    .sync_data(o_sys_esc_error)
);
sync_2ff fifo_overflow_2ff (
    .clk_dest(i_sys_clk),
    .rst_n(i_sys_rstn),
    .async_data(i_rx_fifo_overflow),
    .sync_data(o_sys_fifo_overflow)
);

wire nchar_empty;
assign o_sys_nchar_valid = !nchar_empty;
async_fifo #(.DSIZE(9), .ASIZE(3)) nchar_fifo (
    .i_wclk(i_rx_clk),
    .i_wrst_n(i_rx_hard_rstn),
    .i_wr(i_rx_nchar_wr),
    .i_wdata(i_rx_nchar),
    .i_rclk(i_sys_clk),
    .i_rrst_n(i_sys_rstn),
    .i_rd(i_sys_nchar_read),
    .o_rdata(o_sys_nchar),
    .o_rempty(nchar_empty),
    .o_wfull(o_rx_nchar_full)
);

wire tc_empty;
assign o_sys_timecode_valid = !tc_empty;
async_fifo #(.DSIZE(8), .ASIZE(2)) tc_fifo (
    .i_wclk(i_rx_clk),
    .i_wrst_n(i_rx_hard_rstn),
    .i_wr(i_rx_timecode_wr),
    .i_wdata(i_rx_timecode),
    .i_rclk(i_sys_clk),
    .i_rrst_n(i_sys_rstn),
    .i_rd(i_sys_timecode_read),
    .o_rdata(o_sys_timecode),
    .o_rempty(tc_empty),
    .o_wfull(o_rx_timecode_full)
);

endmodule
