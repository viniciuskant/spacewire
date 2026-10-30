
// Credit counter for flow-control
module credit
#(parameter FIFO_DEPTH=64)
 (
    // 50Mhz system clock and reset
    input i_sys_clk,
    input i_sys_rstn,
    // Link Reset signal from FSM
    input i_fsm_link_reset,

    // from TX, if it chose to send a N-char, tx_credit - 1
    input i_tx_nchar_accept,
    // from TX, if it sent an FCT, rx_credit + 8
    input i_tx_fct_accept,
    // from RX, number of received FCTs since last system cycle, tx_credit + 8 * delta
    input [3:0] i_rx_fct_delta,
    // from RX, if it received an FCT, rx_redit - 1
    input i_rx_got_nchar,
    // RX fifo occupancy, for `fct_due`
    input [$clog2(FIFO_DEPTH):0] i_rx_fifo_count,

    // asserted if TX can send another N-char
    output o_tx_has_credit,
    // room for 8 more characters, TX should send an FCT
    output o_tx_fct_due,
    // goes to the FSM (credit error, or N-char received without credit)
    output o_credit_error
);
    localparam logic [6:0] MAX_CREDITS = 56;
    localparam logic [6:0] FCT_GRANT   = 8;

    logic [6:0] tx_credits; //no máximo 7 FCT pendentes, 56 pacotes, 7 bits

    always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
        if (!i_sys_rstn) begin
            tx_credits <= 0;
        end else if (i_fsm_link_reset) begin
            tx_credits <= '0;
        end else begin
        end
    end

    // TODO analisar isso futuramente, pois devido a ciclos de clk isso pode gerar atrasos
    assign o_credit_error = tx_credits > MAX_CREDITS;



endmodule
