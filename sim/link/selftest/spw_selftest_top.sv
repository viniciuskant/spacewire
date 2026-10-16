import uvm_pkg::*;
`include "uvm_macros.svh"

module tb_top;
  spw_serial_if sif();
  assign sif.dout = sif.din;
  assign sif.sout = sif.sin;

  // 2 GHz clock for oversampling din and sin in monitor
  always #250ps
    sif.fast_clk = ~sif.fast_clk;

  initial begin
    sif.fast_clk = 0;
    uvm_config_db #(virtual spw_serial_if)::set(null, "uvm_test_top", "vif", sif);
    run_test("spw_selftest_test");
  end

endmodule
