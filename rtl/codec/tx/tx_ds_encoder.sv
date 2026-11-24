// Encodes `bit_i` into the Data-Strobe signal protocol.
// `bit_valid_i` is asserted to write `bit_i`.
module tx_ds_encoder (
    // TX high-speed clock
    input  logic i_tx_clk,
    input  logic i_tx_rstn,
    input logic i_tx_enable,

    // connected to the enable generator
    input logic i_bit_en,

    input logic i_data,   
    input logic i_valid,

    output o_D,
    output o_S
);

    logic D_reg;
    logic S_reg;

    always_ff @(posedge i_tx_clk or negedge i_tx_rstn) begin
        if (!i_tx_rstn) begin
            D_reg <= 1'b0;
            S_reg <= 1'b0;
        end else if (!i_tx_enable) begin
            D_reg <= 1'b0;
            S_reg <= 1'b0;
        end else if (i_bit_en && i_valid) begin
            D_reg <= i_data;
            if (i_data == D_reg)
                S_reg <= ~S_reg; 
        end
    end

    assign o_D = D_reg;
    assign o_S = S_reg;

endmodule
