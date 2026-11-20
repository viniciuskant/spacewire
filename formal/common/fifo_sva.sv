module fifo_sva #(
    localparam ASIZE = 2,
    localparam DSIZE = 8
)
(
    input                  i_clk,
    input                  i_rstn,
    input                  i_wr,
    input                  i_rd,
    input      [DSIZE-1:0] i_wdata,
    input      [DSIZE-1:0] o_rdata,
    input                  o_empty,
    input                  o_full,
    input      [ASIZE:0]   o_count
);

default clocking cb @(posedge i_clk);
endclocking
default disable iff (!i_rstn);

c_empty: cover property (o_empty);
c_full: cover property (o_full);
a_empty_count: assert property (o_empty == (o_count == 0));
a_full_count: assert property (o_full == (o_count == 1 << ASIZE));
a_no_overflow: assert property (o_count <= 1 << ASIZE);

c_read_empty: cover property (i_rd && o_empty);
c_write_full: cover property (i_wr && o_full);
c_rw: cover property(i_rd && i_wr);

a_rw: assert property(!o_empty && !o_full |=> o_count == $past(o_count) - $past(i_rd) + $past(i_wr));
a_rw_empty: assert property(o_empty |=> o_count == $past(o_count) + $past(i_wr));
a_rw_full: assert property(o_full |=> o_count == $past(o_count) - $past(i_rd));

// first word fall-through
a_fwft: assert property (!o_empty && !i_rd |=> $stable(o_rdata));

endmodule

bind fifo_sva fifo #(.ASIZE(ASIZE), .DSIZE(DSIZE)) u_fifo (.*);