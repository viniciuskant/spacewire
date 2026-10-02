package serial_monitor_pkg;

  import uvm_pkg::*;
  import serial_item_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class spw_serial_monitor extends uvm_monitor;
    `uvm_component_utils(spw_serial_monitor)

    virtual spw_serial_if vif;
    // high-speed oversampling clock (2GHz)
    bit fast_clk;

    // clean, stable signals
    logic filtered_sin, filtered_din;
    logic filtered_sout, filtered_dout;

    logic recovered_clk_rx;
    logic recovered_clk_tx;

    uvm_analysis_port #(spw_serial_char_item) rx_analysis_port;
    uvm_analysis_port #(spw_serial_char_item) tx_analysis_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task generate_fast_clk();
      fast_clk = 0;
      forever begin
        #250ps;
        fast_clk = ~fast_clk;
      end

    endtask

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      rx_analysis_port = new("rx_analysis_port", this);
      tx_analysis_port = new("tx_analysis_port", this);

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
        generate_fast_clk();
        recover_clock();
        monitor_tx_path();
        monitor_rx_path();
      join

    endtask

    virtual task monitor_rx_path();
      decode_char(0);
    endtask
    virtual task monitor_tx_path();
      decode_char(1);
    endtask
    virtual task recover_clock();
      // shift registers for filtering
      logic [2:0] din_shift, sin_shift;
      logic next_din, next_sin;

      logic [2:0] dout_shift, sout_shift;
      logic next_dout, next_sout;

      forever begin
        @(posedge fast_clk);
        din_shift = {din_shift[1:0], vif.din};
        sin_shift = {sin_shift[1:0], vif.sin};
        dout_shift = {dout_shift[1:0], vif.dout};
        sout_shift = {sout_shift[1:0], vif.sout};

        if (din_shift == 3'b000)
          next_din = 0;
        if (din_shift == 3'b111)
          next_din = 1;

        if (sin_shift == 3'b000)
          next_sin = 0;
        if (sin_shift == 3'b111)
          next_sin = 1;

        if (dout_shift == 3'b000)
          next_dout = 0;
        if (dout_shift == 3'b111)
          next_dout = 1;

        if (sout_shift == 3'b000)
          next_sout = 0;
        if (sout_shift == 3'b111)
          next_sout = 1;

        filtered_din <= next_din;
        filtered_sin <= next_sin;
        recovered_clk_tx <= next_din ^ next_sin;

        filtered_dout <= next_dout;
        filtered_sout <= next_sout;
        recovered_clk_rx <= next_dout ^ next_sout;
      end
    endtask

    virtual task decode_char(bit tx_path);
      bit [7:0] prev_char_buf;
      bit [1:0] ctl_char_code;
      spw_char_type_e prev_typ;
      bit curr_char_flag;
      bit curr_parity_bit;
      bit parity_result = 0;
      bit first = 1;
      bit seen_esc = 0;
      bit is_null = 0;
      bit is_timecode = 0;
      spw_serial_char_item item;

      forever begin
        is_null = 0;
        is_timecode = 0;
        // get the parity bit and flag bit
        get_d(tx_path, curr_parity_bit);
        get_d(tx_path, curr_char_flag);

        // If it's not the first parity bit, we'll create the item.
        // We can only send the previous item after receiving the next item's
        // parity bit and control flag, so we can check the parity.
        if (first)
          first = 0;
        else begin
          item = spw_serial_char_item::type_id::create("item", this);
          item.typ = prev_typ;
          item.data = 0;
          item.inject_parity_err = 0;

          // initiate the parity calculation according to the character type
          case (prev_typ)
            SPW_CHAR_DATA : begin
              item.data = prev_char_buf;
              parity_result = ^ prev_char_buf;
              if (seen_esc)
                is_timecode = 1;
              seen_esc = 0;
            end
            SPW_CHAR_FCT : begin
              parity_result = ^ SPW_CHAR_FCT_CODE;
              if (seen_esc)
                is_null = 1;
              seen_esc = 0;
            end
            SPW_CHAR_EOP : begin
              parity_result = ^ SPW_CHAR_EOP_CODE;
              seen_esc = 0;
            end
            SPW_CHAR_EEP : begin
              parity_result = ^ SPW_CHAR_EEP_CODE;
              seen_esc = 0;
            end
            SPW_CHAR_ESC : begin
              parity_result = ^ SPW_CHAR_ESC_CODE;
              seen_esc = 1;
            end
            default : `uvm_fatal(get_type_name(), "shouldn't happen")
          endcase
          // the parity calculation of a character without error must always
          // result in 1, because the parity field must produce odd parity.
          // if the parity_result is 0, we have a parity error
          parity_result = parity_result ^ curr_parity_bit ^ curr_char_flag;
          item.parity_err_detected = ~parity_result;

          if (is_null) begin
            item.typ = SPW_CHAR_NULL;
          end

          // if it's a ESC character, we're not sending
          if (!seen_esc) begin
            if (tx_path)
              tx_analysis_port.write(item);
            else
              rx_analysis_port.write(item);
          end
        end

        // if the character is a control code
        if (curr_char_flag) begin
          get_d(tx_path, ctl_char_code[1]);
          get_d(tx_path, ctl_char_code[0]);

          case (ctl_char_code)
            SPW_CHAR_FCT_CODE : prev_typ = SPW_CHAR_FCT;
            SPW_CHAR_EOP_CODE : prev_typ = SPW_CHAR_EOP;
            SPW_CHAR_EEP_CODE : prev_typ = SPW_CHAR_EEP;
            SPW_CHAR_ESC_CODE : prev_typ = SPW_CHAR_ESC;
            default : `uvm_fatal(get_type_name(), "invalid ctl char code")
          endcase
        end
        else begin // if the character is a NCHAR
          prev_typ = SPW_CHAR_DATA;
          for (int i = 0; i < 8; ++i) begin
            get_d(tx_path, prev_char_buf[i]);
          end
        end
      end
    endtask

    virtual task get_d(bit tx_path, output bit d);
      if (tx_path) begin
        @(recovered_clk_tx);
        d = filtered_din;
      end
      else begin
        @(recovered_clk_rx);
        d = filtered_dout;
      end
    endtask

  endclass
endpackage
