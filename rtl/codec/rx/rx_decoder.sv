import spw_pkg::*;
module rx_decoder (
    input i_rx_clk, // recovered clock
    input i_rx_rstn, // functional reset
    input [1:0] i_dpair, // D pair from ds_capture
    input i_pair_valid,
    // sticky flags, must be registered
    output logic o_got_null,
    output logic o_got_nchar,
    output logic o_got_timecode,
    // sticky errors
    output logic o_parity_error,
    output logic o_esc_error,
    // this error happens if the NCHAR FIFO gets full.
    // It shouldn't happen in normal operation but better
    // safe than sorry. TIMECODE FIFO doesn't get an error signal
    // because we can just drop excess timecodes.
    output logic o_fifo_error, 

    // pulses, can be combinational
    output o_inc_fct, // feeds into gray counter

    // NCHAR async FIFO (outputs not registered)
    input i_nchar_full, // if the NCHAR fifo is full
    output o_nchar_wr, // feeds into async FIFO
    output [8:0] o_nchar_data, // feeds into async FIFO

    // TIMECODE async FIFO (outputs not registered)
    input i_timecode_full, // if the timecode fifo is full
    output o_timecode_wr,
    output [7:0] o_timecode_data

);
typedef enum logic [3:0] {
    ST_PARITY = 0,
    ST_CTL = 1,
    ST_ERROR = 2,
    ST_DATA0 = 3,
    ST_DATA1 = 4,
    ST_DATA2 = 5,
    ST_DATA3 = 6
} state_t;

state_t state_reg, state_next;
logic esc_reg, esc_next;
logic xor_reg, xor_next;

logic [8:0] data_reg, data_next;

// combinatorial events (pulses)
logic dec_nchar; // a NCHAR was decoded
logic dec_tc; // a TIMECODE was decoded
logic dec_fct; // a FCT was decoded
logic dec_null; // a NULL was decoded
logic dec_parity_err; // we detected a parity error
logic dec_esc_err; // we detected an escape error
wire dec_fifo_err = dec_nchar && i_nchar_full;


// we're using data_next here to align the edge with the `wr` signals,
// which use the combinatorial signals `dec_*`.
assign o_nchar_data = data_next;
assign o_timecode_data = data_next[7:0];

assign o_nchar_wr = dec_nchar && !i_nchar_full;
assign o_timecode_wr = dec_tc && !i_timecode_full;

assign o_inc_fct = dec_fct;

always_ff @(posedge i_rx_clk or negedge i_rx_rstn) begin
    if (!i_rx_rstn) begin
        state_reg <= ST_PARITY;
        esc_reg <= 0;
        xor_reg <= 0;
        data_reg <= '0;

        // sticky errors and flags
        o_esc_error <= 0;
        o_fifo_error <= 0;
        o_parity_error <= 0;
        o_got_nchar <= 0;
        o_got_null <= 0;
        o_got_timecode <= 0;
    end else begin
        state_reg <= state_next;
        esc_reg <= esc_next;
        xor_reg <= xor_next;
        data_reg <= data_next;

        // sticky errors and flags
        o_esc_error <= o_esc_error | dec_esc_err;
        o_fifo_error <= o_fifo_error | dec_fifo_err;
        o_parity_error <= o_parity_error | dec_parity_err;
        o_got_nchar <= o_got_nchar | dec_nchar;
        o_got_null <= o_got_null | dec_null;
        o_got_timecode <= o_got_timecode | dec_tc;
    end
end

wire parity_bit = i_dpair[0];
wire ctl_flag = i_dpair[1];

always_comb begin
    // keep state by default
    state_next = state_reg;
    xor_next = xor_reg;
    data_next = data_reg;
    esc_next = esc_reg;

    // no events by default
    dec_fct = 0;
    dec_nchar = 0;
    dec_null = 0;
    dec_tc = 0;

    dec_parity_err = 0;
    dec_esc_err = 0;

    if (i_pair_valid) unique case (state_reg)
        ST_PARITY: begin
            // if the parity is not odd it's an error.
            // parity calculated as <previous payload> ^ parity bit ^ control flag
            if (!(xor_reg ^ parity_bit ^ ctl_flag)) begin
                state_next = ST_ERROR;
                dec_parity_err = 1;
            end else begin
                state_next = ctl_flag ? ST_CTL : ST_DATA0;
                xor_next = 0; // reset parity
            end
        end
        ST_DATA0: begin
            data_next = 0;
            state_next = ST_DATA1; data_next[1:0] = i_dpair;
        end
        ST_DATA1: begin
            state_next = ST_DATA2; data_next[3:2] = i_dpair;
        end
        ST_DATA2: begin
            state_next = ST_DATA3; data_next[5:4] = i_dpair;
        end
        ST_DATA3: begin
            state_next = ST_PARITY;
            data_next[8:6] = {1'b0, i_dpair};
            xor_next = ^data_next[7:0];
            if (esc_reg) dec_tc = 1;
            else dec_nchar = 1;
            esc_next = 0; // reset ESC memory
        end
        ST_CTL: begin
            xor_next = ^i_dpair;
            state_next = ST_PARITY;
            esc_next = 0; // reset ESC memory
            unique case ({i_dpair[0], i_dpair[1]})
                CODE_ESC: begin
                    if (esc_reg) begin
                        dec_esc_err = 1;
                        state_next = ST_ERROR;
                    end else begin
                        esc_next = 1;
                    end
                end
                CODE_EOP: begin
                    if (esc_reg) begin
                        dec_esc_err = 1;
                        state_next = ST_ERROR;
                    end else begin
                        data_next = {1'b1, 8'b0};
                        dec_nchar = 1;
                    end
                end
                CODE_EEP: begin
                    if (esc_reg) begin
                        dec_esc_err = 1;
                        state_next = ST_ERROR;
                    end else begin
                        data_next = {1'b1, 8'b1};
                        dec_nchar = 1;
                    end
                end
                CODE_FCT: begin
                    // {ESC, FCT} is a NULL
                    if (esc_reg) begin
                        dec_null = 1;
                    end else begin
                        dec_fct = 1;
                    end
                end
            endcase
        end
        default: begin
            state_next = ST_ERROR;
        end
    endcase
end

endmodule
