module sw_in_ctrl #(
    parameter int N_PORTS = 4,                   // portas físicas (2--31)
    // verilator lint_off UNUSEDPARAM
    parameter int MY_PORT = 1                    // esta entrada (1--N)
    // verilator lint_on UNUSEDPARAM
)(
    input  logic clk,
    input  logic rst_n,                          // reset (0)

    // rx_fifo TODO: Padronizar a fifo com a do codec dps, fiz essa só para teste inicial
    input  logic [8:0]                     in_data_i,   // frente da rx_fifo
    input  logic                           in_empty_i,
    output logic                           in_rd_en_o,  // retira a frente = 1

    // tabela
    input  logic                           tbl_hit_i,   // rota existe = 1
    input  logic [$clog2(N_PORTS+1)-1:0]   tbl_port_i,  // porta da rota (1--N)

    input  logic [N_PORTS:1]               link_run_i,  // link em Run = 1
    input  logic [N_PORTS:1]               out_full_i,  // tx_fifo cheia = 1

    // árbitro
    output logic [N_PORTS:1]               req_o,       // one-hot: saída pedida
    input  logic                           gnt_i,       // concedido = 1

    // crossbar
    output logic [$clog2(N_PORTS+1)-1:0]   dest_o,      // destino (1--N)
    output logic                           wvalid_o,    // grava palavra = 1
    output logic [8:0]                     wdata_o,     // palavra a gravar
    output logic                           err_o        // descartei pacote = 1 (1 ciclo)
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    typedef enum logic [2:0] {ST_IDLE, ST_REQ, ST_SEND, ST_EEP, ST_SPILL} state_t;

    // regs
    state_t        state;
    logic [PW-1:0] dest_q;     // destino (1--N)
    logic          del_hdr_q;  // apagar cabeçalho = 1
    logic          err_q;      // pulso de descarte

    // cabeçalho
    logic [7:0]       addr;      // frente da fifo
    logic             is_mark;   // EOP/EEP = 1
    logic             is_path;   // caminho (1--N) = 1
    logic             is_log;    // lógico (32--254) com rota = 1
    logic [PW-1:0]    cand;      // destino candidato/ 0 = inválido
    logic [N_PORTS:1] cand_sel;  // one-hot do candidato
    logic             hdr_ok;    // destino válido e em Run = 1

    assign addr    = in_data_i[7:0];
    assign is_mark = in_data_i[8];
    assign is_path = (addr >= 8'd1) && (addr <= 8'(N_PORTS));
    assign is_log  = (addr >= 8'd32) && (addr <= 8'd254) && tbl_hit_i;
    assign cand    = is_path ? PW'(addr) : (is_log ? tbl_port_i : '0);

    // destino
    logic [N_PORTS:1] dest_sel;   // one-hot de dest_q
    logic             dest_full;  // saída de destino cheia = 1
    logic             xfer;       // copia palavra neste ciclo = 1

    // one-hot por comparação: candidato 0 ou > N vira zero (índice seguro)
    always_comb begin
        for (int i = 1; i <= N_PORTS; i++) begin
            cand_sel[i] = (cand   == PW'(unsigned'(i)));
            dest_sel[i] = (dest_q == PW'(unsigned'(i)));
        end
    end

    assign hdr_ok    = |(cand_sel & link_run_i);
    assign dest_full = |(dest_sel & out_full_i);
    assign xfer      = gnt_i && !in_empty_i && !dest_full;

    // saídas
    always_comb begin
        in_rd_en_o = 1'b0;
        wvalid_o   = 1'b0;
        wdata_o    = in_data_i;
        req_o      = '0;
        case (state)
            ST_IDLE:  in_rd_en_o = !in_empty_i && (is_mark || !hdr_ok); // marcador sozinho ou erro
            ST_REQ: begin
                req_o      = dest_sel;
                in_rd_en_o = gnt_i && del_hdr_q;  // apaga cabeçalho
            end
            ST_SEND: begin
                req_o      = dest_sel;
                in_rd_en_o = xfer;
                wvalid_o   = xfer;
            end
            // ST_EEP: Parte 4
            ST_SPILL: in_rd_en_o = !in_empty_i;
            default:  ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            dest_q    <= '0;
            del_hdr_q <= 1'b0;
            err_q     <= 1'b0;
        end else begin
            err_q <= 1'b0;
            case (state)
                // idle
                ST_IDLE: begin
                    if (!in_empty_i && !is_mark) begin
                        if (hdr_ok) begin
                            dest_q    <= cand;
                            del_hdr_q <= is_path;  // caminho = 1/ lógico = 0
                            state     <= ST_REQ;
                        end else begin
                            err_q <= 1'b1;
                            state <= ST_SPILL;
                        end
                    end
                end
                // req
                ST_REQ:   if (gnt_i) state <= ST_SEND;
                // send
                ST_SEND:  if (xfer && is_mark) state <= ST_IDLE;
                // ST_EEP: Parte 4
                // spill
                ST_SPILL: if (!in_empty_i && is_mark) state <= ST_IDLE;
                default:  state <= ST_IDLE;
            endcase
        end
    end

    assign dest_o = dest_q;
    assign err_o  = err_q;

endmodule
