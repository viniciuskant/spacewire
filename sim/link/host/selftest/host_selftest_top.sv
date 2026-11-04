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

  // TX FIFO -> RX FIFO loopback, small enough to fill up
  localparam int DEPTH = 8;
  logic [$clog2(DEPTH+1)-1:0] free_space;

  rx_fifo #(.DEPTH(DEPTH), .DATA_WIDTH(9)) u_loop_fifo (
    .wr_clk_i(clk_system),
    .rd_clk_i(clk_system),
    .rst_n(rst_n),
    .wr_en_i(hif.SpW_Packet_TX_en),
    .wr_data_i(hif.SpW_Packet_TX),
    .rd_en_i(hif.SpW_Packet_RX_en),
    .rd_data_o(hif.SpW_Packet_RX),
    .empty_o(hif.empty_rx_fifo),
    .free_space_o(free_space)
  );
  assign hif.full_tx_fifo = (free_space == '0);

  always_ff @(posedge clk_system or negedge rst_n) begin
    if (!rst_n) begin
      hif.Time_Code_RX <= '0;
      hif.Time_Code_RX_valid <= 0;
    end else begin
      hif.Time_Code_RX <= hif.Time_Code_TX;
      hif.Time_Code_RX_valid <= hif.Time_Code_TX_valid;
    end
  end

  initial begin
    uvm_config_db #(virtual spw_host_if)::set(null, "uvm_test_top", "vif", hif);
    run_test("host_selftest_test");
  end

endmodule
