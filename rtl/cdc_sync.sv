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
