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

module rptr_empty #(parameter ADDRSIZE = 4
)(
    output logic rempty, 
    output [ADDRSIZE-1:0] raddr,
    output logic [ADDRSIZE :0] rptr,
    input [ADDRSIZE :0] rq2_wptr,
    input rinc, rclk, rrst_n
);
    logic [ADDRSIZE:0] rbin;
    logic [ADDRSIZE:0] rgraynext, rbinnext;
    
    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) 
            {rbin, rptr} <= 0;
        else
            {rbin, rptr} <= {rbinnext, rgraynext};
    end

    // Memory read-address pointer (okay to use binary to address memory)
    assign raddr = rbin[ADDRSIZE-1:0];
    assign rbinnext = rbin + (rinc & ~rempty);
    assign rgraynext = (rbinnext>>1) ^ rbinnext;

    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    logic rempty_val;
    assign rempty_val = (rgraynext == rq2_wptr);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) 
            rempty <= 1'b1;
        else
            rempty <= rempty_val;
    end
endmodule
