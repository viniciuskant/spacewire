module flow_control_rx #(
    parameter DEPTH_FIFO = 2048
)(
    input  logic clk,
    input  logic rst_n,

    input  logic run_state,
    input  logic en_in_fifo_rx, // 1 quando um N-Char é gravado
    input  logic [$clog2(DEPTH_FIFO)-1:0] free_slots_fifo,

    output logic send_FCT
);

    localparam int MAX_CREDITS = 56;
    localparam int FCT_GRANT   = 8;

    logic [6:0] credits;

    assign send_FCT = run_state && (credits <= MAX_CREDITS - FCT_GRANT)
                                 && (free_slots_fifo >= FCT_GRANT);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credits <= '0;
        end else if (!run_state) begin
            credits <= '0;
        end else begin
            unique case ({send_FCT, en_in_fifo_rx})
                2'b10: credits <= credits + FCT_GRANT;
                2'b01: credits <= credits - 1;
                2'b11: credits <= credits + FCT_GRANT - 1;
                default: credits <= credits;
            endcase
        end
    end

endmodule