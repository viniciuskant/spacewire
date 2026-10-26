package ds_item_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  /// Common base of everything the DS sequencers carry, so configuration
  /// items can travel down the same path as characters.
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
      `uvm_field_real(new_baud_rate_mhz, UVM_ALL_ON)
    `uvm_object_utils_end

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
  class ds_raw_item extends ds_base_item;
    rand ds_raw_kind_e typ;
    rand bit [7:0] data; // valid for SPW_RAW_DATA
    rand bit inject_parity_err;
    bit got_parity_err; // set by the monitor

    `uvm_object_utils_begin(ds_raw_item)
      `uvm_field_enum(ds_raw_kind_e, typ, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_parity_err, UVM_ALL_ON)
      `uvm_field_int(got_parity_err, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ds_raw_item");
      super.new(name);
    endfunction

    constraint ctl_no_data {
      (typ != SPW_RAW_DATA) -> (data == 0);
    }

    virtual function string convert2string();
      string s;
      s = $sformatf("SPW_RAW type=%s", typ.name());
      if (typ == SPW_RAW_DATA)
        s = {s, $sformatf(" data=0x%0h", data)};
      if (inject_parity_err)
        s = {s, " inject_parity_err"};
      if (got_parity_err)
        s = {s, " got_parity_err"};
      return s;
    endfunction
  endclass

  class ds_char_item extends ds_base_item;
    rand ds_char_kind_e typ;
    rand bit inject_parity_err;
    rand bit inject_esc_err;
    rand bit [7:0] data; // valid for SPW_CHAR_DATA and SPW_CHAR_TIMECODE
    ds_err_e err; // set by the decoder, ERR_NONE for valid characters
    bit got_parity_err; // set by the decoder
    ds_raw_item bad_raw; // raw item that triggered the error

    `uvm_object_utils_begin(ds_char_item)
      `uvm_field_enum(ds_char_kind_e, typ, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_esc_err, UVM_ALL_ON)
      `uvm_field_int(inject_parity_err, UVM_ALL_ON)
      `uvm_field_enum(ds_err_e, err, UVM_ALL_ON)
      `uvm_field_int(got_parity_err, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ds_char_item");
      super.new(name);
    endfunction

    constraint c_typ_before {
      solve typ before data;
    }
    // SPW_CHAR_ERROR is only produced by the decoder
    constraint c_no_error {
      typ != SPW_CHAR_ERROR;
    }
    constraint ctl_no_data {
      (typ != SPW_CHAR_DATA && typ != SPW_CHAR_TIMECODE) -> (data == 0);
    }
    constraint c_esc_err {
      (typ != SPW_CHAR_TIMECODE && typ != SPW_CHAR_NULL) -> (inject_esc_err == 0);
    }
    // errors are opt-in: sequences override these when they want them
    constraint c_no_err_default {
      soft inject_parity_err == 0;
      soft inject_esc_err == 0;
    }

    virtual function string convert2string();
      string s;
      s = $sformatf("SPW_CHAR type=%s", typ.name());
      if (typ == SPW_CHAR_DATA)
        s = {s, $sformatf(" data=0x%0h", data)};
      if (typ == SPW_CHAR_TIMECODE)
        s = {s, $sformatf(" tc_value=%0d", data)};
      if (err != SPW_ERR_NONE)
        s = {s, $sformatf(" err=%s", err.name())};
      return s;
    endfunction

  endclass
endpackage
