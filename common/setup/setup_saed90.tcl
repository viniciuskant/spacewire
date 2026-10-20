# ============================================================
source "${PDK_DIR}/saed90/hvt.tcl"

# NDM não está disponível no SAED90 mínimo
set LIBRARY_FILES ""

# search path for all files
lappend search_path "${DB_PATH}"
lappend search_path "${RTL_DIR}"

# library settings
set target_library   $TARGET_LIBRARY
set synthetic_library "dw_foundation.sldb"

# I/O pads — opcional. O SAED90 tem I/O em SAED_EDK90nm_IO/
# Se for usar, copie o .db para ${PDK_DIR}/saed90/DBs/ e descomente:
set iopad_library "${PDK_DIR}/saed90/DBs/saed90nm_io_wb_tt_2p5v.db"

# link_library: monta dinamicamente conforme IO esteja definido ou não
if { $iopad_library ne "" } {
    set_app_var link_library "* $target_library $synthetic_library $iopad_library"
} else {
    set_app_var link_library "* $target_library $synthetic_library"
}