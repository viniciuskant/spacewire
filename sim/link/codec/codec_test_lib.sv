package codec_test_lib_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  import codec_env_pkg::*;
  import host_seq_lib_pkg::*;
  import ds_seq_lib_pkg::*;
  `include "uvm_macros.svh"

  class codec_base_test extends uvm_test;
    `uvm_component_utils(codec_base_test)

    codec_env env0;
    virtual spw_serial_if ds_vif;
    virtual spw_host_if host_vif;

    function new(string name = "codec_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env0 = codec_env::type_id::create("env0", this);
      // a hung sequence or monitor fails the test instead of running forever
      uvm_root::get().set_timeout(10ms, 1);

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "ds_vif", ds_vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
      if (!uvm_config_db #(virtual spw_host_if)::get(this, "", "host_vif", host_vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_host_if")
      end
      uvm_config_db #(virtual spw_serial_if)::set(this, "env0.ds0.*", "vif", ds_vif);
      uvm_config_db #(virtual spw_host_if)::set(this, "env0.host0.*", "vif", host_vif);
      uvm_config_db #(bit)::set(this, "env0.ds0", "has_partner", 1);
    endfunction

    // returns 0 if the link did not come up in tmo
    protected task wait_link_up(realtime tmo, output bit ok);
      fork
        begin
          fork
            env0.ds0.partner.link_up_ev.wait_on();
            #(tmo);
          join_any
          disable fork;
        end
      join
      ok = env0.ds0.partner.link_is_up();
      if (!ok)
        `uvm_error(get_type_name(), $sformatf("link not up %0t after the start of the test", tmo))
    endtask

    // returns the time reset was released
    protected task wait_reset_done(output realtime t);
      wait (host_vif.rst_n === 1);
      t = $realtime;
    endtask
  endclass

  /// Leaves the partner silent and checks what the DUT does on its own after
  /// reset: ErrorReset (6.4us) -> ErrorWait (12.8us) -> Ready -> Started,
  /// where it may only send NULLs, then back to ErrorReset after 12.8us
  /// without a NULL from the partner.
  class codec_smoke_test extends codec_base_test;
    `uvm_component_utils(codec_smoke_test)

    // slack for the CDC and for a NULL being 8 bits long
    realtime tolerance = 2us;
    realtime run_time = 80us;

    uvm_tlm_analysis_fifo #(ds_char_item) dut_chars;
    realtime t_reset;
    realtime t_null[$]; // first NULL of each burst
    bit in_burst;
    ds_char_item last_char; // not checked until the next one arrives

    function new(string name = "codec_smoke_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // the partner stays silent
      uvm_config_db #(bit)::set(this, "env0.ds0", "has_partner", 0);
      dut_chars = new("dut_chars", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      env0.ds0.tx_decoder.char_ap.connect(dut_chars.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      wait_reset_done(t_reset);
      fork
        watch_dut_chars();
        watch_bursts();
        #(run_time);
      join_any
      disable fork;
      phase.drop_objection(this);
    endtask

    // A burst starts with the first character after the DUT's TX was idle.
    // The last character of a burst is not checked: the link reset that ends
    // the burst can cut it short, and the transition to D = S = 0 then reads
    // as one more 0 bit (an ESC cut after 3 bits looks like an EEP).
    protected task watch_dut_chars();
      ds_char_item c;
      forever begin
        dut_chars.get(c);
        if (!in_burst) begin
          in_burst = 1;
          t_null.push_back($realtime);
          `uvm_info("SMOKE", $sformatf("DUT started sending at %0t", $realtime), UVM_LOW)
        end
        if (last_char != null) check_char(last_char);
        last_char = c;
      end
    endtask

    protected task watch_bursts();
      forever begin
        env0.ds0.m0.tx_silence_ev.wait_trigger();
        if (in_burst) begin
          `uvm_info("SMOKE", $sformatf("DUT went idle at %0t", $realtime), UVM_LOW)
        end
        if (last_char != null && last_char.typ != SPW_CHAR_NULL) begin
          `uvm_info("SMOKE", $sformatf("last character of the burst was cut by the link reset, not checked: %s",
                                       last_char.convert2string()), UVM_LOW)
        end
        in_burst = 0;
        last_char = null;
      end
    endtask

    protected function void check_char(ds_char_item c);
      if (c.typ != SPW_CHAR_NULL || c.err != SPW_ERR_NONE) begin
        `uvm_error("SMOKE", $sformatf("DUT sent %s, but only NULLs are allowed before it receives a NULL",
                                      c.convert2string()))
      end
    endfunction

    virtual function void check_phase(uvm_phase phase);
      realtime exp_first = SPW_T_ERR_RST_DWELL + SPW_T_ERR_WAIT_DWELL;
      // Started timeout, then ErrorReset and ErrorWait again
      realtime exp_period = SPW_T_STARTED_TIMEOUT + SPW_T_ERR_RST_DWELL + SPW_T_ERR_WAIT_DWELL;
      super.check_phase(phase);

      if (t_null.size() == 0) begin
        `uvm_error("SMOKE", $sformatf("DUT sent nothing in %0t after reset", run_time))
        return;
      end

      check_time("first NULL after reset", t_null[0] - t_reset, exp_first);
      for (int i = 1; i < t_null.size(); i++)
        check_time($sformatf("NULL burst %0d to %0d", i - 1, i), t_null[i] - t_null[i-1], exp_period);
    endfunction

    protected function void check_time(string what, realtime got, realtime exp);
      if (got < exp - tolerance || got > exp + tolerance) begin
        `uvm_error("SMOKE", $sformatf("%s: %0.2fus, expected %0.2fus +- %0.2fus",
                                      what, got / 1us, exp / 1us, tolerance / 1us))
      end
      else begin
        `uvm_info("SMOKE", $sformatf("%s: %0.2fus (expected %0.2fus)", what, got / 1us, exp / 1us), UVM_LOW)
      end
    endfunction
  endclass

  /// Brings the link up with the partner and checks it stays up
  class codec_link_up_test extends codec_base_test;
    `uvm_component_utils(codec_link_up_test)

    realtime hold_time = 200us;

    function new(string name = "codec_link_up_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      bit ok;
      realtime t_reset;
      phase.raise_objection(this);
      wait_reset_done(t_reset);
      wait_link_up(100us, ok);
      if (ok) begin
        `uvm_info(get_type_name(), $sformatf("link up %0.2fus after reset",
                                             (env0.ds0.partner.t_link_up - t_reset) / 1us), UVM_LOW)
        #(hold_time);
        if (env0.ds0.partner.link_ups != 1 || !env0.ds0.partner.link_is_up())
          `uvm_error(get_type_name(), $sformatf("link did not stay up for %0t: %0d link ups, now in %s",
                                                hold_time, env0.ds0.partner.link_ups,
                                                env0.ds0.partner.state.name()))
      end
      phase.drop_objection(this);
    endtask
  endclass

  /// Random packets and timecodes in both directions at once, with random
  /// backpressure on the host RX FIFO to exercise flow control
  class codec_packet_test extends codec_base_test;
    `uvm_component_utils(codec_packet_test)

    realtime traffic_timeout = 3ms;

    host_packet_seq host_pkts;
    host_timecode_seq host_tcs;
    ds_packet_seq ds_pkts;
    ds_timecode_seq ds_tcs;

    function new(string name = "codec_packet_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      int unsigned rx_read_pct = $urandom_range(100, 5);
      super.build_phase(phase);
      uvm_config_db #(int unsigned)::set(this, "env0.host0.d0", "rx_read_pct", rx_read_pct);
      `uvm_info(get_type_name(), $sformatf("rx_read_pct=%0d", rx_read_pct), UVM_LOW)

      host_pkts = host_packet_seq::type_id::create("host_pkts");
      host_tcs = host_timecode_seq::type_id::create("host_tcs");
      ds_pkts = ds_packet_seq::type_id::create("ds_pkts");
      ds_tcs = ds_timecode_seq::type_id::create("ds_tcs");
      if (!host_pkts.randomize() || !host_tcs.randomize() || !ds_pkts.randomize() || !ds_tcs.randomize())
        `uvm_fatal(get_type_name(), "Failed to randomize sequences")
    endfunction

    virtual task run_phase(uvm_phase phase);
      bit ok;
      phase.raise_objection(this);
      wait_link_up(100us, ok);
      if (ok) begin
        fork
          begin
            fork
              host_pkts.start(env0.host0.s0);
              host_tcs.start(env0.host0.s0);
              ds_pkts.start(env0.ds0.s0);
              ds_tcs.start(env0.ds0.s0);
            join
          end
          begin
            #(traffic_timeout);
            `uvm_error(get_type_name(), $sformatf("sequences not done after %0t: partner has %0d credit from the DUT",
                                                  traffic_timeout, env0.ds0.partner.tx_credit))
          end
        join_any
        disable fork;
        env0.sb.wait_drained(500us);
        if (env0.ds0.partner.link_ups != 1)
          `uvm_error(get_type_name(), $sformatf("link went down during the test (%0d link ups)",
                                                env0.ds0.partner.link_ups))
      end
      phase.drop_objection(this);
    endtask
  endclass
endpackage
