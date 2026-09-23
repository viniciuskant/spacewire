module flow_control_tx (
    input logic clk,
    input logic rst_n,

    input logic run_state,
    input logic en_out_fifo_tx, // se alto mandou um dado
    input logic got_FCT_rx,

    output logic sending_allowed
);

    localparam int MAX_CREDITS = 56;
    localparam int FCT_GRANT   = 8;

    logic [6:0] credits; //no máximo 7 FCT pendentes, 56 pacotes, 7 bits

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credits <= '0;
        end else if (!run_state) begin
            credits <= '0;
        end else begin
            unique case ({got_FCT_rx && (credits <= MAX_CREDITS - FCT_GRANT),
                          en_out_fifo_tx})
                2'b10: credits <= credits + FCT_GRANT;
                2'b01: credits <= credits - 1;
                2'b11: credits <= credits + FCT_GRANT - 1;
                default: credits <= credits;
            endcase
        end
    end

    // TODO analisar isso futuramente, pois devido a ciclos de clk isso pode gerar atrasos
    assign sending_allowed = (credits != 0);

endmodule