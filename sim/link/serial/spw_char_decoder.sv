
package char_decoder_pkg;
import serial_item_pkg::*;
import spw_defines_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"
class char_decoder extends uvm_subscriber #(ds_raw_item);

  `uvm_component_utils(char_decoder)

  uvm_analysis_port #(ds_char_item) char_ap;
  protected bit esc_pending;
  protected ds_raw_item esc_token;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    char_ap = new("char_ap", this);
  endfunction

  function void write(ds_raw_item t);
    ds_char_item c;
    c.data = 0;
    c.err = SPW_ERR_NONE;
    case (t.typ)
        SPW_RAW_DATA: begin
            if (esc_pending) begin
                c.typ = SPW_CHAR_TIMECODE;
                esc_pending = 0;
            end else begin
                c.typ = SPW_CHAR_DATA;
            end
            c.data = t.data;
        end
        SPW_RAW_FCT: begin
            if (esc_pending) begin
                c.typ = SPW_CHAR_NULL;
                esc_pending = 0;
            end else begin
                c.typ = SPW_CHAR_FCT;
            end
        end
        SPW_RAW_EOP: begin
            if (esc_pending) begin
                c.typ = SPW_CHAR_ERROR;
                c.err = SPW_ERR_ESC;
                c.bad_raw = t;
                esc_pending = 0;
            end else begin
                c.typ = SPW_CHAR_EOP;
            end
        end
        SPW_RAW_EEP: begin
            if (esc_pending) begin
                c.typ = SPW_CHAR_ERROR;
                c.err = SPW_ERR_ESC;
                c.bad_raw = t;
                esc_pending = 0;
            end else begin
            end
        end
        SPW_RAW_ESC: begin
            if (esc_pending) begin
                c.typ = SPW_CHAR_ERROR;
                c.err = SPW_ERR_ESC;
                c.bad_raw = t;
                esc_pending = 0;
            end else begin
                esc_pending = 1;
            end
        end
    endcase


  endfunction

endclass
endpackage