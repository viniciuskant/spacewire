package ds_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ds_driver_pkg::*;
  import ds_monitor_pkg::*;
  import ds_item_pkg::*;
  import char_decoder_pkg::*;

  /// DS link agent:
  ///
  ///   s0 --> d0 --> din/sin
  ///   din/sin   --> m0.rx_raw_ap --> rx_decoder.char_ap
  ///   dout/sout --> m0.tx_raw_ap --> tx_decoder.char_ap
  ///
  /// Sequences on s0 can mix ds_char_item, ds_raw_item (e.g. a lone ESC) and
  /// ds_config_item.
  class ds_agent extends uvm_agent;
    `uvm_component_utils(ds_agent)
    function new(string name = "ds_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    ds_driver d0;
    ds_monitor m0;
    char_decoder rx_decoder;
    char_decoder tx_decoder;
    uvm_sequencer #(ds_base_item) s0;

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      s0 = uvm_sequencer #(ds_base_item)::type_id::create("s0", this);
      d0 = ds_driver::type_id::create("d0", this);
      m0 = ds_monitor::type_id::create("m0", this);
      rx_decoder = char_decoder::type_id::create("rx_decoder", this);
      tx_decoder = char_decoder::type_id::create("tx_decoder", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      d0.seq_item_port.connect(s0.seq_item_export);
      m0.rx_raw_ap.connect(rx_decoder.analysis_export);
      m0.tx_raw_ap.connect(tx_decoder.analysis_export);
    endfunction

    // a half received NULL or timecode must not survive a link reset
    virtual task run_phase(uvm_phase phase);
      fork
        forever begin
          m0.rx_silence_ev.wait_trigger();
          rx_decoder.reset();
        end
        forever begin
          m0.tx_silence_ev.wait_trigger();
          tx_decoder.reset();
        end
      join
    endtask

  endclass
endpackage
