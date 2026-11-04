//=============================================================================
// spw_codec_utils.sv
// Single shared implementation of SpaceWire character <-> DS-bit-stream
// encoding, used by: link driver (serialize), link monitor (deserialize),
// and the reference model (golden re-check). Keeping this in exactly one
// place avoids the classic bug of the driver and checker disagreeing on
// parity/bit-order and masking real DUT defects.
//
// Character encoding per ECSS-E-ST-50-12C sec 7:
//   Each character is preceded by a parity bit, then a control-flag bit,
//   then either:
//     - 8 data bits (LSB first) if control-flag = 0 (data character), or
//     - 2 control bits if control-flag = 1 (control character):
//         00 = FCT, 01 = EOP, 10 = EEP, 11 = ESC
//   NULL = ESC followed immediately by FCT.
//   Timecode = ESC followed immediately by a data character carrying the
//              6-bit time value + 2-bit control flags.
//   Parity bit makes the count of 1s in {parity, control-flag, payload bits}
//   PLUS the previous character's control-flag+payload bits odd (parity is
//   computed across the boundary, not just within one character) -- verify
//   this against your spec revision, some texts describe it as running
//   parity seeded from the preceding character only.
//=============================================================================
package codec_utils_pkg;
  import spw_defines_pkg::*;

  class spw_encoder_util;

    // Running parity state carried between successive encode/decode calls.
    // Each driver/monitor instance should own its own persistent copy of this
    // class (not share one across independent link directions).
    local bit prev_payload_xor;

    function new();
      prev_payload_xor = 1'b0; // reset state (post ErrorReset, parity restarts)
    endfunction

    function void reset_state();
      prev_payload_xor = 1'b0;
    endfunction

    /// Encodes an NCHAR to be serialized
    function automatic bit [0:9] encode_n_char(bit [7:0] data, bit inject_parity_error = 0);
      bit [0:9] encoded;
      bit parity = ~prev_payload_xor;
      prev_payload_xor = ^ data;

      encoded[0] = parity ^ inject_parity_error;
      encoded[1] = 0;
      for (int i = 2; i < 10; ++i)
        encoded[i] = data[i-2];
      return encoded;

    endfunction

    /// Encodes an FCT to be serialized
    function automatic bit [0:3] encode_fct(bit inject_parity_error);
      return encode_ctl_char(SPW_CHAR_FCT_CODE, inject_parity_error);
    endfunction

    function automatic bit [0:3] encode_eop(bit inject_parity_error);
      return encode_ctl_char(SPW_CHAR_EOP_CODE, inject_parity_error);
    endfunction

    function automatic bit [0:3] encode_eep(bit inject_parity_error);
      return encode_ctl_char(SPW_CHAR_EEP_CODE, inject_parity_error);
    endfunction

    function automatic bit [0:3] encode_esc(bit inject_parity_error);
      return encode_ctl_char(SPW_CHAR_ESC_CODE, inject_parity_error);
    endfunction

    local function automatic bit [0:3] encode_ctl_char(bit [1:0] code, bit inject_parity_error);
      bit [0:3] encoded;
      bit parity = prev_payload_xor;
      prev_payload_xor = ^ code;

      encoded[0] = parity ^ inject_parity_error;
      encoded[1] = 1;
      encoded[2] = code[1];
      encoded[3] = code[0];

      return encoded;
    endfunction

    //-------------------------------------------------------------------
    // check_parity: recompute expected parity for a received character and
    // compare against the parity bit actually observed on the wire.
    // Returns 1 if parity is OK, 0 if a parity error is detected.
    //-------------------------------------------------------------------
    // function automatic bit check_parity(bit rx_parity_bit,
    //                                      bit ctrl_flag,
    //                                      bit [7:0] bits,
    //                                      int nbits);
    //   bit expected;
    //   expected = ctrl_flag ^ last_parity_bit ^ 1'b1;
    //   for (int i = 0; i < nbits; i++) expected ^= bits[i];
    //   //expected = ^{ctrl_flag, bits[nbits-1:0]} ^ last_parity_bit ^ 1'b1;
    //   last_parity_bit = rx_parity_bit; // running state always tracks the wire,
    //                                     // even on a mismatch, so we resync
    //   return (expected == rx_parity_bit);
    // endfunction

  endclass: spw_encoder_util

  class spw_decoder_util;
    // Running parity state carried between successive encode/decode calls.
    // Each driver/monitor instance should own its own persistent copy of this
    // class (not share one across independent link directions).
    local bit prev_payload_xor;

    local bit [7:0] char_shift;
    local bit char_flag;

    function new();
      prev_payload_xor = 1'b0; // reset state (post ErrorReset, parity restarts)
      char_shift = 8'b0;
      char_flag = 0;
    endfunction

    function void reset_state();
      prev_payload_xor = 1'b0;
      char_shift = 8'b0;
      char_flag = 0;
    endfunction

    function automatic void eat_bit(bit d);
      char_shift = {char_shift[6:0], d};
    endfunction
  endclass
endpackage
