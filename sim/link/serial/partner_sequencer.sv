package partner_sequencer_pkg;
import uvm_pkg::*;
import ds_item_pkg::*;
`include "uvm_macros.svh"

// ---------------------------------------------------------------------------
// partner_sequencer.sv
//
// Logical (character-level) sequencer of the serial agent. It owns the
// analysis FIFO that lets sequences read what the DUT transmitted, plus the
// events sequences use to signal / observe link state.
//
// The FIFO is only a subscriber: the agent connects the decoder's char_ap to
// ser_fifo.analysis_export. The decoder does not know this class exists.
// ---------------------------------------------------------------------------

class partner_sequencer extends uvm_sequencer#(ds_char_item);
  `uvm_component_utils(partner_sequencer)

  partner_cfg                          cfg;            // set by the agent
  uvm_tlm_analysis_fifo#(ds_char_item) ser_fifo;       // DUT -> partner characters
  uvm_event                            link_up_ev;     // triggered by bring-up on success
  uvm_event                            link_reset_ev;  // triggered when the link goes down

  function new(string name, uvm_component parent);
    super.new(name, parent);
    link_up_ev    = new("link_up_ev");
    link_reset_ev = new("link_reset_ev");
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ser_fifo = new("ser_fifo", this);
  endfunction

  // Called through serial_agent::link_reset(). Drops stale characters so an
  // old NULL/FCT cannot satisfy a wait in the next bring-up, and wakes any
  // sequence blocked on the link so it can abort.
  function void link_reset();
    ser_fifo.flush();
    link_up_ev.reset();
    link_reset_ev.trigger();
  endfunction
endclass
endpackage