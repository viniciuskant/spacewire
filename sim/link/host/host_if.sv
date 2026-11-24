/// Host side of the codec (rtl/codec/codec.sv). Signal names follow the DUT
/// ports. Everything is synchronous to clk_system.
interface spw_host_if (
  input logic clk_system,
  input logic rst_n
);
  // TX buffer: [8] = 0 -> data in [7:0], [8] = 1 -> EOP (9'h100) / EEP (9'h101)
  logic i_tx_wr;
  logic [8:0] i_tx_wdata;
  logic o_tx_full;

  // RX buffer, first word fall through: o_rx_rdata is valid while o_rx_valid
  logic i_rx_rd;
  logic [8:0] o_rx_rdata;
  logic o_rx_valid;

  // time-codes, one-cycle ticks
  logic i_tick;
  logic [7:0] i_timecode;
  logic o_tick;
  logic [7:0] o_timecode;

  // link control
  logic i_link_start;
  logic i_auto_start;
  logic i_link_disable;
  logic [6:0] i_run_div; // run rate = 200 MHz / (i_run_div + 1)

  // status
  logic [2:0] o_link_state; // spw_pkg::e_link_state
  logic o_link_run;
  logic o_link_error;

  clocking drv_cb @(posedge clk_system);
    output i_tx_wr, i_tx_wdata;
    output i_rx_rd;
    output i_tick, i_timecode;
    output i_link_start, i_auto_start, i_link_disable, i_run_div;
    input o_tx_full, o_rx_valid;
  endclocking

  clocking mon_cb @(posedge clk_system);
    input i_tx_wr, i_tx_wdata, o_tx_full;
    input i_rx_rd, o_rx_rdata, o_rx_valid;
    input i_tick, i_timecode;
    input o_tick, o_timecode;
    input o_link_state, o_link_run, o_link_error;
  endclocking

endinterface
