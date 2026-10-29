// Encodes `bit_i` into the Data-Strobe signal protocol.
// `bit_valid_i` is asserted to write `bit_i`.
module tx_ds_encoder (
    // TX high-speed clock
    input  logic clk,
    input  logic rst_n,

    // connected to the enable generator
    input logic bit_en,

    input  logic bit_i,   

    output logic D_out,
    output logic S_out
);

    logic D_reg;
    logic S_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            D_reg <= 1'b0;
            S_reg <= 1'b0;
        end else if (bit_en) begin
            if (bit_i == D_reg)
                S_reg <= ~S_reg; 
            D_reg <= bit_i;
        end
    end

    assign D_out = D_reg;
    assign S_out = S_reg;

endmodule
