set _here [file dirname [file normalize [info script]]]
source [file join $_here ds_rx_fe.tcl]
source [file join $_here cdc.tcl]

namespace eval spw_codec {
    variable T_SYS_CLK 20    ;# 50 MHz
    variable T_TX_CLK 5    ;# 200 MHz
    variable T_RX_D 5 ;# period of bit coming in at 200Mbit/s
    variable T_RX_CLK [expr 2*$T_RX_D]   ;# 100 MHz

    variable SYS_CLK_PORT i_sys_clk
    variable TX_CLK_PORT i_tx_clk 

    # build normalized module paths
    proc paths {codec} {
        set codec [string trimright $codec /] ;# normalizes module path
        set pfx [expr {$codec eq "" ? "" : "$codec/"}] ;# handles standalone mode
        return [list $codec $pfx]
    }

    proc cdc_pair {from to limit} {
        set_max_delay   $limit -from [get_clocks $from] -to [get_clocks $to]
        set_false_path  -hold  -from [get_clocks $from] -to [get_clocks $to]
    }

    proc constraints {codec sys_clk tx_clk din_port sin_port dout_port sout_port} {
        lassign [paths $codec] codec pfx
        variable T_SYS_CLK
        variable T_TX_CLK
        variable T_RX_D
        variable T_RX_CLK
        variable SYS_CLK_PORT
        variable TX_CLK_PORT

        set rx_clk [ds_rx_fe::constraints ${pfx}/u_rx/u_fe $din_port $sin_port]
        set_clock_groups -asynchronous -group [get_clocks $tx_clk] -group [get_clocks $rx_clk]

        # Keep the CDC primitives as separate hierarchy (the constraints and CDC
        # reviews find them by name) and never merge their flops.
        set CDC_DESIGNS [get_designs -quiet {sync_2ff* async_fifo* sync_gray*}]
        set_ungroup $CDC_DESIGNS false
        set_register_merging $CDC_DESIGNS false

        # CDC: RX -> System
        set rx_cdc ${pfx}u_rx/u_cdc
        cdc::each gray $rx_cdc/u_gray* $T_RX_CLK $T_SYS_CLK
        cdc::each sync_2ff $rx_cdc/u_2ff* $T_RX_CLK $T_SYS_CLK
        cdc::each afifo $rx_cdc/u_afifo* $T_RX_CLK $T_SYS_CLK $sys_clk

        # CDC: System -> TX
        set tx_cdc ${pfx}u_tx/u_cdc
        cdc::each sync_2ff $tx_cdc/u_2ff* $T_SYS_CLK $T_TX_CLK
        cdc::each afifo $tx_cdc/u_afifo* $T_SYS_CLK $T_TX_CLK $tx_clk

        # run_div only changes when the link is down, so we don't synchronize it.
        set_false_path -from [get_ports i_run_div*]

        # RX resets: asserted and released asynchronously (if the line is silent we can't synchronize them)
        set_false_path -from [get_ports i_sys_rstn] -to [get_clocks $RX_CLKS]

        # if the codec is the top level
        if {codec ne ""} {
            # portas que n vem do clock do sistema
            set NOT_SYS_IN [get_ports {i_sys_clk i_tx_clk i_sys_rstn i_tx_rstn i_D i_S i_run_div*}]
            set SYS_IN  [remove_from_collection [all_inputs]  $NOT_SYS_IN]
            set SYS_OUT [remove_from_collection [all_outputs] [get_ports {$dout_port $sout_port}]]

            # Host-side ports: assume 30 % of the cycle is used outside the codec
            set_input_delay  [expr {0.3 * $T_SYS_CLK}] -clock clk_sys $SYS_IN
            set_output_delay [expr {0.3 * $T_SYS_CLK}] -clock clk_sys $SYS_OUT

            # Synchronized TX reset arrives from a flop on clk_tx (reset_sync at the top)
            set_input_delay  [expr {0.3 * $T_TX_CLK}]  -clock clk_tx  [get_ports i_tx_rstn]

            # Line outputs: straight from the D/S flops to the pads
            set_output_delay 1.0 -clock clk_tx [get_ports {$dout_port $sout_port}]

            set_driving_cell -lib_cell BUFJIX1 [get_ports [list $dout_port $sout_port]]
            set_load 0.01 [all_outputs]

        }
    }
}
