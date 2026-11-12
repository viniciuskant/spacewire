module spw_router #(// matriz + rmap + banco de registradores
    parameter int N_PORTS = 4                    // portas físicas (2--31)
)(
    input  logic clk,                            // clk_system (50 MHz)
    input  logic rst_n,                          // reset (0)

    // rx_fifo de cada porta (ligados dos codecs)
    input  logic [N_PORTS:1][8:0]            in_data_i,    // frente da rx_fifo
    input  logic [N_PORTS:1]                 in_empty_i,
    output logic [N_PORTS:1]                 in_rd_en_o,   // retira a frente = 1

    // tx_fifo de cada porta
    output logic [N_PORTS:1][8:0]            out_data_o,
    input  logic [N_PORTS:1]                 out_full_i,   // tx_fifo cheia = 1
    output logic [N_PORTS:1]                 out_wr_en_o,  // grava = 1

    input  logic [N_PORTS:1]                 link_run_i,   // link em Run = 1

    // time-code
    input  logic                             tc_en_i,      // repasse ligado = 1
    input  logic [N_PORTS:1]                 tc_got_i,     // chegou time-code = 1 (pulso)
    input  logic [N_PORTS:1][7:0]            tc_rx_i,
    output logic [N_PORTS:1]                 tc_send_o,    // enviar time-code = 1 (pulso)
    output logic [7:0]                       tc_tx_o,
    output logic [5:0]                       tc_reg_o,     // registrador de tempo (debug)

    // tabela de rotas TODO: Por enquanto não recebe do rmap, fazer a ligação(deixei pra testar antes)
    input  logic                             tbl_wr_en_i,
    input  logic [7:0]                       tbl_addr_i,   // endereço lógico (32--254)
    input  logic [$clog2(N_PORTS+1)-1:0]     tbl_port_i,   // porta de saída (1--N)
    input  logic                             tbl_valid_i,  // 1 = rota válida/ 0 = apaga

    // status
    output logic [N_PORTS:0]                 err_route_o,  // entrada descartou pacote = 1 (pulso)
    output logic [N_PORTS:0]                 out_busy_o    // saída com dono = 1
);

    // porta 0: matriz <-> coded_port_zero
    logic [8:0]  cfg_out_data;   // matriz -> RMAP
    logic        cfg_out_wr_en;
    logic        cfg_out_full;
    logic [8:0]  cfg_in_data;    // RMAP -> matriz
    logic        cfg_in_empty;
    logic        cfg_in_rd_en;

    logic        spw_rx_ready;   // rx_fifo do RMAP com espaço = 1
    logic        spw_tx_valid;   // tx_fifo do RMAP com dado = 1

    // RMAP <-> banco
    logic [31:0] reg_bank_w_data;
    logic [8:0]  reg_bank_w_addr;
    logic        reg_bank_w_en;
    logic [31:0] reg_bank_r_data;
    logic [8:0]  reg_bank_r_addr;
    logic        reg_bank_r_en;

    assign cfg_out_full = !spw_rx_ready;
    assign cfg_in_empty = !spw_tx_valid;

    spw_switch #(.N_PORTS(N_PORTS)) u_switch (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data_i), .in_empty_i(in_empty_i), .in_rd_en_o(in_rd_en_o),
        .out_data_o(out_data_o), .out_full_i(out_full_i), .out_wr_en_o(out_wr_en_o),
        .link_run_i(link_run_i),
        .cfg_in_data_i(cfg_in_data), .cfg_in_empty_i(cfg_in_empty), .cfg_in_rd_en_o(cfg_in_rd_en),
        .cfg_out_data_o(cfg_out_data), .cfg_out_full_i(cfg_out_full), .cfg_out_wr_en_o(cfg_out_wr_en),
        .cfg_ready_i(1'b1),
        .tc_en_i(tc_en_i), .tc_got_i(tc_got_i), .tc_rx_i(tc_rx_i),
        .tc_send_o(tc_send_o), .tc_tx_o(tc_tx_o), .tc_reg_o(tc_reg_o),
        .tbl_wr_en_i(tbl_wr_en_i), .tbl_addr_i(tbl_addr_i), .tbl_port_i(tbl_port_i), .tbl_valid_i(tbl_valid_i),
        .err_route_o(err_route_o), .out_busy_o(out_busy_o)
    );

    // porta 0 (RMAP)
    coded_port_zero u_port0 (
        .clk(clk), .rst_n(rst_n),
        .spw_rx_data(cfg_out_data), .spw_rx_valid(cfg_out_wr_en), .spw_rx_ready(spw_rx_ready),
        .spw_tx_data(cfg_in_data), .spw_tx_valid(spw_tx_valid), .spw_tx_ready(cfg_in_rd_en),
        .reg_bank_w_data(reg_bank_w_data), .reg_bank_w_addr(reg_bank_w_addr), .reg_bank_w_en(reg_bank_w_en),
        .reg_bank_r_data(reg_bank_r_data), .reg_bank_r_addr(reg_bank_r_addr), .reg_bank_r_en(reg_bank_r_en)
    );

    // banco de registradores (do RMAP, usado como está)
    rmap_reg_bank u_bank (
        .rdata(reg_bank_r_data),
        .wdata(reg_bank_w_data), .waddr(reg_bank_w_addr), .wclken(reg_bank_w_en), .wclk(clk),
        .raddr(reg_bank_r_addr), .rclken(reg_bank_r_en), .rclk(clk)
    );

endmodule
