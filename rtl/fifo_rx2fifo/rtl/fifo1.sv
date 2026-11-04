// https://www.researchgate.net/publication/252160343_Simulation_and_Synthesis_Techniques_for_Asynchronous_FIFO_Design/link/54bfe9ee0cf28eae4a66421c/download?_tp=eyJjb250ZXh0Ijp7ImZpcnN0UGFnZSI6InB1YmxpY2F0aW9uIiwicGFnZSI6InB1YmxpY2F0aW9uIn19

module fifo1 #(
    parameter DSIZE = 10,
    parameter ASIZE = 4
)(  
    output [DSIZE-1:0] rdata,
    output wfull,
    output rempty,

    input [DSIZE-1:0] wdata,
    input winc, wclk, wrst_n,
    input rinc, rclk, rrst_n
);
    logic [ASIZE-1:0] waddr, raddr;
    logic [ASIZE:0] wptr, rptr, wq2_rptr, rq2_wptr;

    // cdc
    sync_r2w sync_r2w (.wq2_rptr(wq2_rptr), .rptr(rptr), .wclk(wclk), .wrst_n(wrst_n));
    sync_w2r sync_w2r (.rq2_wptr(rq2_wptr), .wptr(wptr), .rclk(rclk), .rrst_n(rrst_n));

    fifomem #(DSIZE, ASIZE) fifomem (
        .rdata(rdata),
        .wdata(wdata),
        .waddr(waddr), 
        .raddr(raddr),
        .wclken(winc),
        .wfull(wfull),
        .wclk(wclk)
    );

    rptr_empty #(ASIZE) rptr_empty(
        .rempty(rempty),
        .raddr(raddr),
        .rptr(rptr), 
        .rq2_wptr(rq2_wptr),
        .rinc(rinc), 
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    wptr_full #(ASIZE) wptr_full(
        .wfull(wfull), 
        .waddr(waddr),
        .wptr(wptr), 
        .wq2_rptr(wq2_rptr),
        .winc(winc), 
        .wclk(wclk),
        .wrst_n(wrst_n)
    );
endmodule
