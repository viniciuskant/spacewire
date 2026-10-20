package basic_seq_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  `include "uvm_macros.svh"

// ---------------------------------------------------------------------------
// partner_bringup_seq.sv
//
// Partner side of the SpaceWire link initialization handshake:
//
//   1. start NULLs         (cfg.idle_mode = SEND_NULL; the driver fills idle
//                           time with NULLs, so none are sent one by one)
//   2. wait for DUT NULL
//   3. send cfg.fct_count FCTs
//   4. wait for DUT FCT
//   5. trigger link_up_ev
//
// Runs on partner_sequencer (character level). Reads the DUT's characters from
// p_sequencer.ser_fifo. Check `result` after the sequence finishes when
// running negative tests with cfg.report_errors = 0.
//
// Note: CH_ERROR items from the DUT are skipped while waiting. Add a check in
// wait_for() if you want a parity/ESC error during bring-up to abort it.
// ---------------------------------------------------------------------------

class partner_bringup_seq extends uvm_sequence#(ds_char_item);
  `uvm_object_utils(partner_bringup_seq)
  `uvm_declare_p_sequencer(partner_sequencer)

  typedef enum { WAIT_OK, WAIT_TIMEOUT, WAIT_ABORT } wait_res_e;

  typedef enum {
    BRINGUP_OK,
    BRINGUP_SKIPPED,        // start_mode == START_NEVER
    BRINGUP_NO_DUT_NULL,    // timed out waiting for the DUT's NULL
    BRINGUP_NO_DUT_FCT,     // timed out waiting for the DUT's FCT
    BRINGUP_ABORTED         // link was reset during bring-up
  } bringup_result_e;

  bringup_result_e result;

  function new(string name = "partner_bringup_seq");
    super.new(name);
  endfunction

  task body();
    partner_cfg cfg = p_sequencer.cfg;
    wait_res_e  res;
    bit         dut_null_seen = 0;

    result = BRINGUP_OK;

    if (cfg.start_mode == START_NEVER) begin
      result = BRINGUP_SKIPPED;
      return;
    end

    // Drop anything left over from before this bring-up.
    p_sequencer.ser_fifo.flush();

    // Reactive start: stay silent until the DUT transmits a NULL.
    if (cfg.start_mode == START_AFTER_DUT_NULL) begin
      wait_for(CH_NULL, cfg.t_null_timeout, res);
      if (!check_wait(res, BRINGUP_NO_DUT_NULL, "DUT NULL")) return;
      dut_null_seen = 1;
    end

    // Step 1: start transmitting NULLs.
    if (cfg.start_delay > 0) #(cfg.start_delay);
    cfg.idle_mode = SEND_NULL;

    // Step 2: DUT's NULL (the FIFO already holds it if it arrived early).
    if (!dut_null_seen) begin
      wait_for(CH_NULL, cfg.t_null_timeout, res);
      if (!check_wait(res, BRINGUP_NO_DUT_NULL, "DUT NULL")) return;
    end

    // Step 3: grant credit to the DUT.
    repeat (cfg.fct_count) begin
      send_char(CH_FCT);
      if (cfg.fct_gap > 0) #(cfg.fct_gap);
    end

    // Step 4: DUT's FCT (grants us credit, and moves both ends to Run).
    wait_for(CH_FCT, cfg.t_fct_timeout, res);
    if (!check_wait(res, BRINGUP_NO_DUT_FCT, "DUT FCT")) return;

    // Step 5
    p_sequencer.link_up_ev.trigger();
    `uvm_info("BRINGUP", "link up: NULL and FCT exchanged", UVM_MEDIUM)
  endtask

  // -------------------------------------------------------------------------

  // Send one logical character through the translator to the wire. Returns
  // when the raw driver has accepted all of its tokens, so a loop of these is
  // paced by the link rate.
  protected task send_char(ds_char_kind_e k);
    ds_char_item c = ds_char_item::type_id::create("c");
    start_item(c);
    c.kind = k;
    finish_item(c);
  endtask

  // Block until the DUT sends a character of kind k, the timeout expires, or
  // the link is reset. Other characters are discarded. The nested fork keeps
  // `disable fork` from killing anything outside this task.
  protected task wait_for(ds_char_kind_e k, time tmo, output wait_res_e res);
    ds_char_item c;
    res = WAIT_TIMEOUT;
    fork
      begin
        fork
          begin
            do p_sequencer.ser_fifo.get(c); while (c.kind != k);
            res = WAIT_OK;
          end
          begin
            #(tmo);
            res = WAIT_TIMEOUT;
          end
          begin
            p_sequencer.link_reset_ev.wait_trigger();
            res = WAIT_ABORT;
          end
        join_any
        disable fork;
      end
    join
  endtask

  protected function bit check_wait(wait_res_e res,
                                    bringup_result_e fail_result,
                                    string what);
    if (res == WAIT_OK) return 1;

    if (res == WAIT_ABORT) begin
      result = BRINGUP_ABORTED;
      `uvm_info("BRINGUP", $sformatf("aborted by link reset while waiting for %s", what), UVM_MEDIUM)
    end
    else begin
      result = fail_result;
      if (p_sequencer.cfg.report_errors)
        `uvm_error("BRINGUP", $sformatf("timeout waiting for %s", what))
    end
    return 0;
  endfunction
endclass
  class init_seq extends uvm_sequence;
    `uvm_object_utils(init_seq)

    function new(string name = "spw_selftest_seq");
      super.new(name);
    endfunction

    rand int num;

    constraint c1 {
      soft num inside {[20:100]};
    }

    virtual task body();
      int parity_err = 0;
      spw_serial_config_item rst_item = spw_serial_config_item::type_id::create("rst_item");
      spw_serial_char_item flush_item;

      start_item(rst_item);
      `uvm_info("SEQ", "Generating reset config item", UVM_HIGH)
      rst_item.typ = SPW_CFG_RESET;
      finish_item(rst_item);

      for (int i = 0; i < num; ++i) begin
        spw_serial_char_item item = spw_serial_char_item::type_id::create("item");
        start_item(item);
        if (!item.randomize()) begin
          `uvm_fatal(get_type_name(), "failed to randomize item")
        end

        // randomly inject a parity error in the characer
        if (!std::randomize(parity_err) with {parity_err inside {[0:20]}; }) begin
          `uvm_fatal(get_type_name(), "failed to randomize parity_err")
        end

        if (parity_err == 0)
          item.inject_parity_err = 1;

        `uvm_info("SEQ", $sformatf("Generate new item: %s", item.convert2string()), UVM_HIGH)
        finish_item(item);
      end
      flush_item = spw_serial_char_item::type_id::create("flush_item");
      start_item(flush_item);
      flush_item.typ = SPW_CHAR_NULL;
      flush_item.data = 0;
      `uvm_info("SEQ", "Sending NULL to flush monitor", UVM_HIGH)
      finish_item(flush_item);

      `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
    endtask

  endclass
endpackage
