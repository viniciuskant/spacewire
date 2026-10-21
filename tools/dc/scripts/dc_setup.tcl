# library dir & path
set DC_DIR $DC_DIR
set PDK_MACRO $PDK_MACRO

# design setting
set DESIGN rvx


# Seleciona o setup correspondente ou aborta com erro
switch -exact $PDK_MACRO {
    "SAED90" {
        source "${SETUP_DIR}/setup_saed90.tcl"
    }
    "SAED32" {
        source "${SETUP_DIR}/setup_saed32.tcl"
    }
    "IHP130" - "ihp130" {
        source "${SETUP_DIR}/setup_ihp.tcl"
    }
    default {
        puts "ERROR: Invalid PDK_NAME '$current_pdk'."
        puts "Valid options are: 'SAED90', 'SAED32', or 'IHP130'."
        exit 1
    }
}


set_app_var compile_seqmap_propagate_high_effort false

# output dir
set RUN_NAME [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

set RUN_DIR "${DC_DIR}/runs/$RUN_NAME"

set REPORTS_DIR  "$RUN_DIR/reports/syn"
set OUTPUTS_DIR  "$RUN_DIR/outputs"
set WORK_DIR  "$RUN_DIR/work"
set SNAPSHOT_DIR "$RUN_DIR/snapshots"
set FORMALITY_DIR "$RUN_DIR/formality"
set PRE_LAYOUT_DIR "$RUN_DIR/pre_layout"

foreach dir [list $RUN_DIR $REPORTS_DIR $OUTPUTS_DIR $SNAPSHOT_DIR $FORMALITY_DIR $PRE_LAYOUT_DIR] {
    file mkdir $dir
    puts "Criado: $dir"
}

set work_path "$WORK_DIR"

if {![file exists $work_path]} {
    file mkdir $work_path
}

# files to backup
file copy "${DC_DIR}/scripts" $SNAPSHOT_DIR/
file copy "${RTL_DIR}"        $SNAPSHOT_DIR/

puts ""
puts "RUN NAME: $RUN_NAME"
puts "RUN DIR: $RUN_DIR"
puts "REPORTS: $REPORTS_DIR"
puts "OUTPUTS: $OUTPUTS_DIR"
puts "SNAPSHOTS: $SNAPSHOT_DIR"
puts ""