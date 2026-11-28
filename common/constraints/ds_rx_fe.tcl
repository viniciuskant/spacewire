proc ds_rx_fe {fe dport sport} {

    # 200Mbit/s
    set tbit 5.0
    set p [expr 2*$tbit]
    # clock-path jitter in ns
    set jitter 0.10

    # skew values taken from standard example
    set partner_tx_skew 1.234 ;# link partner output D/S skew
    set cable_skew 0.5 ;# 5m cable at 0.1ns/m
    set cable_jitter 0.5 ;# 5m cable at 0.1ns/m
    set SKEW [expr $partner_tx_skew + $cable_skew + $cable_jitter]
    set clk [expr {$fe eq "" ? "rx_clk" : "rx_clk_[string map {/ _} [string trimright $fe /]]"}]]

    # Five conditions need to be met in the clock recovery.
    # With:
    # d = Delay from the D pin to the capture flop's D input
    # L_D = Delay from the D pin through the XOR and buffer to the flop's CK pin
    # L_S = Same, for the S pin
    # T_bit = period between data bits

    # We have:
    # 1. d + t_setup < L_D
    #  = D races its own clock edge (setup check)
    # 2. max(L_D, L_S) + t_hold < d + T_bit − skew
    #  = the next bit must not overtake the capture (hold check)
    # 3. d + t_setup < L_S + T_bit − skew
    #  = setup on edges caused by S (default setup across edges)
    # 4. t_cq + t_path + t_setup < T_bit − skew − Δ_local
    #  = q_neg → data_pair, half cycle (default fall → rise)
    # 5. T_bit − skew − DCD >= t_mpw
    #  = minimum pulse width of rx_clk (DCD = duty-cycle distortion in the clock path), min pulse width check
    # Standalone: FE undefined -> default prefix and port names
    # Integrated: FE defined   -> caller must also define DPORT and SPORT
    # "" means the FE module is the top level in this synthesis.
    # Set FE = "u_codec/u_rx/u_ds_fe" at top.

    create_clock -name $clk -period $p [get_pins ${fe}/u_xor/Q]

    # pad -> XOR input, per corner (measure: report_timing -from {d s} -to ${FE}u_xor/*)
    set_clock_latency -source -early 0.30 [get_clocks $clk]
    set_clock_latency -source -late  0.45 [get_clocks $clk]

    # same edge: clock jitter only
    set_clock_uncertainty $jitter [get_clocks $clk]

    # rise<->fall: half-period shrinks by link skew (conditions 2, 3, 4)
    foreach chk {-setup -hold} {
    set_clock_uncertainty $chk [expr $jitter+$skew] -rise_from $clk -fall_to $clk
    set_clock_uncertainty $chk [expr $jitter+$skew] -fall_from $clk -rise_to $clk
    }

    # ---------- D is launched by the bit event, on both edges ----------
    set_input_delay 0 -clock $clk                        [get_ports $dport]
    set_input_delay 0 -clock $clk -clock_fall -add_delay [get_ports $dport]

    # ---------- condition 1: same-edge (zero-cycle) capture ----------
    set_multicycle_path 0 -setup -rise_from [get_clocks $clk] -to [get_cells ${fe}/d_pos_reg]
    set_multicycle_path 0 -setup -fall_from [get_clocks $clk] -to [get_cells ${fe}/d_neg_reg]
    # cross-edge pairs stay at default: they ARE conditions 2 and 3. No false paths.

    # ---------- condition 5: pulse width including link skew ----------
    # tool checks (T_bit - DCD) >= requirement, so add SKEW to the cell's t_mpw from the lib
    set mpw 2.0
    set_min_pulse_width [expr $mpw + $skew] [get_clocks $clk]

    # ---------- condition 6 + environment: standalone only ----------
    if {$fe eq ""} {
        set_driving_cell -lib_cell BUFJIX1 [get_ports [list $dport $sport]]
        set_output_delay -clock $clk [expr 0.5*$p] [get_ports o_pair*]
        set_load 0.01 [all_outputs]
    }

    return $clk
}