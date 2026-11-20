# Router Synthesis

## Codec Synthesis

### Constrains Checklist

1. Asynchronous FIFOs
   - Check gray counter pointers
2. FCT/activity gray counters
   - Bit skew between updates
3. Recovered RX clock
   - Negated RX clock
   - Maximum skew between D and S
   - Clock uncertainty
   - DONT_TOUCHs
4. 2FFs
   - Distance between FFs
5. Resets
   - Reset synchronizer
   - False paths
6. Quasi-static configuration
   - Run rate divider
7. Asynchronous clocks

### Constraints Review (`common/constraints/codec.tcl`)

Reviewed by reading the file against the RTL and `tools/dc/scripts`; not run through DC yet.

#### Must fix

1. **`dont_touch` on `rx_clk_rec` before compile (line 36).** `rx_clk_rec` still holds a generic `xor` primitive and an `~` inverter. A `dont_touch` applied before `compile_ultra` stops DC from mapping them, so GTECH cells would end up on the RX clock. Either:
   - instantiate the PDK XOR/inverter cells in `rx_clk_rec.sv` (see its TODOs) and `dont_touch` those leaf cells, or
   - apply the `dont_touch` after the first compile, before `compile_ultra -incremental`.
2. **`u_tx/u_clk_gate/u_icg` doesn't exist (line 37).** There's no ICG in `rtl/`. With `-quiet`, `set_dont_touch` gets an empty argument, which will probably error. Remove the line or guard it with `sizeof_collection` until the ICG exists. The comment on line 34 also mentions a "test mux" that isn't in the RTL. Note that `compile_ultra -gate_clock` inserts its own clock-gating cells, which is unrelated to a hand-placed ICG.

#### Still open

- **`i_sys_rstn` has no input delay** (excluded by `NOT_SYS_IN`, line 92). Its release timing in the sys domain isn't checked. Constrain it on `clk_sys`, as `i_tx_rstn` is on `clk_tx`.
- **`u_rx/rx_rstn_reg` isn't protected.** It drives the RX async resets. DC ignores the RTL `(* dont_touch *)`, so add an explicit `set_dont_touch`. The same applies to the `(* async_reg *)` attributes on the synchronizer flops.
- **RX uncertainty is too pessimistic** (lines 123–124). The 1.1 ns external skew/jitter applies to every `clk_rx` path, including internal flop-to-flop and hold paths that share the recovered clock. Expect heavy hold buffering. That budget belongs only on the pad → capture-flop paths.
- **The D-capture check is an absolute limit** (lines 114–115). The real requirement (see `rx_ds_capture.sv`) is relative: the `i_D` → `d_*_reg` path must be faster than `i_D` → XOR → clock tree → CK. `set_max_delay 1.0` only guarantees this if the clock path is longer than 1 ns, and `set_min_delay 0.0` adds nothing. Check it with `set_data_check` or a post-CTS comparison of arrival times.
- **Gray-code limits are exactly one RX period.** `cdc_pair` gives 10 ns for RX ↔ sys, but the activity counters change on every 10 ns RX edge, so the skew between bits must be strictly less. Use roughly 0.8–0.9 × `T_RX_CLK`, or the per-FIFO/per-counter version in the TODO.
- **No `o_D`/`o_S` skew constraint.** Line 104 only sets a 1.0 ns output delay. The link cares about the skew between D and S, so add a min output delay (or a skew check) to keep the two paths balanced.
- **No input transition/drive model.** While the driving cell is a TODO, add a `set_input_transition` as the old `constraints.tcl` had.
- **Minor:** `FSM_RX_EN` (line 11) is unused, line 39 still just says "# constrain", and the commented line 64 still uses `$T_TX`.

#### Design note (RTL, not constraints)

`rx_rstn` releases one sys cycle after `rx_enable` rises in ErrorWait, when the far end may already be sending. The release can therefore be asynchronous to an active `clk_rx`. The `clk_sys → clk_rx` max delay limits the path delay but can't prevent metastability on release. Consider making the RX flops tolerate a bad first edge, for example by gating on `primed` or adding a short release chain.
