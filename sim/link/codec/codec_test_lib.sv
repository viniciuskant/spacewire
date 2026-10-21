package codec_test_lib_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  import codec_env_pkg::*;
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
    endfunction

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
endpackage
