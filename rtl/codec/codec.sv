import spw_pkg::*;

module spw_codec #(
    parameter int RX_AW       = 6,        // receive buffer: 2**RX_AW entries (64)
    parameter int TX_AW       = 6         // host TX FIFO:   2**TX_AW entries (64)
)(
    // ---------------- clocks and resets ----------------
    input  logic        i_sys_clk,          // 50 MHz system clock
    input  logic        i_tx_clk,           // free-running 200 MHz, TX domain
    input  logic        i_sys_rstn,        // global reset, synchronized to clk_sys
    input  logic        i_tx_rstn,         // global reset, synchronized to clk_tx

    // ---------------- SpaceWire line ----------------
    input  logic        i_D, i_S,      // from the input pads (async)
    output logic        o_D, o_S,     // to the output pads (TX domain flops)

    // ---------------- host transmit (packets to send) ----------------
    input  logic        i_tx_wr,
    input  logic [8:0]  i_tx_wdata,         // {ctrl, data}: data, EOP, EEP
    output logic        o_tx_full,

    // ---------------- host receive (packets received) ----------------
    input  logic        i_rx_rd,
    output logic [8:0]  o_rx_rdata,         // {ctrl, data}, first-word fall-through
    output logic        o_rx_valid,         // !empty

    // ---------------- time-codes ----------------
    input  logic        i_tick,          // one-cycle pulse
    input  logic [7:0]  i_timecode,
    output logic        o_tick,         // one-cycle pulse, no backpressure
    output logic [7:0]  o_timecode,

    // ---------------- link control ----------------
    input  logic        i_link_start,
    input  logic        i_auto_start,
    input  logic        i_link_disable,
    input  logic [6:0]  i_run_div,          // run-rate divider; change only while the link is down

    // ---------------- status ----------------
    output e_link_state o_link_state,       // state machine state
    output logic        o_link_run,
    output logic        o_link_error // pulsed when the link detected an error
);
    localparam int RX_DEPTH = 1 << RX_AW;

    // ---- state machine signals ----
    wire fsm_tx_enable, fsm_rx_enable, fsm_fct_allowed, fsm_link_run, fsm_link_error, fsm_left_run;

    e_link_state fsm_state;
    wire link_connecting = fsm_state == LINK_ST_CONNECTING;

    // ---- RX -> FSM ----
    wire rx_got_null, rx_got_fct, rx_got_nchar, rx_got_timecode;
    wire rx_disconnect, rx_parity_err, rx_esc_err, rx_afifo_overflow, rx_credit_err;

    // ---- credit signals ----
    wire [3:0] rx_fct_delta;
    wire rx_write;
    wire tx_nchar_accept, tx_fct_accept;
    wire tx_has_credit, tx_fct_due, rx_has_credit;
    wire tx_credit_err;

    // ---- buffers ----
    wire rxbuf_wr, rxbuf_full, rx_buf_empty;
    wire [8:0] rxbuf_wdata;
    wire [RX_AW:0] rxbuf_count;

    wire txbuf_pop, txbuf_empty;
    wire [8:0] txbuf_rdata;


    state_machine fsm (
        .i_sys_clk(i_sys_clk),
        .i_sys_rstn(i_sys_rstn),
        .i_link_start(i_link_start),
        .i_auto_start(i_auto_start),
        .i_link_disable(i_link_disable),
        // room for the first FCT is the same condition as `fct_due`
        .i_rx_space_ok(tx_fct_due),
        .i_rx_got_null(rx_got_null),
        .i_rx_got_fct(rx_got_fct),
        .i_rx_got_nchar(rx_got_nchar),
        .i_rx_got_timecode(rx_got_timecode),
        .i_rx_parity_err(rx_parity_err),
        .i_rx_esc_err(rx_esc_err),
        .i_rx_overflow_err(rx_afifo_overflow),
        .i_disconnect(rx_disconnect),
        .i_rx_credit_err(rx_credit_err),
        .i_tx_credit_err(tx_credit_err),
        .o_tx_enable(fsm_tx_enable),
        .o_rx_enable(fsm_rx_enable),
        .o_fct_allowed(fsm_fct_allowed),
        .o_link_run(fsm_link_run),
        .o_link_error(fsm_link_error),
        .o_left_run(fsm_left_run),
        .o_state(fsm_state)
    );

    credit #(
        .FIFO_DEPTH(RX_DEPTH)
    ) credit0 (
        .i_sys_clk(i_sys_clk),
        .i_sys_rstn(i_sys_rstn),
        .i_rx_enable(fsm_rx_enable),
        .i_fct_allowed(fsm_fct_allowed),
        .i_tx_nchar_accept(tx_nchar_accept),
        .i_tx_fct_accept(tx_fct_accept),
        .o_tx_has_credit(tx_has_credit),
        .o_tx_fct_due(tx_fct_due),
        .i_rx_fct_delta(rx_fct_delta),
        .i_rx_write(rx_write),
        .i_rx_fifo_count(rxbuf_count),
        .o_rx_has_credit(rx_has_credit),
        .o_credit_error(tx_credit_err)
    );

    rx rx0 (
        .i_sys_clk(i_sys_clk),
        .i_sys_rstn(i_sys_rstn),
        .i_rx_enable(fsm_rx_enable),
        .i_link_run(fsm_link_run),
        .i_D(i_D),
        .i_S(i_S),
        .i_fifo_full(rxbuf_full),
        .o_nchar_wr(rxbuf_wr),
        .o_nchar(rxbuf_wdata),
        .o_tick(o_tick),
        .o_timecode(o_timecode),
        .o_fct_delta(rx_fct_delta),
        .o_rx_write(rx_write),
        .i_has_credit(rx_has_credit),
        .o_got_null(rx_got_null),
        .o_got_fct(rx_got_fct),
        .o_got_nchar(rx_got_nchar),
        .o_got_timecode(rx_got_timecode),
        .o_disconnect(rx_disconnect),
        .o_parity_error(rx_parity_err),
        .o_esc_error(rx_esc_err),
        .o_afifo_overflow(rx_afifo_overflow),
        .o_credit_error(rx_credit_err)
    );

    // receive buffer, read by the host
    fifo #(
        .ASIZE(RX_AW),
        .DSIZE(9)
    ) rx_buf (
        .i_clk(i_sys_clk),
        .i_rstn(i_sys_rstn),
        .i_wr(rxbuf_wr),
        .i_rd(i_rx_rd),
        .i_wdata(rxbuf_wdata),
        .o_rdata(o_rx_rdata),
        .o_empty(rx_buf_empty),
        .o_full(rxbuf_full),
        .o_count(rxbuf_count)
    );
    assign o_rx_valid = !rx_buf_empty;

    // transmit buffer, written by the host
    fifo #(
        .ASIZE(TX_AW),
        .DSIZE(9)
    ) tx_buf (
        .i_clk(i_sys_clk),
        .i_rstn(i_sys_rstn),
        .i_wr(i_tx_wr),
        .i_rd(txbuf_pop),
        .i_wdata(i_tx_wdata),
        .o_rdata(txbuf_rdata),
        .o_empty(txbuf_empty),
        .o_full(o_tx_full),
        .o_count()
    );

    tx tx0 (
        .i_tx_clk(i_tx_clk),
        .i_tx_rstn(i_tx_rstn),
        .i_sys_clk(i_sys_clk),
        .i_sys_rstn(i_sys_rstn),
        .i_clk_div(i_run_div),
        .i_tx_enable(fsm_tx_enable),
        .i_left_run(fsm_left_run),
        .i_link_connecting(link_connecting),
        .i_link_run(fsm_link_run),
        // 10 Mb/s until Run, then the configured rate
        .i_use_run_rate(fsm_link_run),
        .i_fifo_empty(txbuf_empty),
        .i_fifo_rdata(txbuf_rdata),
        .o_fifo_pop(txbuf_pop),
        .i_tick_in(i_tick),
        .i_timecode(i_timecode),
        .i_has_credit(tx_has_credit),
        .i_fct_due(tx_fct_due),
        .o_nchar_accept(tx_nchar_accept),
        .o_fct_accept(tx_fct_accept),
        .o_D(o_D),
        .o_S(o_S)
    );

    assign o_link_state = fsm_state;
    assign o_link_run = fsm_link_run;
    assign o_link_error = fsm_link_error;

endmodule

