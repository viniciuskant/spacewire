module coded_port_zero #(
    parameter int DATA_WIDTH_FIFO = 9,
    parameter int DEPTH_FIFO = 16
)(
    input logic clk,
    input logic rst_n,

    input logic [DATA_WIDTH_FIFO-1:0] spw_rx_data,
    input logic spw_rx_valid,
    output logic spw_rx_ready,

    output logic [DATA_WIDTH_FIFO-1:0] spw_tx_data,
    output logic spw_tx_valid,
    input logic spw_tx_ready,

    output logic [31:0] reg_bank_w_data,
    output logic [8:0] reg_bank_w_addr,
    output logic reg_bank_w_en,
    input logic [31:0] reg_bank_r_data,
    output logic [8:0] reg_bank_r_addr,
    output logic reg_bank_r_en
);

    localparam int FIFO_ASIZE = $clog2(DEPTH_FIFO);


    logic [DATA_WIDTH_FIFO-1:0] rx_fifo_wdata;
    logic rx_fifo_winc;
    logic rx_fifo_rinc;
    logic [DATA_WIDTH_FIFO-1:0] rx_fifo_rdata;
    logic rx_fifo_rempty;
    logic [FIFO_ASIZE:0] rx_fifo_free_space;

    logic [DATA_WIDTH_FIFO-1:0] tx_fifo_wdata;
    logic tx_fifo_winc;
    logic tx_fifo_rinc;
    logic [DATA_WIDTH_FIFO-1:0] tx_fifo_rdata;
    logic tx_fifo_rempty;
    logic [FIFO_ASIZE:0] tx_fifo_free_space;
    logic tx_fifo_full;

    logic [8:0] rmap_rx_data;
    logic rmap_rx_valid;
    logic [8:0] rmap_tx_data;
    logic rmap_tx_valid;

    logic busy;


    assign rx_fifo_wdata = spw_rx_data;
    assign rx_fifo_winc  = spw_rx_valid & spw_rx_ready;
    assign spw_rx_ready  = (rx_fifo_free_space != '0);

    // consome o FIFO sempre que houver dado disponível e não oculpado
    assign rmap_rx_valid = ~rx_fifo_rempty & ~busy;
    assign rmap_rx_data = rx_fifo_rdata;
    assign rx_fifo_rinc = ~rx_fifo_rempty & ~busy;


    assign tx_fifo_full = (tx_fifo_free_space == '0);

    assign tx_fifo_wdata = rmap_tx_data;
    assign tx_fifo_winc = rmap_tx_valid & ~tx_fifo_full;

    assign spw_tx_data = tx_fifo_rdata;
    assign spw_tx_valid = ~tx_fifo_rempty;
    assign tx_fifo_rinc = ~tx_fifo_rempty & spw_tx_ready;


    RMAP u_rmap (
        .clk (clk),
        .rst_n (rst_n),

        .rx_data (rmap_rx_data),
        .rx_valid (rmap_rx_valid),
        .tx_data (rmap_tx_data),
        .tx_valid (rmap_tx_valid),

        .reg_bank_w_data (reg_bank_w_data),
        .reg_bank_w_addr (reg_bank_w_addr),
        .reg_bank_w_en (reg_bank_w_en),

        .reg_bank_r_data (reg_bank_r_data),
        .reg_bank_r_addr (reg_bank_r_addr),
        .reg_bank_r_en (reg_bank_r_en),

        .tx_fifo_full (tx_fifo_full),
        .busy (busy)
    );

    sync_fifo #(
        .DSIZE (DATA_WIDTH_FIFO),
        .ASIZE (FIFO_ASIZE)
    ) u_rx_fifo (
        .clk (clk),
        .rst_n (rst_n),

        .wdata (rx_fifo_wdata),
        .winc (rx_fifo_winc),

        .rinc (rx_fifo_rinc),
        .rdata (rx_fifo_rdata),
        .rempty (rx_fifo_rempty),
        .free_space_o (rx_fifo_free_space)
    );

    sync_fifo #(
        .DSIZE (DATA_WIDTH_FIFO),
        .ASIZE (FIFO_ASIZE)
    ) u_tx_fifo (
        .clk (clk),
        .rst_n (rst_n),

        .wdata (tx_fifo_wdata),
        .winc (tx_fifo_winc),

        .rinc (tx_fifo_rinc),
        .rdata (tx_fifo_rdata),
        .rempty (tx_fifo_rempty),
        .free_space_o (tx_fifo_free_space)
    );

endmodule