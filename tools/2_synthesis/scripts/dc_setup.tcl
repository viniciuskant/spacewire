# library dir & path
set PRJ_ROOT            $PRJ_ROOT_SETUP
set FLOW_ROOT           $FLOW_ROOT_SETUP
set IO_LIB_PATH	        $IO_LIB_PATH_SETUP
set STD_LIB_PATH        $STD_LIB_PATH_SETUP
set SOURCE_PATH         $FLOW_ROOT/inp_data/source

# search path for all files
set_app_var search_path [concat $search_path "." $STD_LIB_PATH $IO_LIB_PATH $SOURCE_PATH]

# library settings
set synthetic_library   "dw_foundation.sldb"
set target_library      $STD_LIB_PATH/ixc013g2ng_stdcell_slow_1p08V_125C.db	    ;#slow
set iopad_library	    $IO_LIB_PATH/ixc013g2_iocell_slow_1p08V_3p0V_125C.db 	;#slow

# set link_library        "* $target_library $synthetic_library $iopad_library"
set_app_var link_library  [concat "*" $target_library $synthetic_library $iopad_library] 

# min/max (BC-WC): each lib max (slow) gets its version min (fast)
set_min_library $STD_LIB_PATH/ixc013g2ng_stdcell_slow_1p08V_125C.db \
    -min_version $STD_LIB_PATH/ixc013g2ng_stdcell_fast_1p32V_m40C.db

set_min_library $IO_LIB_PATH/ixc013g2_iocell_slow_1p08V_3p0V_125C.db \
    -min_version $IO_LIB_PATH/ixc013g2_iocell_fast_1p32V_3p6V_m40C.db 

# design setting
set TOP_MODULE_NAME top_pad_rvx
set DESIGN rvx

#UM: Fix register autoremoval
#set_app_var compile_seqmap_propagate_constants false
set_app_var compile_seqmap_propagate_high_effort false

# output dir
set PRE_LAYOUT_DIR	$FLOW_ROOT/out_data/pre_layout
set REPORT_DIR  	$FLOW_ROOT/out_data/reports/syn

file mkdir $PRE_LAYOUT_DIR
file mkdir $REPORT_DIR
