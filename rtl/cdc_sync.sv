module cdc_sync #(
    parameter int STAGES = 2
)(
    input  logic clk,
    input  logic d,
    output logic q
);

    logic [STAGES-1:0] sync_ff;

    always_ff @(posedge clk) begin
        sync_ff <= {sync_ff[STAGES-2:0], d};
    end

    assign q = sync_ff[STAGES-1];

endmodule

module cdc2ff (
    input  wire clk_dest,      // Destination clock
    input  wire rst_n,
    input  wire async_data,    // Asynchronous input
    output wire sync_data      // Synchronized output
);

    (* async_reg = "true" *) reg sync_ff1;
    (* async_reg = "true" *) reg sync_ff2;

    always @(posedge clk_dest or negedge rst_n) begin
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