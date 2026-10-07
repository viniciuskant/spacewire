module rx_signal (
    input logic ref_rx_clk, // clock de amostragem 200 MHz
    output logic rx_clk,
    input logic rst_n,

    input logic d_i,
    input logic s_i,

    output logic bit_valid_o,
    output logic bit_o
);

    // sincronização das entradas no domínio de ref_rx_clk, evitar instabilidade
    logic d_meta, s_meta;
    logic d_sync, s_sync; // estável

    // TODO acho que não é para ser problema, pois o clk recuperado tem que ser um múltiplo do ref_rx_clk
    always_ff @(posedge ref_rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            d_meta <= 1'b0;
            s_meta <= 1'b0;
            d_sync <= 1'b0;
            s_sync <= 1'b0;
        end else begin
            d_meta <= d_i;
            s_meta <= s_i;
            d_sync <= d_meta;
            s_sync <= s_meta;
        end
    end


    logic xor_prev; // valor anterior de (d_sync ^ s_sync)
    logic xor_now; // valor atual

    assign xor_now = d_sync ^ s_sync;

    always_ff @(posedge ref_rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            xor_prev <= 1'b0;
            bit_valid_o <= 1'b0;
            bit_o <= 1'b0;
        end else begin
            xor_prev <= xor_now;

            if (xor_now != xor_prev) begin // transição detectada
                bit_valid_o <= 1'b1;
                bit_o <= d_sync; // captura o data no instante da transição
            end else begin
                bit_valid_o <= 1'b0;
            end
        end
    end

    always_ff @(posedge ref_rx_clk or negedge rst_n) begin
        if (!rst_n)
            rx_clk <= 1'b0;
        else if (xor_now != xor_prev)
            rx_clk <= ~rx_clk;
    end

endmodule