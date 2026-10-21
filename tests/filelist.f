// --- Defines ---
+define+$PDK_MACRO

// --- Testbench ---
${TESTS_DIR}/tb_codec.sv

// --- RTL Top ---
${RTL_DIR}/codec.sv

// --- RTL Submódulos ---
${RTL_DIR}/var_clk_divider.sv
${RTL_DIR}/error_cleanup_fsm.sv
${RTL_DIR}/flow_control.sv
${RTL_DIR}/flow_control_rx.sv
${RTL_DIR}/flow_control_tx.sv
${RTL_DIR}/state_machine.sv
${RTL_DIR}/rx.sv
${RTL_DIR}/rx_char.sv
${RTL_DIR}/rx_signal.sv
${RTL_DIR}/tx.sv
${RTL_DIR}/tx_char.sv
${RTL_DIR}/tx_signal.sv
${RTL_DIR}/rx_fifo.sv
${RTL_DIR}/tx_fifo.sv
${RTL_DIR}/cdc_sync.sv
${RTL_DIR}/spw_char_decode.sv

// --- Async FIFO ---
${RTL_DIR}/async_fifo/async_fifo.sv
${RTL_DIR}/async_fifo/fifomem.sv
${RTL_DIR}/async_fifo/rptr_empty.sv
${RTL_DIR}/async_fifo/sync_r2w.sv
${RTL_DIR}/async_fifo/sync_w2r.sv
${RTL_DIR}/async_fifo/wptr_full.sv
