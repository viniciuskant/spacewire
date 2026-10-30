// Synchronous FIFO with clockless read (first-word fall-through)
module fifo #(parameter ASIZE = 2, DSIZE = 16) (
  input                  i_clk,
  input                  i_rstn,
  input                  i_wr,
  input                  i_rd,
  input      [DSIZE-1:0] i_wdata,
  output     [DSIZE-1:0] o_rdata,
  output                 o_empty,
  output                 o_full
);

localparam int FIFO_SIZE = 1 << ASIZE;

reg [DSIZE-1:0] mem [0:FIFO_SIZE];
reg [ASIZE:0]       wptr, rptr;        // One extra bit to count laps

wire empty = (wptr == rptr);
wire full = (wptr[ASIZE] != rptr[ASIZE]) && (wptr[ASIZE-1:0] == rptr[ASIZE-1:0]);

always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin 
        wptr <= 0;
        rptr <= 0;
    end else begin
        if (i_wr && !full) begin
            mem[wptr[ASIZE-1:0]] <= i_wdata;
            wptr <= wptr + 1'b1;
        end
        if (i_rd && !empty) begin
            rptr <= rptr + 1'b1;
        end
    end
end

assign o_full = full;
assign o_empty = empty;
assign o_rdata = mem[rptr[ASIZE-1:0]];

endmodule
