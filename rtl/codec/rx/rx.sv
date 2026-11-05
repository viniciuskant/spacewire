module rx(
    input i_sys_clk,
    input i_sys_rstn,

    // fifo interface
    input i_fifo_full,
    output o_nchar_wr,
    output [8:0] o_nchar,

    // timecode interface
    output o_tick,
    output [7:0] o_timecode,

    // credit interface
    output [3:0] fct_delta
);



endmodule
