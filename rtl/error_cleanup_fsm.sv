module error_cleanup_fsm (
    input logic clk_system,
    input logic clk_tx,
    input logic rst_n,
    input logic run_state,
    input logic rx_Error,
    input logic disconnect,
    input logic credit_err,
    input logic rd_en_fifo_tx,
    input logic empty_tx_fifo_temp,
    input logic [8:0] rd_data_fifo_tx_temp,
    output logic [8:0] rd_data_fifo_tx,
    output logic rd_en_fifo_tx_temp,
    output logic empty_tx_fifo
);

    localparam logic [8:0] EEP_MARKER = 9'b1_0000_0010;

    typedef enum logic {
        WAIT_ERRO = 1'b0,
        CLEAN_TX_FIFO = 1'b1
    } state_t;

    state_t current_state;

    logic clean_req_sys;
    logic clean_done_sys;

    always_ff @(posedge clk_system or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= WAIT_ERRO;
            clean_req_sys <= 1'b0;
        end else begin
            case (current_state)
                WAIT_ERRO: begin
                    if (run_state && (rx_Error || disconnect || credit_err)) begin
                        clean_req_sys <= 1'b1;
                        current_state <= CLEAN_TX_FIFO;
                    end
                end

                CLEAN_TX_FIFO: begin
                    if (clean_done_sys) begin
                        clean_req_sys <= 1'b0;
                        current_state <= WAIT_ERRO;
                    end
                end
            endcase
        end
    end


    logic [1:0] clean_req_sync_tx;
    logic clean_req_tx;

    always_ff @(posedge clk_tx or negedge rst_n) begin
        if (!rst_n) clean_req_sync_tx <= 2'b00;
        else clean_req_sync_tx <= {clean_req_sync_tx[0], clean_req_sys};
    end
    assign clean_req_tx = clean_req_sync_tx[1];

    logic clean_done_tx;

    always_ff @(posedge clk_tx or negedge rst_n) begin
        if (!rst_n) begin
            clean_done_tx <= 1'b0;
        end
        else if (!clean_req_tx) begin
            clean_done_tx <= 1'b0;
        end
        else if (empty_tx_fifo_temp || rd_data_fifo_tx_temp == EEP_MARKER) begin
            clean_done_tx <= 1'b1;
        end
    end

    logic [1:0] clean_done_sync_sys;

    always_ff @(posedge clk_system or negedge rst_n) begin
        if (!rst_n) clean_done_sync_sys <= 2'b00;
        else clean_done_sync_sys <= {clean_done_sync_sys[0], clean_done_tx};
    end
    assign clean_done_sys = clean_done_sync_sys[1];

    always_comb begin
        if (clean_req_tx) begin
            rd_data_fifo_tx = 9'b0;
            rd_en_fifo_tx_temp = 1'b1; // drena a FIFO
            empty_tx_fifo = 1'b1;
        end
        else begin
            rd_data_fifo_tx = rd_data_fifo_tx_temp;
            rd_en_fifo_tx_temp = rd_en_fifo_tx;
            empty_tx_fifo = empty_tx_fifo_temp;
        end
    end

endmodule