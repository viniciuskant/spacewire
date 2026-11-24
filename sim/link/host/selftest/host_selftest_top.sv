import uvm_pkg::*;
`include "uvm_macros.svh"

module host_selftest_top;
  logic clk_system = 0;
  logic rst_n = 0;

  // 50 MHz system clock
  always #10ns clk_system = ~clk_system;

  initial begin
    repeat (5) @(posedge clk_system);
    rst_n <= 1;
  end

  spw_host_if hif (.clk_system(clk_system), .rst_n(rst_n));

  // TX buffer -> RX buffer loopback, small enough to fill up
  localparam int AW = 3; // 8 entries
  logic loop_empty;

  fifo #(.ASIZE(AW), .DSIZE(9)) u_loop_fifo (
    .i_clk(clk_system),
    .i_rstn(rst_n),
    .i_wr(hif.i_tx_wr),
    .i_rd(hif.i_rx_rd),
    .i_wdata(hif.i_tx_wdata),
    .o_rdata(hif.o_rx_rdata),
    .o_empty(loop_empty),
    .o_full(hif.o_tx_full),
    .o_count()
  );
  assign hif.o_rx_valid = !loop_empty;

  always_ff @(posedge clk_system or negedge rst_n) begin
    if (!rst_n) begin
      hif.o_timecode <= '0;
      hif.o_tick <= 0;
    end else begin
      hif.o_timecode <= hif.i_timecode;
      hif.o_tick <= hif.i_tick;
    end
  end

  // no link here: status stays quiet
  assign hif.o_link_state = '0;
  assign hif.o_link_run = 0;
  assign hif.o_link_error = 0;

  initial begin
    uvm_config_db #(virtual spw_host_if)::set(null, "uvm_test_top", "vif", hif);
    run_test("host_selftest_test");
  end

endmodule
