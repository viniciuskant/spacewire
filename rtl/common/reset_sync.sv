
// 2FF reset synchronizer. Asynchronous assert, synchronous release.
// It must have one instance per
// clock domain, excluding the RX clock.
module reset_sync (
    input logic i_clk,
    input logic i_rstn,
    output logic o_rstn
);
(* dont_touch *) logic r0;
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) {o_rstn, r0} <= 2'b00;
    else         {o_rstn, r0} <= {r0, 1'b1};
end
endmodule