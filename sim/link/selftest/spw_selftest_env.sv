package selftest_env_pkg;
  import uvm_pkg::*;
  import selftest_agent_pkg::*;
  import selftest_checker_pkg::*;
  `include "uvm_macros.svh"

  class spw_selftest_env extends uvm_env;
    `uvm_component_utils(spw_selftest_env)

    spw_selftest_agent a0;
    spw_selftest_checker chk0;

    function new(string name = "spw_selftest_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      a0 = spw_selftest_agent::type_id::create("a0", this);
      chk0 = spw_selftest_checker::type_id::create("chk0", this);

    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      a0.m0.rx_analysis_port.connect(chk0.mon_rx_fifo.analysis_export);
      a0.d0.ap.connect(chk0.driver_fifo.analysis_export);
    endfunction

  endclass

endpackage
