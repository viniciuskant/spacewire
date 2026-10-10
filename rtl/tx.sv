module tx(
    input  logic clk,
    input  logic rst_n,

    // interface com outro codec
    output logic d_o,
    output logic s_o,

    // interface com a fifo
    output logic rd_en_fifo,
    input logic [8:0] rd_data_fifo, // <- rd_data_o
    input logic empty_fifo, // <- empty_o

    // interface com a maquina de estado
    input logic run_state,
    input logic bit_tick_i, // TODO perguntar o que seria isso
    input logic send_fct_i,
    input logic send_eop_i,
    input logic send_eep_i,
    input logic send_null_i,
    output logic char_ack_o,

    // vem direto sem passar pela fifo
    input logic send_timecode_i,
    input logic [7:0] timecode_i

);
    logic send_data;
    logic busy;
    assign send_data = run_state & ~empty_fifo;
    assign rd_en_fifo = !busy; // TODO arrumar a lógica de leitura da fifo

    logic bit_valid;
    logic bit_signal;

    tx_signal dut_tx_signal (
        .clk(clk),
        .rst_n(rst_n),

        .bit_valid_i(bit_valid),
        .bit_i(bit_signal),   

        .d_o(d_o),
        .s_o(s_o)
    );

    tx_char dut_tx_char (
        .clk(clk),
        .rst_n(rst_n),

        .bit_tick_i(bit_tick_i),

        // Pedidos de envio (arbitrados por prioridade fixa)
        .send_data_i(send_data),
        .data_i(rd_data_fifo),
        .busy_o(busy),
        
        // interface com a maquina de estado
        .send_fct_i(send_fct_i),
        .send_eop_i(send_eop_i),
        .send_eep_i(send_eep_i),
        .send_null_i(send_null_i),
        .send_timecode_i(send_timecode_i),
        .timecode_i(timecode_i),

        .char_ack_o(char_ack_o),

        // Interface com tx_signal
        .bit_valid_o(bit_valid),
        .bit_o(bit_signal)
    );


endmodule
