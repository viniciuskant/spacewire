package host_driver_pkg;
  import uvm_pkg::*;
  import host_item_pkg::*;
  `include "uvm_macros.svh"

  /// Drives the host side of the codec.
  ///
  /// Packets are written to the TX FIFO word by word, holding each word until
  /// full_tx_fifo is low. In parallel, the RX FIFO is drained on its own,
  /// reading on rx_read_pct percent of the cycles.
  ///
  /// Knobs (uvm_config_db #(int unsigned)):
  ///   rx_read_pct: chance of reading the RX FIFO on a cycle, 0 to 100
  ///   tx_gap_max:  max idle cycles between two TX words
  class host_driver extends uvm_driver #(host_base_item);
    `uvm_component_utils(host_driver)

    virtual spw_host_if vif;

    // items right after they are fully written to the DUT
    uvm_analysis_port #(host_packet_item) pkt_ap;
    uvm_analysis_port #(host_timecode_item) tc_ap;

    int unsigned rx_read_pct = 100;
    int unsigned tx_gap_max = 0;
    bit [7:0] tx_div = 8'd10; // 10 Mbit/s with the 200 MHz reference

    function new(string name, uvm_component parent);
      super.new(name, parent);
      pkt_ap = new("pkt_ap", this);
      tc_ap = new("tc_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual spw_host_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_host_if")
      end
      void'(uvm_config_db #(int unsigned)::get(this, "", "rx_read_pct", rx_read_pct));
      void'(uvm_config_db #(int unsigned)::get(this, "", "tx_gap_max", tx_gap_max));
      if (rx_read_pct > 100) begin
        `uvm_fatal(get_type_name(), $sformatf("rx_read_pct must be <= 100, got %0d", rx_read_pct))
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      vif.drv_cb.div_counter_tx <= tx_div;
      vif.drv_cb.SpW_Packet_TX <= '0;
      vif.drv_cb.SpW_Packet_TX_en <= 0;
      vif.drv_cb.SpW_Packet_RX_en <= 0;
      vif.drv_cb.Time_Code_TX <= '0;
      vif.drv_cb.Time_Code_TX_valid <= 0;

      wait (vif.rst_n === 1);
      fork
        drain_rx();
        drive_items();
      join
    endtask

    protected task drive_items();
      host_base_item item;
      host_packet_item pkt;
      host_timecode_item tc;
      host_config_item cfg;

      forever begin
        seq_item_port.get_next_item(item);
        // every operation starts right after a clock edge
        @(vif.drv_cb);

        if ($cast(pkt, item)) begin
          send_packet(pkt);
          pkt_ap.write(pkt);
        end
        else if ($cast(tc, item)) begin
          send_timecode(tc);
          tc_ap.write(tc);
        end
        else if ($cast(cfg, item)) begin
          case (cfg.typ)
            HOST_CFG_TX_DIV: begin
              tx_div = cfg.tx_div;
              vif.drv_cb.div_counter_tx <= tx_div;
            end
            default: `uvm_fatal(get_type_name(), "invalid cfg item type")
          endcase
        end
        else begin
          `uvm_fatal(get_type_name(), "invalid sequence item")
        end

        seq_item_port.item_done();
      end
    endtask

    protected task send_packet(host_packet_item pkt);
      bit [8:0] words[$];
      pkt.to_words(words);
      foreach (words[i]) begin
        int unsigned gap = (i == 0) ? 0 : $urandom_range(tx_gap_max);
        if (gap > 0) begin
          vif.drv_cb.SpW_Packet_TX_en <= 0;
          repeat (gap) @(vif.drv_cb);
        end
        send_word(words[i]);
      end
      vif.drv_cb.SpW_Packet_TX_en <= 0;
    endtask

    // Must be called right after a clock edge. Returns right after the edge
    // where the DUT took the word, so words can go back to back.
    protected task send_word(bit [8:0] w);
      vif.drv_cb.SpW_Packet_TX <= w;
      vif.drv_cb.SpW_Packet_TX_en <= 1;
      do @(vif.drv_cb); while (vif.drv_cb.full_tx_fifo !== 0);
    endtask

    protected task send_timecode(host_timecode_item tc);
      vif.drv_cb.Time_Code_TX <= tc.value;
      vif.drv_cb.Time_Code_TX_valid <= 1;
      @(vif.drv_cb);
      vif.drv_cb.Time_Code_TX_valid <= 0;
    endtask

    protected task drain_rx();
      forever begin
        @(vif.drv_cb);
        vif.drv_cb.SpW_Packet_RX_en <= ($urandom_range(99) < rx_read_pct);
      end
    endtask

  endclass
endpackage
