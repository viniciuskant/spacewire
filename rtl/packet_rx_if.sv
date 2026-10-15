module packet_rx_if #(
    parameter int AXIS_TDATA_WIDTH = 8 // Largura nativa do N-Char SpaceWire
) (
    input  logic clk,
    input  logic rst_n,

    // rx_fifo:Payload de 9 bits
    input  logic       rx_fifo_empty_i,
    input  logic [8:0] rd_data_i,
    output logic       rd_en_o,

    // Entrega dos pacotes recebidos aqui
    output logic [AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output logic                        m_axis_tvalid,
    input  logic                        m_axis_tready,
    output logic                        m_axis_tlast,
    output logic                        m_axis_tuser
);

    initial begin
        if (AXIS_TDATA_WIDTH != 8)
            $fatal(1, "packet_rx_if: AXIS_TDATA_WIDTH deve ser 8 (largura fixa do N-Char SpaceWire, casada com o payload de 9 bits de rx_fifo)");
    end

    logic       hold_valid;
    logic [7:0] hold_data;

    wire head_valid = !rx_fifo_empty_i;
    wire head_ctrl  = rd_data_i[8];
    wire head_eep   = rd_data_i[0];

    assign m_axis_tvalid = hold_valid && head_valid;
    assign m_axis_tdata  = hold_data;
    assign m_axis_tlast  = head_ctrl;
    assign m_axis_tuser  = head_ctrl && head_eep;

    // pop: descarta marcador de pacote vazio, ou
    // consome a palavra seguinte junto com o handshake do byte em hold
    assign rd_en_o = head_valid && (!hold_valid || m_axis_tready);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_valid <= 1'b0;
            hold_data  <= 8'h00;
        end else if (rd_en_o) begin
            if (head_ctrl) begin
                hold_valid <= 1'b0;           // pacote fechado ou vazio
            end else begin
                hold_valid <= 1'b1;
                hold_data  <= rd_data_i[7:0];
            end
        end
    end

endmodule
