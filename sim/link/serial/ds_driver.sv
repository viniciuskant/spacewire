package ds_driver_pkg;
  import uvm_pkg::*;
  import ds_item_pkg::*;
  import codec_utils_pkg::*;
  import spw_defines_pkg::*;
  `include "uvm_macros.svh"

  class ds_driver extends uvm_driver #(
    ds_base_item
  );
    `uvm_component_utils(ds_driver)

    virtual spw_serial_if vif;

    // every raw character, right before it is sent
    uvm_analysis_port #(ds_raw_item) ap;
    // every character item, right before it is sent
    uvm_analysis_port #(ds_char_item) char_ap;

    realtime bit_period = 100ns; // default 10MHz rate
    spw_encoder_util encoder;

    bit last_d = 0;
    bit last_s = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
      char_ap = new("char_ap", this);
    endfunction

    // only call from run_phase: it drives the interface
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
      ds_base_item item;
      ds_char_item char_item;
      ds_raw_item raw_item;
      ds_config_item cfg_item;

      reset();

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
        else if ($cast(char_item, item)) begin
          char_ap.write(char_item);
          send_char(char_item);
        end
        else if ($cast(raw_item, item)) begin
          send_raw_item(raw_item);
        end
        else begin
          `uvm_fatal(get_type_name(), "invalid sequence item")
        end

        seq_item_port.item_done();
      end

    endtask

    // Splits a character into raw characters.
    // NULL and TIMECODE get the parity error injected in their ESC
    local task send_char(ds_char_item c);
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
            send_raw(SPW_RAW_FCT);
          end
        end
        SPW_CHAR_TIMECODE: begin
          send_raw(SPW_RAW_ESC, 0, c.inject_parity_err);
          // send another ESC on purpose
          // TODO: change this to send EOP/EEP as well
          if (c.inject_esc_err) begin
            send_raw(SPW_RAW_ESC);
          end else begin
            send_raw(SPW_RAW_DATA, c.data);
          end
        end
        default: `uvm_fatal(get_type_name(), $sformatf("can't transmit %s", c.convert2string()))
      endcase
    endtask

    local task send_raw(ds_raw_kind_e k, bit [7:0] d = 0, bit parity_err = 0);
      ds_raw_item t = ds_raw_item::type_id::create("t");
      t.typ = k;  t.data = d;  t.inject_parity_err = parity_err;
      send_raw_item(t);
    endtask

    local task send_raw_item(ds_raw_item t);
      ap.write(t);
      case (t.typ)
        SPW_RAW_DATA : send_nchar(encoder.encode_n_char(t.data, t.inject_parity_err));
        SPW_RAW_FCT  : send_ctl(encoder.encode_fct(t.inject_parity_err));
        SPW_RAW_EOP  : send_ctl(encoder.encode_eop(t.inject_parity_err));
        SPW_RAW_EEP  : send_ctl(encoder.encode_eep(t.inject_parity_err));
        SPW_RAW_ESC  : send_ctl(encoder.encode_esc(t.inject_parity_err));
      endcase
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
