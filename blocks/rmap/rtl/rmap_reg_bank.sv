module rmap_reg_bank (
    output logic [31:0] rdata,
    input logic [31:0] wdata,
    input logic [8:0] waddr,
    input logic [8:0] raddr,
    input logic wclken, 
    input logic wclk,
    input logic rclken,
    input logic rclk
);

`ifdef SAED90
    // TODO arrumar os paths depois para usar essa memoria
    SRAM512x32 mem (
        // Port 1: Write
        .CE1(wclk), 
        .A1(waddr), 
        .CSB1(~(wclken)), 
        .WEB1(~(wclken)), 
        .I1(wdata), 
        .O1(),
        
        // Port 2: Read
        .CE2(rclk), 
        .A2(raddr), 
        .CSB2(~rclken), 
        .WEB2(1'b1),
        .I2(32'b0), 
        .O2(rdata)
    );

`elsif SAED32
    SRAM2RW512x32 mem (
        // Port 1: Write
        .CE1(wclk), 
        .A1(waddr), 
        .CSB1(~(wclken)), 
        .WEB1(~(wclken)), 
        .OEB1(1'b1),
        .I1(wdata), 
        .O1(), 
        
        // Port 2: Read
        .CE2(rclk), 
        .A2(raddr), 
        .CSB2(~rclken), 
        .WEB2(1'b1),
        .OEB2(1'b0),
        .I2(32'b0), 
        .O2(rdata)
    );

`else
    logic [31:0] mem [0:511];

    assign rdata = mem[raddr];

    always_ff @(posedge wclk) begin
        if (wclken) 
            mem[waddr] <= wdata;
    end
`endif

endmodule