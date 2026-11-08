import spw_pkg::*;

module state_machine (
    input i_sys_clk, // system clock
    input i_sys_rstn, // synchronized reset

    input i_link_start,
    input i_auto_start,
    input i_link_disable,
    input i_rx_space_ok, // don't start without room for the first FCT

    // RX
    input i_rx_got_null,
    input i_rx_got_fct,
    input i_rx_got_nchar,
    input i_rx_got_timecode,
    input i_rx_parity_err,
    input i_rx_esc_err,
    input i_rx_overflow_err,
    input i_disconnect,
    input i_rx_credit_err,

    // TX
    input i_tx_credit_err,

    // outputs, all registered from `next_state`
    output reg o_tx_enable, // High in {Started, Connecting, Run}
    output reg o_rx_enable, // High in {ErrorWait, Ready, Started, Connecting, Run}
    output reg o_fct_allowed, // High in {Connecting, Run}
    output reg o_link_run, // High in {Run}
    output reg o_link_error, // one cycle pulse after a fault in Run
    output e_link_state o_state

);
    localparam TIMER_W = $clog2(T_12U8_CYCLES + 1);

    wire rx_error = i_rx_parity_err | i_rx_esc_err | i_rx_overflow_err | i_disconnect;
    wire credit_error = i_tx_credit_err | i_rx_credit_err;
    wire link_enabled = (!i_link_disable) && (i_link_start || (i_auto_start && i_rx_got_null));

    e_link_state state, next_state;
    assign o_state = state;


    //temporizador
    logic timer_en;
    logic timer_clear;
    logic [TIMER_W-1:0] timer;
    
    always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
        if (!i_sys_rstn) timer <= '0;
        else if (timer_clear) timer <= '0;
        else if (timer_en) timer <= timer + 1'b1;
    end

    wire timeout_6u4  = timer >= T_6U4_CYCLES;
    wire timeout_12u8 = timer >= T_12U8_CYCLES;


    logic next_tx_enable, next_rx_enable, next_fct_allowed, next_link_run, next_link_error;
    always_ff @(posedge i_sys_clk or negedge i_sys_rstn) begin
        if (!i_sys_rstn) begin
            state <= LINK_ST_ERROR_RESET;
            // outputs
            o_tx_enable <= 0;
            o_rx_enable <= 0;
            o_fct_allowed <= 0;
            o_link_run <= 0;
            o_link_error <= 0;
        end else begin
            state <= next_state;
            o_tx_enable <= next_tx_enable;
            o_rx_enable <= next_rx_enable;
            o_fct_allowed <= next_fct_allowed;
            o_link_run <= next_link_run;
            o_link_error <= next_link_error;
        end
    end

    always_comb begin
        next_state = state;
        timer_en = 1'b0;
        timer_clear = 1'b0;
        // this is the only output here because we want it to be
        // a pulse when going from Run to ErrorReset
        next_link_error = 0;

        case (state)
            LINK_ST_ERROR_RESET: begin
                timer_en = 1'b1; 
                if (timeout_6u4) begin
                    next_state = LINK_ST_ERROR_WAIT;
                    timer_clear = 1'b1;
                end
            end
            LINK_ST_ERROR_WAIT: begin
                timer_en = 1'b1;
                if (rx_error | i_rx_got_fct | i_rx_got_nchar | i_rx_got_timecode) begin
                    next_state = LINK_ST_ERROR_RESET;
                    timer_clear = 1'b1;
                end else if (timeout_12u8) begin
                    next_state = LINK_ST_READY;
                    timer_clear = 1'b1;
                end 
            end

            LINK_ST_READY: begin
                if (rx_error | i_rx_got_fct | i_rx_got_nchar | i_rx_got_timecode) begin
                    next_state = LINK_ST_ERROR_RESET;
                    timer_clear = 1'b1;
                // we want to initiate communication only if it's possible to send FCTs
                // (if we have enough space in the receive buffer)
                end else if (link_enabled && i_rx_space_ok) begin
                    next_state = LINK_ST_STARTED;
                    timer_clear = 1'b1;
                end
            end

            LINK_ST_STARTED: begin
                timer_en = 1'b1;
                if (timeout_12u8 | rx_error | i_rx_got_fct | i_rx_got_nchar | i_rx_got_timecode) begin
                    next_state = LINK_ST_ERROR_RESET;
                    timer_clear = 1'b1;
                end else if (i_rx_got_null) begin
                    next_state = LINK_ST_CONNECTING;
                    timer_clear = 1'b1;
                end
            end

            LINK_ST_CONNECTING: begin
                timer_en = 1'b1;
                if (timeout_12u8 | rx_error | i_rx_got_nchar | i_rx_got_timecode) begin
                    next_state = LINK_ST_ERROR_RESET;
                    timer_clear = 1'b1;
                end else if (i_rx_got_fct) begin
                    next_state = LINK_ST_RUN;
                    timer_clear = 1'b1;
                end
            end

            LINK_ST_RUN: begin
                if (rx_error | credit_error | i_link_disable) begin
                    next_state = LINK_ST_ERROR_RESET;
                    next_link_error = rx_error | credit_error;
                    timer_clear = 1'b1;
                end
            end

            default: begin
                next_state = LINK_ST_ERROR_RESET;
            end
        endcase
    end

    // next outputs
    assign next_tx_enable = next_state inside {LINK_ST_STARTED, LINK_ST_CONNECTING, LINK_ST_RUN};
    assign next_rx_enable = next_state != LINK_ST_ERROR_RESET;
    assign next_fct_allowed = next_state inside {LINK_ST_CONNECTING, LINK_ST_RUN};
    assign next_link_run = next_state == LINK_ST_RUN;

endmodule
