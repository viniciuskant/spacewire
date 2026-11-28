# library dir & path
set DC_DIR $DC_DIR
set PDK_MACRO $PDK_MACRO

# design setting
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

set RUN_DIR "${DC_DIR}/runs/codec_$RUN_NAME"

set REPORTS_DIR  "$RUN_DIR/reports/"
set OUTPUTS_DIR  "$RUN_DIR/outputs"
set WORK_DIR  "$RUN_DIR/work"
set SNAPSHOT_DIR "$RUN_DIR/snapshots"
set NETLIST "$OUTPUTS_DIR/netlist"
set SVF "$OUTPUTS_DIR/svf"
set CURRENT_RUN "$DC_DIR/current_run_codec"

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

# files to backup
file copy "${DC_DIR}/scripts_codec" $SNAPSHOT_DIR/
file copy "${RTL_DIR}"        $SNAPSHOT_DIR/

puts ""
puts "RUN NAME: $RUN_NAME"
puts "RUN DIR: $RUN_DIR"
puts "REPORTS: $REPORTS_DIR"
puts "OUTPUTS: $OUTPUTS_DIR"
puts "SNAPSHOTS: $SNAPSHOT_DIR"
puts ""