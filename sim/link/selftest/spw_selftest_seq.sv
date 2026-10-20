package selftest_seq_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  `include "uvm_macros.svh"

  class spw_selftest_seq extends uvm_sequence #(ds_base_item);
    `uvm_object_utils(spw_selftest_seq)

    function new(string name = "spw_selftest_seq");
      super.new(name);
    endfunction

    rand int num;

    constraint c1 {
      soft num inside {[20:100]};
    }

    virtual task body();
      int parity_err = 0;
      int esc_err = 0;
      ds_config_item rst_item = ds_config_item::type_id::create("rst_item");

      start_item(rst_item);
      `uvm_info("SEQ", "Generating reset config item", UVM_HIGH)
      rst_item.typ = SPW_CFG_RESET;
      finish_item(rst_item);

      for (int i = 0; i < num; ++i) begin
        ds_char_item item = ds_char_item::type_id::create("item");
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

        // randomly inject an escape error in NULLs and timecodes
        if (item.typ inside {SPW_CHAR_NULL, SPW_CHAR_TIMECODE}) begin
          if (!std::randomize(esc_err) with {esc_err inside {[0:10]}; }) begin
            `uvm_fatal(get_type_name(), "failed to randomize esc_err")
          end
          if (esc_err == 0)
            item.inject_esc_err = 1;
        end

        `uvm_info("SEQ", $sformatf("Generate new item: %s", item.convert2string()), UVM_HIGH)
        finish_item(item);
      end

      `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
    endtask

  endclass
endpackage
