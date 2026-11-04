set CLK_PORT                 clk_system 
set CLK_PORT_TX              clk_ref_tx 

set_case_analysis 0 [get_ports {div_counter_tx[7]}]
set_case_analysis 0 [get_ports {div_counter_tx[6]}]
set_case_analysis 0 [get_ports {div_counter_tx[5]}]
set_case_analysis 0 [get_ports {div_counter_tx[4]}]
set_case_analysis 0 [get_ports {div_counter_tx[3]}]
set_case_analysis 0 [get_ports {div_counter_tx[2]}]
set_case_analysis 0 [get_ports {div_counter_tx[1]}]
set_case_analysis 1 [get_ports {div_counter_tx[0]}]

set CLOCK_PERIOD_SYS   20    ;# 50 MHz
set CLOCK_PERIOD_REF    5    ;# 200 MHz
set CLOCK_UNCERTAINTY_SETUP  1
set CLOCK_LATENCY            1
set CLOCK_TRANSITION         0.2
set INPUT_DELAY              0.1
set OUTPUT_DELAY             0.1
set OUTPUT_LOAD              10
set INPUT_TRANSITION         0.2

set ALL_IN_BUT_CLK [remove_from_collection [all_inputs] [get_ports "$CLK_PORT $CLK_PORT_TX"]]
set ALL_OUT        [all_outputs]

create_clock -period $CLOCK_PERIOD_SYS -name MY_CLK [get_ports $CLK_PORT]
create_clock -period $CLOCK_PERIOD_REF -name TX_CLK [get_ports $CLK_PORT_TX]

create_generated_clock -name GEN_CLK_TX -source [get_ports $CLK_PORT_TX] -divide_by 2 [get_pins u_var_clk_divider/clk_out]

set_clock_groups -asynchronous -group [get_clocks MY_CLK] -group [get_clocks TX_CLK] -group [get_clocks GEN_CLK_TX]

set_clock_uncertainty -setup $CLOCK_UNCERTAINTY_SETUP [get_clocks {MY_CLK TX_CLK GEN_CLK_TX}]
set_clock_latency     $CLOCK_LATENCY     [get_clocks {MY_CLK TX_CLK GEN_CLK_TX}]
set_clock_transition  $CLOCK_TRANSITION  [get_clocks {MY_CLK TX_CLK GEN_CLK_TX}]

set_input_delay  $INPUT_DELAY  -clock MY_CLK $ALL_IN_BUT_CLK
set_output_delay $OUTPUT_DELAY -clock MY_CLK $ALL_OUT

set_load             $OUTPUT_LOAD      $ALL_OUT
set_input_transition $INPUT_TRANSITION $ALL_IN_BUT_CLK

set_false_path -from [get_ports rst_n] -to [all_registers]