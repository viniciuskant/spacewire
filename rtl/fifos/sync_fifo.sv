module sync_fifo #(
    parameter int DSIZE = 9,
    parameter int ASIZE = 5
) (
    input logic clk,
    input logic rst_n,

    input logic winc,
    input logic [DSIZE-1:0] wdata,

    input logic rinc,
    output logic [DSIZE-1:0] rdata,
    output logic rempty,
    output logic [ASIZE:0] free_space_o
);

    localparam int DEPTH = 1 << ASIZE;
    localparam int PTR_WIDTH = ASIZE + 1;

    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic empty;

    wire [ASIZE:0] wr_addr = wr_ptr[ASIZE:0];
    wire [ASIZE:0] rd_addr = rd_ptr[ASIZE:0];

    fifomem #(.DSIZE(DSIZE), .ASIZE(ASIZE)) fifomem (
        .rdata (rdata),
        .wdata (wdata),
        .waddr (wr_addr),
        .raddr (rd_addr),
        .wclken (winc),
        .wfull (),
        .wclk (clk)
    );

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1] != rd_ptr[PTR_WIDTH-1]) &&
                   (wr_ptr[ASIZE-1:0]  == rd_ptr[ASIZE-1:0]);

    assign rempty = empty;
    assign free_space_o = DEPTH - (wr_ptr - rd_ptr);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (winc && !full)
            wr_ptr <= wr_ptr + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rinc && !empty)
            rd_ptr <= rd_ptr + 1'b1;
    end

endmodule