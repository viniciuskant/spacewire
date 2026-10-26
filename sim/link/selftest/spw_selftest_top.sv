import uvm_pkg::*;
`include "uvm_macros.svh"

module tb_top;
  spw_serial_if sif();
  assign sif.dout = sif.din;
  assign sif.sout = sif.sin;

  initial begin
    uvm_config_db #(virtual spw_serial_if)::set(null, "uvm_test_top", "vif", sif);
    run_test("spw_selftest_test");
  end

endmodule
