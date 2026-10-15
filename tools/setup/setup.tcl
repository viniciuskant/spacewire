# proj paths
set SCRIPT_DIR     [file dirname [file normalize [info script]]]
set PRJ_ROOT_SETUP [file dirname [file dirname $SCRIPT_DIR]]
set FLOW_ROOT_SETUP [file dirname $SCRIPT_DIR]

# library dir & path
set PDK_PATH_SETUP            "/pdk/ihp/ihp130"
set IO_LIB_PATH_SETUP	      $PDK_PATH_SETUP/ixc013g2_iocell/db
set STD_LIB_PATH_SETUP        $PDK_PATH_SETUP/ixc013g2ng_stdcell/db
set STD_VERILOG_PATH_SETUP    $PDK_PATH_SETUP/ixc013g2ng_stdcell/verilog/ixc013g2ng_stdcell.v
