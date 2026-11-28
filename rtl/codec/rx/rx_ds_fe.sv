// RX DS front-end. Contains the clock recovery logic
// and the capture flops. 

module rx_ds_fe (
    input i_D,
    input i_S,
    input i_rx_rstn,
    output o_rx_clk,
    output logic [1:0] o_pair,
    output logic o_pair_valid
);

wire ds_xor;
// cells from IHP130
EO2JIX1 u_xor (
    .A (i_D),
    .B (i_S),
    .Q (ds_xor)
);

BUFJIX4 u_buf (
    .A(ds_xor),
    .Q (o_rx_clk)
);

logic d_pos;    // bit captured on the rising edge (earlier bit of a pair)
logic d_neg;    // bit captured on the falling edge (later bit of a pair)
logic primed;   // first rising-edge bit has been captured

always_ff @(negedge o_rx_clk or negedge i_rx_rstn)
    if (!i_rx_rstn) d_neg <= 1'b0;
    else            d_neg <= i_D;

always_ff @(posedge o_rx_clk or negedge i_rx_rstn)
    if (!i_rx_rstn) begin
        d_pos      <= 1'b0;
        primed     <= 1'b0;
        o_pair       <= '0;
        o_pair_valid <= 1'b0;
    end else begin
        d_pos      <= i_D;
        primed     <= 1'b1;
        o_pair       <= {d_neg, d_pos};   // {later, earlier}
        o_pair_valid <= primed;
    end

endmodule