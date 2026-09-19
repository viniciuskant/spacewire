module flow_control_tx (
    input logic clk,
    input logic rst_n,

    input logic run_state,
    input logic en_out_fifo_tx, // se alta mandou um dado
    input logic got_FCT_rx,

    output logic sending_allowed
);

    logic [6:0] credits; //no máximo 7 FCT pendentes, 56 pacotes, 8 bits

    always_ff @(posedge clk) begin 
        if (!rst_n) begin
            credits <= '0;
        end else if (run_state) begin
            if (en_out_fifo_tx and got_FCT_rx) credits <= credits;
            if (en_out_fifo_tx) credits <= credits - 1;
            if (got_FCT_rx credits <= 48) credits <= credits + 8;
        end
    end

    // TODO analisar isso futuramente, pois devido a ciclos de clk isso pode gerar atrasos
    logic sending_allowed_reg;
    always_ff @(posedge clk) begin
        if (!rst_n) sending_allowed_reg <= 1'b0;
        else sending_allowed_reg <= |credits;
    end
    assign sending_allowed = sending_allowed_reg;

endmodule