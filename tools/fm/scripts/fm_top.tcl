set PROJECT_ROOT $::env(PROJECT_ROOT)

set RTL_DIR $::env(RTL_DIR)
set VERIF_DIR $::env(VERIF_DIR)
set CONSTRAINTS_DIR $::env(CONSTRAINTS_DIR)
set PDK_CONFIG $::env(PDK_CONFIG)
set SETUP_DIR $::env(SETUP_DIR)
set TOOLS_DIR $::env(TOOLS_DIR)

set DC_DIR $::env(DC_DIR)
set FC_DIR $::env(FC_DIR)
set FM_DIR $::env(FM_DIR)
set VCS_DIR $::env(VCS_DIR)

set PDK_MACRO $::env(PDK_MACRO)
set DESIGN $::env(DESIGN)


source "${FM_DIR}/scripts/fm_setup.tcl"

set mv_use_fm_gui false
set sh_new_variables true

read_db $TARGET_LIBRARY
read_db $GTECH_LIBRARY
read_db $SYNTHETIC_LIBRARY

set synopsys_auto_setup true
set_svf "${DC_DIR}/current_run/outputs/svf/${DESIGN}_netlist.svf"

read_sverilog -container r -lib WORK -vcs [list \
    -f "${RTL_DIR}/filelist.f" \
]
get_designs -quiet r:/*

set_top r:/WORK/$DESIGN

read_verilog -container i -lib WORK "$DC_DIR/current_run/outputs/netlist/${DESIGN}_netlist.v"

set_top i:/WORK/$DESIGN

match
#apos o match da para aplicar comandos para tentar achar certos erros e poupar o tempo o verify

verify
analyze_points -failing

report_status > $REPORTS_DIR/formality_status.rpt
report_failing_points > $REPORTS_DIR/formality_failing.rpt
report_aborted > $REPORTS_DIR/formality_aborted.rpt
report_unmatched_points > $REPORTS_DIR/formality_unmatched.rpt

# exit
