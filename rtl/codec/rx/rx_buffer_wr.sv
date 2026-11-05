import spw_pkg::*;

`ifdef RX_BUFFER_WR
`define ASSUME assume
`else
`define ASSUME assert
`endif

// sits between the decoder and the FIFO. Injects
// EEPs on error
module rx_buffer_wr (
    input i_sys_clk,
    input i_sys_rstn,
    // FSM signal. Low = flush the crossing FIFO, write the EEP
    // if mid-packet.
    input i_rx_enable,

    // credit interface
    input i_has_rx_credit,
    output o_rx_write, // an N-char was written: rx_credit - 1
    output o_rx_credit_err, // got character without remaining credit
    // async FIFO interface
    input i_afifo_valid, // FIFO not empty
    input [8:0] i_afifo_rdata, // FIFO data
    output logic o_afifo_pop, // FIFO read enable

    // RX codec FIFO/buffer
    input i_buf_full,
    output logic o_buf_wr,
    output [8:0] o_buf_wdata
);

// we can forward a nchar under these conditions
wire will_send = i_afifo_valid && i_has_rx_credit && !i_buf_full;
// if we have a credit error, we'll discard the character
wire discard = i_afifo_valid && !i_has_rx_credit;

logic in_packet;

always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
    if (!i_sys_rstn) in_packet <= 0;
    else if (!i_rx_enable && o_buf_wr) in_packet <= 0; // EEP written
    else if (i_rx_enable && will_send) in_packet <= !i_afifo_rdata[8]; // if control bit is 1, we got EOP/EEP, leave packet
end

// when in error, we pop it while there's stuff in the fifo
assign o_afifo_pop = i_rx_enable ? (will_send || discard) : i_afifo_valid;
// when in error, we write an EEP if inside a packet and buffer not full
assign o_buf_wr = i_rx_enable ? will_send : (in_packet && !i_buf_full);
// when in error, we select the EEP for `o_buf_wr` to send it once
assign o_buf_wdata = i_rx_enable ? i_afifo_rdata : CONST_EEP;
// different from `o_buf_wr` because we only assert this if not in error
assign o_rx_write = i_rx_enable && will_send;
assign o_rx_credit_err = i_rx_enable && discard;

`ifndef SYNTHESIS
default clocking cb @(posedge i_sys_clk); endclocking;
default disable iff !i_sys_rstn;

// --- input assumptions ---
// the buffer is never full when we need to put an EEP
a_buf_not_full: `ASSUME property (!i_rx_enable && in_packet |-> !i_buf_full);

// --- assertions ---
a_one_eep: assert property (!i_rx_enable && o_buf_wr |=> !o_buf_wr);
a_no_idle_wr: assert property (!i_rx_enable && !in_packet |=> !o_buf_wr);
a_afifo_empty_on_enable: assert property ($rose(i_rx_enable) |-> !i_afifo_valid);
`endif

endmodule

`undef ASSUME
