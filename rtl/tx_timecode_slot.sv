module tx_timecode_slot (
    input i_sys_clk,
    input i_sys_rstn,
    input i_link_run,
    input i_tc_accept, // from the selector
    input i_tick_in,
    input [7:0] i_timecode,

    output o_tc_valid,
    output [7:0] o_timecode
);

    logic [7:0] slot;
    logic full;

    wire will_clear = !full || i_tc_accept;
    wire load = i_tick_in && i_link_run && will_clear;

    always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
        if (!i_sys_rstn) begin
            slot <= 0;
            full <= 0;
        end else begin
            if (load) begin
                slot <= i_timecode;
                full <= 1'b1;
            end else if (i_tc_accept || !i_link_run) begin
                full <= 0;
            end
        end
    end
    assign o_tc_valid = full;
    assign o_timecode = slot;
endmodule