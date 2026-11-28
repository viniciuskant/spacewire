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

current_design $DESIGN

set_verification_top

# Clock Gating
set_clock_gating_style -sequential_cell latch \
    -control_point before \
    -control_signal scan_enable \
    -minimum_bitwidth 4
    # -positive_edge_logic {integrated}

#compile_ultra -no_autoungroup -scan
compile_ultra -no_autoungroup -gate_clock 

# DFT I
#create_test_protocol -infer_clock -infer_asynch
#dft_drc
#preview_dft
#insert_dft

# Reports pós compile
report_timing -delay_type max -max_paths 3 > $REPORTS_DIR/2_post_compile_timing.rpt
report_qor                        > $REPORTS_DIR/2_post_compile_qor.rpt
report_constraints -all_violators > $REPORTS_DIR/2_post_compile_constraints.rpt
report_power       -verbose       > $REPORTS_DIR/2_post_compile_power.rpt
check_design                      > $REPORTS_DIR/2_post_compile_check_design.rpt

# Opt
#compile_ultra -scan -incremental
compile_ultra -incremental

# DFT II
#dft_drc                                        > $REPORTS_DIR/DFT_drc.rpt
#report_scan_path -view existing_dft -chain all > $REPORTS_DIR/DFT_report_scan_path.rpt
#report_constraints -all_violators              > $REPORTS_DIR/DFT_report_constraints.rpt

# Reports pós incremental
report_timing -delay_type max -max_paths 3 -input_pins -nets -transition_time -capacitance > $REPORTS_DIR/3_inc_compile_timing.rpt
report_qor                        > $REPORTS_DIR/3_inc_compile_qor.rpt
report_constraints -all_violators > $REPORTS_DIR/3_inc_compile_constraints.rpt
report_power       -verbose       > $REPORTS_DIR/3_inc_compile_power.rpt
check_design                      > $REPORTS_DIR/3_inc_compile_check_design.rpt

# Datapath analysis
analyze_datapath_extraction       > $REPORTS_DIR/3_inc_compile_datapath_extraction.rpt

report_port                       > $REPORTS_DIR/3_report_port.rpt

######################################################
## Outputs
######################################################

check_design
write_file -format ddc -hierarchy -output ${OUTPUTS_DIR}/netlist/${DESIGN}_netlist.ddc
write_file -format verilog -hierarchy -output ${OUTPUTS_DIR}/netlist/${DESIGN}_netlist.v



