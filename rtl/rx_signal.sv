module rx_signal (
    input logic ref_rx_clk, // clock de amostragem 200 MHz
    input logic rst_n,

    input logic D_in,
    input logic S_in,

    output logic bit_valid_o,
    output logic bit_o
);

    // sincronização das entradas no domínio de ref_rx_clk, evitar instabilidade
    logic D_meta, S_meta;
    logic D_sync, S_sync; // estável

    // TODO acho que não é para ser problema, pois o clk recuperado tem que ser um múltiplo do ref_rx_clk
    always_ff @(posedge ref_rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            D_meta <= 1'b0;
            S_meta <= 1'b0;
            D_sync <= 1'b0;
            S_sync <= 1'b0;
        end else begin
            D_meta <= D_in;
            S_meta <= S_in;
            D_sync <= D_meta;
            S_sync <= S_meta;
        end
    end


    logic xor_prev; // valor anterior de (D_sync ^ S_sync)
    logic xor_now; // valor atual

    assign xor_now = D_sync ^ S_sync;

    always_ff @(posedge ref_rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            xor_prev <= 1'b0;
            bit_valid_o <= 1'b0;
            bit_o <= 1'b0;
        end else begin
            xor_prev <= xor_now;

            if (xor_now != xor_prev) begin // transição detectada
                bit_valid_o <= 1'b1;
                bit_o <= D_sync; // captura o data no instante da transição
            end else begin
                bit_valid_o <= 1'b0;
            end
        end
    end

endmodule
