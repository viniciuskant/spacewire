module codec #(
    parameter int DEPTH_FIFO = 2048,
    parameter int DATA_WIDTH_FIFO = 9,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
)(
    input clk,
    input rst_n,

    input S_in,
    input D_in,
    output S_out,
    output D_out,

    //matrix de roteamento
    input [8:0] SpW_Packet_TX, 
    input SpW_Packet_TX_en,
    output [8:0] SpW_Packet_RX,
    input SpW_Packet_RX_en,
    output empty_rx_fifo,

    // timecode
    input [7:0] Time_Code_TX,
    input Time_Code_TX_valid,
    output [7:0] Time_Code_RX,
    output Time_Code_RX_valid
);


    logic [8:0] wr_data_fifo_rx; // TODO verificar a largura de bits
    logic wr_en_fifo_rx;
    logic [8:0] wr_data_fifo_tx; // TODO verificar a largura de bits
    logic wr_en_fifo_tx;
    logic full_fifo_tx;
    logic empty_tx_fifo;

    rx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) dut_rx_fifo (
        .wr_clk_i(clk), //TODO por hora estão iguais, mas tem que ser mudados
        .rd_clk_i(clk), //TODO por hora estão iguais, mas tem que ser mudados
        .rst_n(rst_n),

        .wr_data_i(wr_data_fifo_rx),
        .wr_en_i(wr_en_fifo_rx),

        // saída do módulo
        .rd_en_i(SpW_Packet_RX_en),
        .rd_data_o(SpW_Packet_RX),
        .empty_o(empty_rx_fifo),
        .free_space_o(free_slots_fifo_rx)
    );

    tx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) dut_tx_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .wr_data_i(SpW_Packet_TX),
        .wr_en_i(SpW_Packet_TX_en),
        .full_o(full_fifo_tx),

        .rd_data_o(wr_data_fifo_tx),
        .rd_en_i(wr_en_fifo_tx),
        .empty_o(empty_tx_fifo)
    );

    logic run_state;
    logic en_out_fifo_tx;
    logic got_fct;
    logic sending_allowed;
    logic send_fct, send_fct_fc, send_fct_sm;
    assign send_fct = send_fct_fc | send_fct_sm;

    logic [$clog2(DEPTH_FIFO)-1:0] free_slots_fifo_rx;

    flow_control #(.DEPTH_FIFO(DEPTH_FIFO)) dut_fc(
        .clk(clk),
        .rst_n(rst_n),
        .run_state(run_state),
        .en_out_fifo_tx(en_out_fifo_tx),
        .got_FCT_rx(got_fct),
        .sending_allowed(sending_allowed),
        .en_in_fifo_rx(wr_en_fifo_rx),
        .free_slots_fifo_rx(free_slots_fifo_rx),
        .send_FCT(send_fct_fc)
    );

    logic got_bit;
    logic got_null;
    logic got_TimeCode;
    logic got_nchar;
    logic got_Cred;
    logic rx_Error;
    logic got_eop;
    logic got_eep;
    logic parity_err;
    logic escape_err;

    assign rx_Error = escape_err | parity_err; // TODO arrumar isso depois

    logic en_rx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic en_tx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic rst_n_rx;
    logic rst_n_tx;
    logic send_null, send_eep, send_eop;
    logic link_disabled;
    logic start_link = 1; // TODO verificar o que seria essa start_link, mas creio
                      // que seja um sinal externo para controle de quandoa ativar o rx

    state_machine #(.CLK_FREQ(CLK_FREQ))dut_sm(
        .clk(clk),
        .rst_n(rst_n),

        // RX
        .en_rx(en_rx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_rx(rst_n_rx),
        .got_bit(got_bit),
        .got_FCT(got_fct),
        .got_null(got_null),
        .got_TimeCode(got_TimeCode),
        .got_N_Char(got_nchar),
        .got_Cred(got_Cred),
        .rx_Error(rx_Error),

        // TX
        .en_tx(en_tx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_tx(rst_n_tx),
        .send_FCT(send_fct_sm),
        .send_Null(send_null),
        .send_EOP(send_eop),
        .send_EEP(send_eep),

        // FSM
        .link_disabled(link_disabled),
        .start_link(start_link),
        .run_state(run_state)
    );

    rx #(
        .SYS_CLK_FREQ_HZ(SYS_CLK_FREQ_HZ),
        .DISCONNECT_TIMEOUT_NS(DISCONNECT_TIMEOUT_NS)
    ) dut_rx (
        .clk(clk),
        .rst_n(rst_n_rx),

        // interface com outro codec
        .d_i(D_in),
        .s_i(S_in),

        // interface com a fifo
        .rx_data(wr_data_fifo_rx),
        .rx_en(wr_en_fifo_rx),

        // para a maquina de estado
        .got_null_o(got_null),
        .got_fct_o(got_fct),
        .got_nchar_o(got_nchar),
        .got_eop_o(got_eop),
        .got_eep_o(got_eep),
        .got_timecode_o(Time_Code_RX_valid),
        .parity_err_o(parity_err),
        .escape_err_o(escape_err),
        .disconnect_o(link_disabled),

        // sai direto sem passar pela fifo
        .timecode_o(Time_Code_RX)
    );

    logic bit_tick; //TODO falta conectar
    logic char_ack_o; //TODO falta conectar

    tx dut_tx(
        .clk(clk),
        .rst_n(rst_n_tx),

        // interface com outro codec
        .d_o(D_out),
        .s_o(S_out),

        // interface com a fifo
        .rd_en_fifo(wr_en_fifo_tx),
        .rd_data_fifo(wr_data_fifo_tx), 
        .empty_fifo(empty_tx_fifo),

        // interface com a maquina de estado
        .run_state(run_state),
        .bit_tick_i(1), // TODO perguntar o que seria isso
        .send_fct_i(send_fct),
        .send_eop_i(send_eop),
        .send_eep_i(send_eep),
        .send_null_i(send_null),
        .char_ack_o(char_ack_o), // TODO perguntar o que seria isso

        // vem direto sem passar pela fifo
        .send_timecode_i(Time_Code_TX_valid),
        .timecode_i(Time_Code_TX)

    );

endmodule
