package ds_monitor_pkg;

  import uvm_pkg::*;
  import ds_item_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  /// Event-driven DS monitor: no sampling clock, it wakes on every change of
  /// D or S. In DS encoding exactly one of them changes per bit, so a change
  /// of D ^ S is a bit, and the bit is the value of D.
  ///
  /// Path 0 (rx) is din/sin, what the IP receives. Path 1 (tx) is
  /// dout/sout, what the IP transmits.
  class ds_monitor extends uvm_monitor;
    `uvm_component_utils(ds_monitor)

    virtual spw_serial_if vif;

    // analysis port connected to the IP RX side (din/sin)
    uvm_analysis_port #(ds_raw_item) rx_raw_ap;
    // analysis port connected to the IP TX side (dout/sout)
    uvm_analysis_port #(ds_raw_item) tx_raw_ap;

    // A path with no transition for silence_timeout is idle: the character
    // being received is dropped and parity restarts with the next bit. This
    // resynchronizes after a link reset, where the transmitter sets D/S to 0.
    // Set with uvm_config_db #(realtime) "silence_timeout".
    realtime silence_timeout = 850ns;
    // Two bits closer than this are reported as a glitch: half a bit at the
    // fastest rate in docs/internal/spec.adoc, 200 Mbit/s (5 ns per bit).
    // uvm_config_db #(realtime) "min_bit_period", 0 disables the check.
    realtime min_bit_period = 2.5ns;
    // D and S are read this long after they change, so that changes in the
    // same time step settle first: a value that flips and flips back is not a bit
    realtime settle_time = 1ps;

    // triggered when a path that was sending goes idle
    uvm_event rx_silence_ev;
    uvm_event tx_silence_ev;

    // per path state, indexed by tx_path
    protected bit active[2];        // bits are arriving
    protected realtime last_edge[2];
    protected uvm_event active_ev[2]; // the path went from idle to active
    protected int unsigned nbits[2];  // bits of the current character so far
    protected bit parity_bit[2];
    protected bit char_flag[2];
    protected bit [7:0] payload[2];   // data LSB first, or the 2 control bits
    protected bit prev_payload_xor[2];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      rx_raw_ap = new("rx_raw_ap", this);
      tx_raw_ap = new("tx_raw_ap", this);
      rx_silence_ev = new("rx_silence_ev");
      tx_silence_ev = new("tx_silence_ev");
      active_ev[0] = new("rx_active_ev");
      active_ev[1] = new("tx_active_ev");
      void'(uvm_config_db #(realtime)::get(this, "", "silence_timeout", silence_timeout));
      void'(uvm_config_db #(realtime)::get(this, "", "min_bit_period", min_bit_period));

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
        watch_edges(0);
        watch_edges(1);
        watch_silence(0);
        watch_silence(1);
      join
    endtask

    protected function string path_name(bit tx_path);
      return tx_path ? "TX" : "RX";
    endfunction

    // Turns D/S changes into bits
    protected task watch_edges(bit tx_path);
      logic d, s;
      bit x, x_last = 0;
      realtime t;

      forever begin
        if (tx_path)
          @(vif.dout or vif.sout);
        else
          @(vif.din or vif.sin);
        t = $realtime;
        #(settle_time);

        d = tx_path ? vif.dout : vif.din;
        s = tx_path ? vif.sout : vif.sin;
        if ($isunknown({d, s})) continue; // before reset
        x = d ^ s;
        // nothing changed in the end, or D and S changed together (a
        // transmitter reset): not a bit
        if (x == x_last) continue;
        x_last = x;

        if (active[tx_path] && min_bit_period > 0 && t - last_edge[tx_path] < min_bit_period) begin
          `uvm_warning(get_type_name(), $sformatf("%s path: glitch, two bits %0t apart",
                                                  path_name(tx_path), t - last_edge[tx_path]))
        end
        last_edge[tx_path] = t;
        if (!active[tx_path]) begin
          active[tx_path] = 1;
          active_ev[tx_path].trigger();
        end
        push_bit(tx_path, d);
      end
    endtask

    // Sleeps while bits arrive, and marks the path idle silence_timeout
    // after its last edge. Wakes about once per silence_timeout, not per bit.
    protected task watch_silence(bit tx_path);
      forever begin
        if (!active[tx_path]) active_ev[tx_path].wait_trigger();
        while ($realtime < last_edge[tx_path] + silence_timeout)
          #(last_edge[tx_path] + silence_timeout - $realtime);
        go_idle(tx_path);
      end
    endtask

    protected function void go_idle(bit tx_path);
      if (nbits[tx_path] > 0) begin
        `uvm_info(get_type_name(), $sformatf("%s path went idle %0d bits into a character, dropping it",
                                             path_name(tx_path), nbits[tx_path]), UVM_MEDIUM)
      end
      active[tx_path] = 0;
      nbits[tx_path] = 0;
      prev_payload_xor[tx_path] = 0;
      if (tx_path)
        tx_silence_ev.trigger();
      else
        rx_silence_ev.trigger();
    endfunction

    // Each character is published as soon as its last bit arrives. Its
    // parity bit covers the previous character's payload plus its own parity
    // and control flag, so a parity error belongs to the character that
    // carries the wrong parity bit.
    protected function void push_bit(bit tx_path, bit d);
      int unsigned n = nbits[tx_path];

      if (n == 0)
        parity_bit[tx_path] = d;
      else if (n == 1)
        char_flag[tx_path] = d;
      else if (char_flag[tx_path])
        payload[tx_path][3 - n] = d; // control code, bit 1 first
      else
        payload[tx_path][n - 2] = d; // data, LSB first
      nbits[tx_path] = n + 1;

      if (nbits[tx_path] == (char_flag[tx_path] ? 4 : 10) && nbits[tx_path] > 2)
        publish_char(tx_path);
    endfunction

    protected function void publish_char(bit tx_path);
      ds_raw_item item = ds_raw_item::type_id::create("item");
      bit [1:0] ctl_char_code = payload[tx_path][1:0];

      item.data = 0;
      item.inject_parity_err = 0;
      // odd parity: a correct character always xors to 1
      item.got_parity_err = ~(prev_payload_xor[tx_path] ^ parity_bit[tx_path] ^ char_flag[tx_path]);

      if (char_flag[tx_path]) begin // control character
        case (ctl_char_code)
          SPW_CHAR_FCT_CODE : item.typ = SPW_RAW_FCT;
          SPW_CHAR_EOP_CODE : item.typ = SPW_RAW_EOP;
          SPW_CHAR_EEP_CODE : item.typ = SPW_RAW_EEP;
          SPW_CHAR_ESC_CODE : item.typ = SPW_RAW_ESC;
        endcase
        prev_payload_xor[tx_path] = ^ ctl_char_code;
      end
      else begin // data character
        item.typ = SPW_RAW_DATA;
        item.data = payload[tx_path];
        prev_payload_xor[tx_path] = ^ payload[tx_path];
      end
      nbits[tx_path] = 0;

      if (tx_path)
        tx_raw_ap.write(item);
      else
        rx_raw_ap.write(item);
    endfunction

  endclass
endpackage
