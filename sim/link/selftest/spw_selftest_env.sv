package selftest_env_pkg;
  import uvm_pkg::*;
  import ds_agent_pkg::*;
  import selftest_checker_pkg::*;
  `include "uvm_macros.svh"

  /// Loopback env: the top ties dout/sout to din/sin, so both monitor paths
  /// must see exactly what the agent drove.
  class spw_selftest_env extends uvm_env;
    `uvm_component_utils(spw_selftest_env)

    ds_agent a0;
    spw_selftest_checker chk_rx;
    spw_selftest_checker chk_tx;

    function new(string name = "spw_selftest_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      a0 = ds_agent::type_id::create("a0", this);
      chk_rx = spw_selftest_checker::type_id::create("chk_rx", this);
      chk_tx = spw_selftest_checker::type_id::create("chk_tx", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      a0.d0.ap.connect(chk_rx.exp_raw_fifo.analysis_export);
      a0.d0.char_ap.connect(chk_rx.exp_char_fifo.analysis_export);
      a0.m0.rx_raw_ap.connect(chk_rx.act_raw_fifo.analysis_export);
      a0.rx_decoder.char_ap.connect(chk_rx.act_char_fifo.analysis_export);

      a0.d0.ap.connect(chk_tx.exp_raw_fifo.analysis_export);
      a0.d0.char_ap.connect(chk_tx.exp_char_fifo.analysis_export);
      a0.m0.tx_raw_ap.connect(chk_tx.act_raw_fifo.analysis_export);
      a0.tx_decoder.char_ap.connect(chk_tx.act_char_fifo.analysis_export);
    endfunction

  endclass

endpackage
