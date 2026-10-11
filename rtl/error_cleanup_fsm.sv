module error_cleanup_fsm (
    input logic clk,
    input logic rst_n,
    input logic run_state,
    input logic rx_Error,
    input logic disconnect,
    input logic rd_en_fifo_tx,
    input logic empty_tx_fifo_temp,
    input logic [8:0] rd_data_fifo_tx_temp,
    output logic [8:0] rd_data_fifo_tx,
    output logic rd_en_fifo_tx_temp,
    output logic empty_tx_fifo
);

    typedef enum logic {
        WAIT_ERRO = 1'b0,
        CLEAN_TX_FIFO = 1'b1
    } state_t;

    state_t current_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            current_state <= WAIT_ERRO;
        end else begin
            case (current_state)
                WAIT_ERRO: begin
                    if (run_state && (rx_Error || disconnect)) begin
                        current_state <= CLEAN_TX_FIFO;
                    end
                end

                CLEAN_TX_FIFO: begin
                    if (rd_data_fifo_tx_temp == 9'b1_0000_0010) begin
                        current_state <= WAIT_ERRO;
                    end
                end
            endcase
        end
    end

    always_comb begin
        rd_data_fifo_tx = rd_data_fifo_tx_temp;
        rd_en_fifo_tx_temp = rd_en_fifo_tx;
        empty_tx_fifo = empty_tx_fifo_temp;

        case (current_state)
            WAIT_ERRO: begin
                if (run_state && (rx_Error || disconnect)) begin
                    rd_data_fifo_tx = 9'b1_0000_0001;
                    rd_en_fifo_tx_temp = rd_en_fifo_tx;
                    empty_tx_fifo = 0;
                end else begin
                    rd_data_fifo_tx = rd_data_fifo_tx_temp;
                    rd_en_fifo_tx_temp = rd_en_fifo_tx;
                    empty_tx_fifo = empty_tx_fifo_temp;
                end
            end

            CLEAN_TX_FIFO: begin
                rd_data_fifo_tx = '0;
                rd_en_fifo_tx_temp = 1;
                empty_tx_fifo = 1;
            end
        endcase
    end

endmodule