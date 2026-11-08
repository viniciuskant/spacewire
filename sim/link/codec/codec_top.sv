import uvm_pkg::*;
`include "uvm_macros.svh"

/// Testbench top for rtl/codec/codec.sv: the DS agent plays the link partner
/// on D/S, the host agent drives the buffer, timecode and link control ports.
module codec_top;
  logic clk_system = 0;
  logic clk_ref_tx = 0;
  logic rst_n = 0;

  always #10ns clk_system = ~clk_system;  // 50 MHz
  initial begin
    repeat (10) @(posedge clk_system);
    rst_n <= 1;
  end
  initial begin
    #($urandom_range(0, 4)) // random phase for the TX clock
    forever #2.5ns clk_ref_tx = ~clk_ref_tx; // 200 MHz
  end

  // synchronized resets
  logic sys_rstn, tx_rstn;
  reset_sync u_rst_sys (.i_clk(clk_system), .i_rstn(rst_n), .o_rstn(sys_rstn));
  reset_sync u_rst_tx  (.i_clk(clk_ref_tx), .i_rstn(rst_n), .o_rstn(tx_rstn));

  spw_host_if hif (.clk_system(clk_system), .rst_n(sys_rstn));
  spw_serial_if sif ();

  spw_codec dut (
    .i_sys_clk (clk_system),
    .i_tx_clk (clk_ref_tx),
    .i_sys_rstn (sys_rstn),
    .i_tx_rstn (tx_rstn),

    .i_D (sif.din),
    .i_S (sif.sin),
    .o_D (sif.dout),
    .o_S (sif.sout),

    .i_tx_wr (hif.i_tx_wr),
    .i_tx_wdata (hif.i_tx_wdata),
    .o_tx_full (hif.o_tx_full),

    .i_rx_rd (hif.i_rx_rd),
    .o_rx_rdata (hif.o_rx_rdata),
    .o_rx_valid (hif.o_rx_valid),

    .i_tick (hif.i_tick),
    .i_timecode (hif.i_timecode),
    .o_tick (hif.o_tick),
    .o_timecode (hif.o_timecode),

    .i_link_start (hif.i_link_start),
    .i_auto_start (hif.i_auto_start),
    .i_link_disable (hif.i_link_disable),
    .i_run_div (hif.i_run_div),

    .o_link_state (hif.o_link_state),
    .o_link_run (hif.o_link_run),
    .o_link_error (hif.o_link_error)
  );

  initial begin
    uvm_config_db #(virtual spw_serial_if)::set(null, "uvm_test_top", "ds_vif", sif);
    uvm_config_db #(virtual spw_host_if)::set(null, "uvm_test_top", "host_vif", hif);
    run_test();
  end

endmodule
