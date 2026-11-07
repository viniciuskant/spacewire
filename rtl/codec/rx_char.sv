module rx_char (
    input logic clk, // clock de referencia (200 MHz)
    input logic rst_n,

    input logic bit_valid_i, // domínio rx_clk
    input logic bit_i, // domínio rx_clk

    output logic [9:0] data_o,
    output logic data_valid_o,

    output logic got_bit_o,
    output logic parity_err_o,
    output logic escape_err_o
);

    // CDC: bit_valid_i / bit_i  (rx_clk -> clk)
    // rx_clk (reconstituído) é mais lento que clk, então bit_valid_i fica alto por varios ciclos de clk. 
    // sincronizar (2 FFs) e detectar a borda de subida, gerando "bit_pulse" (1 ciclo por bit).

    logic bv_s1, bv_s2, bv_s3;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) {bv_s3, bv_s2, bv_s1} <= 3'b000;
        else {bv_s3, bv_s2, bv_s1} <= {bv_s2, bv_s1, bit_valid_i};
    end

    logic bit_pulse;
    assign bit_pulse = bv_s2 & ~bv_s3; // 1 ciclo em clk por bit
    assign got_bit_o = bit_pulse;

    // bit_i sincronizado nas mesmas etapas, bi_s2 alinhado com bv_s2
    logic bi_s1, bi_s2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) {bi_s2, bi_s1} <= 2'b00;
        else {bi_s2, bi_s1} <= {bi_s1, bit_i};
    end

    logic bit_s;
    assign bit_s = bi_s2; // valor estável no ciclo do pulso

    //reconstrução do frame
    logic [6:0] bits_even;
    logic [6:0] bits_odd;

    logic [11:0] rx_data;
    assign rx_data  = {bits_odd[6], bits_even[6], bits_odd[5], bits_even[5], bits_odd[4],  bits_even[4],
                       bits_odd[3], bits_even[3], bits_odd[2], bits_even[2], bits_odd[1], bits_even[1]};

    logic rx_flag, rx_parity;
    assign rx_parity = bits_even[0];
    assign rx_flag   = bits_odd [0];

    logic [3:0] bit_idx;
    logic last_bit;
    logic done_i; // pulso de 1 ciclo ao fim de cada char

    // last_bit: combinatório, indica que o bit no índice atual é o ultimo do caractere. 
    // usa bit_s (bit corrente) para completar o campo de tip quando necessário (ex.: FCT/EOP/EEP no bit 3).
    always_comb begin
        last_bit = 1'b0;
        if (!rx_flag) begin // data char: 10 bits
            if (bit_idx == 4'h9) last_bit = 1'b1;
        end else begin
            if (bit_idx == 4'h3) begin // FCT/EOP/EEP/ESC
                last_bit = 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_idx <= 4'h0;
        else if (bit_pulse) begin
            if (last_bit) bit_idx <= 4'h0;
            else bit_idx <= bit_idx + 4'h1;
        end
    end

    //pega dos bits das duas bordas, já que basta olhar o valid (pulse)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bits_even <= 8'h0;
            bits_odd <= 8'h0;
        end else if (bit_pulse) begin
            if (bit_idx == 4'h0) begin
                bits_even <= 8'h0;
                bits_odd <= 8'h0;
            end
            if (!bit_idx[0])
                bits_even[bit_idx[3:1]] <= bit_s;
            else
                bits_odd[bit_idx[3:1]] <= bit_s;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_i <= 1'b0;
        else done_i <= bit_pulse & last_bit;
    end

    logic got_eop, got_eep, got_esc, got_timecode, got_data, got_fct, got_null;
    logic parity_calc;
    logic prev_is_esc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            got_fct <= 1'b0;
            got_esc <= 1'b0;
            got_eop <= 1'b0;
            got_eep <= 1'b0;
            got_null <= 1'b0;
            got_timecode <= 1'b0;
            got_data <= 1'b0;
            parity_calc <= 1'b0;
        end else begin
            got_fct <= 1'b0;
            got_eop <= 1'b0;
            got_esc <= 1'b0;
            got_eep <= 1'b0;
            got_null <= 1'b0;
            got_timecode <= 1'b0;
            got_data <= 1'b0;

            if (bit_pulse & last_bit) begin // se terminou o frame
                if (!rx_flag) begin
                    got_timecode <= (prev_is_esc) ? 1'b1 : 1'b0;
                    got_data <= (prev_is_esc) ? 1'b0 : 1'b1;
                    parity_calc <= ^{bit_s, rx_data[6:0]};
                end else begin
                    if (bit_idx == 4'h3) begin // FCT/EOP/EEP/ESC
                        if ({bit_s, rx_data[0]} == 2'b00) begin
                            got_null <= (prev_is_esc) ? 1'b1 : 1'b0;
                            got_fct <= (prev_is_esc) ? 1'b0 : 1'b1;
                            parity_calc <= bit_s ^ rx_data[0];
                        end else if ({bit_s, rx_data[0]} == 2'b10) begin
                            got_eop <= 1'b1;
                            parity_calc <= bit_s ^ rx_data[0];
                        end else if ({bit_s, rx_data[0]} == 2'b01) begin
                            got_eep <= 1'b1;
                            parity_calc <= bit_s ^ rx_data[0];
                        end else begin
                            got_esc <= 1'b1;
                            parity_calc <= bit_s ^ rx_data[0];
                        end
                    end 
                end
            end
        end
    end

    logic prev_parity_calc;
    logic parity_err_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parity_err_reg <= 1'b0;
            prev_parity_calc <= 1'b0;
            prev_is_esc <= 1'b0;
        end else begin
            if (parity_err_reg) begin
                parity_err_reg <= 1'b1; // trava o erro
            end else if (bit_pulse && bit_idx == 4'h1) begin
                parity_err_reg <= (rx_parity ^ bit_s ^ prev_parity_calc) != 1'b1;
            end else if (done_i) begin
                prev_is_esc <= got_esc;
                prev_parity_calc <= parity_calc;
            end
        end
    end

    assign parity_err_o = parity_err_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            escape_err_o <= 1'b0;
        else if (escape_err_o)
            escape_err_o <= 1'b1; // trava o erro
        else if (prev_is_esc && (got_eep | got_eop | got_esc))
            escape_err_o <= 1'b1;
    end

 
    // codificação interna (últimos 2 bits da saída)
    //      2'b00 Data Characters
    //      2'b01 Control Characters
    //      2'b10 NULL
    //      2'b11 Timecode

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= '0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;
            if (done_i && !parity_err_o && !escape_err_o) begin
                if (got_data) begin// data char
                    data_o <= {rx_data[7:0], 2'b00};
                    data_valid_o <= 1'b1;
                end else if (got_fct || got_eop || got_eep) begin
                    data_o <= {6'd0, rx_data[1:0], 2'b01};
                    data_valid_o <= 1'b1;
                end else if (got_null) begin
                    data_o <= {8'd0, 2'b10};
                    data_valid_o <= 1'b1;
                end else if (got_timecode) begin //timecode
                    data_o <= {rx_data[7:0], 2'b11};
                    data_valid_o <= 1'b1;
                end
            end
        end
    end

endmodule
