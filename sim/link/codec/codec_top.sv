import uvm_pkg::*;
`include "uvm_macros.svh"

/// Testbench top for rtl/codec.sv: the DS agent plays the link partner on
/// D/S, the host agent drives the FIFO and timecode ports.
module codec_top;
  logic clk_system = 0;
  logic clk_ref_tx = 0;
  logic rst_n = 0;

  always #10ns clk_system = ~clk_system;  // 50 MHz
  always #2.5ns clk_ref_tx = ~clk_ref_tx; // 200 MHz

  initial begin
    repeat (10) @(posedge clk_system);
    rst_n <= 1;
  end

  spw_host_if hif (.clk_system(clk_system), .rst_n(rst_n));
  spw_serial_if sif ();

  // 2 GHz clock for oversampling D/S in the DS monitor
  initial sif.fast_clk = 0;
  always #250ps sif.fast_clk = ~sif.fast_clk;

  codec dut (
    .clk_system (clk_system),
    .clk_ref_tx (clk_ref_tx),
    .div_counter_tx (hif.div_counter_tx),
    .rst_n (rst_n),

    .S_in (sif.sin),
    .D_in (sif.din),
    .S_out (sif.sout),
    .D_out (sif.dout),

    .SpW_Packet_TX (hif.SpW_Packet_TX),
    .SpW_Packet_TX_en (hif.SpW_Packet_TX_en),
    .full_tx_fifo (hif.full_tx_fifo),
    .SpW_Packet_RX (hif.SpW_Packet_RX),
    .SpW_Packet_RX_en (hif.SpW_Packet_RX_en),
    .empty_rx_fifo (hif.empty_rx_fifo),

    .Time_Code_TX (hif.Time_Code_TX),
    .Time_Code_TX_valid (hif.Time_Code_TX_valid),
    .Time_Code_RX (hif.Time_Code_RX),
    .Time_Code_RX_valid (hif.Time_Code_RX_valid)
  );

  initial begin
    uvm_config_db #(virtual spw_serial_if)::set(null, "uvm_test_top", "ds_vif", sif);
    uvm_config_db #(virtual spw_host_if)::set(null, "uvm_test_top", "host_vif", hif);
    run_test();
  end

endmodule
