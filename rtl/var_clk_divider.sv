module var_clk_divider (
    input logic clk,
    input logic rst_n,
    input logic [7:0] new_limit,
    output logic clk_out
);

    logic [7:0] counter;
    logic [7:0] current_limit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 8'd0;
            current_limit <= 8'd0;
            clk_out <= 1'b0;
        end else begin
            if (counter >= current_limit) begin
                counter <= 8'd0;
                clk_out <= ~clk_out;
                current_limit <= new_limit;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule
