module sw_crossbar #(
    parameter int N_PORTS = 4                    // portas físicas (2--31)
)(
    // controles de entrada (linha i = entrada i)
    input  logic [N_PORTS:0]                         wvalid_i,   // entrada quer gravar = 1
    input  logic [N_PORTS:0][8:0]                    wdata_i,    // palavra
    input  logic [N_PORTS:0][$clog2(N_PORTS+1)-1:0]  dest_i,     // destino (0--N)
    input  logic [N_PORTS:0][N_PORTS:0]              req_i,      // req_o da entrada

    // árbitros (linha j = saída j)
    input  logic [N_PORTS:0][N_PORTS:0]              gnt_i,      // gnt_o do árbitro j

    // tx_fifo de cada saída
    output logic [N_PORTS:0]                         out_wr_en_o,
    output logic [N_PORTS:0][8:0]                    out_data_o,

    output logic [N_PORTS:0][N_PORTS:0]              req_col_o,  // [j][i] = req_i[i][j]
    output logic [N_PORTS:0]                         gnt_in_o    // entrada i escolhida = 1
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    // generate com genvar
    logic [N_PORTS:0][N_PORTS:0] dsel;   // [i][j]: dest_i[i] == j (> N: tudo zero)
    logic [N_PORTS:0][N_PORTS:0] ghit;   // [i][j]: destino j e árbitro j escolheu i
    logic [N_PORTS:0][N_PORTS:0] wsel;   // [j][i]: entrada i grava na saída j

    for (genvar i = 0; i <= N_PORTS; i++) begin : g_in
        for (genvar j = 0; j <= N_PORTS; j++) begin : g_out
            assign dsel[i][j]      = (dest_i[i] == PW'(j));
            assign ghit[i][j]      = dsel[i][j] && gnt_i[j][i];
            assign req_col_o[j][i] = req_i[i][j];                          // linha para coluna
            assign wsel[j][i]      = wvalid_i[i] && gnt_in_o[i] && dsel[i][j];  // só o dono grava
        end
        assign gnt_in_o[i] = |ghit[i];                                     // árbitro para entrada
    end

    // dados: entrada para saída
    for (genvar j = 0; j <= N_PORTS; j++) begin : g_mux
        logic [8:0] masked [0:N_PORTS];   // palavra da entrada i se ela grava em j/ senão 0
        logic [8:0] mux;                  // OR de todas as masked

        for (genvar i = 0; i <= N_PORTS; i++) begin : g_and
            assign masked[i] = wsel[j][i] ? wdata_i[i] : 9'd0;
        end

        always_comb begin
            mux = 9'd0;
            for (int i = 0; i <= N_PORTS; i++) mux = mux | masked[i];
        end

        assign out_wr_en_o[j] = |wsel[j];
        assign out_data_o[j]  = mux;
    end

endmodule
