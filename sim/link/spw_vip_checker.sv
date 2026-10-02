package selftest_checker_pkg;
  import uvm_pkg::*;
  import serial_item_pkg::*;
  `include "uvm_macros.svh"

  /// Class for sanity checking the VIP
  class spw_selftest_checker extends uvm_component;
    `uvm_component_utils(spw_selftest_checker)

    uvm_tlm_analysis_fifo #(spw_serial_char_item) driver_fifo;
    uvm_tlm_analysis_fifo #(spw_serial_char_item) mon_rx_fifo;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      driver_fifo = new("driver_fifo", this);
      mon_rx_fifo = new("mon_rx_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
      spw_serial_char_item exp_item, next_exp_item, act_item;

      driver_fifo.get(exp_item);
      forever begin
        mon_rx_fifo.get(act_item);
        driver_fifo.get(next_exp_item);

        // Verify Character Type and Data Match
        if (exp_item.typ != act_item.typ || exp_item.data != act_item.data) begin
          `uvm_error(
            "INTF_CHK",
            $sformatf("MISMATCH! Expected: %s, Observed: %s", exp_item.convert2string(), act_item.convert2string())
          )
        end

        // Verify Parity Error (current actual vs NEXT expected)
        if (next_exp_item.inject_parity_err != act_item.parity_err_detected) begin
          `uvm_error(
            "INTF_CHK",
            $sformatf("PARITY MISMATCH! Injected: %0b, Observed: %0b", exp_item.inject_parity_err, act_item.parity_err_detected)
          )
        end
        exp_item = next_exp_item;
      end
    endtask
  endclass
endpackage
