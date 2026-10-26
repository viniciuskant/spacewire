// This module is the enable generator for the TX,
// Since the TX frequency is variable (2MHz-200MHz).
// the `clk_div` specifies the frequency divisor.
// the output enable frequency is calculated as: 200MHz / (clk_div+1).
// Some values:
// clk_div = 0 => full frequency (200Mhz)
// clk_div = 1 => 1/2 frequency (100Mhz)
// clk_div = 2 => 1/3 frequency (66.66Mhz)
// clk_div = 3 => 1/4 frequency (50Mhz)
// clk_div = 4 => 1/5 frequency (40Mhz)
module tx_enable_gen (
    input logic clk,
    input logic rst_n,
    input logic [7:0] clk_div,
    output logic en_out
);
logic [7:0] counter;
logic en;
assign en_out = en;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 8'b0;
        en <= 0;
    end else begin
        if (counter == clk_div) begin
            en <= 1;
            counter <= 8'b0;
        end else begin
            en <= 0;
            counter <= counter + 1;
        end
    end

end
endmodule