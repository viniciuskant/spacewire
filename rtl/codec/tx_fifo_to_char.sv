module tx_fifo_to_char (
    input  logic clk,
    input  logic rst_n,

    // tx_fifo
    input  logic       fifo_empty_i,
    input  logic [8:0] fifo_rd_data_i,
    output logic       fifo_rd_en_o,

    // tx_char
    input  logic       char_ack_i,
    output logic       send_data_o,
    output logic [7:0] data_o,
    output logic       send_eop_o,
    output logic       send_eep_o
);

    typedef enum logic {ST_IDLE, ST_REQUEST} state_t;

    state_t state, state_n;

    logic [8:0] word_q, word_n; // palavra travada no topo da fifo

    // decodificacao da palavra travada
    wire is_ctrl = word_q[8];
    wire is_eep  = word_q[0];

    // Pedidos em nivel enquanto estiver em ST_REQUEST
    assign send_data_o = (state == ST_REQUEST) && !is_ctrl;
    assign send_eop_o  = (state == ST_REQUEST) &&  is_ctrl && !is_eep;
    assign send_eep_o  = (state == ST_REQUEST) &&  is_ctrl &&  is_eep;
    assign data_o      = word_q[7:0];

    //logica comb:
    always_comb begin
        state_n      = state;
        word_n       = word_q;
        fifo_rd_en_o = 1'b0;

        unique case (state)
            ST_IDLE: begin
                if (!fifo_empty_i) begin
                    word_n  = fifo_rd_data_i; // trava, sem pop
                    state_n = ST_REQUEST;
                end
            end

            ST_REQUEST: begin
                if (char_ack_i) begin
                    fifo_rd_en_o = 1'b1; // transmitido
                    state_n      = ST_IDLE;
                end
            end

            default: state_n = ST_IDLE;
        endcase
    end

    //regs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= ST_IDLE;
            word_q <= 9'b0;
        end else begin
            state  <= state_n;
            word_q <= word_n;
        end
    end

endmodule
