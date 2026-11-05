import spw_pkg::*;

// generates the FSM-ready signals `got_bit` and `got_fct`
// and `disconnect` after the link has been silent for too long.
module rx_link_mon (
    input i_sys_clk,
    input i_sys_rstn,
    input i_rx_enable, // signal from state machine
    input [3:0] i_fct_delta, // from CDC boundary
    input [3:0] i_act_pos_delta, // from CDC boundary
    input [3:0] i_act_neg_delta, // from CDC boundary
    output logic o_got_bit, // sticky flag
    output o_got_fct,
    output o_disconnect
);

localparam CTR_WIDTH = $clog2(DISCONNECT_CYCLES + 1);

assign o_got_fct = i_fct_delta != 0;
wire activity = (i_act_neg_delta != 0) || (i_act_pos_delta != 0);


logic [CTR_WIDTH-1:0] quiet_cnt;

assign o_disconnect = o_got_bit && (quiet_cnt == DISCONNECT_CYCLES);
always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
    if (!i_sys_rstn) begin
        quiet_cnt <= 0;
        o_got_bit <= 0;
    end else if (!i_rx_enable) begin
        quiet_cnt <= 0;
        o_got_bit <= 0;
    end else begin
        if (activity) o_got_bit <= 1;
        // we only want to start counting if we already received a bit
        if (!o_got_bit || activity) quiet_cnt <= '0;
        else if (quiet_cnt != DISCONNECT_CYCLES) quiet_cnt <= quiet_cnt + 1;
    end
end

// formal verification
`ifndef SYNTHESIS
default clocking cb @(posedge i_sys_clk); endclocking
default disable iff (!i_sys_rstn);

// --- invariants ---
// the quiet counter saturates at the target
a_cnt_range:   assert property (quiet_cnt <= DISCONNECT_CYCLES);

// no disconnect without a first bit, and none while the receiver is disabled
a_disc_armed:  assert property (o_disconnect |-> o_got_bit);
a_disc_rxen:   assert property (!i_rx_enable |-> !o_disconnect);

// --- got_bit behavior ---
// cleared while the receiver is disabled
a_gb_clear:    assert property (!i_rx_enable |=> !o_got_bit);
// only rises because of activity
a_gb_rise:     assert property ($rose(o_got_bit) |-> $past(activity));
// stays set until the receiver is disabled
//a_gb_sticky:   assert property (o_got_bit && i_rx_enable |=> o_got_bit || !$past(i_rx_enable));

// --- disconnect timing ---
// never early: within CONNECT_CYCLES quiet cycles after activity, no disconnect
a_disc_early:  assert property (
    activity ##1 (!activity && i_rx_enable)[*1:DISCONNECT_CYCLES] |-> !o_disconnect);
// never late: after DISC_CYCLES+1 quiet cycles, disconnect must be high
a_disc_late:   assert property (
    activity ##1 (!activity && i_rx_enable)[*DISCONNECT_CYCLES+1] |-> o_disconnect);
// activity clears it on the next cycle
a_disc_clear:  assert property (activity |=> !o_disconnect);

// --- input assumptions (from the CDC primitives) ---
// differences stay well inside the counter width; if this fires, the
// Gray counters are too narrow for the clock ratio
a_fct_delta:   assert property (i_fct_delta     <= 3);
a_act_pos:     assert property (i_act_pos_delta <= 3);
a_act_neg:     assert property (i_act_neg_delta <= 3);
`endif

endmodule