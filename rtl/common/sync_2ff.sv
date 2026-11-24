
// 2FF synchronizer
module sync_2ff (
    input  clk_dest,      // Destination clock
    input  rst_n,
    input  async_data,    // Asynchronous input
    output sync_data      // Synchronized output
);

    (* async_reg = "true" *) logic sync_ff1;
    (* async_reg = "true" *) logic sync_ff2;

    always_ff @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= async_data;   // May go metastable
            sync_ff2 <= sync_ff1;     // Very unlikely to be metastable
        end
    end

    assign sync_data = sync_ff2;
endmodule