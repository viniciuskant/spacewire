set T_SYS_CLK 20    ;# 50 MHz
set T_TX_CLK 5    ;# 200 MHz
set T_RX_CLK 10   ;# 100 MHz

set SYS_CLK_PORT i_sys_clk
set TX_CLK_PORT i_tx_clk 
set RX_CLK_PIN u_rx/u_clk_rec/o_rx_clk
set RX_CLK_N_PIN u_rx/u_clk_rec/o_rx_clk_n

set RX_CLKS {clk_rx clk_rx_n}
set FSM_RX_EN u_fsm/o_rx_enable_reg

set_ungroup [get_cells u_rx/u_clk_rec] false

create_clock -name clk_sys -period $T_SYS_CLK [get_ports $SYS_CLK_PORT]
create_clock -name clk_tx -period $T_TX_CLK [get_ports $TX_CLK_PORT]

# create_clock -name clk_rx -period $T_RX_CLK [get_pins $RX_CLK_PIN]
# create_generated_clock -name clk_rx_n -source [get_pins $RX_CLK_PIN] -divide_by 1 -invert [get_pins $RX_CLK_N_PIN]

# TODO revisar: tentativa de ajustar as constraints para que a STA entenda o caminho do clock reconstituído
create_clock -name clk_rx -period $T_RX_CLK [get_pins $RX_CLK_PIN]
create_generated_clock -name clk_rx_n -source [get_pins $RX_CLK_PIN] -divide_by 1 -invert [get_pins $RX_CLK_N_PIN]

# TODO: Substituir este atraso estimado pelo atraso real de propagação
# da célula XOR mapeada no PDK (EO2JIX0), considerando PVT, slew e carga.
# Atualmente, a instância sintetizada ainda pode estar mapeada como GTECH_XOR2.
#
# Comandos úteis para:
# get_cells -hierarchical *xor*
# report_cell [get_cells u_rx/u_clk_rec/xor0]
# grep -R -n -B 10 -A 5 'xor (' ixc013g2ng_stdcell/oa/ixc013g2ng_stdcell/
# grep -R -l 'xor (Q, A, B);' ixc013g2ng_stdcell/oa/ixc013g2ng_stdcell/*/functional/verilog.v
# célula: EO2JIX0
# grep -n -A 200 'cell (EO2JIX0)' ixc013g2ng_stdcell/lib/ixc013g2ng_stdcell_slow_1p08V_125C.lib
# index_1 -> Slew da entrada
# index_2 -> Capacitância da saída

set RX_XOR_DELAY 0.15

set_clock_latency -late  $RX_XOR_DELAY [get_clocks clk_rx]
set_clock_latency -early $RX_XOR_DELAY [get_clocks clk_rx]



set_clock_uncertainty -setup 0.20 [all_clocks]
set_clock_uncertainty -hold  0.05 [all_clocks]
set_clock_transition  0.10        [all_clocks]

set_clock_groups -asynchronous -group [get_clocks clk_tx] -group [get_clocks {clk_rx clk_rx_n}]

# ========= CDC =============

# Keep the CDC primitives as separate hierarchy (the constraints and CDC
# reviews find them by name) and never merge their flops.
set CDC_DESIGNS [get_designs -quiet {sync_2ff* async_fifo* sync_gray_counter*}]
set_ungroup         $CDC_DESIGNS false
set_register_merging $CDC_DESIGNS false
 
# Hand-instantiated clock cells: the RX clock recovery (XOR, test mux,
# inverter) and the TX clock-gating cell must not be resized or restructured.
set_dont_touch [get_cells -quiet -hier -filter "ref_name =~ *rx_clk_rec*"]
set_dont_touch [get_cells -quiet u_tx/u_clk_gate/u_icg]      ;# EDIT: ICG instance path

# constrain 
set T_SYS_TX [expr {min($T_SYS_CLK, $T_TX_CLK)}]
set T_SYS_RX [expr {min($T_SYS_CLK, $T_RX_CLK)}]

proc cdc_pair {from to limit} {
    set_max_delay   $limit -from [get_clocks $from] -to [get_clocks $to]
    set_false_path  -hold  -from [get_clocks $from] -to [get_clocks $to]
}
 
cdc_pair clk_sys  clk_tx   $T_SYS_TX
cdc_pair clk_tx   clk_sys  $T_SYS_TX
cdc_pair $RX_CLKS clk_sys  $T_SYS_RX
cdc_pair clk_sys  $RX_CLKS $T_SYS_RX

# TODO: testar versão explicita dos constraints da FIFO
# proc cdc_async_fifo {fifo t_ptr t_data} {
#     # Gray pointers: bound bit skew, at most the shorter clock period
#     set_max_delay $t_ptr  -from [get_cells $fifo/wgray_reg*] -to [get_cells $fifo/rq1_wgray_reg*]
#     set_max_delay $t_ptr  -from [get_cells $fifo/rgray_reg*] -to [get_cells $fifo/wq1_rgray_reg*]
#     # storage -> read side: data is stable 2+ destination cycles before use
#     set_max_delay $t_data -from [get_cells $fifo/mem_reg*]
# }

# foreach_in_collection f [get_cells -hier -filter "ref_name =~ async_fifo*"] {
#     set n [get_object_name $f]
#     cdc_async_fifo $n $T_SYS_TX [expr {2 * $T_TX}]   ;# pick per FIFO's clock pair
# }


# run_div only changes when the link is down, so we don't synchronize it.
set_false_path -from [get_ports i_run_div*]

# RX resets: asserted and released asynchronously (if the line is silent we can't synchronize them)
set_false_path -from [get_ports i_sys_rstn] -to [get_clocks $RX_CLKS]

# ========================

# TODO
# constraint mais pro physical. Ver depois se realmente precisa
# Encontra automaticamente o pino D do PRIMEIRO flip-flop de todos os sincronizadores
#set sync_first_stage_pins [get_pins -hierarchical *sync_2ff*/sync_ff1_reg*/D]

# Aplica restrição de atraso máximo (ex: 1 período do clock de destino) ignorando o skew de clock
# Isso evita que o primeiro FF fique longe demais da lógica de origem e previne metaestabilidade
#if {[sizeof_collection $sync_first_stage_pins] > 0} {
#    set_max_delay -datapath_only -from [all_clocks] -to $sync_first_stage_pins 5.0
#}


# IO
# Só se for o top-level

# portas que n vem do clock do sistema
set NOT_SYS_IN [get_ports {i_sys_clk i_tx_clk i_sys_rstn i_tx_rstn i_D i_S i_run_div*}]
set SYS_IN  [remove_from_collection [all_inputs]  $NOT_SYS_IN]
set SYS_OUT [remove_from_collection [all_outputs] [get_ports {o_D o_S}]]

# Host-side ports: assume 30 % of the cycle is used outside the codec
set_input_delay  [expr {0.3 * $T_SYS_CLK}] -clock clk_sys $SYS_IN
set_output_delay [expr {0.3 * $T_SYS_CLK}] -clock clk_sys $SYS_OUT

# Synchronized TX reset arrives from a flop on clk_tx (reset_sync at the top)
set_input_delay  [expr {0.3 * $T_TX_CLK}]  -clock clk_tx  [get_ports i_tx_rstn]

# Line outputs: straight from the D/S flops to the pads
set_output_delay 1.0 -clock clk_tx [get_ports {o_D o_S}]

# TODO
# set_driving_cell -lib_cell $DRIVE_CELL -pin $DRIVE_PIN \
#                  [remove_from_collection [all_inputs] [get_ports {i_sys_clk i_tx_clk}]]
# set_load [load_of $LOAD_PIN] [all_outputs]


# Data-Strobe input
set RX_CAP_FLOPS [get_cells -hier -filter "full_name =~ u_rx/u_cap/d_*_reg*"]
set_max_delay -datapath_only 1.0 -from [get_ports i_D] -to $RX_CAP_FLOPS
set_min_delay -datapath_only 0.0 -from [get_ports i_D] -to $RX_CAP_FLOPS

# Recovered clock uncertainty
# TODO: verificar valores de acordo com o cabo e especificação dos outros
# Example budget at 200 Mbit/s; replace with your link's numbers
set RX_SKEW_EXT 0.8   ;# far-end skew + cable + receiver, D vs S
set RX_JITTER   0.3
set RX_UNC [expr {$RX_SKEW_EXT + $RX_JITTER}]
set_clock_uncertainty -setup $RX_UNC [get_clocks {clk_rx clk_rx_n}]
set_clock_uncertainty -hold  $RX_UNC [get_clocks {clk_rx clk_rx_n}]

# Perguntas a se fazer:
#   * o sinal d e s vão chegar diretamente da parte analógica, sem passar por um "lógica digital"?