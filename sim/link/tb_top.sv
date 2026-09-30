import uvm_pkg::*;
`include "uvm_macros.svh"

module tb_top;
  
  // 1. Clocks
  logic sys_clk;
  logic rst_n;
  // ... clock generation logic ...

  // 2. Instantiate the two distinct interfaces
  // The Host Interface (e.g., a simple FIFO / Register interface)
  spw_host_if  h_if (.clk(sys_clk), .rst_n(rst_n));

  // The Serial Interface (SpaceWire D/S pins)
  spw_serial_if s_if (); 

  // 3. Instantiate the SpaceWire IP Core (DUT)
  spw_ip_core dut (
    // System Clock & Reset
    .clk        (sys_clk),
    .rst_n      (rst_n),
    
    // --- HOST INTERFACE PINS ---
    .tx_data    (h_if.tx_data),
    .tx_write   (h_if.tx_write),
    .tx_full    (h_if.tx_full),
    .rx_data    (h_if.rx_data),
    .rx_read    (h_if.rx_read),
    .rx_empty   (h_if.rx_empty),
    
    // --- SERIAL INTERFACE PINS ---
    .spw_din    (s_if.spw_d_in),
    .spw_sin    (s_if.spw_s_in),
    .spw_dout   (s_if.spw_d_out),
    .spw_sout   (s_if.spw_s_out)
  );

  // 4. Pass the virtual interfaces to the UVM Environment
  initial begin
    uvm_config_db#(virtual spw_host_if)::set(null, "uvm_test_top.env.host_agent.*", "vif", h_if);
    uvm_config_db#(virtual spw_serial_if)::set(null, "uvm_test_top.env.serial_agent.*", "vif", s_if);
    
    run_test();
  end

endmodule
