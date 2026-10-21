package ds_monitor_pkg;

  import uvm_pkg::*;
  import ds_item_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class ds_monitor extends uvm_monitor;
    `uvm_component_utils(ds_monitor)

    virtual spw_serial_if vif;

    // clean, stable signals
    logic filtered_sin = 0, filtered_din = 0;
    logic filtered_sout = 0, filtered_dout = 0;

    // recovered from din/sin (what the IP receives)
    logic recovered_clk_rx = 0;
    // recovered from dout/sout (what the IP transmits)
    logic recovered_clk_tx = 0;

    // analysis port connected to the IP RX side (din/sin)
    uvm_analysis_port #(ds_raw_item) rx_raw_ap;
    // analysis port connected to the IP TX side (dout/sout)
    uvm_analysis_port #(ds_raw_item) tx_raw_ap;

    // A path with no transition for silence_timeout is idle: the character
    // being received is dropped and parity restarts with the next bit. This
    // resynchronizes after a link reset, where the transmitter sets D/S to 0.
    // Set with uvm_config_db #(realtime) "silence_timeout".
    realtime silence_timeout = 850ns;
    // triggered when a path that was sending goes idle
    uvm_event rx_silence_ev;
    uvm_event tx_silence_ev;

    // 1 while bits are arriving on the path, indexed by tx_path
    protected bit active[2];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      rx_raw_ap = new("rx_raw_ap", this);
      tx_raw_ap = new("tx_raw_ap", this);
      rx_silence_ev = new("rx_silence_ev");
      tx_silence_ev = new("tx_silence_ev");
      void'(uvm_config_db #(realtime)::get(this, "", "silence_timeout", silence_timeout));

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
        recover_clock();
        monitor_tx_path();
        monitor_rx_path();
      join

    endtask

    virtual task monitor_rx_path();
      decode_char(0);
    endtask
    virtual task monitor_tx_path();
      decode_char(1);
    endtask
    virtual task recover_clock();
      // shift registers for filtering
      logic [2:0] din_shift, sin_shift;
      logic next_din = 0, next_sin = 0;

      logic [2:0] dout_shift, sout_shift;
      logic next_dout = 0, next_sout = 0;

      forever begin
        @(posedge vif.fast_clk);
        din_shift = {din_shift[1:0], vif.din};
        sin_shift = {sin_shift[1:0], vif.sin};
        dout_shift = {dout_shift[1:0], vif.dout};
        sout_shift = {sout_shift[1:0], vif.sout};

        if (din_shift == 3'b000)
          next_din = 0;
        if (din_shift == 3'b111)
          next_din = 1;

        if (sin_shift == 3'b000)
          next_sin = 0;
        if (sin_shift == 3'b111)
          next_sin = 1;

        if (dout_shift == 3'b000)
          next_dout = 0;
        if (dout_shift == 3'b111)
          next_dout = 1;

        if (sout_shift == 3'b000)
          next_sout = 0;
        if (sout_shift == 3'b111)
          next_sout = 1;

        // class properties can't take nonblocking assignments. The data is
        // updated before the clock, so get_d() always samples the new value
        filtered_din = next_din;
        filtered_sin = next_sin;
        recovered_clk_rx = next_din ^ next_sin;

        filtered_dout = next_dout;
        filtered_sout = next_sout;
        recovered_clk_tx = next_dout ^ next_sout;
      end
    endtask

    // Each character is published as soon as its last bit arrives. Its
    // parity bit covers the previous character's payload plus its own parity
    // and control flag, so a parity error belongs to the character that
    // carries the wrong parity bit.
    virtual task decode_char(bit tx_path);
      bit prev_payload_xor = 0;
      int unsigned nbits;
      bit ok;
      ds_raw_item item;

      forever begin
        read_char(tx_path, prev_payload_xor, item, ok, nbits);
        if (ok) begin
          if (tx_path)
            tx_raw_ap.write(item);
          else
            rx_raw_ap.write(item);
        end
        else begin
          if (nbits > 0) begin
            `uvm_info(get_type_name(), $sformatf("%s path went idle %0d bits into a character, dropping it",
                                                 tx_path ? "TX" : "RX", nbits), UVM_MEDIUM)
          end
          prev_payload_xor = 0;
          if (tx_path)
            tx_silence_ev.trigger();
          else
            rx_silence_ev.trigger();
        end
      end
    endtask

    // ok = 0 if the path went idle before the character was complete
    protected task read_char(bit tx_path, inout bit prev_payload_xor, output ds_raw_item item,
                             output bit ok, output int unsigned nbits);
      bit [7:0] data;
      bit [1:0] ctl_char_code;
      bit char_flag;
      bit parity_bit;

      nbits = 0;
      item = null;

      get_d(tx_path, parity_bit, ok);
      if (!ok) return;
      nbits++;
      get_d(tx_path, char_flag, ok);
      if (!ok) return;
      nbits++;

      item = ds_raw_item::type_id::create("item");
      item.data = 0;
      item.inject_parity_err = 0;
      // odd parity: a correct character always xors to 1
      item.got_parity_err = ~(prev_payload_xor ^ parity_bit ^ char_flag);

      if (char_flag) begin // control character
        get_d(tx_path, ctl_char_code[1], ok);
        if (!ok) return;
        nbits++;
        get_d(tx_path, ctl_char_code[0], ok);
        if (!ok) return;
        nbits++;

        case (ctl_char_code)
          SPW_CHAR_FCT_CODE : item.typ = SPW_RAW_FCT;
          SPW_CHAR_EOP_CODE : item.typ = SPW_RAW_EOP;
          SPW_CHAR_EEP_CODE : item.typ = SPW_RAW_EEP;
          SPW_CHAR_ESC_CODE : item.typ = SPW_RAW_ESC;
        endcase
        prev_payload_xor = ^ ctl_char_code;
      end
      else begin // data character, LSB first
        for (int i = 0; i < 8; ++i) begin
          get_d(tx_path, data[i], ok);
          if (!ok) return;
          nbits++;
        end
        item.typ = SPW_RAW_DATA;
        item.data = data;
        prev_payload_xor = ^ data;
      end
    endtask

    // Waits for the next bit. An idle path waits forever for its first
    // transition; an active one gives up after silence_timeout (ok = 0).
    virtual task get_d(bit tx_path, output bit d, output bit ok);
      bit timed_out = 0;
      ok = 1;
      if (!active[tx_path]) begin
        wait_edge(tx_path);
        active[tx_path] = 1;
      end
      else begin
        fork
          begin
            fork
              wait_edge(tx_path);
              begin
                #(silence_timeout);
                timed_out = 1;
              end
            join_any
            disable fork;
          end
        join
        if (timed_out) begin
          ok = 0;
          active[tx_path] = 0;
          return;
        end
      end
      d = tx_path ? filtered_dout : filtered_din;
    endtask

    protected task wait_edge(bit tx_path);
      if (tx_path)
        @(recovered_clk_tx);
      else
        @(recovered_clk_rx);
    endtask

  endclass
endpackage
