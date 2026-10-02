module rx_fifo #(
    parameter int DEPTH      = 32,  // Tem que ser 2^(x>=3) mult de 8
    parameter int DATA_WIDTH = 9
) (
    input  logic wr_clk_i,
    input  logic rd_clk_i,
    input  logic rst_n,

    input  logic                  wr_en_i,
    input  logic [DATA_WIDTH-1:0] wr_data_i,
    output logic                  full_o,  // acho que é uma saída desnecessário

    input  logic                  rd_en_i,
    output logic [DATA_WIDTH-1:0] rd_data_o,
    output logic                  empty_o,

    output logic [$clog2(DEPTH+1)-1:0] free_space_o
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1; // 1 bit extra pra distinguir cheio/vazio

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    //binário -> Gray
    function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] b);
        bin2gray = b ^ (b >> 1);
    endfunction

    function automatic logic [PTR_WIDTH-1:0] gray2bin(input logic [PTR_WIDTH-1:0] g);
        logic [PTR_WIDTH-1:0] b;
        int i;
        begin
            b[PTR_WIDTH-1] = g[PTR_WIDTH-1];
            for (i = PTR_WIDTH-2; i >= 0; i--)
                b[i] = g[i] ^ b[i+1];
            gray2bin = b;
        end
    endfunction

    // Escrita
    logic [PTR_WIDTH-1:0] wr_ptr_bin, wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_wsync1, rd_ptr_gray_wsync2; // sincronizador 2-FF

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

    always_ff @(posedge wr_clk_i or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else begin
            if (wr_en_i && !full_o) begin
                mem[wr_addr] <= wr_data_i;
                wr_ptr_bin   <= wr_ptr_bin + 1'b1;
            end
            wr_ptr_gray <= bin2gray(wr_ptr_bin + (wr_en_i && !full_o));
        end
    end

    always_ff @(posedge wr_clk_i or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_gray_wsync1 <= '0;
            rd_ptr_gray_wsync2 <= '0;
        end else begin
            rd_ptr_gray_wsync1 <= rd_ptr_gray; // vem do dominio de leitura
            rd_ptr_gray_wsync2 <= rd_ptr_gray_wsync1;
        end
    end

    assign full_o = (wr_ptr_gray == {~rd_ptr_gray_wsync2[PTR_WIDTH-1:PTR_WIDTH-2],
                                       rd_ptr_gray_wsync2[PTR_WIDTH-3:0]});

    assign free_space_o = DEPTH - (wr_ptr_bin - gray2bin(rd_ptr_gray_wsync2));

    // Leitura
    logic [PTR_WIDTH-1:0] rd_ptr_bin, rd_ptr_gray;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_rsync1, wr_ptr_gray_rsync2; // sincronizador 2-FF

    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    assign rd_data_o = mem[rd_addr];

    always_ff @(posedge rd_clk_i or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else begin
            if (rd_en_i && !empty_o)
                rd_ptr_bin <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= bin2gray(rd_ptr_bin + (rd_en_i && !empty_o));
        end
    end

    always_ff @(posedge rd_clk_i or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_gray_rsync1 <= '0;
            wr_ptr_gray_rsync2 <= '0;
        end else begin
            wr_ptr_gray_rsync1 <= wr_ptr_gray; // vem do dominio de escrita
            wr_ptr_gray_rsync2 <= wr_ptr_gray_rsync1;
        end
    end

    assign empty_o = (rd_ptr_gray == wr_ptr_gray_rsync2);

endmodule
