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

module sync_w2r #(parameter ADDRSIZE = 4
)(
    output reg [ADDRSIZE:0] rq2_wptr,
    input [ADDRSIZE:0] wptr,
    input rclk, rrst_n
);

    logic [ADDRSIZE:0] rq1_wptr;
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) 
            {rq2_wptr,rq1_wptr} <= 0;
        else
            {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
    end
endmodule
