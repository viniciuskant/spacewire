source "${PDK_DIR}/saed90/hvt.tcl"

set LIBRARY_FILES ""

lappend search_path "${DB_PATH}"
lappend search_path "${RTL_DIR}"

if {[info exists SRAM_DB_DIR]} {
    lappend search_path $SRAM_DB_DIR
}
lappend search_path "${PDK_DIR}/saed90/IO/DBs"

set target_library   $TARGET_LIBRARY
set synthetic_library "dw_foundation.sldb"

set sram_libraries $SRAM_DB_MAX
set iopad_library "${PDK_DIR}/saed90/IO/DBs/saed90nm_io_typ_pg.db"

set_app_var link_library "* $target_library $synthetic_library $sram_libraries $iopad_library"