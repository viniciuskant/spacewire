package codec_env_pkg;
  import uvm_pkg::*;
  import ds_agent_pkg::*;
  import host_agent_pkg::*;
  `include "uvm_macros.svh"

  /// ds0 is the link partner on D/S, host0 the user of the FIFO ports
  class codec_env extends uvm_env;
    `uvm_component_utils(codec_env)

    ds_agent ds0;
    host_agent host0;

    function new(string name = "codec_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ds0 = ds_agent::type_id::create("ds0", this);
      host0 = host_agent::type_id::create("host0", this);
    endfunction

  endclass
endpackage
