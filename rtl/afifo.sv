// DSIZE is the data width, ASIZE is the address width,
// so the FIFO depth is 2^ASIZE.
module afifo #(parameter DSIZE = 2, ASIZE = 4)
(
    input i_wclk,
    input i_wrst_n,
    input i_wr,
    input [DSIZE-1:0] i_wdata,
    input i_rclk,
    input i_rrst_n,
    input i_rd,
    output [DSIZE-1:0] o_rdata,
    output reg o_rempty,
    output reg o_wfull
);

localparam MEMSIZE = 1 << ASIZE;
wire [ASIZE-1:0] waddr, raddr;
wire wfull_next, rempty_next;

reg [ASIZE:0] wgray, wbin, wq2_rgray, wq1_rgray,
             rgray, rbin, rq2_wgray, rq1_wgray;

wire [ASIZE:0] wgraynext, wbinnext;
wire [ASIZE:0] rgraynext, rbinnext;

reg [DSIZE-1:0] mem [0:MEMSIZE-1];

// cross the read gray pointer into the write clock domain
always @(posedge i_wclk or negedge i_wrst_n) begin
    if (!i_wrst_n) begin
        wq1_rgray <= 0;
        wq2_rgray <= 0;
    end else begin
        // 2-FF synchronizer
        wq1_rgray <= rgray;
        wq2_rgray <= wq1_rgray;
    end
end

// advance when requesting write and not full
assign wbinnext = wbin + { {ASIZE{1'b0}}, ((i_wr) && (!o_wfull))};
// GRAY COUNTER = (counter >>) 1 ^ counter
assign wgraynext = (wbinnext >> 1) ^ wbinnext;
// the address discards the MSB, which is for detecting a full FIFO only
assign waddr = wbin[ASIZE-1:0];

// register these two values -- the address and the gray code
// representation
always @(posedge i_wclk or negedge i_wrst_n) begin
    if (!i_wrst_n) begin
        wbin <= 0;
        wgray <= 0;
    end else begin
        wbin <= wbinnext;
        wgray <= wgraynext;
    end
end

// full check in gray code:
// the full check in normal coding is if both counters are the same except
// for the MSB. Converting to gray code, this condition translates to the
// two MSBs being different, while the rest is the same.
assign wfull_next = (wgraynext == {~wq2_rgray[ASIZE:ASIZE-1], wq2_rgray[ASIZE-2:0]});

// calculate whether or not the register will be full on the next clock
always @(posedge i_wclk or negedge i_wrst_n) begin
    if (!i_wrst_n) o_wfull <= 0;
    else o_wfull <= wfull_next;
end

// write the FIFO on the write clock
always @(posedge i_wclk) begin
    if (i_wr && (!o_wfull)) begin
        mem[waddr] <= i_wdata;
    end
end

// CDC
// cross the write gray pointer into the read clock domain
always @(posedge i_rclk or negedge i_rrst_n) begin
    if (!i_rrst_n) begin
        rq1_wgray <= 0;
        rq2_wgray <= 0;
    end else begin
        rq1_wgray <= wgray;
        rq2_wgray <= rq1_wgray;
    end
end

// calculate the next read address
assign rbinnext = rbin + {{ASIZE{1'b0}}, (i_rd && !o_rempty)};
assign rgraynext = (rbinnext >> 1) ^ rbinnext;


// register these two values - the read address and the gray code
// version of it in the next clock
always @(posedge i_rclk or negedge i_rrst_n) begin
    if (!i_rrst_n) begin
        rbin <= 0;
        rgray <= 0;
    end else begin
        rbin <= rbinnext;
        rgray <= rgraynext;
    end
end

assign raddr = rbin[ASIZE-1:0];

// determine if we'll be empty in the next clock,
// using the synchronized write gray pointer
assign rempty_next = (rgraynext == rq2_wgray);

always @(posedge i_rclk or negedge i_rrst_n) begin
    if (!i_rrst_n) begin
        o_rempty <= 1'b1;
    end else begin
        o_rempty <= rempty_next;
    end
end

// read from the memory - a clockless read
assign o_rdata = mem[raddr];

endmodule
