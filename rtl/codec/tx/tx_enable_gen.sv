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
    // "Enable TX" signal from the FSM
    input logic tx_enable,
    input logic [6:0] clk_div,
    // if low, the `clk_div` gets overwritten with the 10MHz rate
    input logic use_run_rate,
    // generated `enable`
    output logic bit_en
);
// 200MHz / (19 + 1) = 10MHz
localparam [6:0] START_DIV = 19;
logic [6:0] counter;
wire [6:0] div = use_run_rate ? clk_div : START_DIV;

wire [6:0] next_counter = (counter == 0) ? div : counter - 1;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= START_DIV;
        bit_en <= 0;
    end else if (!tx_enable) begin
        counter <= START_DIV;
        bit_en <= 0;
    end else begin
        counter <= next_counter;
        bit_en <= next_counter == 0;
    end
end
endmodule
