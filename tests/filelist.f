// --- Defines ---
+define+$PDK_MACRO

// --- Testbench ---
${TESTS_DIR}/tb_codec.sv

// --- RTL Top ---
${RTL_DIR}/codec/codec.sv

// --- RTL Submódulos ---
${RTL_DIR}/codec/var_clk_divider.sv
${RTL_DIR}/codec/error_cleanup_fsm.sv
${RTL_DIR}/codec/flow_control.sv
${RTL_DIR}/codec/flow_control_rx.sv
${RTL_DIR}/codec/flow_control_tx.sv
${RTL_DIR}/codec/state_machine.sv
${RTL_DIR}/codec/rx.sv
${RTL_DIR}/codec/rx_char.sv
${RTL_DIR}/codec/rx_signal.sv
${RTL_DIR}/codec/tx.sv
${RTL_DIR}/codec/tx_char.sv
${RTL_DIR}/codec/tx_signal.sv
${RTL_DIR}/codec/cdc_sync.sv
${RTL_DIR}/codec/spw_char_decode.sv

// --- Async FIFO ---
${RTL_DIR}/fifos/async_fifo.sv
${RTL_DIR}/fifos/sync_fifo.sv
${RTL_DIR}/fifos/fifomem.sv
${RTL_DIR}/fifos/rptr_empty.sv
${RTL_DIR}/fifos/sync_r2w.sv
${RTL_DIR}/fifos/sync_w2r.sv
${RTL_DIR}/fifos/wptr_full.sv
