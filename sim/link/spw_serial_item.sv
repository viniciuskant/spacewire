package serial_item_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class spw_serial_base_item extends uvm_sequence_item;
    `uvm_object_utils(spw_serial_base_item)
    function new(string name = "spw_serial_base_item");
      super.new(name);
    endfunction

    virtual function string convert2str();
    endfunction
  endclass

  class spw_serial_config_item extends spw_serial_base_item;
    spw_config_type_e typ;
    real new_baud_rate_mhz;

    `uvm_object_utils_begin(spw_serial_config_item)
      `uvm_field_enum(spw_config_type_e, typ, UVM_ALL_ON)
      `uvm_field_real(new_baud_rate_mhz, UVM_ALL_ON) `uvm_object_utils_end

    function new(string name = "spw_serial_config_item");
      super.new(name);
    endfunction

    virtual function string convert2str();
      string s;
      s = $sformatf("SPW_CFG type=%s", typ.name());
      return s;
    endfunction
  endclass

  class spw_serial_char_item extends spw_serial_base_item;
    rand spw_char_type_e typ;
    rand byte data; // valid for SPW_CHAR_DATA

    // Error injection controls - consumed by the driver's encode step
    bit inject_parity_err;
    // Is 1 if the reconstructed packet has the wrong parity
    bit parity_err_detected;

    `uvm_object_utils_begin(spw_serial_char_item)
      `uvm_field_enum(spw_char_type_e, typ, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_parity_err, UVM_ALL_ON)
      `uvm_field_int(parity_err_detected, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "spw_serial_char_item");
      super.new(name);
    endfunction

    constraint ctl_no_data {
      (typ != SPW_CHAR_DATA && typ != SPW_CHAR_TIMECODE) -> (data == 0);
    }

    virtual function string convert2string();
      string s;
      s = $sformatf("SPW_CHAR type=%s", typ.name());
      if (typ == SPW_CHAR_DATA)
        s = {s, $sformatf(" data=0x%0h", data)};
      if (typ == SPW_CHAR_TIMECODE)
        s = {s, $sformatf(" tc_value=%0d", data)};
      if (inject_parity_err)
        s = {s, " [PARITY_ERR]"};
      return s;
    endfunction

  endclass
endpackage
