set SYS_CLK_PORT i_sys_clk
set TX_CLK_PORT i_tx_clk
set T_SYS_CLK 20
set T_TX_CLK 5
set T_RX_BIT 5 ;# 200Mbit/s
set T_RX_CLK [expr {2 * $T_RX_BIT}] ;# 100MHz

create_clock -name clk_sys -period $T_SYS_CLK [get_ports $SYS_CLK_PORT]
create_clock -name clk_tx -period $T_TX_CLK [get_ports $TX_CLK_PORT]

set CLKS [list clk_sys clk_tx]

set_clock_uncertainty -setup 0.20 [get_clocks $CLKS]
set_clock_uncertainty -hold  0.05 [get_clocks $CLKS]
set_clock_transition  0.10        [get_clocks $CLKS]