package host_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import host_item_pkg::*;
  import host_driver_pkg::*;
  import host_monitor_pkg::*;

  /// Host agent: sequences on s0 can mix host_packet_item,
  /// host_timecode_item and host_config_item.
  class host_agent extends uvm_agent;
    `uvm_component_utils(host_agent)
    function new(string name = "host_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    host_driver d0;
    host_monitor m0;
    uvm_sequencer #(host_base_item) s0;

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      s0 = uvm_sequencer #(host_base_item)::type_id::create("s0", this);
      d0 = host_driver::type_id::create("d0", this);
      m0 = host_monitor::type_id::create("m0", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      d0.seq_item_port.connect(s0.seq_item_export);
    endfunction

  endclass
endpackage
