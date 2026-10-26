# PDK SETUP
set PDK_BASE "/pdk/ihp/ihp130"

set LIB_IO_PATH_SETUP $PDK_BASE/ixc013g2_iocell/db
set STD_LIB_PATH_SETUP $PDK_BASE/ixc013g2ng_stdcell/db
set STD_VERILOG_PATH_SETUP $PDK_BASE/ixc013g2ng_stdcell/verilog/ixc013g2ng_stdcell.v

# library dir & path
set LIB_IO_PATH $LIB_IO_PATH_SETUP
set STD_LIB_PATH $STD_LIB_PATH_SETUP

# search path for all files
set_app_var search_path [concat $search_path "." $STD_LIB_PATH $LIB_IO_PATH $RTL_DIR]

# library settings
set target_library      $STD_LIB_PATH/ixc013g2ng_stdcell_slow_1p08V_125C.db	    ;#slow
set synthetic_library   "dw_foundation.sldb"
set iopad_library	    $LIB_IO_PATH/ixc013g2_iocell_slow_1p08V_3p0V_125C.db 	;#slow

set_app_var link_library "* $target_library $synthetic_library $iopad_library"

# min/max (BC-WC): each lib max (slow) gets its version min (fast)
set_min_library $STD_LIB_PATH/ixc013g2ng_stdcell_slow_1p08V_125C.db \
    -min_version $STD_LIB_PATH/ixc013g2ng_stdcell_fast_1p32V_m40C.db

set_min_library $LIB_IO_PATH/ixc013g2_iocell_slow_1p08V_3p0V_125C.db \
    -min_version $LIB_IO_PATH/ixc013g2_iocell_fast_1p32V_3p6V_m40C.db 
