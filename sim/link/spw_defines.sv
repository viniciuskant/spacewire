//=============================================================================
// spw_defines.svh
// Shared types/enums/constants for the SpaceWire UVM environment.
// NOTE: Encoding/parity/timing details are drawn from ECSS-E-ST-50-12C.
//       Double-check bit ordering and parity polarity against your exact
//       spec revision and your DUT's register/timing spec before sign-off;
//       this file is written to be structurally correct and easy to audit,
//       not a substitute for a spec read-through.
//=============================================================================

package spw_defines_pkg;
  // Character-level type. Data and Timecode are "data characters";
  // FCT/EOP/EEP/ESC/NULL are built from "control characters".
  // NULL = ESC + FCT (two control chars back to back) at the character level,
  // modeled here as its own enum value for stimulus/coverage convenience.
  typedef enum bit [2:0] {
    SPW_CHAR_DATA,
    SPW_CHAR_FCT,
    SPW_CHAR_EOP,
    SPW_CHAR_EEP,
    SPW_CHAR_ESC,
    SPW_CHAR_NULL,
    SPW_CHAR_TIMECODE
  } spw_char_type_e;

  parameter bit [2:0] SPW_CHAR_FCT_CODE = 2'b00;
  parameter bit [2:0] SPW_CHAR_EOP_CODE = 2'b01;
  parameter bit [2:0] SPW_CHAR_EEP_CODE = 2'b10;
  parameter bit [2:0] SPW_CHAR_ESC_CODE = 2'b11;

  // Link state machine per ECSS-E-ST-50-12C section 8.5
  typedef enum bit [3:0] {
    SPW_ST_ERROR_RESET,
    SPW_ST_ERROR_WAIT,
    SPW_ST_READY,
    SPW_ST_STARTED,
    SPW_ST_CONNECTING,
    SPW_ST_RUN
  } spw_link_state_e;

  // Error injection modes usable by both char-level driver and link-partner agent
  typedef enum bit [2:0] {
    SPW_ERR_NONE,
    SPW_ERR_PARITY, // flip parity bit deliberately
    SPW_ERR_ESCAPE, // invalid character following ESC
    SPW_ERR_CREDIT_VIOLATE, // send more data than granted FCT credit
    SPW_ERR_DISCONNECT, // stop toggling D/S to force timeout
    SPW_ERR_TRUNC_EOP // truncate packet with EOP unexpectedly early
  } spw_err_inject_e;

  typedef enum int {
    SPW_CFG_RESET,
    SPW_CFG_SPEED
  } spw_config_type_e;

  // Flow control credit limits (ECSS-E-ST-50-12C 8.5.3)
  parameter int SPW_FCT_CREDIT_STEP = 8; // bytes granted per FCT
  parameter int SPW_FCT_CREDIT_MAX = 56; // max outstanding credit (7 FCTs)

  parameter realtime SPW_T_ERR_RST_DWELL = 12.8us;
  parameter realtime SPW_T_ERR_WAIT_DWELL = 6.4us;
endpackage
