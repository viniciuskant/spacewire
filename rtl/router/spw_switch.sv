module spw_switch #(
    parameter int N_PORTS = 4                    // portas físicas (2--31)
)(
    input  logic clk,                            // clk_system (50 MHz)
    input  logic rst_n,                          // reset (0)

    // rx_fifo de cada porta
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

    // tabela de rotas
    input  logic                             tbl_wr_en_i,
    input  logic [7:0]                       tbl_addr_i,   // endereço lógico (32--254)
    input  logic [$clog2(N_PORTS+1)-1:0]     tbl_port_i,   // porta de saída (1--N)
    input  logic                             tbl_valid_i,  // 1 = rota válida/ 0 = apaga

    // status
    output logic [N_PORTS:1]                 err_route_o,  // entrada descartou pacote = 1 (pulso)
    output logic [N_PORTS:1]                 out_busy_o    // saída com dono = 1
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    // tabela
    logic [N_PORTS:1][7:0]      look_addr;   // endereço consultado por entrada
    logic [N_PORTS:1]           look_hit;
    logic [N_PORTS:1][PW-1:0]   look_port;

    // entradas -> crossbar
    logic [N_PORTS:1]           ic_wvalid;
    logic [N_PORTS:1][8:0]      ic_wdata;
    logic [N_PORTS:1][PW-1:0]   ic_dest;
    logic [N_PORTS:1][N_PORTS:1] ic_req;     // linha i = req_o da entrada i
    logic [N_PORTS:1]           ic_gnt;      // gnt da entrada i

    // crossbar <-> árbitros
    logic [N_PORTS:1][N_PORTS:1] arb_req;    // linha j = pedidos para a saída j
    logic [N_PORTS:1][N_PORTS:1] arb_gnt;    // linha j = gnt_o do árbitro j
    // verilator lint_off UNUSEDSIGNAL
    logic [N_PORTS:1][PW-1:0]   arb_owner;   // dono de cada saída (debug)
    // verilator lint_on UNUSEDSIGNAL

    sw_route_table #(.N_PORTS(N_PORTS)) u_tbl (
        .clk(clk), .rst_n(rst_n),
        .tbl_wr_en_i(tbl_wr_en_i), .tbl_addr_i(tbl_addr_i),
        .tbl_port_i(tbl_port_i), .tbl_valid_i(tbl_valid_i),
        .lookup_addr_i(look_addr), .lookup_hit_o(look_hit), .lookup_port_o(look_port)
    );

    for (genvar i = 1; i <= N_PORTS; i++) begin : g_port
        assign look_addr[i] = in_data_i[i][7:0];

        // entrada i
        sw_in_ctrl #(.N_PORTS(N_PORTS), .MY_PORT(i)) u_in (
            .clk(clk), .rst_n(rst_n),
            .in_data_i(in_data_i[i]), .in_empty_i(in_empty_i[i]), .in_rd_en_o(in_rd_en_o[i]),
            .tbl_hit_i(look_hit[i]), .tbl_port_i(look_port[i]),
            .link_run_i(link_run_i), .out_full_i(out_full_i),
            .req_o(ic_req[i]), .gnt_i(ic_gnt[i]),
            .dest_o(ic_dest[i]), .wvalid_o(ic_wvalid[i]), .wdata_o(ic_wdata[i]),
            .err_o(err_route_o[i])
        );

        // saída i
        sw_out_arb #(.N_PORTS(N_PORTS)) u_arb (
            .clk(clk), .rst_n(rst_n),
            .req_i(arb_req[i]),
            .wr_en_i(out_wr_en_o[i]), .wr_marker_i(out_data_o[i][8]),  // EOP/EEP solta a saída
            .gnt_o(arb_gnt[i]), .busy_o(out_busy_o[i]), .owner_o(arb_owner[i])
        );
    end

    sw_crossbar #(.N_PORTS(N_PORTS)) u_xbar (
        .wvalid_i(ic_wvalid), .wdata_i(ic_wdata), .dest_i(ic_dest), .req_i(ic_req),
        .gnt_i(arb_gnt),
        .out_wr_en_o(out_wr_en_o), .out_data_o(out_data_o),
        .req_col_o(arb_req), .gnt_in_o(ic_gnt)
    );

    sw_tc_unit #(.N_PORTS(N_PORTS)) u_tc (
        .clk(clk), .rst_n(rst_n),
        .tc_en_i(tc_en_i), .link_run_i(link_run_i),
        .tc_got_i(tc_got_i), .tc_rx_i(tc_rx_i),
        .tc_send_o(tc_send_o), .tc_tx_o(tc_tx_o), .tc_reg_o(tc_reg_o)
    );

endmodule
