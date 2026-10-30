
// 2-FF synchronizer
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

module sync_gray_ctr #(parameter WIDTH=2)
(
    // write clock, reset and inputs
    input i_w_clk,
    input i_w_rstn,
    input i_inc,
    // read clock
    input i_r_clk,
    input i_r_rstn,
    // gray value synchronized to read clock
    output [WIDTH-1:0] o_rgray
);
    logic [WIDTH-1:0] bin;
    logic [WIDTH-1:0] gray;
    (* async_reg = "true" *) logic [WIDTH-1:0] gray_ff1;
    (* async_reg = "true" *) logic [WIDTH-1:0] gray_ff2;

    wire [WIDTH-1:0] nextbin = bin + i_inc;
    wire [WIDTH-1:0] nextgray = nextbin ^ (nextbin >> 1);
    always_ff @(posedge i_w_clk or negedge i_w_rstn) begin
        if (!i_w_rstn) begin 
            bin <= 0;
            gray <= 0;
        end else begin
            bin <= nextbin;
            gray <= nextgray;
        end
    end

    always_ff @(posedge i_r_clk or negedge i_r_rstn) begin
        if (!i_r_rstn) begin 
            gray_ff1 <= 0;
            gray_ff2 <= 0;
        end else begin
            gray_ff1 <= gray;
            gray_ff2 <= gray_ff1;
        end
    end
    assign o_rgray = gray_ff2;

    `ifdef FORMAL
    a

    `endif

endmodule
