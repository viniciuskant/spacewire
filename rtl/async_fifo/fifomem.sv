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

module fifomem #(
    parameter DATASIZE = 8, // Memory data word width
    parameter ADDRSIZE = 4  // Number of mem address bits
)(
    output [DATASIZE-1:0] rdata,
    input [DATASIZE-1:0] wdata,
    input [ADDRSIZE-1:0] waddr, raddr,
    input wclken, wfull, wclk,
    input rclken, rclk
);

`ifdef SAED90
    generate
        if (ADDRSIZE <= 4) begin : g_sram16x16
            logic [15:0] wdata_pad;
            logic [15:0] rdata_full;
            logic [3:0]  waddr_pad, raddr_pad;
            logic [15:0] unused_o1;

            assign wdata_pad = {{(16-DATASIZE){1'b0}}, wdata};
            assign waddr_pad = {{(4-ADDRSIZE){1'b0}}, waddr};
            assign raddr_pad = {{(4-ADDRSIZE){1'b0}}, raddr};
            assign rdata     = rdata_full[DATASIZE-1:0];

            SRAM16x16 mem (
                // Port 1: Write
                .CE1(wclk), 
                .A1(waddr_pad), 
                .CSB1(~(wclken & ~wfull)), 
                .WEB1(~(wclken & ~wfull)), 
                .I1(wdata_pad), 
                .O1(unused_o1),
                // Port 2: Read
                .CE2(rclk), 
                .A2(raddr_pad), 
                .CSB2(~rclken), 
                .WEB2(1'b1), 
                .I2(16'b0), 
                .O2(rdata_full)
            );
        end else if (ADDRSIZE <= 6) begin : g_sram16x64
            logic [15:0] wdata_pad;
            logic [15:0] rdata_full;
            logic [5:0]  waddr_pad, raddr_pad;
            logic [15:0] unused_o1;

            assign wdata_pad = {{(16-DATASIZE){1'b0}}, wdata};
            assign waddr_pad = {{(6-ADDRSIZE){1'b0}}, waddr};
            assign raddr_pad = {{(6-ADDRSIZE){1'b0}}, raddr};
            assign rdata     = rdata_full[DATASIZE-1:0];

            SRAM16x64 mem (
                // Port 1: Write
                .CE1(wclk), 
                .A1(waddr_pad), 
                .CSB1(~(wclken & ~wfull)), 
                .WEB1(~(wclken & ~wfull)), 
                .I1(wdata_pad), 
                .O1(unused_o1),
                // Port 2: Read
                .CE2(rclk), 
                .A2(raddr_pad), 
                .CSB2(~rclken), 
                .WEB2(1'b1), 
                .I2(16'b0), 
                .O2(rdata_full)
            );
        end
    endgenerate
`elsif SAED32
    generate
        if (ADDRSIZE <= 4) begin : g_sram16x16
            logic [15:0] wdata_pad;
            logic [15:0] rdata_full;
            logic [3:0]  waddr_pad, raddr_pad;
            logic [15:0] unused_o1;

            assign wdata_pad = {{(16-DATASIZE){1'b0}}, wdata};
            assign waddr_pad = {{(4-ADDRSIZE){1'b0}}, waddr};
            assign raddr_pad = {{(4-ADDRSIZE){1'b0}}, raddr};
            assign rdata     = rdata_full[DATASIZE-1:0];

            SRAM2RW16x16 mem (
                // Port 1: Write
                .CE1(wclk), 
                .A1(waddr_pad), 
                .CSB1(~(wclken & ~wfull)), 
                .WEB1(~(wclken & ~wfull)), 
                .OEB1(1'b1),
                .I1(wdata_pad), 
                .O1(unused_o1),
                // Port 2: Read
                .CE2(rclk), 
                .A2(raddr_pad), 
                .CSB2(~rclken), 
                .WEB2(1'b1),
                .OEB2(1'b0),
                .I2(16'b0), 
                .O2(rdata_full)
            );
            
        end else if (ADDRSIZE <= 6) begin : g_sram16x64
            logic [15:0] wdata_pad;
            logic [15:0] rdata_full;
            logic [5:0]  waddr_pad, raddr_pad;
            logic [15:0] unused_o1;

            assign wdata_pad = {{(16-DATASIZE){1'b0}}, wdata};
            assign waddr_pad = {{(6-ADDRSIZE){1'b0}}, waddr};
            assign raddr_pad = {{(6-ADDRSIZE){1'b0}}, raddr};
            assign rdata     = rdata_full[DATASIZE-1:0];

            SRAM2RW16x64 mem (
                // Port 1: Write
                .CE1(wclk), 
                .A1(waddr_pad), 
                .CSB1(~(wclken & ~wfull)), 
                .WEB1(~(wclken & ~wfull)), 
                .OEB1(1'b1),
                .I1(wdata_pad), 
                .O1(unused_o1),
                
                // Port 2: Read
                .CE2(rclk), 
                .A2(raddr_pad), 
                .CSB2(~rclken), 
                .WEB2(1'b1),
                .OEB2(1'b0),
                .I2(16'b0), 
                .O2(rdata_full)
            );
        end
    endgenerate
`else

    // RTL Verilog memory model
    localparam DEPTH = 1<<ADDRSIZE;
    logic [DATASIZE-1:0] mem [0:DEPTH-1];

    assign rdata = mem[raddr];
    always_ff @(posedge wclk) begin
        if (wclken && !wfull) 
            mem[waddr] <= wdata;
    end
`endif
endmodule