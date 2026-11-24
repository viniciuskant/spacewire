package host_item_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // control words of the codec buffers (spw_pkg::CONST_EOP / CONST_EEP)
  parameter bit [8:0] HOST_WORD_EOP = 9'b1_0000_0000;
  parameter bit [8:0] HOST_WORD_EEP = 9'b1_0000_0001;

  typedef enum {
    HOST_END_EOP,
    HOST_END_EEP,
    HOST_END_NONE // no end marker, the next packet continues this one
  } host_end_e;

  typedef enum {
    HOST_CFG_RUN_DIV, // i_run_div
    HOST_CFG_LINK     // i_link_start, i_auto_start, i_link_disable
  } host_config_kind_e;

  /// Common base of everything the host sequencer carries
  class host_base_item extends uvm_sequence_item;
    `uvm_object_utils(host_base_item)
    function new(string name = "host_base_item");
      super.new(name);
    endfunction
  endclass

  class host_config_item extends host_base_item;
    host_config_kind_e typ;
    bit [6:0] run_div;  // HOST_CFG_RUN_DIV: run rate = 200 MHz / (run_div + 1)
    bit link_start;     // HOST_CFG_LINK
    bit auto_start;
    bit link_disable;

    `uvm_object_utils_begin(host_config_item)
      `uvm_field_enum(host_config_kind_e, typ, UVM_ALL_ON)
      `uvm_field_int(run_div, UVM_ALL_ON)
      `uvm_field_int(link_start, UVM_ALL_ON)
      `uvm_field_int(auto_start, UVM_ALL_ON)
      `uvm_field_int(link_disable, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "host_config_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      if (typ == HOST_CFG_RUN_DIV)
        return $sformatf("HOST_CFG type=%s run_div=%0d", typ.name(), run_div);
      return $sformatf("HOST_CFG type=%s link_start=%0b auto_start=%0b link_disable=%0b",
                       typ.name(), link_start, auto_start, link_disable);
    endfunction
  endclass

  /// A packet written to the TX FIFO or read from the RX FIFO
  class host_packet_item extends host_base_item;
    rand bit [7:0] data[];
    rand host_end_e end_marker;

    `uvm_object_utils_begin(host_packet_item)
      `uvm_field_array_int(data, UVM_ALL_ON)
      `uvm_field_enum(host_end_e, end_marker, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "host_packet_item");
      super.new(name);
    endfunction

    constraint c_size {
      data.size() <= 1024;
      soft data.size() inside {[1:64]};
    }
    // a soft == HOST_END_EOP would also win over a dist in randomize() with
    constraint c_end {
      soft end_marker != HOST_END_NONE;
    }

    /// FIFO words of this packet, end marker included
    function void to_words(ref bit [8:0] words[$]);
      words.delete();
      foreach (data[i]) words.push_back({1'b0, data[i]});
      case (end_marker)
        HOST_END_EOP: words.push_back(HOST_WORD_EOP);
        HOST_END_EEP: words.push_back(HOST_WORD_EEP);
        default: ;
      endcase
    endfunction

    virtual function string convert2string();
      string s = $sformatf("HOST_PKT len=%0d end=%s", data.size(), end_marker.name());
      for (int i = 0; i < data.size() && i < 8; i++)
        s = {s, $sformatf(" %02h", data[i])};
      if (data.size() > 8) s = {s, " ..."};
      return s;
    endfunction
  endclass

  class host_timecode_item extends host_base_item;
    rand bit [7:0] value;

    `uvm_object_utils_begin(host_timecode_item)
      `uvm_field_int(value, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "host_timecode_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("HOST_TC value=%0d", value);
    endfunction
  endclass
endpackage
