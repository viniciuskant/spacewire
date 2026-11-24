package host_seq_lib_pkg;
  import uvm_pkg::*;
  import host_item_pkg::*;
  `include "uvm_macros.svh"

  /// Sends num random packets
  class host_packet_seq extends uvm_sequence #(host_base_item);
    `uvm_object_utils(host_packet_seq)

    rand int num;
    rand int unsigned max_len;

    constraint c_num {
      soft num inside {[5:30]};
      soft max_len == 64;
    }

    function new(string name = "host_packet_seq");
      super.new(name);
    endfunction

    virtual task body();
      for (int i = 0; i < num; ++i) begin
        host_packet_item pkt = host_packet_item::type_id::create("pkt");
        start_item(pkt);
        if (!pkt.randomize()) begin
          `uvm_fatal(get_type_name(), "failed to randomize packet")
        end
        // picked outside the solver: Verilator 5.052 ignores inline
        // constraints on data.size() and drops dist weights next to the
        // item's soft constraint. This also overrides the item's soft size
        pkt.end_marker = ($urandom_range(9) == 0) ? HOST_END_EEP : HOST_END_EOP;
        pkt.data = new[$urandom_range(max_len)];
        foreach (pkt.data[i]) pkt.data[i] = $urandom();
        `uvm_info("SEQ", $sformatf("Generate new packet: %s", pkt.convert2string()), UVM_HIGH)
        finish_item(pkt);
      end
      `uvm_info("SEQ", $sformatf("Done generation of %0d packets", num), UVM_LOW)
    endtask
  endclass

  /// Sends num random timecodes, min_gap_ns to max_gap_ns apart.
  ///
  /// The codec holds one timecode and drops a tick that comes while it is
  /// still sending the previous one (tx_timecode_slot), so the default gap
  /// leaves room for one: a timecode is 14 bits, 1.4 us at 10 Mbit/s.
  class host_timecode_seq extends uvm_sequence #(host_base_item);
    `uvm_object_utils(host_timecode_seq)

    rand int num;
    rand int unsigned min_gap_ns;
    rand int unsigned max_gap_ns;

    constraint c_num {
      soft num inside {[5:20]};
      soft min_gap_ns == 3000;
      soft max_gap_ns == 5000;
      min_gap_ns <= max_gap_ns;
    }

    function new(string name = "host_timecode_seq");
      super.new(name);
    endfunction

    virtual task body();
      for (int i = 0; i < num; ++i) begin
        host_timecode_item tc = host_timecode_item::type_id::create("tc");
        #($urandom_range(max_gap_ns, min_gap_ns) * 1ns);
        start_item(tc);
        if (!tc.randomize()) begin
          `uvm_fatal(get_type_name(), "failed to randomize timecode")
        end
        finish_item(tc);
      end
      `uvm_info("SEQ", $sformatf("Done generation of %0d timecodes", num), UVM_LOW)
    endtask
  endclass
endpackage
