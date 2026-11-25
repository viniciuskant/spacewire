// module to recover clock signal from S and D.
// TODO: properly constrain this module.
module rx_clk_rec (
    input i_D,
    input i_S,
    output o_rx_clk,
    output o_rx_clk_n
);

// cells from IHP130
EO2JIX1 u_xor (
    .A (i_D),
    .B (i_S),
    .Q (o_rx_clk)
);
INVJIX1 u_inv (.A(o_rx_clk), .Q(o_rx_clk_n));
endmodule
