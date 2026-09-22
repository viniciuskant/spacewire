
interface spw_codec_if (input logic clk);
  logic rst_n;
  // Physical Data-Strobe (DS) signals
  logic din, sin;   // Receive pair
  logic dout, sout; // Transmit pair

  logic [7:0] tx_data;
  logic tx_write;
  logic tx_eop;
  logic tx_eep;
  logic tx_full;
  logic [7:0] rx_data;
  logic rx_read;
  logic rx_empty;

  // Driver/Monitor clocking blocks
  clocking host_driver_cb @(posedge clk);
    default input #1ns output #2ns;
    output tx_data, tx_write, tx_eop, tx_eep, rx_read;
    input  tx_full, rx_data, rx_empty;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns output #2ns;
    input din, sin, dout, sout;
    input tx_data, tx_valid, tx_ready, tx_eop, tx_eep;
  endclocking

  modport DRV (clocking driver_cb, input rst_n);
  modport MON (clocking monitor_cb, input rst_n);
endinterface

