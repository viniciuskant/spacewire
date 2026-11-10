//=============================================================================
// Asynchronous FIFO (Clock Domain Crossing) implementation based on:
//
// Verilog, Expert & Cummings, Clifford. (2002). 
// Simulation and Synthesis Techniques for Asynchronous FIFO Design. 
//
// Available at: https://www.researchgate.net/publication/252160343_Simulation_and_Synthesis_Techniques_for_Asynchronous_FIFO_Design/link/54bfe9ee0cf28eae4a66421c/download?_tp=eyJjb250ZXh0Ijp7ImZpcnN0UGFnZSI6InB1YmxpY2F0aW9uIiwicGFnZSI6InB1YmxpY2F0aW9uIn19
//
// The technique uses Gray-coded pointers and 2-flip-flop synchronizers for
// safe data/pointer transfer between clock domains.
//=============================================================================

module wptr_full #(parameter ADDRSIZE = 4
)(
    output logic wfull, output[ADDRSIZE-1:0] waddr,
    output logic [ADDRSIZE :0] wptr,
    input [ADDRSIZE :0] wq2_rptr,
    input winc, wclk, wrst_n
);
    logic [ADDRSIZE:0] wbin;
    logic [ADDRSIZE:0] wgraynext, wbinnext;
    // GRAYSTYLE2 pointer
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            {wbin, wptr} <= 0;
        else
            {wbin, wptr} <= {wbinnext, wgraynext};
    end

    // Memory write-address pointer (okay to use binary to address memory)
    assign waddr = wbin[ADDRSIZE-1:0];
    assign wbinnext = wbin + (winc & ~wfull);
    assign wgraynext = (wbinnext>>1) ^ wbinnext;

    //------------------------------------------------------------------
    // Simplified version of the three necessary full-tests:
    // assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
    // (wgnext[ADDRSIZE-1] !=wq2_rptr[ADDRSIZE-1]) &&
    // (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
    //------------------------------------------------------------------

    logic wfull_val;
    assign wfull_val = (wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) 
            wfull <= 1'b0;
        else
            wfull <= wfull_val;
    end
endmodule
