// Utilizando Icarus pra rodar o sv
module rx_char (
    input  logic clk,
    input  logic rst_n,

    // Interface com rx_signal
    input  logic bit_valid_i,
    input  logic bit_i,

    // RxErr como high(Rever necessidade, mas deixei aplicação peonta)
    // input  logic rst_rx_i,      
    // input  logic disconnect_i,

    output logic [7:0] data_o,
    output logic       got_null_o,
    output logic       got_fct_o,
    output logic       got_nchar_o,
    output logic       got_eop_o,
    output logic       got_eep_o,
    output logic       got_timecode_o,
    output logic [7:0] timecode_o,

    //+ RxErr
    // output logic rx_err_level_o, // RxErr em nivel

    output logic parity_err_o,
    output logic escape_err_o
);

    // Codigos de controle: 2 bits
    localparam logic [1:0] CODE_FCT = 2'b00;
    localparam logic [1:0] CODE_EOP = 2'b01;
    localparam logic [1:0] CODE_EEP = 2'b10;
    localparam logic [1:0] CODE_ESC = 2'b11;

    localparam logic [6:0] NULL_SYNC_PATTERN = 7'b1110100;

    typedef enum logic [1:0] {ST_HUNT_NULL, ST_WAIT_FLAG, ST_READ_PAYLOAD, ST_CHECK_PARITY} state_t;

    state_t state, state_n;

    logic [3:0] bit_idx,    bit_idx_n; //bits ja consumidos no estado atual
    logic [3:0] bit_cnt,    bit_cnt_n;
    logic       cur_flag,   cur_flag_n;
    logic       captured_parity, captured_parity_n;

    logic [7:0] data_acc,   data_acc_n;   //payload de dado
    logic [1:0] ctrl_code,  ctrl_code_n;  //codigo de controle

    logic       xor_acc,        xor_acc_n;
    logic       prev_char_xor,  prev_char_xor_n;

    logic       esc_pending, esc_pending_n; // 1 = ultimo caractere completo foi um ESC

    logic [5:0] hunt_sh,    hunt_sh_n; // ultimos 6 bits recebidos em HUNT_NULL

    logic [7:0] data_o_n, timecode_o_n;
    logic got_null_n, got_fct_n, got_nchar_n, got_eop_n, got_eep_n, got_timecode_n;
    logic parity_err_n, escape_err_n;

    //FSM + decodificacao
    always_comb begin
        // defaults
        state_n            = state;
        bit_idx_n          = bit_idx;
        bit_cnt_n          = bit_cnt;
        cur_flag_n         = cur_flag;
        captured_parity_n  = captured_parity;
        data_acc_n         = data_acc;
        ctrl_code_n        = ctrl_code;
        xor_acc_n          = xor_acc;
        prev_char_xor_n    = prev_char_xor;
        esc_pending_n      = esc_pending;
        hunt_sh_n          = hunt_sh;

        data_o_n       = data_o;
        timecode_o_n   = timecode_o;
        got_null_n     = 1'b0;
        got_fct_n      = 1'b0;
        got_nchar_n    = 1'b0;
        got_eop_n      = 1'b0;
        got_eep_n      = 1'b0;
        got_timecode_n = 1'b0;
        parity_err_n   = 1'b0;
        escape_err_n   = 1'b0;

        unique case (state)
            ST_HUNT_NULL: begin
                if (bit_valid_i) begin
                    hunt_sh_n = {hunt_sh, bit_i}[5:0]; // descarta o bit mais antigo (Icarus ficava avisando)
                    if ({hunt_sh, bit_i} == NULL_SYNC_PATTERN) begin
                        esc_pending_n     = 1'b1;
                        ctrl_code_n       = CODE_FCT;
                        cur_flag_n        = 1'b1;
                        captured_parity_n = 1'b0;
                        prev_char_xor_n   = 1'b0;
                        xor_acc_n         = 1'b0;
                        state_n           = ST_CHECK_PARITY;
                    end
                end
            end

            ST_WAIT_FLAG: begin
                if (bit_valid_i) begin
                    if (bit_idx == 4'd0) begin
                        captured_parity_n = bit_i;
                        bit_idx_n         = 4'd1;
                    end else begin
                        cur_flag_n = bit_i;
                        bit_cnt_n  = bit_i ? 4'd2 : 4'd8; // flag=1 -> controle(2b); flag=0 -> dado(8b)
                        xor_acc_n  = 1'b0;
                        bit_idx_n  = 4'd0;
                        state_n    = ST_READ_PAYLOAD;
                    end
                end
            end

            ST_READ_PAYLOAD: begin
                if (bit_valid_i) begin
                    xor_acc_n = xor_acc ^ bit_i;

                    if (cur_flag) begin
                        // codigo de controle: 2 bits, MSB primeiro
                        if (bit_idx == 4'd0) ctrl_code_n[1] = bit_i;
                        else                 ctrl_code_n[0] = bit_i;
                    end else begin
                        // dado, 8 bits: LSB primeiro = direta
                        data_acc_n[bit_idx] = bit_i; //TODO verificar a lógica, mas talvez bit_idx possar ser de 3 bits
                    end

                    if (bit_idx == bit_cnt - 4'd1)
                        state_n = ST_CHECK_PARITY;
                    else
                        bit_idx_n = bit_idx + 4'd1;
                end
            end


            ST_CHECK_PARITY: begin
                prev_char_xor_n = xor_acc;
                parity_err_n    = (captured_parity != ~(prev_char_xor ^ cur_flag));

                if (!cur_flag) begin
                    if (esc_pending) begin
                        got_timecode_n = 1'b1;
                        timecode_o_n   = data_acc;
                        esc_pending_n  = 1'b0;
                    end else begin
                        got_nchar_n = 1'b1;
                        data_o_n    = data_acc;
                    end
                end else begin
                    unique case (ctrl_code)
                        CODE_FCT: begin
                            if (esc_pending) begin
                                got_null_n    = 1'b1;
                                esc_pending_n = 1'b0;
                            end else begin
                                got_fct_n = 1'b1;
                            end
                        end
                        CODE_EOP: begin
                            if (esc_pending) begin
                                escape_err_n  = 1'b1;
                                esc_pending_n = 1'b0;
                            end else begin
                                got_nchar_n = 1'b1;
                                got_eop_n   = 1'b1;
                            end
                        end
                        CODE_EEP: begin
                            if (esc_pending) begin
                                escape_err_n  = 1'b1;
                                esc_pending_n = 1'b0;
                            end else begin
                                got_nchar_n = 1'b1;
                                got_eep_n   = 1'b1;
                            end
                        end
                        CODE_ESC: begin
                            if (esc_pending) begin
                                escape_err_n  = 1'b1;
                                esc_pending_n = 1'b0;
                            end else begin
                                esc_pending_n = 1'b1;
                            end
                        end
                        default: ;
                    endcase
                end

                if (bit_valid_i) begin
                    captured_parity_n = bit_i;
                    bit_idx_n         = 4'd1;
                end else begin
                    bit_idx_n         = 4'd0;
                end
                state_n = ST_WAIT_FLAG;
            end

            default: state_n = ST_HUNT_NULL;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= ST_HUNT_NULL;
            bit_idx         <= 4'd0;
            bit_cnt         <= 4'd0;
            cur_flag        <= 1'b0;
            captured_parity <= 1'b0;
            data_acc        <= 8'b0;
            ctrl_code       <= 2'b0;
            xor_acc         <= 1'b0;
            prev_char_xor   <= 1'b0;
            esc_pending     <= 1'b0;
            hunt_sh         <= 6'b0;

            data_o          <= 8'b0;
            timecode_o      <= 8'b0;
            got_null_o      <= 1'b0;
            got_fct_o       <= 1'b0;
            got_nchar_o     <= 1'b0;
            got_eop_o       <= 1'b0;
            got_eep_o       <= 1'b0;
            got_timecode_o  <= 1'b0;
            parity_err_o    <= 1'b0;
            escape_err_o    <= 1'b0;
        end else begin
            state           <= state_n;
            bit_idx         <= bit_idx_n;
            bit_cnt         <= bit_cnt_n;
            cur_flag        <= cur_flag_n;
            captured_parity <= captured_parity_n;
            data_acc        <= data_acc_n;
            ctrl_code       <= ctrl_code_n;
            xor_acc         <= xor_acc_n;
            prev_char_xor   <= prev_char_xor_n;
            esc_pending     <= esc_pending_n;
            hunt_sh         <= hunt_sh_n;

            data_o          <= data_o_n;
            timecode_o      <= timecode_o_n;
            got_null_o      <= got_null_n;
            got_fct_o       <= got_fct_n;
            got_nchar_o     <= got_nchar_n;
            got_eop_o       <= got_eop_n;
            got_eep_o       <= got_eep_n;
            got_timecode_o  <= got_timecode_n;
            parity_err_o    <= parity_err_n;
            escape_err_o    <= escape_err_n;
        end
    end

    // RxErr em high
    // logic rx_err_sticky_q;
    //
    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         rx_err_sticky_q <= 1'b0;
    //     end else if (rst_rx_i) begin
    //         rx_err_sticky_q <= 1'b0;                     // clear (ErrorReset) vence o set
    //     end else if (parity_err_n | escape_err_n | disconnect_i) begin
    //         rx_err_sticky_q <= 1'b1;                     // set: fica em 1 ate rst_rx_i
    //     end
    // end
    //
    // assign rx_err_level_o = rx_err_sticky_q;          // saida direto de flop (sem OR depois)

endmodule
