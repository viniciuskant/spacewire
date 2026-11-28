namespace eval cdc {
    proc sync_2ff {inst src_period dst_period} {
        set period [expr {min($src_period, $dst_period)}]
        set to [get_cells $inst/sync_ff1_reg*]

        set_max_delay -ignore_clock_latency $period -to $to ;# keeps the route short
        set_false_path -hold -to $to

        # keep the two flops close
        set_max_delay [expr {0.2 * $dst_period}] -from [get_cells $inst/sync_ff1_reg*] -to [get_cells $inst/sync_ff2_reg*]
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
    proc gray {inst src_period dst_period {frac 0.8}} {
        _constrain_gray $inst/gray_reg* $inst/gray_ff1_reg* $inst/gray_ff2_reg* $src_period $dst_period $frac
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
    proc rst_sync {inst dst_period} {
        set s1 [get_cells $inst/sync_ff1_reg*]
        set s2 [get_cells $inst/sync_ff2_reg*]
        # async reset pins of the synchronizer flops only (in IHP it's RN for DFRRQx flops)
        set rn [get_pins -of_objects [add_to_collection $s1 $s2] -filter "name == RN"]

        set_false_path -to $rn                                       ;# async input
        set_max_delay [expr {0.2*$dst_period}] -from $s1 -to $s2     ;# keep stages close
    # rst_out_n -> domain flops: no exception, recovery/removal timed normally
    }

}