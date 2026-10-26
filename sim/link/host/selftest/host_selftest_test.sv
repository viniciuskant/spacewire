package host_selftest_test_pkg;
  import uvm_pkg::*;
  import host_selftest_env_pkg::*;
  import host_seq_lib_pkg::*;
  `include "uvm_macros.svh"

  class host_selftest_test extends uvm_test;
    `uvm_component_utils(host_selftest_test)

    host_selftest_env env0;
    host_packet_seq pkt_seq;
    host_timecode_seq tc_seq;
    virtual spw_host_if vif;

    function new(string name = "host_selftest_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      int unsigned rx_read_pct = $urandom_range(100, 10);
      int unsigned tx_gap_max = $urandom_range(3);

      super.build_phase(phase);
      env0 = host_selftest_env::type_id::create("env0", this);
      // a hung sequence or monitor fails the test instead of running forever
      uvm_root::get().set_timeout(10ms, 1);

      if (!uvm_config_db #(virtual spw_host_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_host_if")
      end
      uvm_config_db #(virtual spw_host_if)::set(this, "env0.a0.*", "vif", vif);

      // random backpressure on both FIFOs
      uvm_config_db #(int unsigned)::set(this, "env0.a0.d0", "rx_read_pct", rx_read_pct);
      uvm_config_db #(int unsigned)::set(this, "env0.a0.d0", "tx_gap_max", tx_gap_max);
      `uvm_info(get_type_name(), $sformatf("rx_read_pct=%0d tx_gap_max=%0d", rx_read_pct, tx_gap_max), UVM_LOW)

      pkt_seq = host_packet_seq::type_id::create("pkt_seq");
      tc_seq = host_timecode_seq::type_id::create("tc_seq");
      if (!pkt_seq.randomize() || !tc_seq.randomize()) begin
        `uvm_fatal(get_type_name(), "Failed to randomize sequences")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      fork
        pkt_seq.start(env0.a0.s0);
        tc_seq.start(env0.a0.s0);
      join
      // allow the RX side to drain the loopback FIFO
      phase.get_objection().set_drain_time(this, 5us);
      phase.drop_objection(this);
    endtask

  endclass
endpackage
