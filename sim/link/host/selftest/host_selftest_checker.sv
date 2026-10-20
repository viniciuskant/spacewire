package host_selftest_checker_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  /// In-order comparator for the host VIP selftest: every item written to
  /// exp_fifo must show up, in order and equal, on act_fifo.
  class host_selftest_cmp #(type T = uvm_object) extends uvm_component;
    `uvm_component_param_utils(host_selftest_cmp #(T))

    uvm_tlm_analysis_fifo #(T) exp_fifo;
    uvm_tlm_analysis_fifo #(T) act_fifo;

    int items_checked = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      exp_fifo = new("exp_fifo", this);
      act_fifo = new("act_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
      T exp_item, act_item;
      forever begin
        exp_fifo.get(exp_item);
        act_fifo.get(act_item);
        if (!exp_item.compare(act_item)) begin
          `uvm_error("HOST_CHK", $sformatf("MISMATCH! Expected: %s, Observed: %s",
                                           exp_item.convert2string(), act_item.convert2string()))
        end
        items_checked++;
      end
    endtask

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (items_checked == 0) begin
        `uvm_error("HOST_CHK", "Simulation ended with 0 items checked!")
      end
      else begin
        `uvm_info("HOST_CHK", $sformatf("Successfully checked %0d items.", items_checked), UVM_LOW)
      end
      if (exp_fifo.used() > 0 || act_fifo.used() > 0) begin
        `uvm_error("HOST_CHK", $sformatf("Test ended with %0d expected / %0d observed unchecked items!",
                                         exp_fifo.used(), act_fifo.used()))
      end
    endfunction
  endclass
endpackage
