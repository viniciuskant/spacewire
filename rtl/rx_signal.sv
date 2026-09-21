module rx_signal #(
    parameter int SYS_CLK_FREQ_HZ      = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
) (
    input  logic clk,
    input  logic rst_n,

    // Linhas D/S ja sincronizadas (Ver como sincronizar clock na chegada dps)
    input  logic d_i,
    input  logic s_i,

    output logic bit_valid_o,
    output logic bit_o,
    output logic disconnect_o
);

    // multiplicacao em longint(64b): (850 ns * 50 MHz = 42.5e9)
    localparam int unsigned DISCONNECT_TIMEOUT_CYCLES =
        int'((longint'(DISCONNECT_TIMEOUT_NS) * longint'(SYS_CLK_FREQ_HZ)) / 1_000_000_000);

    localparam int CNT_WIDTH = $clog2(DISCONNECT_TIMEOUT_CYCLES + 1);

    logic                  xor_prev;
    logic                  first_bit_seen; 
    logic [CNT_WIDTH-1:0]  disconnect_cnt;

    wire xor_now        = d_i ^ s_i;
    wire edge_detected  = (xor_now != xor_prev);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xor_prev       <= 1'b0;
            first_bit_seen <= 1'b0;
            disconnect_cnt <= '0;
            bit_valid_o    <= 1'b0;
            bit_o          <= 1'b0;
            disconnect_o   <= 1'b0;
        end else begin
            xor_prev     <= xor_now;
            bit_valid_o  <= 1'b0;
            disconnect_o <= 1'b0;

            if (edge_detected) begin
                bit_o          <= d_i;
                bit_valid_o    <= 1'b1;
                first_bit_seen <= 1'b1;
                disconnect_cnt <= '0;
            end else if (first_bit_seen) begin
                if (disconnect_cnt == (DISCONNECT_TIMEOUT_CYCLES - 1)) begin
                    disconnect_o   <= 1'b1;
                    disconnect_cnt <= '0; // reset contagem 
                end else begin
                    disconnect_cnt <= disconnect_cnt + 1'b1;
                end
            end
            // antes do 1o bit pos-reset o contador de desconexao fica parado
        end
    end

endmodule
