import spw_pkg::*;

// Credit counter for flow-control
module credit
#(
    parameter FIFO_DEPTH=64, // receive buffer depth
    localparam DELTA_W=4, // FCT delta width
    localparam FIFO_CNT_W=$clog2(FIFO_DEPTH+1), // width of fifo occupancy counter
    localparam CW = $clog2(MAX_CREDITS+1) // width of credit counters
)
(
    input i_sys_clk,
    input i_sys_rstn,
    input i_rx_enable, // from state machine
    input i_fct_allowed, // state machine: connecting or run

    // TX interface
    // from TX, if it chose to send a N-char, tx_credit - 1
    input i_tx_nchar_accept,
    // from TX, if it sent an FCT, rx_credit + 8
    input i_tx_fct_accept,
    // asserted if TX can send another N-char
    output o_tx_has_credit,
    // room for 8 more characters, TX should send an FCT
    output o_tx_fct_due,

    // RX interface
    // from RX, number of received FCTs since last system cycle, tx_credit + 8 * delta
    input [DELTA_W-1:0] i_rx_fct_delta,
    // from RX, if it received an nchar, rx_credit - 1
    input i_rx_write,
    // Receive fifo/buffer occupancy, for `fct_due`
    input [FIFO_CNT_W-1:0] i_rx_fifo_count,
    output o_rx_has_credit, // if RX can accept a new nchar (rx_credit != 0)

    // goes to the FSM (tx_credit exceeds MAX_CREDITS)
    output o_credit_error
);

logic [CW-1:0] tx_credit, rx_credit;

// for each received FCT we add FCT_GRANT to credits,
// and if TX decides to send an nchar, we lose one credit.
// These signals are one bit wider to fit the possible overflowed count
wire [CW:0] new_tx_credits = i_rx_fct_delta * FCT_GRANT - i_tx_nchar_accept;
wire [CW:0] tx_credit_next = tx_credit + new_tx_credits;

// if the TX sent an FCT, we add FCT_GRANT to rx credits,
// and if RX decides to write an nchar to the FIFO, we lose one credit.
// These signals are one bit wider to fit the possible overflowed count
wire [CW:0] new_rx_credits = i_tx_fct_accept * FCT_GRANT - i_rx_write;
wire [CW:0] rx_credit_next = rx_credit + new_rx_credits;

always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
    if (!i_sys_rstn) begin
        tx_credit <= '0;
        rx_credit <= '0;
    end else begin
        tx_credit <= i_fct_allowed ? tx_credit_next[CW-1:0] : '0;

        // Keep the RX credit at 0 until the FSM enables RX.
        rx_credit <= i_rx_enable   ? rx_credit_next[CW-1:0] : '0;
    end
end

// permission to grant one more FCT, as long as RX credit doesn't exceed 56
// and the receive FIFO doesn't fill (the -1 is the reserved EEP slot)
assign o_tx_fct_due = (rx_credit + FCT_GRANT <= MAX_CREDITS)
    && (rx_credit + i_rx_fifo_count + FCT_GRANT <= FIFO_DEPTH - 1);

assign o_rx_has_credit = rx_credit != 0;
assign o_tx_has_credit = tx_credit != 0;

// tx credit can't exceed MAX_CREDITS. This can only happen on `i_fct_allowed`.
assign o_credit_error = tx_credit_next > MAX_CREDITS;

`ifndef SYNTHESIS
default clocking cb @(posedge i_sys_clk); endclocking;
default disable iff (!i_sys_rstn);

a_rx_credit: assert property (rx_credit <= MAX_CREDITS);
a_rx_fifo: assert property (rx_credit != 0 |-> rx_credit + i_rx_fifo_count <= FIFO_DEPTH - 1);
a_tx_credit: assert property (tx_credit <= MAX_CREDITS);
// tx_credit may hold a bad value at maximum one cycle after an overflow
a_tx_credit_bad: assert property (!$past(o_credit_error) |-> tx_credit <= MAX_CREDITS);
// The FSM must leave connecting/run on the edge that samples the error
a_err_exit: assert property (o_credit_error |=> !i_fct_allowed);
a_fct_delta: assert property (i_rx_fct_delta <= 3);


`endif

endmodule
