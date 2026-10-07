module rx #(
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
) (
    input logic ref_rx_clk,
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

    // sai direto sem passar pela fifo
    output logic got_timecode_o,
    output logic [7:0] timecode_o
);

    logic bit_valid;
    logic bit_signal;

    rx_signal dut_rx_signal(
        .ref_rx_clk(ref_rx_clk),
        .rst_n(rst_n),

        .d_i(d_i),
        .s_i(s_i),

        .bit_valid_o(bit_valid),
        .bit_o(bit_signal)
    );

    rx_char dut_rx_char (
        .ref_rx_clk(ref_rx_clk),
        .rst_n(rst_n),

        .bit_valid_i(bit_valid),
        .bit_i(bit_signal),

        .data_o(rx_data),
        .data_valid_o(rx_en)
        .timecode_o(timecode_o),
        .got_timecode_o(got_timecode_o),

        .got_null(got_null_o),
        .got_fct(got_fct_o),

        .parity_err_o(parity_err_o),
        .escape_err_o(escape_err_o)
    );

endmodule
