module tx_fifo #(
    parameter int DEPTH      = 32,  // deve ser potencia de 2 (TX_FIFO_DEPTH)
    parameter int DATA_WIDTH = 9
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                  wr_en_i,
    input  logic [DATA_WIDTH-1:0] wr_data_i,
    output logic                  full_o,

    input  logic                  rd_en_i,
    output logic [DATA_WIDTH-1:0] rd_data_o,
    output logic                  empty_o,

    output logic [$clog2(DEPTH+1)-1:0] free_space_o
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr; // 1 bit extra pra distinguir cheio/vazio

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign full_o  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                      (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign empty_o = (wr_ptr == rd_ptr);

    assign free_space_o = DEPTH - (wr_ptr - rd_ptr);

    assign rd_data_o = mem[rd_addr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en_i && !full_o) begin
            mem[wr_addr] <= wr_data_i;
            wr_ptr       <= wr_ptr + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en_i && !empty_o) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

endmodule
