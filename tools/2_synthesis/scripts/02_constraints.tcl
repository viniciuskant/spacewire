# ============================================================
# 02_constraints.tcl - Santiago CPU / IHP130 (core 1.2V)
# ============================================================

# --- Design Constraints ---
set CLK_PORT                 clock
set CLOCK_PERIOD             30
set CLOCK_UNCERTAINTY_SETUP  1
set CLOCK_LATENCY            1
set CLOCK_TRANSITION         0.2
set INPUT_DELAY              0.1
set OUTPUT_DELAY             0.1
set OUTPUT_LOAD              10
set INPUT_TRANSITION         0.2

set ALL_IN_BUT_CLK [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]
set ALL_OUT        [all_outputs]

create_clock -period $CLOCK_PERIOD -name MY_CLK [get_ports $CLK_PORT]
set_clock_uncertainty -setup $CLOCK_UNCERTAINTY_SETUP [get_clocks MY_CLK]
set_clock_latency     $CLOCK_LATENCY     [get_clocks MY_CLK]
set_clock_transition  $CLOCK_TRANSITION  [get_clocks MY_CLK]

set_input_delay  $INPUT_DELAY  -clock MY_CLK $ALL_IN_BUT_CLK
set_output_delay $OUTPUT_DELAY -clock MY_CLK $ALL_OUT

set_load             $OUTPUT_LOAD      $ALL_OUT
set_input_transition $INPUT_TRANSITION $ALL_IN_BUT_CLK


