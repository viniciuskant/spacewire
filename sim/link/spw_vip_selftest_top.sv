import uvm_pkg::*;
`include "uvm_macros.svh"

class spw_vip_selftest_agent extends uvm_agent;
  `uvm_component_utils(spw_vip_selftest_agent)
  function new(string name="spw_vip_selftest_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  spw_serial_driver d0;
  spw_serial_monitor m0;
  uvm_sequencer #(spw_serial_base_item) s0;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s0 = uvm_sequencer#(spw_serial_base_item)::type_id::create("s0", this);
    d0 = spw_serial_driver::type_id::create("d0", this);
    m0 = spw_serial_monitor::type_id::create("m0", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d0.seq_item_port.connect(s0.seq_item_export);

  endfunction


endclass

class spw_vip_selftest_env extends uvm_env;
  `uvm_component_utils(spw_vip_selftest_env)

  function new(string name="spw_vip_selftest_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass
