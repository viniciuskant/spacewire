module flow_control #(
    parameter int DEPTH_FIFO = 2048
)(
    input logic clk,
    input logic rst_n,

    input logic run_state,

    input logic en_out_fifo_tx,
    input logic got_FCT_rx,
    output logic sending_allowed,

    input logic en_in_fifo_rx,
    input logic [$clog2(DEPTH_FIFO_RX)-1:0] free_slots_fifo_rx,
    output logic send_FCT
);

    flow_control_tx u_tx (
        .clk             (clk),
        .rst_n           (rst_n),
        .run_state       (run_state),
        .en_out_fifo_tx  (en_out_fifo_tx),
        .got_FCT_rx      (got_FCT_rx),
        .sending_allowed (sending_allowed)
    );

    flow_control_rx #(
        .DEPTH_FIFO (DEPTH_FIFO)
    ) u_rx (
        .clk             (clk),
        .rst_n           (rst_n),
        .run_state       (run_state),
        .en_in_fifo_rx   (en_in_fifo_rx),
        .free_slots_fifo (free_slots_fifo_rx),
        .send_FCT        (send_FCT)
    );

endmodule