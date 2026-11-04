package host_selftest_env_pkg;
  import uvm_pkg::*;
  import host_item_pkg::*;
  import host_agent_pkg::*;
  import host_selftest_checker_pkg::*;
  `include "uvm_macros.svh"

  /// Loopback env: the top feeds the TX FIFO straight into the RX FIFO and
  /// Time_Code_TX into Time_Code_RX. Checks driver -> TX monitor (nothing is
  /// lost while full_tx_fifo is high) and TX monitor -> RX monitor.
  class host_selftest_env extends uvm_env;
    `uvm_component_utils(host_selftest_env)

    host_agent a0;
    host_selftest_cmp #(host_packet_item) chk_drv_pkt;
    host_selftest_cmp #(host_packet_item) chk_loop_pkt;
    host_selftest_cmp #(host_timecode_item) chk_drv_tc;
    host_selftest_cmp #(host_timecode_item) chk_loop_tc;

    function new(string name = "host_selftest_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      a0 = host_agent::type_id::create("a0", this);
      chk_drv_pkt = host_selftest_cmp #(host_packet_item)::type_id::create("chk_drv_pkt", this);
      chk_loop_pkt = host_selftest_cmp #(host_packet_item)::type_id::create("chk_loop_pkt", this);
      chk_drv_tc = host_selftest_cmp #(host_timecode_item)::type_id::create("chk_drv_tc", this);
      chk_loop_tc = host_selftest_cmp #(host_timecode_item)::type_id::create("chk_loop_tc", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      a0.d0.pkt_ap.connect(chk_drv_pkt.exp_fifo.analysis_export);
      a0.m0.tx_pkt_ap.connect(chk_drv_pkt.act_fifo.analysis_export);
      a0.m0.tx_pkt_ap.connect(chk_loop_pkt.exp_fifo.analysis_export);
      a0.m0.rx_pkt_ap.connect(chk_loop_pkt.act_fifo.analysis_export);

      a0.d0.tc_ap.connect(chk_drv_tc.exp_fifo.analysis_export);
      a0.m0.tx_tc_ap.connect(chk_drv_tc.act_fifo.analysis_export);
      a0.m0.tx_tc_ap.connect(chk_loop_tc.exp_fifo.analysis_export);
      a0.m0.rx_tc_ap.connect(chk_loop_tc.act_fifo.analysis_export);
    endfunction
  endclass
endpackage
