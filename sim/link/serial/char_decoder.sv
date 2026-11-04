
package char_decoder_pkg;
import ds_item_pkg::*;
import spw_defines_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"
/// Decodes raw DS characters (ESC + DATA/FCT) into composed
/// characters (NULL/TIMECODE)
///
/// An ESC followed by EOP/EEP/ESC becomes SPW_CHAR_ERROR with err=SPW_ERR_ESC.
/// A parity error in any of the raw characters sets got_parity_err and, for
/// characters without an escape error, err=SPW_ERR_PARITY.
class char_decoder extends uvm_subscriber #(ds_raw_item);

  `uvm_component_utils(char_decoder)

  // this analysis port connects to the monitor's port
  uvm_analysis_port #(ds_char_item) char_ap;
  protected bit esc_pending;
  protected ds_raw_item esc_token;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    char_ap = new("char_ap", this);
  endfunction

  /// Forget a pending ESC, e.g. after a link reset
  function void reset();
    esc_pending = 0;
    esc_token = null;
  endfunction

  function void write(ds_raw_item t);
    ds_char_item c = ds_char_item::type_id::create("c");
    bit was_esc = esc_pending;

    c.data = 0;
    c.err = SPW_ERR_NONE;
    c.got_parity_err = t.got_parity_err | (was_esc && esc_token.got_parity_err);
    esc_pending = 0;

    case (t.typ)
        SPW_RAW_DATA: begin
            c.typ = was_esc ? SPW_CHAR_TIMECODE : SPW_CHAR_DATA;
            c.data = t.data;
        end
        SPW_RAW_FCT: begin
            c.typ = was_esc ? SPW_CHAR_NULL : SPW_CHAR_FCT;
        end
        SPW_RAW_EOP: begin
            c.typ = SPW_CHAR_EOP;
        end
        SPW_RAW_EEP: begin
            c.typ = SPW_CHAR_EEP;
        end
        SPW_RAW_ESC: begin
            if (!was_esc) begin
                // wait for the next character to decide what this is
                esc_pending = 1;
                esc_token = t;
                return;
            end
        end
    endcase

    if (was_esc && t.typ inside {SPW_RAW_EOP, SPW_RAW_EEP, SPW_RAW_ESC}) begin
        c.typ = SPW_CHAR_ERROR;
        c.err = SPW_ERR_ESC;
        c.bad_raw = t;
    end
    else if (c.got_parity_err) begin
        c.err = SPW_ERR_PARITY;
    end

    char_ap.write(c);
  endfunction
endclass
endpackage
