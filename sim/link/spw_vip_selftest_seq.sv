package selftest_seq_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import serial_item_pkg::*;
  `include "uvm_macros.svh"

  class spw_selftest_seq extends uvm_sequence;
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
