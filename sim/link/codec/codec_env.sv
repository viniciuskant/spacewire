package codec_env_pkg;
  import uvm_pkg::*;
  import ds_agent_pkg::*;
  import host_agent_pkg::*;
  import codec_scoreboard_pkg::*;
  `include "uvm_macros.svh"

  /// ds0 is the link partner on D/S, host0 the user of the FIFO ports
  class codec_env extends uvm_env;
    `uvm_component_utils(codec_env)

    ds_agent ds0;
    host_agent host0;
    codec_scoreboard sb;

    function new(string name = "codec_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ds0 = ds_agent::type_id::create("ds0", this);
      host0 = host_agent::type_id::create("host0", this);
      sb = codec_scoreboard::type_id::create("sb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      host0.m0.tx_pkt_ap.connect(sb.host_tx_pkt_fifo.analysis_export);
      host0.m0.rx_pkt_ap.connect(sb.host_rx_pkt_fifo.analysis_export);
      host0.m0.tx_tc_ap.connect(sb.host_tx_tc_fifo.analysis_export);
      host0.m0.rx_tc_ap.connect(sb.host_rx_tc_fifo.analysis_export);
      ds0.d0.char_ap.connect(sb.partner_chars_fifo.analysis_export);
      ds0.tx_decoder.char_ap.connect(sb.dut_chars_fifo.analysis_export);
      sb.partner = ds0.partner;
    endfunction

  endclass
endpackage
