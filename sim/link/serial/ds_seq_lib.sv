package ds_seq_lib_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  `include "uvm_macros.svh"

  /// Sends num random packets from the partner: DATA characters ended by an
  /// EOP (or 1 in 10 times an EEP). The driver paces them by the DUT's credit.
  class ds_packet_seq extends uvm_sequence #(ds_base_item);
    `uvm_object_utils(ds_packet_seq)

    rand int num;
    rand int unsigned max_len;

    constraint c_num {
      soft num inside {[5:30]};
      soft max_len == 64;
    }

    function new(string name = "ds_packet_seq");
      super.new(name);
    endfunction

    virtual task body();
      for (int i = 0; i < num; ++i) begin
        int unsigned len = $urandom_range(max_len);
        for (int j = 0; j < len; ++j)
          send_char(SPW_CHAR_DATA, $urandom());
        send_char(($urandom_range(9) == 0) ? SPW_CHAR_EEP : SPW_CHAR_EOP);
      end
      `uvm_info("SEQ", $sformatf("Done generation of %0d packets", num), UVM_LOW)
    endtask

    protected task send_char(ds_char_kind_e k, bit [7:0] d = 0);
      ds_char_item c = ds_char_item::type_id::create("c");
      start_item(c);
      c.typ = k;
      c.data = d;
      finish_item(c);
    endtask
  endclass

  /// Sends num random timecodes from the partner, with up to max_gap_ns
  /// between them
  class ds_timecode_seq extends uvm_sequence #(ds_base_item);
    `uvm_object_utils(ds_timecode_seq)

    rand int num;
    rand int unsigned max_gap_ns;

    constraint c_num {
      soft num inside {[5:20]};
      soft max_gap_ns == 2000;
    }

    function new(string name = "ds_timecode_seq");
      super.new(name);
    endfunction

    virtual task body();
      for (int i = 0; i < num; ++i) begin
        ds_char_item c = ds_char_item::type_id::create("c");
        #($urandom_range(max_gap_ns) * 1ns);
        start_item(c);
        c.typ = SPW_CHAR_TIMECODE;
        c.data = $urandom();
        finish_item(c);
      end
      `uvm_info("SEQ", $sformatf("Done generation of %0d timecodes", num), UVM_LOW)
    endtask
  endclass
endpackage
