import uvm_pkg::*;
`include "uvm_macros.svh"

class spw_char_driver extends uvm_driver #(spw_char_transaction);
  `uvm_component_utils(spw_char_driver)

  virtual spw_codec_if vif;
  protected logic cur_d;
  protected logic cur_s;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual spw_codec_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface handle not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    spw_char_transaction item;
    cur_d = 1'b0;
    cur_s = 1'b0;
    seq_item_port.get_next_item(item);

    @(posedge vif.drv_db);
    vif.drv_cb.tx_data  <= item.payload[i];
    vif.drv_cb.tx_valid <= 1'b1;
    vif.drv_cb.tx_eop   <= 1'b0;
    vif.drv_cb.tx_eep   <= 1'b0;

    seq_item_port.item_done();


    // initialize physical lines low
  endtask

  task drive_token(spw_token_item item);
    foreach (item.payload[i]) begin
      @(vif.drv_cb);
      vif.drv_cb.tx_data  <= item.payload[i];
      vif.drv_cb.tx_valid <= 1'b1;
      vif.drv_cb.tx_eop   <= 1'b0;
      vif.drv_cb.tx_eep   <= 1'b0;
      
      do @(vif.drv_cb); while (!vif.drv_cb.tx_ready);
    end

    // Drive End Marker
    vif.drv_cb.tx_valid <= 1'b1;
    vif.drv_cb.tx_eop   <= (item.end_marker == EOP);
    vif.drv_cb.tx_eep   <= (item.end_marker == EEP);
    do @(vif.drv_cb); while (!vif.drv_cb.tx_ready);

    vif.drv_cb.tx_valid <= 1'b0;
    vif.drv_cb.tx_eop   <= 1'b0;
    vif.drv_cb.tx_eep   <= 1'b0;
  endtask
endclass
