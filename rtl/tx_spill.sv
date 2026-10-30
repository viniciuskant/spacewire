
// Module responsible for spilling the rest of a packet
// waiting in the TX FIFO after a link error.
// Sits between the TX FIFO and the TX selector
// CDC:
// Stays fully in the system clock domain
module tx_spill (
    input i_sys_clk,
    input i_sys_rstn,
    input i_link_error,
    // host side
    input i_host_valid,
    input [8:0] i_host_data,
    output o_host_pop,
    // selector side
    input i_sel_nchar_accept,
    output o_sel_nchar_valid,
    output [8:0] o_sel_nchar_data,
    // status
    output o_spilling
);
    logic in_packet;
    wire is_eop_eep = i_host_data[8];
    logic spilling;

    // packet state including this cycle's accept
    wire in_packet_next = i_sel_nchar_accept ? !is_eop_eep : in_packet;

    // pass-through to the selector, hidden while spilling
    assign o_sel_nchar_valid = i_host_valid && !spilling;
    assign o_sel_nchar_data = i_host_data;

    // popping the host FIFO when selector accepts nchar or when spilling
    wire discard = spilling & i_host_valid;
    assign o_host_pop = discard || i_sel_nchar_accept;

    assign o_spilling = spilling;

    always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
        if (!i_sys_rstn) begin
            in_packet <= 0;
            spilling <= 0;
        end else begin
            in_packet <= i_link_error ? 1'b0 : in_packet_next;

            if (i_link_error && in_packet_next) begin
                spilling <= 1'b1;
            end else if (discard && is_eop_eep) begin
                spilling <= 1'b0;
            end
        end
    end

    `ifndef SYNTHESIS
    assert property (@(posedge i_sys_clk) disable iff (!i_sys_rstn)
        !(i_sel_nchar_accept && spilling));
    `endif

endmodule