module tx(
    input logic clk_tx,
    input logic clk_system,
    input logic rst_n,

    output logic D_out,
    output logic S_out,

    output logic rd_en_fifo,
    input logic [8:0] rd_data_fifo,
    input logic empty_fifo,

    input logic run_state,
    input logic bit_tick_i,
    input logic send_fct_i,
    input logic send_eop_i,
    input logic send_eep_i,
    input logic send_null_i,
    output logic char_ack_o,

    input logic send_timecode_i,
    input logic [7:0] timecode_i
);
    logic send_data;
    logic busy_char;
    logic busy;

    logic [7:0] tc_fifo_rdata;
    logic tc_fifo_rempty;
    logic tc_fifo_wfull;
    logic tc_fifo_rinc;

    fifo1 #(.DSIZE(8), .ASIZE(4)) u_tc_fifo ( // TODO não sei se seria extremamente necessário, mas acho válido para não perder time code
        .wfull (tc_fifo_wfull),
        .rempty (tc_fifo_rempty),
        .wdata (timecode_i),
        .winc (send_timecode_i),
        .wclk (clk_system),
        .wrst_n (rst_n),
        .rdata (tc_fifo_rdata),
        .rinc (tc_fifo_rinc),
        .rclk (clk_tx),
        .rrst_n (rst_n)
    );

    assign busy = busy_char | ~tc_fifo_rempty;

    logic rd_en_cond, rd_en_cond_d;
    assign rd_en_cond = ~busy & ~empty_fifo;

    always_ff @(posedge clk_tx or negedge rst_n) begin
        if (!rst_n) rd_en_cond_d <= 1'b0;
        else rd_en_cond_d <= rd_en_cond;
    end

    assign rd_en_fifo = rd_en_cond & ~rd_en_cond_d;

    logic [8:0] data_reg;
    logic data_valid;

    always_ff @(posedge clk_tx or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= '0;
            data_valid <= 1'b0;
        end else begin
            if (rd_en_fifo) begin
                data_reg <= rd_data_fifo;
                data_valid <= 1'b1;
            end else if (busy_char) begin
                data_valid <= 1'b0;
            end
        end
    end

    assign send_data = run_state & data_valid;

    logic busy_char_d;
    always_ff @(posedge clk_tx or negedge rst_n) begin
        if (!rst_n) busy_char_d <= 1'b0;
        else busy_char_d <= busy_char;
    end

    assign tc_fifo_rinc = busy_char & ~busy_char_d & ~tc_fifo_rempty;

    logic bit_valid;
    logic bit_signal;

    tx_signal u_tx_signal (
        .clk(clk_tx),
        .rst_n(rst_n),
        .bit_valid_i(bit_valid),
        .bit_i(bit_signal),
        .D_out(D_out),
        .S_out(S_out)
    );

    tx_char u_tx_char (
        .clk(clk_tx),
        .rst_n(rst_n),
        .bit_tick_i(bit_tick_i),
        .send_data_i(send_data),
        .data_i(data_reg),
        .busy_o(busy_char),
        .send_fct_i(send_fct_i),
        .send_eop_i(send_eop_i),
        .send_eep_i(send_eep_i),
        .send_null_i(send_null_i),
        .send_timecode_i(~tc_fifo_rempty),
        .timecode_i(tc_fifo_rdata),
        .bit_valid_o(bit_valid),
        .bit_o(bit_signal)
    );

endmodule