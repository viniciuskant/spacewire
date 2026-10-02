package selftest_test_pkg;
  import uvm_pkg::*;
  import selftest_env_pkg::*;
  import selftest_seq_pkg::*;
  `include "uvm_macros.svh"

  class spw_selftest_test extends uvm_test;
    `uvm_component_utils(spw_selftest_test)

    spw_selftest_env env0;
    spw_selftest_seq seq;
    virtual spw_serial_if vif;

    function new(string name = "spw_selftest_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env0 = spw_selftest_env::type_id::create("env0", this);

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
      uvm_config_db #(virtual spw_serial_if)::set(this, "env0.a0.*", "vif", vif);

      seq = spw_selftest_seq::type_id::create("seq");
      if (!seq.randomize()) begin
        `uvm_fatal(get_type_name(), "Failed to randomize sequence")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      seq.start(env0.a0.s0);
      phase.drop_objection(this);
    endtask

  endclass
endpackage
