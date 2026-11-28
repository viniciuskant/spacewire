set _here [file dirname [file normalize [info script]]]
source [file join $_here ds_rx_fe.tcl]
source [file join $_here cdc.tcl]

namespace eval spw_codec {

    # build normalized module paths
    proc paths {codec} {
        set codec [string trimright $codec /] ;# normalizes module path
        set pfx [expr {$codec eq "" ? "" : "$codec/"}] ;# handles standalone mode
        return [list $codec $pfx]
    }

    proc impl {codec} {
        lassign [paths $codec] codec pfx
        # Keep the CDC primitives as separate hierarchy (the constraints and CDC
        # reviews find them by name) and never merge their flops.
        set CDC_DESIGNS [get_designs -quiet {sync_2ff* async_fifo* sync_gray*}]
        set_ungroup $CDC_DESIGNS false
        set_register_merging $CDC_DESIGNS false

        ds_rx_fe::impl ${pfx}u_rx/u_fe

        set rx_cdc ${pfx}u_rx/u_cdc
        cdc::each gray_impl $rx_cdc/u_gray*
        cdc::each sync_2ff_impl $rx_cdc/u_2ff*
        cdc::each afifo_impl $rx_cdc/u_afifo*

        set tx_cdc ${pfx}u_tx/u_cdc
        cdc::each sync_2ff_impl $tx_cdc/u_2ff*
        cdc::each afifo_impl $tx_cdc/u_afifo*
    }

    proc constraints {codec sys_clk tx_clk din_port sin_port dout_port sout_port} {
        global T_SYS_CLK
        global T_TX_CLK
        global T_RX_CLK

        lassign [paths $codec] codec pfx

        set rx_clk [ds_rx_fe::constraints ${pfx}u_rx/u_fe $din_port $sin_port]
        set_clock_groups -asynchronous -group [get_clocks $tx_clk] -group [get_clocks $rx_clk]


        # CDC: RX -> System
        set rx_cdc ${pfx}u_rx/u_cdc
        cdc::each gray $rx_cdc/u_gray* $T_RX_CLK $T_SYS_CLK
        cdc::each sync_2ff $rx_cdc/u_2ff* $T_RX_CLK $T_SYS_CLK
        cdc::each afifo $rx_cdc/u_afifo* $T_RX_CLK $T_SYS_CLK $sys_clk

        # CDC: System -> TX
        set tx_cdc ${pfx}u_tx/u_cdc
        cdc::each sync_2ff $tx_cdc/u_2ff* $T_SYS_CLK $T_TX_CLK
        cdc::each afifo $tx_cdc/u_afifo* $T_SYS_CLK $T_TX_CLK $tx_clk


        # if the codec is the top level
        if {$codec eq ""} {
            # portas que n vem do clock do sistema
            set NOT_SYS_IN [get_ports {i_sys_clk i_tx_clk i_tx_rstn i_D i_S i_run_div*}]
            set SYS_IN  [remove_from_collection [all_inputs]  $NOT_SYS_IN]
            set SYS_OUT [remove_from_collection [all_outputs] [get_ports [list $dout_port $sout_port]]]

            # Host-side ports: assume 30 % of the cycle is used outside the codec
            set_input_delay  [expr {0.3 * $T_SYS_CLK}] -clock $sys_clk $SYS_IN
            set_output_delay [expr {0.3 * $T_SYS_CLK}] -clock $sys_clk $SYS_OUT

            # Synchronized TX reset arrives from a flop on clk_tx (reset_sync at the top)
            set_input_delay  [expr {0.3 * $T_TX_CLK}]  -clock $tx_clk  [get_ports i_tx_rstn]

            # Line outputs: straight from the D/S flops to the pads
            set_output_delay 1.0 -clock $tx_clk [get_ports [list $dout_port $sout_port]]

            set_driving_cell -lib_cell BUFJIX1 [get_ports [list $din_port $sin_port]]
            set_load 0.01 [all_outputs]

            # run_div only changes when the link is down, so we don't synchronize it.
            set_false_path -from [get_ports i_run_div*]

            # RX resets: asserted and released asynchronously (if the line is silent we can't synchronize them)
            set_false_path -from [get_ports i_sys_rstn] -to [get_clocks $rx_clk]
            set_false_path -from [get_cells u_rx/rx_rstn_reg*] -to [get_clocks $rx_clk]

        } else {

            # run_div only changes when the link is down, so we don't synchronize it.
            set_false_path -through [get_pins ${pfx}i_run_div*]

            # RX resets: asserted and released asynchronously (if the line is silent we can't synchronize them)
            set_false_path -through [get_pins ${pfx}i_sys_rstn] -to [get_clocks $rx_clk]
            set_false_path -from [get_cells ${pfx}u_rx/rx_rstn_reg*] -to [get_clocks $rx_clk]

        }
    }
}
