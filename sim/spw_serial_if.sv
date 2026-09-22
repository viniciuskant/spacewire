interface spw_serial_if (
  input logic sys_clk, // testbench only, for oversampling of signals
  input logic rst_n
  );
  logic din;
  logic sin;
  logic dout;
  logic sout;

  clocking serial_driver_cb @(posedge sys_clk);
    default input #1ns output #2ns;
    output din, sin;
    input dout, sout;
  endclocking

  clocking serial_monitor_cb @(posedge sys_clk);
    default input #1ns;
    input din, sin, dout, sout;
  endclocking

  modport DRIVER (clocking serial_driver_cb, input rst_n);
  modport MONITOR (clocking serial_monitor_cb, input rst_n);
endinterface
