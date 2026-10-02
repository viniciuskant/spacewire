module rx #(
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
) (
    input logic clk,
    input logic rst_n,

    // interface com outro codec
    input logic d_i,
    input logic s_i,

    // interface com a fifo
    output logic [8:0] rx_data, // -> wr_data_i da fifo
    output logic rx_en, // -> wr_en_i

    // para a maquina de estado
    output logic got_null_o,
    output logic got_fct_o,
    output logic got_nchar_o,
    output logic got_eop_o,
    output logic got_eep_o,
    output logic parity_err_o,
    output logic escape_err_o,
    output logic disconnect_o,

    // sai direto sem passar pela fifo
    output logic got_timecode_o,
    output logic [7:0] timecode_o
);

    logic bit_valid;
    logic bit_signal;

    assign rx_en = got_nchar_o; // TODO acho que isso tem que ser expandido para contempler sinais de erro

    rx_signal #(
        .SYS_CLK_FREQ_HZ(SYS_CLK_FREQ_HZ),
        .DISCONNECT_TIMEOUT_NS(DISCONNECT_TIMEOUT_NS)) dut_rx_signal(
        .clk(clk),
        .rst_n(rst_n),

        .d_i(d_i),
        .s_i(s_i),

        .bit_valid_o(bit_valid),
        .bit_o(bit_signal),
        .disconnect_o(disconnect_o)
    );

    rx_char dut_rx_char (
        .clk(clk),
        .rst_n(rst_n),
        .bit_valid_i(bit_valid),
        .bit_i(bit_signal),

        .data_o(rx_data), //TODO: verificar a largura

        .got_null_o(got_null_o),
        .got_fct_o(got_fct_o),
        .got_nchar_o(got_nchar_o),
        .got_eop_o(got_eop_o),
        .got_eep_o(got_eep_o),
        .got_timecode_o(got_timecode_o),

        .timecode_o(timecode_o),
        .parity_err_o(parity_err_o),
        .escape_err_o(escape_err_o)
    );

endmodule
