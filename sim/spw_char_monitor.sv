import uvm_pkg::*;
`include "uvm_macros.svh"

class spw_token_monitor extends uvm_monitor;
  `uvm_component_utils(spw_token_monitor)

  virtual spw_codec_if vif;
  uvm_analysis_port #(spw_token_item) ap;

  // Configuration knob: 0 = Monitor RX pair (din/sin), 1 = Monitor TX pair (dout/sout)
  bit monitor_tx = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual spw_codec_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface 'vif' not set for spw_token_monitor")
    
    void'(uvm_config_db#(bit)::get(this, "", "monitor_tx", monitor_tx));
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.rst_n == 1'b1);

    fork
      monitor_ds_stream();
    join_none
  endtask

  // Helper task: blocks until a Data or Strobe transition occurs
  task sample_ds_bit(output logic bit_val);
    logic prev_d, prev_s;
    
    get_ds_lines(prev_d, prev_s);
    
    if (monitor_tx) begin
      wait ((vif.dout !== prev_d) || (vif.sout !== prev_s) || (!vif.rst_n));
    end else begin
      wait ((vif.din  !== prev_d) || (vif.sin  !== prev_s) || (!vif.rst_n));
    end

    if (!vif.rst_n) return;

    // In DS encoding, the Data line always contains the actual bit value
    bit_val = monitor_tx ? vif.dout : vif.din;
  endtask

  // Read current physical line states
  function void get_ds_lines(output logic d, output logic s);
    d = monitor_tx ? vif.dout : vif.din;
    s = monitor_tx ? vif.sout : vif.sin;
  endfunction

  // Main Stream Processing State Machine
  task monitor_ds_stream();
    spw_token_item item;
    bit esc_flag = 0;
    
    forever begin
      logic p_bit, dc_bit;

      if (!vif.rst_n) begin
        esc_flag = 0;
        @(posedge vif.rst_n);
      end

      // Bit 0: Parity Bit
      sample_ds_bit(p_bit);
      
      // Bit 1: Data/Control Flag Bit (0 = N-Char, 1 = L-Char)
      sample_ds_bit(dc_bit);

      if (dc_bit == 1'b0) begin
        // -------------------------------------------------------------
        // N-Char Processing (10-bit frame: P + D/C + 8 Data bits)
        // -------------------------------------------------------------
        logic [7:0] data_byte;
        logic [9:0] nchar_frame;
        
        for (int i = 0; i < 8; i++) begin
          sample_ds_bit(data_byte[i]);
        end
        
        nchar_frame = {data_byte, dc_bit, p_bit};
        
        item = spw_token_item::type_id::create("item");
        //item.time_stamp = $time;
        item.is_valid_parity = (^nchar_frame == 1'b1); // Check odd parity

        if (!item.is_valid_parity) begin
          `uvm_error("MON_PARITY", $sformatf("Parity error in N-Char frame 0x%03h", nchar_frame))
        end

        if (esc_flag) begin
          // Sequence: ESC + Time-Char = Time-Code Token
          item.token_type   = TOKEN_TIME_CODE;
          item.time_val     = data_byte[5:0];
          item.data_payload = data_byte;
          esc_flag          = 1'b0;
        end else begin
          // Standard Data Character
          item.token_type   = TOKEN_NCHAR;
          item.data_payload = data_byte;
        end

        ap.write(item);

      end else begin
        // -------------------------------------------------------------
        // L-Char Processing (4-bit frame: P + D/C + 2 Control bits)
        // -------------------------------------------------------------
        logic [1:0] ctrl_bits;
        logic [3:0] lchar_frame;
        
        sample_ds_bit(ctrl_bits[0]);
        sample_ds_bit(ctrl_bits[1]);

        lchar_frame = {ctrl_bits, dc_bit, p_bit};
        
        item = spw_token_item::type_id::create("item");
        item.time_stamp = $time;
        item.is_valid_parity = (^lchar_frame == 1'b1); // Check odd parity

        if (!item.is_valid_parity) begin
          `uvm_error("MON_PARITY", $sformatf("Parity error in L-Char frame 0x%01h", lchar_frame))
        end

        case (ctrl_bits)
          CTRL_FCT: begin
            if (esc_flag) begin
              // Sequence: ESC + FCT = NULL Token
              item.token_type = TOKEN_NULL;
              esc_flag        = 1'b0;
            end else begin
              item.token_type = TOKEN_FCT;
            end
            ap.write(item);
          end

          CTRL_EOP: begin
            item.token_type = TOKEN_EOP;
            esc_flag        = 1'b0;
            ap.write(item);
          end

          CTRL_EEP: begin
            item.token_type = TOKEN_EEP;
            esc_flag        = 1'b0;
            ap.write(item);
          end

          CTRL_ESC: begin
            if (esc_flag) begin
              // Escape Error: Two consecutive ESC codes
              `uvm_error("MON_ESC", "Received invalid consecutive ESC characters")
              item.token_type = TOKEN_ERROR;
              ap.write(item);
              esc_flag = 1'b0;
            end else begin
              // Set ESC flag and wait for next token to determine type
              esc_flag = 1'b1;
            end
          end
        endcase
      end
    end
  endtask

endclass
