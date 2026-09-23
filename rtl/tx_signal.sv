module tx_signal (
    input  logic clk,
    input  logic rst_n,

    input  logic bit_valid_i,
    input  logic bit_i,   

    output logic d_o,
    output logic s_o
);

    logic d_reg;
    logic s_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_reg <= 1'b0;
            s_reg <= 1'b0;
        end else if (bit_valid_i) begin
            if (bit_i == d_reg)
                s_reg <= ~s_reg; 
            d_reg <= bit_i;
        end
    end

    assign d_o = d_reg;
    assign s_o = s_reg;

endmodule
