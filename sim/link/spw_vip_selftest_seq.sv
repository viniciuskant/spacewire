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

        `uvm_info("SEQ", $sformatf("Generate new item: %s", item.convert2str()), UVM_HIGH)
        finish_item(item);
      end
      `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
    endtask
    virtual task send_item(spw_serial_base_item item);
      start_item(item);
      `uvm_info("SEQ", $sformatf("Generate new item: %s", item.convert2str()), UVM_HIGH)
      finish_item(item);
    endtask
    virtual function spw_serial_config_item item_reset();
      spw_serial_config_item item = spw_serial_config_item::type_id::create("item");
      item.typ = SPW_CFG_RESET;
      return item;
    endfunction
    virtual function spw_serial_config_item item_set_speed(real mhz);
      spw_serial_config_item item = spw_serial_config_item::type_id::create("item");
      item.typ = SPW_CFG_SPEED;
      item.new_baud_rate_mhz = mhz;
      return item;
    endfunction
    virtual function spw_serial_char_item item_data(byte d);
      spw_serial_char_item item = spw_serial_char_item::type_id::create("item");
      item.typ = SPW_CHAR_DATA;
      item.data = d;
      return item;
    endfunction
    virtual function spw_serial_char_item item_timecode(byte d);
      spw_serial_char_item item = spw_serial_char_item::type_id::create("item");
      item.typ = SPW_CHAR_TIMECODE;
      item.data = d;
      return item;
    endfunction
    virtual function spw_serial_char_item item_fct();
      spw_serial_char_item item = spw_serial_char_item::type_id::create("item");
      item.typ = SPW_CHAR_FCT;
      item.data = 0;
      return item;
    endfunction
    virtual function spw_serial_char_item item_null();
      spw_serial_char_item item = spw_serial_char_item::type_id::create("item");
      item.typ = SPW_CHAR_NULL;
      item.data = 0;
      return item;
    endfunction
  endclass
endpackage
