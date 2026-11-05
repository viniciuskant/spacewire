// 2-FF synchronizer

// Outputs the number of events in the write clock between
// two samples of the read clock. The parameter WIDTH must
// be wide enough to accommodate the maximum number of events
// that can happen between two read cycles.
module sync_gray_counter #(parameter WIDTH=2)
(
    // write clock, reset and inputs
    input i_w_clk,
    input i_w_rstn,
    input i_inc,
    // read clock
    input i_r_clk,
    input i_r_rstn,
    // difference of events between two read clocks
    output [WIDTH-1:0] o_delta
);
    logic [WIDTH-1:0] bin;
    logic [WIDTH-1:0] gray;

    logic [WIDTH-1:0] read_bin_prev;
    logic [WIDTH-1:0] read_bin_curr;

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
            read_bin_prev <= 0;
        end else begin
            gray_ff1 <= gray;
            gray_ff2 <= gray_ff1;
            read_bin_prev <= read_bin_curr;
        end
    end

    always_comb begin
        read_bin_curr[WIDTH-1] = gray_ff2[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; --i) begin
            read_bin_curr[i] = read_bin_curr[i+1] ^ gray_ff2[i];
        end
    end

    assign o_delta = read_bin_curr - read_bin_prev;
endmodule
