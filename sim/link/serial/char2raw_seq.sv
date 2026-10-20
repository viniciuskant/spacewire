
package char2raw_pkg;
import uvm_pkg::*;
import ds_item_pkg::*;
import spw_defines_pkg::*;
`include "uvm_macros.svh"

/// This class translates from character items to raw items,
/// so we can send them to the driver.
class char2raw_seq extends uvm_sequence#(ds_raw_item);
  `uvm_object_utils(char2raw_seq)
  uvm_sequencer#(ds_char_item) up_sqr;   // set by the agent before start

  function new(string name = "char2raw_seq");
    super.new(name);
  endfunction

  task body();
    ds_char_item c;
    forever begin
      up_sqr.get_next_item(c);
      translate(c);
      up_sqr.item_done();
    end
  endtask

  task translate(ds_char_item c);
    case (c.typ)
      SPW_CHAR_DATA:     send_raw(SPW_RAW_DATA, c.data, c.inject_parity_err);
      SPW_CHAR_EOP:      send_raw(SPW_RAW_EOP, 0, c.inject_parity_err);
      SPW_CHAR_EEP:      send_raw(SPW_RAW_EEP, 0, c.inject_parity_err);
      SPW_CHAR_FCT:      send_raw(SPW_RAW_FCT, 0, c.inject_parity_err);
      SPW_CHAR_NULL:     begin
        send_raw(SPW_RAW_ESC, 0, c.inject_parity_err);
        // send another ESC on purpose
        // TODO: change this to send EOP/EEP as well
        if (c.inject_esc_err) begin
          send_raw(SPW_RAW_ESC);
        end else begin
          send_raw(SPW_RAW_FCT, 0, c.inject_parity_err);
        end
      end
      SPW_CHAR_TIMECODE: begin
        send_raw(SPW_RAW_ESC);
        // send another ESC on purpose
        // TODO: change this to send EOP/EEP as well
        if (c.inject_esc_err) begin
          send_raw(SPW_RAW_ESC);
        end else begin
          send_raw(SPW_RAW_DATA, c.data, c.inject_parity_err);
        end
      end
    endcase
  endtask

  task send_raw(ds_raw_kind_e k, bit [7:0] d = 0, bit parity_err = 0);
    ds_raw_item t = ds_raw_item::type_id::create("t");
    start_item(t);
    t.typ = k;  t.data = d;  t.inject_parity_err = parity_err;
    finish_item(t);
  endtask
endclass
endpackage