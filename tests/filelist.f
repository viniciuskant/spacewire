// --- Defines ---
+define+$PDK_MACRO

// --- Testbench ---
${TESTS_DIR}/codec/tb_codec.sv

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

// --- FIFOs e sincronizadores (rtl/common) ---
${RTL_DIR}/common/async_fifo.sv
${RTL_DIR}/common/sync_2ff.sv
${RTL_DIR}/common/sync_gray_counter.sv
${RTL_DIR}/common/fifo.sv
${RTL_DIR}/common/reset_sync.sv
