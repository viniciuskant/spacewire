module codec #(
    parameter int DEPTH_FIFO = 2048,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
)(
    input clk,
    input rst_n,

    input S_in,
    input D_in,
    input S_out,
    input D_out,

    // TODO sinais que se comunicam com a fifo, que no final estarão na matrix de roteamento
    input [8:0] SpW_Packet_TX, 
    input SpW_Packet_TX_valid,

    output [8:0] SpW_Packet_RX,
    output SpW_Packet_RX_valid,

    // TIME CODE
    // TODO acho que também vão para a matrix de roteamento, mas por hora deixamos apenas a interface
    input [7:0] Time_Code_TX,
    input Time_Code_TX_valid,

    output [7:0] Time_Code_RX,
    output Time_Code_RX_valid
);

    // TODO colocar as fifos e usar os sinais anteriores

    logic run_state;
    logic en_out_fifo_tx;
    logic got_FCT;
    logic sending_allowed;
    logic send_FCT;

    logic [$clog2(DEPTH_FIFO_RX)-1:0] free_slots_fifo_rx;

    flow_control #(.DEPTH_FIFO(DEPTH_FIFO)) dut_fc(
        .clk(clk),
        .rst_n(rst_n),
        .run_state(run_state),
        .en_out_fifo_tx(en_out_fifo_tx),
        .got_FCT_rx(got_FCT),
        .sending_allowed(sending_allowed),
        .en_in_fifo_rx(en_in_fifo_rx),
        .free_slots_fifo_rx(free_slots_fifo_rx),
        .send_FCT(send_FCT)
    );

    logic got_bit;
    logic got_null;
    logic got_TimeCode;
    logic got_N_Char;
    logic got_Cred;
    logic rx_Error;

    logic en_tx;
    logic rst_n_tx;
    logic send_FCT;
    logic send_Null;
    logic send_NChar;

    state_machine #(.CLK_FREQ(CLK_FREQ))dut_sm(
        .clk(clk),
        .rst_n(rst_n),

        // RX
        .en_rx(en_rx),
        .rst_n_rx(rst_n_rx),
        .got_bit(got_bit),
        .got_FCT(got_FCT),
        .got_null(got_null),
        .got_TimeCode(got_TimeCode),
        .got_N_Char(got_N_Char),
        .got_Cred(got_Cred),
        .rx_Error(rx_Error),

        // TX
        .en_tx(en_tx),
        .rst_n_tx(rst_n_tx),
        .send_FCT(send_FCT),
        .send_Null(send_Null),
        .send_NChar(send_NChar),

        // FSM
        .link_disabled(link_disabled),
        .start_link(start_link),
        .run_state(run_state)
    );


    // TODO colocar rx e tx

endmodule