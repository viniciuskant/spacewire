module packet_tx_if #(
    parameter int AXIS_TDATA_WIDTH    = 8, // 8: largura nativa do N-Char SpaceWire
    parameter int MAX_OUTSTANDING_FCT = 7  // Casar largura de credit_i com flow_control.credit_o
) (
    input  logic clk,
    input  logic rst_n,

    // Escrita dos pacotes para transmitir aqui
    input  logic [AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  logic                        s_axis_tvalid,
    output logic                        s_axis_tready,
    input  logic                        s_axis_tlast,
    input  logic                        s_axis_tuser,

    // tx_fifo: payload de 9 bits
    output logic       wr_en_o,
    output logic [8:0] wr_data_o,
    input  logic       tx_fifo_full_i,

    // flow_control: creditos de FCT disponiveis, em N-Chars (max MAX_OUTSTANDING_FCT*8)
    input  logic [$clog2(MAX_OUTSTANDING_FCT*8+1)-1:0] credit_i
);

    // Correção de bug do Icarus: nao indexar bit de
    // localparam dentro de logica combinacional no Icarus 12 -- aqui os
    // codigos ja sao usados por extenso.
    localparam logic [8:0] WORD_EOP = 9'h102;
    localparam logic [8:0] WORD_EEP = 9'h101;

    initial begin
        if (AXIS_TDATA_WIDTH != 8)
            $fatal(1, "packet_tx_if: AXIS_TDATA_WIDTH deve ser 8 (largura fixa do N-Char SpaceWire, casada com o payload de 9 bits de tx_fifo)");
    end

    logic eop_pending; // 1 = ultimo byte ja gravado, falta gravar o EOP/EEP
    logic eop_is_eep;  // tipo do marcador pendente

    wire has_credit = (credit_i != '0);
    wire beat_ok    = s_axis_tvalid && s_axis_tready;

    assign s_axis_tready = !eop_pending && !tx_fifo_full_i && has_credit;
    assign wr_en_o       = eop_pending ? !tx_fifo_full_i : beat_ok;
    assign wr_data_o     = eop_pending ? (eop_is_eep ? WORD_EEP : WORD_EOP)
                                       : {1'b0, s_axis_tdata};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eop_pending <= 1'b0;
            eop_is_eep  <= 1'b0;
        end else if (eop_pending) begin
            if (!tx_fifo_full_i)
                eop_pending <= 1'b0; // marcador gravado neste ciclo
        end else if (beat_ok && s_axis_tlast) begin
            eop_pending <= 1'b1;
            eop_is_eep  <= s_axis_tuser;
        end
    end

endmodule
