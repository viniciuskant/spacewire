namespace eval cdc {
    # only for 2ff synchronizer
    variable FF1 sync_ff1_reg
    variable FF2 sync_ff2_reg

    proc sync_2ff {inst src_period dst_period} {
        variable FF1; variable FF2;
        set period [expr {min($src_period, $dst_period)}]
        set to [get_cells $inst/${FF1}*]

        set_max_delay -ignore_clock_latency $period -to $to ;# keeps the route short
        set_false_path -hold -to $to

        # keep the two flops close
        set_max_delay [expr {0.2 * $dst_period}] -from [get_cells $inst/${FF1}*] -to [get_cells $inst/${FF2}*]
    }
    proc sync_2ff_impl {inst} {
        variable FF1; variable FF2;
        set ff [get_cells [list $inst/${FF1}* $inst/${FF2}*]]
        set_dont_retime $ff true
        set_register_merging $ff false
        set_scan_element false $ff
    }
    proc _constrain_gray {src_regs ff1_regs ff2_regs src_period dst_period frac} {
        set from [get_cells $src_regs]
        set s1 [get_cells $ff1_regs]
        set s2 [get_cells $ff2_regs]

        # crossing: bit skew below one fastest period
        set bound [expr {$frac * min($src_period, $dst_period)}]
        set_max_delay -ignore_clock_latency $bound -from $from -to $s1
        set_false_path -hold -from $from -to $s1

        # keep the sync FFs close
        set_max_delay [expr {0.2 * $dst_period}] -from $s1 -to $s2
    }
    proc _impl_gray {gray_regs ff1_regs ff2_regs} {
        set ff [get_cells [list $ff1_regs $ff2_regs]]
        set_dont_retime $ff true
        set_scan_element false $ff
        set_dont_retime [get_cells $gray_regs] true
    }

    proc gray {inst src_period dst_period {frac 0.8}} {
        _constrain_gray $inst/gray_reg* $inst/gray_ff1_reg* $inst/gray_ff2_reg* $src_period $dst_period $frac
    }
    proc gray_impl {inst} {
        _impl_gray $inst/gray_reg* $inst/gray_ff1_reg* $inst/gray_ff2_reg*
        set_ungroup [get_cells $inst] false
    }
    proc afifo {inst wr_period rd_period rd_clk {frac 0.8}} {
        # write pointer
        _constrain_gray $inst/wgray_reg* $inst/rq1_wgray_reg* $inst/rq2_wgray_reg* $wr_period $rd_period $frac
        # read pointer
        _constrain_gray $inst/rgray_reg* $inst/wq1_rgray_reg* $inst/wq2_rgray_reg* $rd_period $wr_period $frac

        set mem [get_cells $inst/mem_reg*]
        set_max_delay -ignore_clock_latency $rd_period -from $mem -to [get_clocks $rd_clk]
        set_false_path -hold                           -from $mem -to [get_clocks $rd_clk]
        # memory
    }
    proc afifo_impl {inst} {
        _impl_gray $inst/wgray_reg* $inst/rq1_wgray_reg* $inst/rq2_wgray_reg*
        _impl_gray $inst/rgray_reg* $inst/wq1_rgray_reg* $inst/wq2_rgray_reg*

        set mem [get_cells $inst/mem_reg*]
        set_dont_retime $mem true

        set_ungroup [get_cells $inst] false
    }

    # apply proc `kind` to every instance matching `pattern`
    proc each {kind pattern args} {
        set cells [get_cells -quiet $pattern]
        if {[sizeof_collection $cells] == 0} {
            puts "WARNING: cdc::$kind matched nothing for '$pattern'"
            return
        }
        foreach_in_collection c $cells {
            $kind [get_object_name $c] {*}$args
        }
    }
    proc rstsync {inst dst_period} {
        variable FF1; variable FF2;
        set s1 [get_cells $inst/${FF1}*]
        set s2 [get_cells $inst/${FF2}*]

        set_false_path -to $s1                                       ;# async input
        set_max_delay [expr {0.2*$dst_period}] -from $s1 -to $s2     ;# keep stages close
    }
    proc rstsync_impl {inst} {
        variable FF1; variable FF2;
        set ff [get_cells [list $inst/${FF1}* $inst/${FF2}*]]
        set_dont_retime $ff true
        set_scan_element false $ff
        set_ungroup [get_cells $inst] false
    }

}