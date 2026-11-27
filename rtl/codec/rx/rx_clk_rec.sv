// module to recover clock signal from S and D.
// TODO: properly constrain this module.
module rx_clk_rec (
    input i_D,
    input i_S,
    output o_rx_clk,
    output o_rx_clk_n
);
// TODO: change this to a PDK cell
// (* dont_touch *) xor xor0 (o_rx_clk, i_D, i_S);

(* dont_touch = "true" *) EO2JIX0 xor0 (
    .A (i_D),
    .B (i_S),
    .Q (o_rx_clk)
);
assign o_rx_clk = i_D ^ i_S;
endmodule
