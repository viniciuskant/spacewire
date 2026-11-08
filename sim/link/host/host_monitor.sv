package host_monitor_pkg;
  import uvm_pkg::*;
  import host_item_pkg::*;
  `include "uvm_macros.svh"

  /// Rebuilds packets from the words that cross the host buffers:
  ///   TX: written while i_tx_wr && !o_tx_full
  ///   RX: read while i_rx_rd && o_rx_valid
  /// A packet is published when its EOP/EEP goes through. Partial packets are
  /// dropped on reset.
  ///
  /// It also follows the status outputs: link_state is the DUT's state
  /// (spw_pkg::e_link_state), and link_errors counts o_link_error pulses.
  class host_monitor extends uvm_monitor;
    `uvm_component_utils(host_monitor)

    virtual spw_host_if vif;

    // packets the host wrote to the DUT
    uvm_analysis_port #(host_packet_item) tx_pkt_ap;
    // packets the host read from the DUT
    uvm_analysis_port #(host_packet_item) rx_pkt_ap;
    uvm_analysis_port #(host_timecode_item) tx_tc_ap;
    uvm_analysis_port #(host_timecode_item) rx_tc_ap;

    bit [2:0] link_state;
    int unsigned link_errors;

    protected bit [7:0] tx_data[$];
    protected bit [7:0] rx_data[$];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tx_pkt_ap = new("tx_pkt_ap", this);
      rx_pkt_ap = new("rx_pkt_ap", this);
      tx_tc_ap = new("tx_tc_ap", this);
      rx_tc_ap = new("rx_tc_ap", this);
      if (!uvm_config_db #(virtual spw_host_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_host_if")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);

        if (vif.rst_n !== 1) begin
          tx_data.delete();
          rx_data.delete();
          continue;
        end

        if (vif.mon_cb.i_tx_wr === 1 && vif.mon_cb.o_tx_full === 0)
          collect_word(0, vif.mon_cb.i_tx_wdata);

        if (vif.mon_cb.i_rx_rd === 1 && vif.mon_cb.o_rx_valid === 1)
          collect_word(1, vif.mon_cb.o_rx_rdata);

        if (vif.mon_cb.i_tick === 1)
          tx_tc_ap.write(new_timecode(vif.mon_cb.i_timecode));

        if (vif.mon_cb.o_tick === 1)
          rx_tc_ap.write(new_timecode(vif.mon_cb.o_timecode));

        if (!$isunknown(vif.mon_cb.o_link_state) && vif.mon_cb.o_link_state != link_state) begin
          `uvm_info(get_type_name(), $sformatf("DUT link state %0d -> %0d", link_state, vif.mon_cb.o_link_state), UVM_HIGH)
          link_state = vif.mon_cb.o_link_state;
        end

        if (vif.mon_cb.o_link_error === 1) begin
          link_errors++;
          `uvm_info(get_type_name(), "DUT reported a link error", UVM_LOW)
        end
      end
    endtask

    protected function void collect_word(bit rx, bit [8:0] w);
      host_packet_item pkt;

      if (!w[8]) begin
        if (rx) rx_data.push_back(w[7:0]);
        else tx_data.push_back(w[7:0]);
        return;
      end

      pkt = host_packet_item::type_id::create(rx ? "rx_pkt" : "tx_pkt");
      case (w)
        HOST_WORD_EOP: pkt.end_marker = HOST_END_EOP;
        HOST_WORD_EEP: pkt.end_marker = HOST_END_EEP;
        default: begin
          `uvm_error(get_type_name(), $sformatf("invalid control word 0x%03h on the %s buffer",
                                                w, rx ? "RX" : "TX"))
          return;
        end
      endcase

      if (rx) begin
        pkt.data = rx_data;
        rx_data.delete();
        rx_pkt_ap.write(pkt);
      end
      else begin
        pkt.data = tx_data;
        tx_data.delete();
        tx_pkt_ap.write(pkt);
      end
    endfunction

    protected function host_timecode_item new_timecode(bit [7:0] value);
      host_timecode_item tc = host_timecode_item::type_id::create("tc");
      tc.value = value;
      return tc;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      if (tx_data.size() > 0 || rx_data.size() > 0) begin
        `uvm_info(get_type_name(), $sformatf("test ended inside a packet: %0d TX / %0d RX data words without EOP/EEP",
                                             tx_data.size(), rx_data.size()), UVM_LOW)
      end
    endfunction

  endclass
endpackage
