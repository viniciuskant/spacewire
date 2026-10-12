// Utilizando Icarus pra rodar o sv
module tx_char (
    input logic clk,
    input logic rst_n,

    input logic bit_tick_i,

    // Pedidos de envio (arbitrados por prioridade fixa)
    input logic send_data_i,
    input logic [7:0] data_i,
    input logic send_fct_i,
    input logic send_eop_i,
    input logic send_eep_i,
    input logic send_null_i,
    input logic send_timecode_i,
    input logic [7:0] timecode_i,

    output logic char_ack_o,     // Para char da FIFO não contar ack

    input  logic       nchar_en_i,     // run_state && sending_allowed (flow control)
    input  logic       fifo_empty_i,
    input  logic [8:0] fifo_rd_data_i, // cabeca da tx_fifo (combinacional)
    output logic       fifo_rd_en_o,   // pop: 1 ciclo por N-Char servido (en_out_fifo_tx)

    // Interface com tx_signal
    output logic bit_valid_o,
    output logic bit_o
);

    localparam logic [7:0] PAYLOAD_FCT = 8'b00000000; // code 00 -> bits 0,0
    localparam logic [7:0] PAYLOAD_EOP = 8'b00000010; // code 01 -> bits 0,1 (bit1=1)
    localparam logic [7:0] PAYLOAD_EEP = 8'b00000001; // code 10 -> bits 1,0 (bit0=1)
    localparam logic [7:0] PAYLOAD_ESC = 8'b00000011; // code 11 -> bits 1,1

    typedef enum logic [1:0] {ST_IDLE, ST_PARITY, ST_FLAG, ST_PAYLOAD} state_t;
    typedef enum logic [1:0] {PART2_NONE, PART2_NULL_FCT, PART2_TC_DATA} part2_t;

    state_t state, state_n;
    part2_t part2_pending, part2_pending_n;

    logic       cur_flag,  cur_flag_n;
    logic [7:0] payload_sh, payload_sh_n;   // shift-register do payload (bit 0 = proximo a sair)
    logic [3:0] bit_cnt,   bit_cnt_n;       // bits do payload faltantes
    logic [7:0] tc_latch,  tc_latch_n;      // valor do time-code

    logic       last_char_xor, last_char_xor_n; // XOR{payload} do ultimo caractere completo (sem o flag)
    logic       xor_acc, xor_acc_n;             // acumulador do payload do caractere em andamento

    logic char_ack_n;
    logic bit_valid_n, bit_n;

    logic idle_settled, idle_settled_n;

    logic from_fifo, from_fifo_n; // 1 = caractere em andamento veio da tx_fifo sem char_ack_o

    wire fifo_valid = nchar_en_i && !fifo_empty_i;

    //logica combinacional:
    always_comb begin
        // defaults
        state_n         = state;
        part2_pending_n = part2_pending;
        cur_flag_n      = cur_flag;
        payload_sh_n    = payload_sh;
        bit_cnt_n       = bit_cnt;
        tc_latch_n      = tc_latch;
        last_char_xor_n = last_char_xor;
        xor_acc_n       = xor_acc;
        char_ack_n      = 1'b0;
        bit_valid_n     = 1'b0;
        bit_n           = 1'b0;
        idle_settled_n  = (state == ST_IDLE);
        from_fifo_n     = from_fifo;
        fifo_rd_en_o    = 1'b0;

        unique case (state)

            ST_IDLE: begin
                if (idle_settled) begin
                    from_fifo_n = 1'b0;
                    // Prioridade: Time-code > FCT > N-Char > Null
                    if (send_timecode_i) begin
                        cur_flag_n      = 1'b1; // ESC e caractere de controle
                        payload_sh_n    = PAYLOAD_ESC; // MSB primeiro no bit0
                        bit_cnt_n       = 4'd2;
                        tc_latch_n      = timecode_i;
                        part2_pending_n = PART2_TC_DATA;
                        state_n         = ST_PARITY;
                    end
                    else if (send_fct_i) begin
                        cur_flag_n      = 1'b1;
                        payload_sh_n    = PAYLOAD_FCT;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                    end
                    else if (send_data_i) begin
                        cur_flag_n      = 1'b0; // dado
                        payload_sh_n    = data_i; // LSB primeiro
                        bit_cnt_n       = 4'd8;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                    end
                    else if (send_eop_i) begin
                        cur_flag_n      = 1'b1;
                        payload_sh_n    = PAYLOAD_EOP;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                    end
                    else if (send_eep_i) begin
                        cur_flag_n      = 1'b1;
                        payload_sh_n    = PAYLOAD_EEP;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                    end
                    else if (fifo_valid && !fifo_rd_data_i[8]) begin
                        cur_flag_n      = 1'b0; // dado da tx_fifo
                        payload_sh_n    = fifo_rd_data_i[7:0];
                        bit_cnt_n       = 4'd8;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                        from_fifo_n     = 1'b1;
                        fifo_rd_en_o    = 1'b1; // palavra ja capturada
                    end
                    else if (fifo_valid && !fifo_rd_data_i[0]) begin
                        cur_flag_n      = 1'b1; // EOP da tx_fifo
                        payload_sh_n    = PAYLOAD_EOP;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                        from_fifo_n     = 1'b1;
                        fifo_rd_en_o    = 1'b1;
                    end
                    else if (fifo_valid) begin
                        cur_flag_n      = 1'b1; // EEP da tx_fifo
                        payload_sh_n    = PAYLOAD_EEP;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NONE;
                        state_n         = ST_PARITY;
                        from_fifo_n     = 1'b1;
                        fifo_rd_en_o    = 1'b1;
                    end
                    else if (send_null_i) begin
                        cur_flag_n      = 1'b1;
                        payload_sh_n    = PAYLOAD_ESC;
                        bit_cnt_n       = 4'd2;
                        part2_pending_n = PART2_NULL_FCT;
                        state_n         = ST_PARITY;
                    end
                    // senao: permanece ocioso, nao transmite nada
                end
            end

            // Emite o bit de paridade deste caractere:
            ST_PARITY: begin
                bit_n       = ~(last_char_xor ^ cur_flag);
                bit_valid_n = bit_tick_i;
                xor_acc_n   = 1'b0; // reinicia acumulador do caractere atual
                if (bit_tick_i)
                    state_n = ST_FLAG;
            end

            ST_FLAG: begin
                bit_n       = cur_flag;
                bit_valid_n = bit_tick_i;
                // o flag n entra no acumulador
                if (bit_tick_i)
                    state_n = ST_PAYLOAD;
            end

            ST_PAYLOAD: begin
                bit_n       = payload_sh[0];
                bit_valid_n = bit_tick_i;
                if (bit_tick_i) begin
                    xor_acc_n    = xor_acc ^ payload_sh[0];
                    payload_sh_n = payload_sh >> 1;
                    bit_cnt_n    = bit_cnt - 4'd1;

                    if (bit_cnt == 4'd1) begin
                        // ultimo bit deste caractere foi consumido agora
                        last_char_xor_n = xor_acc ^ payload_sh[0];

                        unique case (part2_pending)
                            PART2_NONE: begin
                                char_ack_n      = !from_fifo; // ack so para pedidos send_*_i
                                state_n         = ST_IDLE;
                            end
                            PART2_NULL_FCT: begin
                                // segunda metade do Null: FCT
                                cur_flag_n      = 1'b1;
                                payload_sh_n    = PAYLOAD_FCT;
                                bit_cnt_n       = 4'd2;
                                part2_pending_n = PART2_NONE;
                                state_n         = ST_PARITY;
                            end
                            PART2_TC_DATA: begin
                                // segunda metade do Time-code: caractere de dado
                                cur_flag_n      = 1'b0;
                                payload_sh_n    = tc_latch;
                                bit_cnt_n       = 4'd8;
                                part2_pending_n = PART2_NONE;
                                state_n         = ST_PARITY;
                            end
                            default: state_n = ST_IDLE;
                        endcase
                    end
                end
            end

            default: state_n = ST_IDLE;
        endcase
    end

    //registradores
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            part2_pending <= PART2_NONE;
            cur_flag      <= 1'b0;
            payload_sh    <= 8'b0;
            bit_cnt       <= 4'b0;
            tc_latch      <= 8'b0;
            last_char_xor <= 1'b0;   // assume caractere "virtual" anterior com payload 0
            xor_acc       <= 1'b0;
            char_ack_o    <= 1'b0;
            bit_valid_o   <= 1'b0;
            bit_o         <= 1'b0;
            idle_settled  <= 1'b0;
            from_fifo     <= 1'b0;
        end else begin
            state         <= state_n;
            part2_pending <= part2_pending_n;
            cur_flag      <= cur_flag_n;
            payload_sh    <= payload_sh_n;
            bit_cnt       <= bit_cnt_n;
            tc_latch      <= tc_latch_n;
            last_char_xor <= last_char_xor_n;
            xor_acc       <= xor_acc_n;
            char_ack_o    <= char_ack_n;
            bit_valid_o   <= bit_valid_n;
            bit_o         <= bit_n;
            idle_settled  <= idle_settled_n;
            from_fifo     <= from_fifo_n;
        end
    end

endmodule
