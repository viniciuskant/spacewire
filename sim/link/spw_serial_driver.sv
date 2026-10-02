package serial_driver_pkg;
  import uvm_pkg::*;
  import serial_item_pkg::*;
  import codec_utils_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class spw_serial_driver extends uvm_driver #(
    spw_serial_base_item
  );
    `uvm_component_utils(spw_serial_driver)

    virtual spw_serial_if vif;

    uvm_analysis_port #(spw_serial_char_item) ap;

    realtime bit_period = 100ns; // default 10MHz rate
    spw_encoder_util encoder;

    bit last_d;
    bit last_s;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
      reset();
    endfunction

    virtual function automatic void reset();
      bit_period = 100ns;
      encoder = new();
      last_d = 0;
      last_s = 0;
      vif.din <= 0;
      vif.sin <= 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual spw_serial_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
      end
    endfunction

    virtual function automatic void set_speed(real rate_mhz);
      bit_period = 1000.0 / rate_mhz * 1ns;
    endfunction

    virtual task run_phase(uvm_phase phase);
      spw_serial_base_item item;
      spw_serial_char_item ch_item;
      spw_serial_config_item cfg_item;

      forever begin
        seq_item_port.get_next_item(item);

        // if the item is a configuration item
        if ($cast(cfg_item, item)) begin
          case (cfg_item.typ)
            SPW_CFG_RESET : reset();
            SPW_CFG_SPEED : set_speed(cfg_item.new_baud_rate_mhz);
            default : `uvm_fatal(get_type_name(), "invalid cfg_item type")
          endcase
        end
        else if ($cast(ch_item, item)) begin
          ap.write(ch_item);
          case (ch_item.typ)
            SPW_CHAR_DATA : begin
              send_nchar(encoder.encode_n_char(ch_item.data, ch_item.inject_parity_err));
            end
            SPW_CHAR_FCT : begin
              send_ctl(encoder.encode_fct(ch_item.inject_parity_err));
            end
            SPW_CHAR_EOP : begin
              send_ctl(encoder.encode_eop(ch_item.inject_parity_err));
            end
            SPW_CHAR_EEP : begin
              send_ctl(encoder.encode_eep(ch_item.inject_parity_err));
            end
            SPW_CHAR_ESC : begin
              send_ctl(encoder.encode_esc(ch_item.inject_parity_err));
            end
            SPW_CHAR_NULL : begin
              send_ctl(encoder.encode_esc(ch_item.inject_parity_err));
              send_ctl(encoder.encode_fct(0));
            end
            SPW_CHAR_TIMECODE : begin
              send_ctl(encoder.encode_esc(ch_item.inject_parity_err));
              send_nchar(encoder.encode_n_char(ch_item.data, 0));
            end
          endcase
        end
        else begin
          `uvm_fatal(get_type_name(), "invalid sequence item")
        end

        seq_item_port.item_done();
      end

    endtask
    local task send_ctl(bit [0:3] bits);
      send_bits(4, {bits, 6'b0});
    endtask
    local task send_nchar(bit [0:9] nchar);
      send_bits(10, nchar);
    endtask

    local task send_bits(int size, bit [0:9] bits);
      bit curr_d;
      bit curr_s;
      for (int i = 0; i < size; i++) begin
        curr_d = bits[i];
        curr_s = last_s;
        if (curr_d == last_d) begin
          curr_s = ~last_s;
        end
        last_d = curr_d;
        last_s = curr_s;

        vif.din <= curr_d;
        vif.sin <= curr_s; #bit_period;
      end
    endtask

  endclass
endpackage
