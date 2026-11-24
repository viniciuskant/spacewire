// Captures the SpaceWire D signal using the recovered clock (D xor S).
// One bit arrives per rx_clk edge: odd bits on rising edges, even bits on
// falling edges (after reset D = S = 0, so the first bit is on a rising edge).
// Bits are delivered as pairs on the rising edge.
//
// pair[0] = earlier bit, pair[1] = later bit (transmission order).
//
// Timing note: d_in must reach the capture flops before the rx_clk edge it
// generates (the D path must be shorter than the XOR + clock-tree path).
// Keep d_in -> d_pos/d_neg free of logic and place these flops near the pads.
module rx_ds_capture (
    input  logic       i_rx_clk,      // from rx_clk_rec
    input  logic       i_rx_rstn,    // functional RX reset (async assert and release)
    input  logic       i_D,        // D line, straight from the input pad
    output logic [1:0] o_pair,
    output logic       o_pair_valid
);
    logic d_pos;    // bit captured on the rising edge (earlier bit of a pair)
    logic d_neg;    // bit captured on the falling edge (later bit of a pair)
    logic primed;   // first rising-edge bit has been captured

    always_ff @(negedge i_rx_clk or negedge i_rx_rstn)
        if (!i_rx_rstn) d_neg <= 1'b0;
        else            d_neg <= i_D;

    always_ff @(posedge i_rx_clk or negedge i_rx_rstn)
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