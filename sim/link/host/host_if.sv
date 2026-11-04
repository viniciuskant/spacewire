/// Host side of the codec (rtl/codec.sv). Signal names follow the DUT ports.
/// Everything is synchronous to clk_system.
interface spw_host_if (
  input logic clk_system,
  input logic rst_n
);
  logic [7:0] div_counter_tx;

  // TX FIFO: [8] = 0 -> data in [7:0], [8] = 1 -> control (EOP/EEP)
  logic [8:0] SpW_Packet_TX;
  logic SpW_Packet_TX_en;
  logic full_tx_fifo;

  // RX FIFO, first word fall through: SpW_Packet_RX is valid while !empty_rx_fifo
  logic [8:0] SpW_Packet_RX;
  logic SpW_Packet_RX_en;
  logic empty_rx_fifo;

  logic [7:0] Time_Code_TX;
  logic Time_Code_TX_valid;
  logic [7:0] Time_Code_RX;
  logic Time_Code_RX_valid;

  clocking drv_cb @(posedge clk_system);
    output div_counter_tx;
    output SpW_Packet_TX, SpW_Packet_TX_en;
    output SpW_Packet_RX_en;
    output Time_Code_TX, Time_Code_TX_valid;
    input full_tx_fifo, empty_rx_fifo;
  endclocking

  clocking mon_cb @(posedge clk_system);
    input SpW_Packet_TX, SpW_Packet_TX_en, full_tx_fifo;
    input SpW_Packet_RX, SpW_Packet_RX_en, empty_rx_fifo;
    input Time_Code_TX, Time_Code_TX_valid;
    input Time_Code_RX, Time_Code_RX_valid;
  endclocking

endinterface
