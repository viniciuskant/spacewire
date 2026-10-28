module sw_out_arb #(
    parameter int N_PORTS = 4                    // portas físicas (2--31)
)(
    input  logic clk,
    input  logic rst_n,                          // reset (0)

    input  logic [N_PORTS:1]               req_i,       // bit i = entrada i pede essa saída
    input  logic                           wr_en_i,     // saída gravou palavra neste ciclo = 1
    input  logic                           wr_marker_i, // palavra gravada é EOP/EEP = 1

    output logic [N_PORTS:1]               gnt_o,       // one-hot: entrada dona
    output logic                           busy_o,
    output logic [$clog2(N_PORTS+1)-1:0]   owner_o      // entrada dona (1--N)/ 0 = livre
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    // regs
    logic          busy_q;
    logic [PW-1:0] owner_q;  // dono (1--N)/ 0 = livre
    logic [PW-1:0] last_q;   // último atendido (1--N)

    // round-robin
    logic [PW-1:0] winner;   // primeiro pedido depois de last_q
    logic          found;
    logic [PW-1:0] idx_p;    // porta olhada (1--N)

    always_comb begin
        winner = '0;
        found  = 1'b0;
        idx_p  = '0;
        for (int k = 1; k <= N_PORTS; k++) begin
            // dá a volta (1..N); unsigned' evita 4 -> -4
            idx_p = PW'(unsigned'(((int'(last_q) - 1 + k) % N_PORTS) + 1));
            if (!found && req_i[idx_p]) begin
                winner = idx_p;
                found  = 1'b1;
            end
        end
    end

    // concessão
    always_comb begin
        for (int i = 1; i <= N_PORTS; i++) begin
            gnt_o[i] = busy_q && (owner_q == PW'(unsigned'(i)));
        end
    end

    // soltar
    logic owner_req;   // dono ainda pede = 1
    logic release_w;   // soltar neste ciclo = 1

    assign owner_req = |(req_i & gnt_o);
    assign release_w = busy_q && ((wr_en_i && wr_marker_i) || !owner_req);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q  <= 1'b0;
            owner_q <= '0;
            last_q  <= PW'(N_PORTS);   // 1a busca começa na porta 1
        end else if (busy_q) begin
            if (release_w) begin
                busy_q  <= 1'b0;
                owner_q <= '0;
            end
        end else if (found) begin  // escolher
            busy_q  <= 1'b1;
            owner_q <= winner;
            last_q  <= winner;
        end
    end

    assign busy_o  = busy_q;
    assign owner_o = owner_q;

endmodule
