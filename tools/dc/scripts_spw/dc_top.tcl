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
set DESIGN spw_router
set SCRIPTS_DIR "${DC_DIR}/scripts_spw"

source "${SCRIPTS_DIR}/dc_setup.tcl"

# Executa os scripts
set_svf "${OUTPUTS_DIR}/svf/${DESIGN}_netlist.svf"
source "${SCRIPTS_DIR}/read.tcl"

source "${CONSTRAINTS_DIR}/spw.tcl"

source "${SCRIPTS_DIR}/compile.tcl"

set_svf -off

# exit
