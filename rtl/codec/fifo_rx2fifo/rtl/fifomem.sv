module fifomem #(
    parameter DATASIZE = 8, // Memory data word width
    parameter ADDRSIZE = 4  // Number of mem address bits
)(
    output [DATASIZE-1:0] rdata,
    input [DATASIZE-1:0] wdata,
    input [ADDRSIZE-1:0] waddr, raddr,
    input wclken, wfull, wclk
);

// TODO colocar a da synopsys
`ifdef VENDORRAM
        // instantiation of a vendor's dual-port RAM
        vendor_ram mem (.dout(rdata), .din(wdata),
        .waddr(waddr), .raddr(raddr),
        .wclken(wclken),
        .wclken_n(wfull), .clk(wclk));
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
