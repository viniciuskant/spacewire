
spw_pkg.sv

common/async_fifo.sv
common/sync_2ff.sv
common/sync_gray_counter.sv
common/fifo.sv
common/reset_sync.sv

codec/tx/cdc_sys_tx.sv
codec/tx/tx_ds_encoder.sv
codec/tx/tx_enable_gen.sv
codec/tx/tx_selector.sv
codec/tx/tx_serializer.sv
codec/tx/tx_spill.sv
codec/tx/tx_timecode_slot.sv
codec/tx/tx.sv

codec/rx/cdc_sys_rx.sv
codec/rx/rx_decoder.sv
codec/rx/rx_clk_rec.sv
codec/rx/rx_ds_capture.sv
codec/rx/rx_link_mon.sv
codec/rx/rx_buffer_wr.sv
codec/rx/rx.sv

codec/credit.sv
codec/state_machine.sv
codec/codec.sv

rmap/rmap_crc8.sv
rmap/rmap_reg_bank.sv
rmap/RMAP.sv
rmap/coded_port_zero.sv

router/sw_route_table.sv
router/sw_in_ctrl.sv
router/sw_out_arb.sv
router/sw_crossbar.sv
router/sw_tc_unit.sv
router/spw_switch.sv

top/spw_router.sv
