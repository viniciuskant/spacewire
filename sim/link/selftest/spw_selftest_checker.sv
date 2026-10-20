package selftest_checker_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  `include "uvm_macros.svh"

  /// Class for sanity checking the VIP. Compares what the agent sent against
  /// what the monitor and decoder observed on one direction of the link, at
  /// both the raw and the character level.
  class spw_selftest_checker extends uvm_component;
    `uvm_component_utils(spw_selftest_checker)

    uvm_tlm_analysis_fifo #(ds_raw_item) exp_raw_fifo;
    uvm_tlm_analysis_fifo #(ds_raw_item) act_raw_fifo;
    uvm_tlm_analysis_fifo #(ds_char_item) exp_char_fifo;
    uvm_tlm_analysis_fifo #(ds_char_item) act_char_fifo;

    int raw_checked = 0;
    int chars_checked = 0;
    int parity_errs_checked = 0;
    int esc_errs_checked = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      exp_raw_fifo = new("exp_raw_fifo", this);
      act_raw_fifo = new("act_raw_fifo", this);
      exp_char_fifo = new("exp_char_fifo", this);
      act_char_fifo = new("act_char_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
      fork
        check_raw();
        check_chars();
      join
    endtask

    protected task check_raw();
      ds_raw_item exp_item, act_item;
      forever begin
        exp_raw_fifo.get(exp_item);
        act_raw_fifo.get(act_item);

        if (exp_item.typ != act_item.typ || exp_item.data != act_item.data) begin
          `uvm_error(
            "RAW_CHK",
            $sformatf("MISMATCH! Expected: %s, Observed: %s", exp_item.convert2string(), act_item.convert2string())
          )
        end

        if (exp_item.inject_parity_err != act_item.got_parity_err) begin
          `uvm_error(
            "RAW_CHK",
            $sformatf("PARITY MISMATCH! Injected: %0b, Observed: %0b (%s)",
                      exp_item.inject_parity_err, act_item.got_parity_err, act_item.convert2string())
          )
        end

        raw_checked++;
      end
    endtask

    protected task check_chars();
      ds_char_item exp_item, act_item;
      ds_char_kind_e exp_typ;
      ds_err_e exp_err;
      forever begin
        exp_char_fifo.get(exp_item);
        act_char_fifo.get(act_item);

        exp_typ = exp_item.inject_esc_err ? SPW_CHAR_ERROR : exp_item.typ;
        exp_err = exp_item.inject_esc_err    ? SPW_ERR_ESC :
                  exp_item.inject_parity_err ? SPW_ERR_PARITY : SPW_ERR_NONE;

        if (exp_typ != act_item.typ || exp_err != act_item.err ||
            (exp_typ != SPW_CHAR_ERROR && exp_item.data != act_item.data)) begin
          `uvm_error(
            "CHAR_CHK",
            $sformatf("MISMATCH! Expected: %s, Observed: %s", exp_item.convert2string(), act_item.convert2string())
          )
        end

        if (exp_item.inject_parity_err != act_item.got_parity_err) begin
          `uvm_error(
            "CHAR_CHK",
            $sformatf("PARITY MISMATCH! Injected: %0b, Observed: %0b (%s)",
                      exp_item.inject_parity_err, act_item.got_parity_err, act_item.convert2string())
          )
        end

        chars_checked++;
        if (exp_item.inject_parity_err) parity_errs_checked++;
        if (exp_item.inject_esc_err) esc_errs_checked++;
      end
    endtask

    // catch trapped items and dead monitors
    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);

      if (raw_checked == 0 || chars_checked == 0) begin
        `uvm_error(
          "INTF_CHK",
          "Simulation ended with 0 items checked! Monitor is likely dead or disconnected."
        )
      end
      else begin
        `uvm_info("INTF_CHK", $sformatf("Successfully checked %0d raw items and %0d characters (%0d parity errors, %0d escape errors).",
                                         raw_checked, chars_checked, parity_errs_checked, esc_errs_checked), UVM_LOW)
      end

      // the sequence sent items but the monitor missed some
      if (exp_raw_fifo.used() > 0 || exp_char_fifo.used() > 0) begin
        `uvm_error(
          "INTF_CHK",
          $sformatf("Test ended with %0d raw / %0d char unchecked expected items!",
                    exp_raw_fifo.used(), exp_char_fifo.used())
        )
      end

      // the monitor saw garbage items the sequence didn't send
      if (act_raw_fifo.used() > 0 || act_char_fifo.used() > 0) begin
        `uvm_error(
          "INTF_CHK",
          $sformatf("Test ended with %0d raw / %0d char unexpected observed items!",
                    act_raw_fifo.used(), act_char_fifo.used())
        )
      end
    endfunction

  endclass
endpackage
