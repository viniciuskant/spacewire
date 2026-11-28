
// 2FF reset synchronizer. Asynchronous assert, synchronous release.
// It must have one instance per clock domain, excluding the RX clock.
module reset_sync (
    input logic i_clk,
    input logic i_rstn,
    output o_rstn
);
logic sync_ff1, sync_ff2;

always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) {sync_ff2, sync_ff1} <= 2'b00;
    else         {sync_ff2, sync_ff1} <= {sync_ff1, 1'b1};
end
assign o_rstn = sync_ff2;
endmodule