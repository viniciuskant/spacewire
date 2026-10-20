package ds_monitor_pkg;

  import uvm_pkg::*;
  import ds_item_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class ds_monitor extends uvm_monitor;
    `uvm_component_utils(ds_monitor)

    virtual spw_serial_if vif;

    // clean, stable signals
    logic filtered_sin, filtered_din;
    logic filtered_sout, filtered_dout;

    logic recovered_clk_rx;
    logic recovered_clk_tx;

    // analysis port connected to the IP RX side
    uvm_analysis_port #(ds_raw_item) rx_raw_ap;
    // analysis port connected to the IP TX side
    uvm_analysis_port #(ds_raw_item) tx_raw_ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      rx_raw_ap = new("rx_raw_ap", this);
      tx_raw_ap = new("tx_raw_ap", this);

      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
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
        @(posedge vif.fast_clk);
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
      ds_raw_kind_e prev_typ;
      bit curr_char_flag;
      bit curr_parity_bit;
      bit parity_result = 0;
      bit first = 1;
      ds_raw_item item;

      forever begin
        // get the parity bit and flag bit
        get_d(tx_path, curr_parity_bit);
        get_d(tx_path, curr_char_flag);

        // If it's not the first parity bit, we'll create the item.
        // We can only send the previous item after receiving the next item's
        // parity bit and control flag, so we can check the parity.
        if (first)
          first = 0;
        else begin
          item = ds_raw_item::type_id::create("item");
          item.typ = prev_typ;
          item.data = 0;
          item.inject_parity_err = 0;

          // initiate the parity calculation according to the character type
          case (prev_typ)
            SPW_RAW_DATA : begin
              item.data = prev_char_buf;
              parity_result = ^ prev_char_buf;
            end
            SPW_RAW_FCT : begin
              parity_result = ^ SPW_CHAR_FCT_CODE;
            end
            SPW_RAW_EOP : begin
              parity_result = ^ SPW_CHAR_EOP_CODE;
            end
            SPW_RAW_EEP : begin
              parity_result = ^ SPW_CHAR_EEP_CODE;
            end
            SPW_RAW_ESC : begin
              parity_result = ^ SPW_CHAR_ESC_CODE;
            end
            default : `uvm_fatal(get_type_name(), "shouldn't happen")
          endcase
          // the parity calculation of a character without error must always
          // result in 1, because the parity field must produce odd parity.
          // if the parity_result is 0, we have a parity error
          parity_result = parity_result ^ curr_parity_bit ^ curr_char_flag;
          item.got_parity_err = ~parity_result;

          if (tx_path)
            tx_raw_ap.write(item);
          else
            rx_raw_ap.write(item);
        end

        // if the character is a control code
        if (curr_char_flag) begin
          get_d(tx_path, ctl_char_code[1]);
          get_d(tx_path, ctl_char_code[0]);

          case (ctl_char_code)
            SPW_CHAR_FCT_CODE : prev_typ = SPW_RAW_FCT;
            SPW_CHAR_EOP_CODE : prev_typ = SPW_RAW_EOP;
            SPW_CHAR_EEP_CODE : prev_typ = SPW_RAW_EEP;
            SPW_CHAR_ESC_CODE : prev_typ = SPW_RAW_ESC;
            default : `uvm_fatal(get_type_name(), "invalid ctl char code")
          endcase
        end
        else begin // if the character is a NCHAR
          prev_typ = SPW_RAW_DATA;
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
