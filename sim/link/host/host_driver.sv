
// package host_driver_pkg;
//   import uvm_pkg::*;
//   import spw_defines_pkg::*;
//   `include "uvm_macros.svh"

//   class spw_host_driver extends uvm_driver #(

//   );
//     `uvm_component_utils(spw_host_driver)

//     virtual spw_host_if vif;

//     function new(string name, uvm_component parent);
//       super.new(name, parent);
//     endfunction


//     virtual function void build_phase(uvm_phase phase);
//       super.build_phase(phase);
//       if (!uvm_config_db #(virtual spw_host_if)::get(this, "", "vif", vif)) begin
//         `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface spw_serial_if")
//       end
//     endfunction

//     virtual task run_phase(uvm_phase phase);

//       forever begin
//         seq_item_port.get_next_item(item);


//         seq_item_port.item_done();
//       end

//     endtask
//     local task send_ctl(bit [0:3] bits);
//       send_bits(4, {bits, 6'b0});
//     endtask
//     local task send_nchar(bit [0:9] nchar);
//       send_bits(10, nchar);
//     endtask

//     local task send_bits(int size, bit [0:9] bits);
//       bit curr_d;
//       bit curr_s;
//       for (int i = 0; i < size; i++) begin
//         curr_d = bits[i];
//         curr_s = last_s;
//         if (curr_d == last_d) begin
//           curr_s = ~last_s;
//         end
//         last_d = curr_d;
//         last_s = curr_s;

//         vif.din <= curr_d;
//         vif.sin <= curr_s; #bit_period;
//       end
//     endtask

//   endclass
// endpacka