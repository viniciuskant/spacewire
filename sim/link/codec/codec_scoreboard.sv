package codec_scoreboard_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  import host_item_pkg::*;
  import ds_partner_pkg::*;
  `include "uvm_macros.svh"

  /// End to end checks of the codec, in order:
  ///   host TX FIFO -> DUT on the wire (packets and timecodes)
  ///   partner on the wire -> host RX FIFO (packets and timecodes)
  ///
  /// Wire characters are grouped into packets the same way the host FIFOs
  /// carry them: DATA bytes ended by an EOP or EEP. Whatever is in flight
  /// when the link goes down is dropped, since the codec does not promise
  /// to deliver it. Wire characters only count while the partner is in Run:
  /// outside it they are link start-up (or a character cut by a link reset),
  /// and an N-char there is already an error from the partner.
  class codec_scoreboard extends uvm_component;
    `uvm_component_utils(codec_scoreboard)

    uvm_tlm_analysis_fifo #(host_packet_item) host_tx_pkt_fifo;
    uvm_tlm_analysis_fifo #(host_packet_item) host_rx_pkt_fifo;
    uvm_tlm_analysis_fifo #(host_timecode_item) host_tx_tc_fifo;
    uvm_tlm_analysis_fifo #(host_timecode_item) host_rx_tc_fifo;
    uvm_tlm_analysis_fifo #(ds_char_item) partner_chars_fifo; // sent by the partner
    uvm_tlm_analysis_fifo #(ds_char_item) dut_chars_fifo;     // sent by the DUT

    ds_partner partner; // set by the env, for link down

    protected host_packet_item exp_wire_pkts[$];
    protected host_packet_item exp_host_pkts[$];
    protected bit [7:0] exp_wire_tcs[$];
    protected bit [7:0] exp_host_tcs[$];
    protected bit [7:0] dut_pkt_data[$];
    protected bit [7:0] partner_pkt_data[$];

    int unsigned wire_pkts_checked, host_pkts_checked;
    int unsigned wire_tcs_checked, host_tcs_checked;
    int unsigned dropped;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      host_tx_pkt_fifo = new("host_tx_pkt_fifo", this);
      host_rx_pkt_fifo = new("host_rx_pkt_fifo", this);
      host_tx_tc_fifo = new("host_tx_tc_fifo", this);
      host_rx_tc_fifo = new("host_rx_tc_fifo", this);
      partner_chars_fifo = new("partner_chars_fifo", this);
      dut_chars_fifo = new("dut_chars_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
      fork
        get_host_tx_pkts();
        get_host_rx_pkts();
        get_host_tx_tcs();
        get_host_rx_tcs();
        get_partner_chars();
        get_dut_chars();
        if (partner != null) flush_on_link_down();
      join
    endtask

    /// True when nothing sent is still on its way
    function bit drained();
      return exp_wire_pkts.size() == 0 && exp_host_pkts.size() == 0 &&
             exp_wire_tcs.size() == 0 && exp_host_tcs.size() == 0 &&
             dut_pkt_data.size() == 0 && partner_pkt_data.size() == 0;
    endfunction

    task wait_drained(realtime tmo);
      realtime t_end = $realtime + tmo;
      while (!drained() && $realtime < t_end) #1us;
    endtask

    // ------------------------------------------------------- host -> wire

    protected task get_host_tx_pkts();
      host_packet_item pkt;
      forever begin
        host_tx_pkt_fifo.get(pkt);
        exp_wire_pkts.push_back(pkt);
      end
    endtask

    protected task get_host_tx_tcs();
      host_timecode_item tc;
      forever begin
        host_tx_tc_fifo.get(tc);
        exp_wire_tcs.push_back(tc.value);
      end
    endtask

    protected task get_dut_chars();
      ds_char_item c;
      host_packet_item pkt;
      forever begin
        dut_chars_fifo.get(c);
        if (!link_is_up()) continue;
        case (c.typ)
          SPW_CHAR_DATA: dut_pkt_data.push_back(c.data);
          SPW_CHAR_EOP, SPW_CHAR_EEP: begin
            pkt = new_packet(dut_pkt_data, c.typ);
            if (exp_wire_pkts.size() == 0)
              `uvm_error("SB", $sformatf("DUT sent a packet the host never wrote: %s", pkt.convert2string()))
            else
              compare_pkt("host -> wire", exp_wire_pkts.pop_front(), pkt);
            wire_pkts_checked++;
          end
          SPW_CHAR_TIMECODE: begin
            if (exp_wire_tcs.size() == 0)
              `uvm_error("SB", $sformatf("DUT sent a timecode the host never wrote: %0d", c.data))
            else
              compare_tc("host -> wire", exp_wire_tcs.pop_front(), c.data);
            wire_tcs_checked++;
          end
          default: ; // NULLs, FCTs and errors belong to the link, not to the data
        endcase
      end
    endtask

    // ------------------------------------------------------- wire -> host

    protected task get_partner_chars();
      ds_char_item c;
      forever begin
        partner_chars_fifo.get(c);
        if (!link_is_up()) continue;
        case (c.typ)
          SPW_CHAR_DATA: partner_pkt_data.push_back(c.data);
          SPW_CHAR_EOP, SPW_CHAR_EEP: exp_host_pkts.push_back(new_packet(partner_pkt_data, c.typ));
          SPW_CHAR_TIMECODE: exp_host_tcs.push_back(c.data);
          default: ;
        endcase
      end
    endtask

    protected task get_host_rx_pkts();
      host_packet_item pkt;
      forever begin
        host_rx_pkt_fifo.get(pkt);
        if (exp_host_pkts.size() == 0)
          `uvm_error("SB", $sformatf("host read a packet the partner never sent: %s", pkt.convert2string()))
        else
          compare_pkt("wire -> host", exp_host_pkts.pop_front(), pkt);
        host_pkts_checked++;
      end
    endtask

    protected task get_host_rx_tcs();
      host_timecode_item tc;
      forever begin
        host_rx_tc_fifo.get(tc);
        if (exp_host_tcs.size() == 0)
          `uvm_error("SB", $sformatf("host got a timecode the partner never sent: %0d", tc.value))
        else
          compare_tc("wire -> host", exp_host_tcs.pop_front(), tc.value);
        host_tcs_checked++;
      end
    endtask

    // ------------------------------------------------------------ helpers

    protected function bit link_is_up();
      return partner != null && partner.link_is_up();
    endfunction

    protected task flush_on_link_down();
      forever begin
        partner.link_down_ev.wait_trigger();
        dropped += exp_wire_pkts.size() + exp_host_pkts.size() + exp_wire_tcs.size() + exp_host_tcs.size();
        `uvm_info("SB", $sformatf("link down, dropping %0d/%0d packets and %0d/%0d timecodes in flight (to wire/to host)",
                                  exp_wire_pkts.size(), exp_host_pkts.size(),
                                  exp_wire_tcs.size(), exp_host_tcs.size()), UVM_LOW)
        exp_wire_pkts.delete();
        exp_host_pkts.delete();
        exp_wire_tcs.delete();
        exp_host_tcs.delete();
        dut_pkt_data.delete();
        partner_pkt_data.delete();
      end
    endtask

    protected function host_packet_item new_packet(ref bit [7:0] data[$], input ds_char_kind_e end_typ);
      host_packet_item pkt = host_packet_item::type_id::create("pkt");
      pkt.data = data;
      pkt.end_marker = (end_typ == SPW_CHAR_EEP) ? HOST_END_EEP : HOST_END_EOP;
      data.delete();
      return pkt;
    endfunction

    protected function void compare_pkt(string path, host_packet_item exp, host_packet_item act);
      if (!exp.compare(act))
        `uvm_error("SB", $sformatf("%s packet MISMATCH! Expected: %s, Observed: %s",
                                   path, exp.convert2string(), act.convert2string()))
    endfunction

    protected function void compare_tc(string path, bit [7:0] exp, bit [7:0] act);
      if (exp != act)
        `uvm_error("SB", $sformatf("%s timecode MISMATCH! Expected: %0d, Observed: %0d", path, exp, act))
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SB", $sformatf("checked %0d/%0d packets and %0d/%0d timecodes (host -> wire / wire -> host), %0d dropped on link down",
                                wire_pkts_checked, host_pkts_checked, wire_tcs_checked, host_tcs_checked, dropped), UVM_LOW)
      if (!drained())
        `uvm_error("SB", $sformatf({"test ended with %0d/%0d packets and %0d/%0d timecodes never delivered ",
                                    "and %0d/%0d bytes of unfinished packets on the wire (to wire/to host)"},
                                   exp_wire_pkts.size(), exp_host_pkts.size(), exp_wire_tcs.size(), exp_host_tcs.size(),
                                   dut_pkt_data.size(), partner_pkt_data.size()))
    endfunction
  endclass
endpackage
