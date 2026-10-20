package ds_item_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class ds_base_item extends uvm_sequence_item;
    `uvm_object_utils(ds_base_item)
    function new(string name = "ds_base_item");
      super.new(name);
    endfunction

  endclass

  class ds_config_item extends ds_base_item;
    ds_config_kind_e typ;
    real new_baud_rate_mhz;

    `uvm_object_utils_begin(ds_config_item)
      `uvm_field_enum(ds_config_kind_e, typ, UVM_ALL_ON)
      `uvm_field_real(new_baud_rate_mhz, UVM_ALL_ON) `uvm_object_utils_end

    function new(string name = "ds_config_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      string s;
      s = $sformatf("SPW_CFG type=%s", typ.name());
      return s;
    endfunction
  endclass


  /// Raw character class. Doesn't containt NULLs or TIMECODES
  class ds_raw_item extends uvm_sequence_item;
    rand ds_raw_kind_e typ;
    rand bit [7:0] data;
    rand bit inject_parity_err;
    bit got_parity_err;

    `uvm_object_utils_begin(ds_raw_item)
      `uvm_field_enum(ds_raw_kind_e, typ, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_parity_err, UVM_ALL_ON)
      `uvm_field_int(got_parity_err, UVM_ALL_ON)
    `uvm_object_utils_end


    function new(string name = "ds_token_item");
      super.new(name);
    endfunction
  endclass

  class ds_char_item extends uvm_sequence_item;
    rand ds_char_kind_e typ;
    rand bit inject_parity_err;
    rand bit inject_esc_err;
    rand bit [7:0] data; // valid for SPW_CHAR_DATA
    ds_err_e err; // set by the decoder, ERR_NONE for valid characters
    ds_raw_item bad_raw; // raw item that triggered the error

    `uvm_object_utils_begin(ds_char_item)
      `uvm_field_enum(ds_char_kind_e, typ, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_esc_err, UVM_ALL_ON)
      `uvm_field_int(inject_parity_err, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ds_char_item");
      super.new(name);
    endfunction

    constraint c_typ_before {
      solve typ before data;
    }
    constraint ctl_no_data {
      (typ != SPW_CHAR_DATA && typ != SPW_CHAR_TIMECODE) -> (data == 0);
    }
    constraint c_esc_err {
      (typ != SPW_CHAR_TIMECODE && typ != SPW_CHAR_NULL) -> (inject_esc_err == 0);
    }

    virtual function string convert2string();
      string s;
      s = $sformatf("SPW_CHAR type=%s", typ.name());
      if (typ == SPW_CHAR_DATA)
        s = {s, $sformatf(" data=0x%0h", data)};
      if (typ == SPW_CHAR_TIMECODE)
        s = {s, $sformatf(" tc_value=%0d", data)};
      return s;
    endfunction

  endclass
endpackage
