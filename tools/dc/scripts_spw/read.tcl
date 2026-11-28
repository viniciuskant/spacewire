# read in design
# do not put testbench in the list below
set_app_var hdlin_enable_hier_map true
set verilogout_show_unconnected_pins true

# set sv_files [glob -nocomplain -directory $RTL_DIR *.sv]
# if {[llength $sv_files] == 0} {
#     error "No .sv files found in $RTL_DIR"
# }
# puts "=== Analyzing [llength $sv_files] files SystemVerilog"

# analyze -format sverilog -library WORK $sv_files
# elaborate $DESIGN -library WORK

# # build gtech design
# current_design $DESIGN
# link
# set_verification_top
# uniquify

# Verilog

set v_files {}
lappend v_files "$RTL_DIR/spw_pkg.sv"
set v_files [concat $v_files [split [exec find "$RTL_DIR/common" -name "*.sv"] "\n"]]
set v_files [concat $v_files [split [exec find "$RTL_DIR/rmap" -name "*.sv"] "\n"]]
set v_files [concat $v_files [split [exec find "$RTL_DIR/codec" -name "*.sv"] "\n"]]
set v_files [concat $v_files [split [exec find "$RTL_DIR/router" -name "*.sv"] "\n"]]
set v_files [concat $v_files [split [exec find "$RTL_DIR/top" -name "*.sv"] "\n"]]
set v_files [lsearch -all -inline -not -exact $v_files ""]

if {[llength $v_files] > 0} {
    analyze -format sverilog -define $PDK_MACRO $v_files
} else {
    puts "ERROR: No .sv files found in $RTL_DIR"
}

# Elaborate top module
elaborate $DESIGN

# Select top module
current_design $DESIGN

# Check hierarchy
link

# uniquify


# DFT spec
#set_scan_configuration -chain_count 1

# to use without pads
#create_port -direction in  test_si
#create_port -direction out test_so
#create_port -direction in  test_se

# or
#set_dft_signal -view spec -type ScanDataIn  -port test_si
#set_dft_signal -view spec -type ScanDataOut -port test_so
#set_dft_signal -view spec -type ScanEnable  -port test_se

# to use with pads
#set_dft_signal -view existing_dft -type ScanDataIn  -port test_si
#set_dft_signal -view existing_dft -type ScanDataOut -port test_so
#set_dft_signal -view existing_dft -type ScanEnable  -port test_se

# check design
check_design > $REPORTS_DIR/dc_check_design.rpt
