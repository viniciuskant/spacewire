# PDK SETUP
source "${PDK_CONFIG}/saed32/hvt.tcl"

set LIBRARY_FILES "${NDM_REFERENCE_LIB_DIRS}"

# search path for all files
lappend search_path "${DB_PATH}"
lappend search_path "${RTL_DIR}"
lappend search_path "${TARGET_LIBRARY}"

# library settings
set target_library $TARGET_LIBRARY
set synthetic_library "dw_foundation.sldb"

set sram_libraries $SRAM_DB_MAX
set iopad_library "${LIB_IO_PATH}/saed32io_wb_tt1p05v25c_2p5v.db"

set_app_var link_library "* $target_library $synthetic_library $sram_libraries $iopad_library"