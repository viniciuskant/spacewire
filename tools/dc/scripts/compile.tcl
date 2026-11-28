set_fix_multiple_port_nets -all -buffer_constants

# --- Protect explicitly instantiated I/O cells ---
# Note: corner/filler/power_cut are physical-only (LEF-only, no logical model)
#       and are therefore created in ICC2, not instantiated in RTL.
foreach pat {PAD_* VDD_* VSS_* IOVDD_* IOVSS_*} {
    set c [get_cells -quiet $pat]
    if {[sizeof_collection $c] > 0} {
        set_dont_touch $c
        puts "INFO: dont_touch applied to [sizeof_collection $c] cells matching '$pat'"
    } else {
        puts "ERROR: no cell matched '$pat' - check top_pad.sv"
    }
}

compile_ultra -no_autoungroup


# DFT I
#create_test_protocol -infer_clock -infer_asynch
#dft_drc
#preview_dft
#insert_dft


# Opt
#compile_ultra -scan -incremental

# DFT II
#dft_drc                                        > $REPORTS_DIR/DFT_drc.rpt
#report_scan_path -view existing_dft -chain all > $REPORTS_DIR/DFT_report_scan_path.rpt
#report_constraints -all_violators              > $REPORTS_DIR/DFT_report_constraints.rpt
#write_scan_def -output                           $PRE_LAYOUT_DIR/$DESIGN.scandeff

# Reports pós incremental
report_timing -delay_type max -max_paths 3 -input_pins -nets -transition_time -capacitance > $REPORTS_DIR/timing.rpt
report_timing -delay_type max -max_paths 3 -input_pins -nets -transition_time -capacitance
report_qor                        > $REPORTS_DIR/qor.rpt
report_constraints -all_violators > $REPORTS_DIR/constraints.rpt
report_power       -verbose       > $REPORTS_DIR/power.rpt
check_design                      > $REPORTS_DIR/check_design.rpt

# Datapath analysis
analyze_datapath_extraction       > $REPORTS_DIR/datapath_extraction.rpt

report_port                       > $REPORTS_DIR/port.rpt

######################################################
## Outputs
######################################################
change_names -rule verilog -hier

write_sdc  $PRE_LAYOUT_DIR/$DESIGN.sdc
write_file -format ddc     -hier -out $PRE_LAYOUT_DIR/$DESIGN.ddc
write_file -format verilog -hier -out $PRE_LAYOUT_DIR/$DESIGN.v

#write_test_protocol -output $PRE_LAYOUT_DIR/$DESIGN.spf

