interface spw_host_if(
  logic sys_clk_50mhz,
  logic tx_clk_200mhz
);
  logic [7:0] tx_data;
  logic tx_write;
  logic tx_ready;
  logic tx_eop;
  logic tx_eep;

  logic [7:0] rx_data;
  logic rx_valid;
  logic rx_read;
  logic rx_eop;
  logic rx_eep;

  logic link_start;
  logic auto_start;
  logic link_disable;

  logic [7:0] tx_clk_div;

  // status and error reporting
  // 0: ErrorReset, 1: ErrorWait, 2: Connecting, 3: Started, 4: Run
  logic [2:0] link_state;

  logic err_parity;
  logic err_disconnect;
  logic err_escape;
  logic err_credit;
endinterface
