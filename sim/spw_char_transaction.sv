import uvm_pkg::*;
`include "uvm_macros.svh"

typedef enum logic [2:0] {
  TOKEN_NCHAR,
  TOKEN_FCT,
  TOKEN_NULL,
  TOKEN_EOP,
  TOKEN_EEP,
  TOKEN_TIMECODE,
  TOKEN_ERROR // injected illegal character sequence
} spw_char_e;

class spw_char_transaction extends uvm_sequence_item;
  rand spw_char_e char_type;
  rand bit [7:0] data_payload;
  rand bit [5:0] time_val;
  rand bit inject_parity_err;


  `uvm_object_utils_begin(spw_char_transaction)
    `uvm_field_enum(spw_char_e, char_type, UVM_ALL_ON)
    `uvm_field_int(data_payload, UVM_ALL_ON)
    `uvm_field_int(time_val, UVM_ALL_ON)
    `uvm_field_int(inject_parity_err, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "spw_char_transaction");
    super.new(name);
  endfunction
endclass
