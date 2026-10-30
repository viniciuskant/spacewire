// TX subsystem
module tx(
    // 200MHz clock
    input i_tx_clk,
    input i_tx_rstn,
    // 50MHz system clock, with same phase as 200MHz clock
    input i_sys_clk,
    input i_sys_rstn,

    // run rate
    input [6:0] i_clk_div,

    // From the FSM
    // This is the "enable TX" signal from the FSM. It remains
    // high in all FSM states except "ErrorReset" and "ErrorWait"
    input i_tx_enable,
    input i_link_error,
    input i_link_connecting,
    input i_link_run,
    input i_use_run_rate,

    // FIFO interface
    input i_fifo_empty,
    input [8:0] i_fifo_rdata,
    output o_fifo_pop,

    // Timecode interface
    input i_tick_in,
    input [7:0] i_timecode,

    // Credit interface
    input i_has_credit,
    input i_fct_due,
    output o_nchar_accept,
    output o_fct_accept,

    // Serial interface
    output o_D,
    output o_S

);

    wire host_valid = !i_fifo_empty;

    wire tc_accept, tc_valid;
    wire [7:0] timecode;
    tx_timecode_slot slot0 (
    .i_sys_clk(i_sys_clk),
    .i_sys_rstn(i_sys_rstn),
    .i_link_run(i_link_run),
    .i_tc_accept(tc_accept), // from the selector
    .i_tick_in(i_tick_in),
    .i_timecode(i_timecode),
    .o_tc_valid(tc_valid),
    .o_timecode(timecode)
    );

    wire spilling;

    wire sel_nchar_accept, sel_nchar_valid;
    wire [8:0] sel_nchar_data;

    tx_spill spill0 (
        .i_sys_clk(i_sys_clk),
        .i_sys_rstn(i_sys_rstn),
        .i_link_error(i_link_error),
        .i_host_valid(host_valid),
        .i_host_data(i_fifo_rdata),
        .o_host_pop(o_fifo_pop),
        .i_sel_nchar_accept(sel_nchar_accept),
        .o_sel_nchar_valid(sel_nchar_valid),
        .o_sel_nchar_data(sel_nchar_data),
        .o_spilling(spilling)
    );


    wire sys_wr_ready, sys_wr_valid;
    wire [2:0] sys_payload_type;
    wire [7:0] sys_payload;
    tx_selector sel0 (
        .i_link_connecting(i_link_connecting),
        .i_link_run(i_link_run),
        .i_fct_due(i_fct_due),
        .i_tc_valid(tc_valid),
        .i_tc_data(timecode),
        .i_nchar_valid(sel_nchar_valid),
        .i_nchar_data(sel_nchar_data),
        .i_has_credit(i_has_credit),
        .i_wr_ready(sys_wr_ready),
        .o_wr_valid(sys_wr_valid),
        .o_wr_payload_type(sys_payload_type),
        .o_wr_payload(sys_payload),
        .o_fct_accept(o_fct_accept),
        .o_tc_accept(tc_accept),
        .o_nchar_accept(sel_nchar_accept)
    );
    assign o_nchar_accept = sel_nchar_accept;


    // ----------- SYS -> TX clock boundary -----------------
    wire tx_ser_pop, tx_ser_valid, tx_enable_tx, tx_use_run_rate;
    wire [2:0] tx_ser_payload_type;
    wire [7:0] tx_ser_payload;
    cdc_sys_tx cdc0 (
    .i_sys_clk(i_sys_clk),
    .i_sys_rstn(i_sys_rstn), // from reset_sync, system domain
    .i_sys_wr_valid(sys_wr_valid), // assert to write FIFO
    .i_sys_payload_type(sys_payload_type),
    .i_sys_payload(sys_payload),
    .i_sys_tx_enable(i_tx_enable),
    .i_sys_use_run_rate(i_use_run_rate),
    .o_sys_wr_ready(sys_wr_ready), // FIFO not full

    // TX clock domain
    .i_tx_clk(i_tx_clk),
    .i_tx_rstn(i_tx_rstn), // from reset_sync, TX domain
    .i_tx_pop(tx_ser_pop),
    .o_tx_rd_valid(tx_ser_valid),
    .o_tx_payload_type(tx_ser_payload_type),
    .o_tx_payload(tx_ser_payload),
    .o_tx_enable_tx(tx_enable_tx),
    .o_tx_use_run_rate(tx_use_run_rate)
    );

    // enable generator
    wire bit_en;
    tx_enable_gen gen0 (
        .clk(i_tx_clk),
        .rst_n(i_tx_rstn),
        .tx_enable(tx_enable_tx),
        .clk_div(i_clk_div),
        .use_run_rate(tx_use_run_rate),
        .bit_en(bit_en)
    );

    wire tx_ser_data_out, tx_ser_valid_out;
    tx_serializer ser0 (
        .clk(i_tx_clk),
        .rst_n(i_tx_rstn),
        .bit_en(bit_en),
        .tx_enable(tx_enable_tx),
        .payload_type(tx_ser_payload_type),
        .payload(tx_ser_payload),
        .valid(tx_ser_valid),
        .pop(tx_ser_pop),
        .data_out(tx_ser_data_out),
        .valid_out(tx_ser_valid_out)
    );
    tx_ds_encoder enc0 (
        .i_tx_clk(i_tx_clk),
        .i_tx_rstn(i_tx_rstn),
        .i_tx_enable(tx_enable_tx),
        .i_bit_en(bit_en),
        .i_data(tx_ser_data_out),
        .i_valid(tx_ser_valid_out),
        .o_D(o_D),
        .o_S(o_S)
    );


endmodule