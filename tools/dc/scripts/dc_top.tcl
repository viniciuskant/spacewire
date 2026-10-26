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
set TOP_MODULE_NAME $::env(TOP_MODULE_NAME)

source "${DC_DIR}/scripts/dc_setup.tcl"

# Executa os scripts
source "${DC_DIR}/scripts/read.tcl"
source "${CONSTRAINTS_DIR}/constraints.tcl"
source "${DC_DIR}/scripts/compile.tcl"

# exit
