module rx(
    input logic clk,
    input logic rst_n,

    // interface com outro codec
    input logic D_in,
    input logic S_in,

    // interface com a fifo
    output logic [9:0] data_o,
    output logic data_valid_o,

    // para a maquina de estado
    output logic got_bit_o,
    output logic parity_err_o,
    output logic escape_err_o
);

    logic bit_valid;
    logic bit_signal;

    rx_signal u_rx_signal(
        .clk(clk),
        .rst_n(rst_n),

        .D_in(D_in),
        .S_in(S_in),

        .bit_valid_o(bit_valid),
        .bit_o(bit_signal)
    );

    rx_char u_rx_char (
        .clk(clk),
        .rst_n(rst_n),

        .bit_valid_i(bit_valid),
        .bit_i(bit_signal),

        .data_o(data_o),
        .data_valid_o(data_valid_o),

        .got_bit_o(got_bit_o),
        .parity_err_o(parity_err_o),
        .escape_err_o(escape_err_o)
    );

endmodule
