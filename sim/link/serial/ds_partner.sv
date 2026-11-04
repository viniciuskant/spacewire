package ds_partner_pkg;
  import uvm_pkg::*;
  import spw_defines_pkg::*;
  import ds_item_pkg::*;
  `include "uvm_macros.svh"

  /// Link partner: the far end of the DUT's link (ECSS-E-ST-50-12C 8.5).
  ///
  /// Runs the link state machine from the characters the DUT sends (write())
  /// and tells the driver what it may send:
  ///   tx_enabled():      Started/Connecting/Run, idle time is filled with NULLs
  ///   fct_wanted():      Connecting/Run, while the DUT can take more credit
  ///   take_tx_credit():  one N-char, only in Run and with credit from the DUT
  ///
  /// Anything the DUT does that sends the link to ErrorReset (parity/escape
  /// errors, characters not allowed in the current state, credit errors,
  /// disconnects, start-up timeouts) is a uvm_error while report_errors is set.
  ///
  /// Knobs (uvm_config_db #(bit)): link_start, auto_fct, report_errors
  class ds_partner extends uvm_subscriber #(ds_char_item);
    `uvm_component_utils(ds_partner)

    bit link_start = 1;    // leave Ready on its own
    bit auto_fct = 1;      // grant credit to the DUT whenever there is room
    bit report_errors = 1; // link errors are DUT bugs

    link_state_e state = SPW_ST_ERROR_RESET;
    int tx_credit; // N-chars the DUT still accepts from us
    int rx_credit; // N-chars we still accept from the DUT
    int unsigned link_ups;
    realtime t_link_up;

    uvm_event link_up_ev;
    uvm_event link_down_ev;

    protected bit got_null;
    protected bit got_fct;
    protected bit error;
    protected uvm_event state_ev; // something the state machine waits on changed

    typedef enum { WAIT_NONE, WAIT_NULL, WAIT_FCT, WAIT_START } wait_e;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      link_up_ev = new("link_up_ev");
      link_down_ev = new("link_down_ev");
      state_ev = new("state_ev");
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'(uvm_config_db #(bit)::get(this, "", "link_start", link_start));
      void'(uvm_config_db #(bit)::get(this, "", "auto_fct", auto_fct));
      void'(uvm_config_db #(bit)::get(this, "", "report_errors", report_errors));
    endfunction

    // ---------------------------------------------------------------- driver

    function bit tx_enabled();
      return state inside {SPW_ST_STARTED, SPW_ST_CONNECTING, SPW_ST_RUN};
    endfunction

    function bit fct_wanted();
      return auto_fct && state inside {SPW_ST_CONNECTING, SPW_ST_RUN} &&
             rx_credit + SPW_FCT_CREDIT_STEP <= SPW_FCT_CREDIT_MAX;
    endfunction

    function void fct_sent();
      rx_credit += SPW_FCT_CREDIT_STEP;
    endfunction

    function bit take_tx_credit();
      if (state != SPW_ST_RUN || tx_credit == 0) return 0;
      tx_credit--;
      return 1;
    endfunction

    // ------------------------------------------------------------------ test

    function void start();
      link_start = 1;
      state_ev.trigger();
    endfunction

    function bit link_is_up();
      return state == SPW_ST_RUN;
    endfunction

    // ------------------------------------------------------------- receiver

    /// Characters received from the DUT
    function void write(ds_char_item t);
      if (state == SPW_ST_ERROR_RESET) return; // receiver held in reset

      if (t.err != SPW_ERR_NONE) begin
        link_error($sformatf("DUT sent %s", t.convert2string()));
        return;
      end

      case (t.typ)
        SPW_CHAR_NULL: got_null = 1;
        SPW_CHAR_FCT: begin
          if (state inside {SPW_ST_ERROR_WAIT, SPW_ST_READY, SPW_ST_STARTED}) begin
            link_error($sformatf("DUT sent an FCT in %s", state.name()));
          end
          else begin
            tx_credit += SPW_FCT_CREDIT_STEP;
            got_fct = 1;
            if (tx_credit > SPW_FCT_CREDIT_MAX)
              link_error($sformatf("credit error: DUT granted %0d characters, more than %0d",
                                   tx_credit, SPW_FCT_CREDIT_MAX));
          end
        end
        SPW_CHAR_DATA, SPW_CHAR_EOP, SPW_CHAR_EEP: begin
          if (state != SPW_ST_RUN) begin
            link_error($sformatf("DUT sent %s in %s", t.convert2string(), state.name()));
          end
          else if (rx_credit == 0) begin
            link_error($sformatf("credit error: DUT sent %s without credit", t.convert2string()));
          end
          else begin
            rx_credit--;
          end
        end
        SPW_CHAR_TIMECODE: begin
          if (state != SPW_ST_RUN)
            link_error($sformatf("DUT sent %s in %s", t.convert2string(), state.name()));
        end
        default: ;
      endcase
      state_ev.trigger();
    endfunction

    /// Called by the agent when the DUT's TX goes idle after sending
    function void dut_went_idle();
      if (state != SPW_ST_ERROR_RESET)
        link_error($sformatf("disconnect: DUT stopped sending in %s", state.name()));
    endfunction

    protected function void link_error(string msg);
      if (error) return; // already on the way to ErrorReset
      if (report_errors)
        `uvm_error(get_type_name(), msg)
      else
        `uvm_info(get_type_name(), msg, UVM_MEDIUM)
      error = 1;
      state_ev.trigger();
    endfunction

    // ---------------------------------------------------------- state machine

    virtual task run_phase(uvm_phase phase);
      bit ok;
      forever begin
        if (state == SPW_ST_RUN) link_down_ev.trigger();

        set_state(SPW_ST_ERROR_RESET);
        tx_credit = 0;
        rx_credit = 0;
        got_null = 0;
        got_fct = 0;
        #(SPW_T_ERR_RST_DWELL);
        error = 0;

        set_state(SPW_ST_ERROR_WAIT);
        wait_for(WAIT_NONE, SPW_T_ERR_WAIT_DWELL, ok);
        if (error) continue;

        set_state(SPW_ST_READY);
        wait_for(WAIT_START, 0, ok);
        if (!ok) continue;

        set_state(SPW_ST_STARTED);
        wait_for(WAIT_NULL, SPW_T_STARTED_TIMEOUT, ok);
        if (!ok) begin
          link_error("timeout in Started: no NULL from the DUT");
          continue;
        end

        set_state(SPW_ST_CONNECTING);
        wait_for(WAIT_FCT, SPW_T_CONNECTING_TIMEOUT, ok);
        if (!ok) begin
          link_error("timeout in Connecting: no FCT from the DUT");
          continue;
        end

        set_state(SPW_ST_RUN);
        link_ups++;
        t_link_up = $realtime;
        `uvm_info(get_type_name(), "link up", UVM_LOW)
        link_up_ev.trigger();
        wait_for(WAIT_NONE, 0, ok); // until an error
        `uvm_info(get_type_name(), "link down", UVM_LOW)
      end
    endtask

    protected function void set_state(link_state_e s);
      `uvm_info(get_type_name(), $sformatf("%s -> %s", state.name(), s.name()), UVM_HIGH)
      state = s;
    endfunction

    protected function bit cond_met(wait_e what);
      case (what)
        WAIT_NULL: return got_null;
        WAIT_FCT: return got_fct;
        WAIT_START: return link_start;
        default: return 0;
      endcase
    endfunction

    // Waits for what, an error or tmo (0 waits forever). ok = 1 if what happened
    protected task wait_for(wait_e what, realtime tmo, output bit ok);
      fork
        begin
          fork
            while (!error && !cond_met(what)) state_ev.wait_trigger();
            if (tmo > 0) #(tmo);
            else forever #1ms;
          join_any
          disable fork;
        end
      join
      ok = !error && cond_met(what);
    endtask

  endclass
endpackage
