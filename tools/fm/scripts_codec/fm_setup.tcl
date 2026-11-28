# library dir & path
set FM_DIR $FM_DIR
set PDK_MACRO $PDK_MACRO

set DESIGN $DESIGN

# Seleciona o setup correspondente ou aborta com erro
switch -exact $PDK_MACRO {
    "SAED90" {
        source "${SETUP_DIR}/setup_saed90.tcl"
    }
    "SAED32" {
        source "${SETUP_DIR}/setup_saed32.tcl"
    }
    "IHP130" {
        set PDK_BASE "/pdk/ihp/ihp130"

        set GTECH_LIBRARY "/tools/synopsys/fm/W-2024.09-SP5/libraries/syn/gtech.db"

        set LIB_IO_PATH_SETUP $PDK_BASE/ixc013g2_iocell/db
        set STD_LIB_PATH_SETUP $PDK_BASE/ixc013g2ng_stdcell/db
        set STD_VERILOG_PATH_SETUP $PDK_BASE/ixc013g2ng_stdcell/verilog/ixc013g2ng_stdcell.v

        # library dir & path
        set LIB_IO_PATH $LIB_IO_PATH_SETUP
        set STD_LIB_PATH $STD_LIB_PATH_SETUP

        # search path for all files
        set_app_var search_path [concat $search_path "." $STD_LIB_PATH $LIB_IO_PATH $RTL_DIR]

        # library settings
        set TARGET_LIBRARY      $STD_LIB_PATH/ixc013g2ng_stdcell_slow_1p08V_125C.db	    ;#slow
        set SYNTHETIC_LIBRARY "/tools/synopsys/designcompiler/W-2024.09-SP5-4/libraries/syn/dw_foundation.sldb"
    }
    default {
        puts "ERROR: Invalid PDK_NAME '$current_pdk'."
        puts "Valid options are: 'SAED90', 'SAED32', or 'IHP130'."
        exit 1
    }
}

# output dir
set RUN_NAME [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

set RUN_DIR "${FM_DIR}/runs/$RUN_NAME"

set REPORTS_DIR  "$RUN_DIR/reports/"
set OUTPUTS_DIR  "$RUN_DIR/outputs"
set WORK_DIR  "$RUN_DIR/work"
set SNAPSHOT_DIR "$RUN_DIR/snapshots"
set NETLIST "$OUTPUTS_DIR/netlist"
set SVF "$OUTPUTS_DIR/svf"
set CURRENT_RUN "$FM_DIR/current_run"

if {[file exists $RUN_DIR]} {
    error "RUN directory already exists: $RUN_DIR"
}

foreach dir [list $RUN_DIR $REPORTS_DIR $OUTPUTS_DIR $SNAPSHOT_DIR $NETLIST $SVF] {
    file mkdir $dir
    puts "Criado: $dir"
}

# remove previous symbolic link
if {[file exists $CURRENT_RUN] || ![catch {file type $CURRENT_RUN}]} {
    file delete $CURRENT_RUN
}

# create new symbolic link
file link -symbolic $CURRENT_RUN $RUN_DIR

set work_path "$WORK_DIR"

if {![file exists $work_path]} {
    file mkdir $work_path
}