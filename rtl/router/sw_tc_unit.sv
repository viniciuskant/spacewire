module sw_tc_unit #(
    parameter int N_PORTS = 4                    // portas físicas (2--31)
)(
    input  logic clk,
    input  logic rst_n,                          // reset (0)

    input  logic                     tc_en_i,     // repasse ligado = 1
    input  logic [N_PORTS:1]         link_run_i,  // link em Run = 1

    // recepção (Time_Code_RX)
    input  logic [N_PORTS:1]         tc_got_i,    // porta recebeu time-code = 1 (pulso)
    input  logic [N_PORTS:1][7:0]    tc_rx_i,     // valor recebido

    // envio (Time_Code_TX)
    output logic [N_PORTS:1]         tc_send_o,   // enviar pela porta = 1 (pulso de 1 ciclo)
    output logic [7:0]               tc_tx_o,     // valor a enviar (igual para todas)
    output logic [5:0]               tc_reg_o     // registrador de tempo (debug)
);

    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta

    // regs
    logic [5:0]       tc_reg_q;   // último tempo visto
    logic [7:0]       tc_val_q;   // time-code a enviar (flags + tempo)
    logic [N_PORTS:1] tc_send_q;  // pulso de envio por porta

    // escolha: menor porta com tc_got
    logic          got;           // alguma porta recebeu = 1
    logic [PW-1:0] src;           // porta escolhida (1--N)
    logic [7:0]    v;             // valor da porta escolhida

    always_comb begin
        got = 1'b0;
        src = '0;
        v   = '0;
        for (int i = N_PORTS; i >= 1; i--) begin  // de cima para baixo (menor vence)
            if (tc_got_i[i]) begin
                got = 1'b1;
                src = PW'(unsigned'(i));
                v   = tc_rx_i[i];
            end
        end
    end

    // aceitação
    logic             is_next;    // v = tc_reg + 1 (mod 64) = 1
    logic [N_PORTS:1] fwd_sel;    // portas que recebem (Run e != origem)

    assign is_next = (v[5:0] == 6'(tc_reg_q + 6'd1));

    always_comb begin
        for (int i = 1; i <= N_PORTS; i++) begin
            fwd_sel[i] = link_run_i[i] && (src != PW'(unsigned'(i)));
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tc_reg_q  <= '0;
            tc_val_q  <= '0;
            tc_send_q <= '0;
        end else begin
            tc_send_q <= '0;
            if (got) begin
                tc_reg_q <= v[5:0];               // sempre
                if (is_next && tc_en_i) begin     // novo: repassa
                    tc_val_q  <= v;
                    tc_send_q <= fwd_sel;
                end
            end
        end
    end

    assign tc_send_o = tc_send_q;
    assign tc_tx_o   = tc_val_q;
    assign tc_reg_o  = tc_reg_q;

endmodule
