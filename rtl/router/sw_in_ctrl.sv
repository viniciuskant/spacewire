module sw_in_ctrl #(
    parameter int N_PORTS = 4,                   // portas físicas (2--31)
    parameter int MY_PORT = 1                    // esta entrada (0--N)
)(
    input  logic clk,
    input  logic rst_n,                          // reset (0)

    // rx_fifo
    input  logic [8:0]                     in_data_i,   // frente da rx_fifo
    input  logic                           in_empty_i,
    output logic                           in_rd_en_o,  // retira a frente = 1

    // tabela
    input  logic                           lookup_hit_i,  // rota existe = 1
    input  logic [$clog2(N_PORTS+1)-1:0]   lookup_port_i, // porta da rota (1--N)

    input  logic [N_PORTS:0]               link_run_i,  // link em Run = 1
    input  logic [N_PORTS:0]               out_full_i,  // tx_fifo cheia = 1

    // árbitro
    output logic [N_PORTS:0]               req_o,       // one-hot: saída pedida
    input  logic                           gnt_i,       // concedido = 1

    // crossbar
    output logic [$clog2(N_PORTS+1)-1:0]   dest_o,      // destino (0--N)
    output logic                           wvalid_o,    // grava palavra = 1
    output logic [8:0]                     wdata_o,     // palavra a gravar
    output logic                           err_o        // descartei pacote = 1 (1 ciclo)
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    typedef enum logic [2:0] {ST_IDLE, ST_REQ, ST_SEND, ST_EEP, ST_SPILL} state_t;

    // regs
    state_t        state;
    logic [PW-1:0] dest_q;     // destino (0--N)
    logic          del_hdr_q;  // apagar cabeçalho = 1
    logic          err_q;      // pulso de descarte
    logic          eep_to_idle_q; // depois do ST_EEP: ST_IDLE = 1/ ST_SPILL = 0

    // cabeçalho
    logic [7:0]       addr;      // frente da fifo
    logic             is_mark;   // EOP/EEP = 1
    logic             is_path;   // caminho (0--N) = 1
    logic             is_log;    // lógico (32--254) com rota = 1
    logic             cand_ok;   // cabeçalho válido = 1 (0 agora é a porta 0)
    logic [PW-1:0]    cand;      // destino candidato (só vale com cand_ok)
    logic [N_PORTS:0] cand_sel;  // one-hot do candidato
    logic             hdr_ok;    // destino válido e em Run = 1

    assign addr    = in_data_i[7:0];
    assign is_mark = in_data_i[8];
    assign is_path = (addr <= 8'(N_PORTS));
    assign is_log  = (addr >= 8'd32) && (addr <= 8'd254) && lookup_hit_i;
    assign cand_ok = is_path || is_log;
    assign cand    = is_path ? PW'(addr) : (is_log ? lookup_port_i : '0);

    // destino
    logic [N_PORTS:0] dest_sel;   // one-hot de dest_q
    logic             dest_full;  // saída de destino cheia = 1
    logic             dest_up;    // link de destino em Run = 1
    logic             my_link_up; // link desta entrada em Run = 1
    logic             xfer;       // copia palavra neste ciclo = 1

    // one-hot por comparação: cabeçalho inválido ou > N vira zero (índice seguro)
    always_comb begin
        for (int i = 0; i <= N_PORTS; i++) begin
            cand_sel[i] = cand_ok && (cand == PW'(unsigned'(i)));
            dest_sel[i] = (dest_q == PW'(unsigned'(i)));
        end
    end

    assign hdr_ok    = |(cand_sel & link_run_i);
    assign dest_full  = |(dest_sel & out_full_i);
    assign dest_up    = |(dest_sel & link_run_i);
    assign my_link_up = link_run_i[MY_PORT];
    assign xfer       = gnt_i && !in_empty_i && !dest_full && dest_up;  // destino caiu: não copia

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
                in_rd_en_o = gnt_i && del_hdr_q && dest_up;  // apaga cabeçalho/ caiu: ST_SPILL apaga
            end
            ST_SEND: begin
                req_o      = dest_sel;
                in_rd_en_o = xfer;
                wvalid_o   = xfer;
            end
            ST_EEP: begin
                req_o    = dest_sel;               // segura a saída até gravar o EEP
                wvalid_o = gnt_i && !dest_full;
                wdata_o  = 9'h101;                 // EEP
            end
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
            eep_to_idle_q <= 1'b0;
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
                ST_REQ: begin
                    if (!dest_up) begin            // destino caiu (descarta)
                        err_q <= 1'b1;
                        state <= ST_SPILL;
                    end else if (gnt_i) begin
                        state <= ST_SEND;
                    end
                end
                // send
                ST_SEND: begin
                    if (!dest_up) begin            // destino caiu (fecha com EEP e descarta resto)
                        err_q         <= 1'b1;
                        eep_to_idle_q <= 1'b0;
                        state         <= ST_EEP;
                    end else if (!my_link_up && in_empty_i) begin  // entrada caiu e o resto se perdeu
                        err_q         <= 1'b1;
                        eep_to_idle_q <= 1'b1;
                        state         <= ST_EEP;
                    end else if (xfer && is_mark) begin
                        state <= ST_IDLE;
                    end
                end
                // eep
                ST_EEP:   if (gnt_i && !dest_full) state <= eep_to_idle_q ? ST_IDLE : ST_SPILL;
                // spill
                ST_SPILL: if (!in_empty_i && is_mark) state <= ST_IDLE;
                default:  state <= ST_IDLE;
            endcase
        end
    end

    assign dest_o = dest_q;
    assign err_o  = err_q;

endmodule
