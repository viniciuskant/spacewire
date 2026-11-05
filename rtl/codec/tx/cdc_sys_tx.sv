// system clock <-> TX clock boundary

module cdc_sys_tx 
#(
    parameter int ASIZE = 2 // depth 4
)
(
    // system clock domain
    input i_sys_clk,
    input i_sys_rstn, // from reset_sync, system domain
    input i_sys_wr_valid, // assert to write FIFO
    input [2:0] i_sys_payload_type,
    input [7:0] i_sys_payload,
    input i_sys_tx_enable,
    input i_sys_use_run_rate,
    output o_sys_wr_ready, // FIFO not full

    // TX clock domain
    input i_tx_clk,
    input i_tx_rstn, // from reset_sync, TX domain
    input i_tx_pop,
    output o_tx_rd_valid,
    output [2:0] o_tx_payload_type,
    output [7:0] o_tx_payload,
    output o_tx_enable_tx,
    output o_tx_use_run_rate
);
    logic fifo_full, fifo_empty;
    localparam int DSIZE = 11; // {type[2:0], payload[7:0]}
    afifo #(DSIZE, ASIZE) fifo0 (
        .i_wclk(i_sys_clk),
        .i_wrst_n(i_sys_rstn),
        .i_wr(i_sys_wr_valid),
        .i_wdata({i_sys_payload_type, i_sys_payload}),
        .i_rclk(i_tx_clk),
        .i_rrst_n(i_tx_rstn),
        .i_rd(i_tx_pop),
        .o_rdata({o_tx_payload_type, o_tx_payload}),
        .o_rempty(fifo_empty),
        .o_wfull(fifo_full)
    );
    assign o_sys_wr_ready = !fifo_full;
    assign o_tx_rd_valid = !fifo_empty;

    sync_2ff tx_enable_2ff (
        .clk_dest(i_tx_clk),
        .rst_n(i_tx_rstn),
        .async_data(i_sys_tx_enable),
        .sync_data(o_tx_enable_tx)
    );

    sync_2ff use_run_rate_2ff (
        .clk_dest(i_tx_clk),
        .rst_n(i_tx_rstn),
        .async_data(i_sys_use_run_rate),
        .sync_data(o_tx_use_run_rate)
    );

endmodule
