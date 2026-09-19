module state_machine #(
    parameter CLK_FREQ = 10_000_000
)(
    input logic clk,
    input logic rst_n,

    // RX
    output logic en_rx,
    output logic rst_rx,
    input logic got_bit,
    input logic got_FCT,
    input logic got_null,
    input logic got_TimeCode,
    input logic got_N_Char,
    input logic got_Cred,
    input logic rx_Error,

    // TX
    output logic en_tx,
    output logic rst_tx,
    output logic send_FCT,
    output logic send_Null,
    output logic send_NChar,

    // FSM
    input logic link_disabled,
    input logic start_link,
    output logic run_state
);

    // TODO: por hora vou deixar assim
    logic auto_start;
    assign auto_start = 1'b1;

    //temporizador
    logic timer_en;
    logic timer_clear;
    logic [7:0] timer_us_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_us_cnt <= 8'd0;
        end else begin
            if (timer_clear) begin
                timer_us_cnt <= 8'd0;
            end else if (timer_en) begin
                timer_us_cnt <= timer_us_cnt + 1'b1;
            end
        end
    end

    localparam int unsigned T_6_4US_CYCLES  = (CLK_FREQ * 64) / 10_000_000;
    localparam int unsigned T_12_8US_CYCLES = (CLK_FREQ * 128) / 10_000_000;

    logic timeout_6_4us;
    logic timeout_12_8us;
    assign timeout_6_4us  = (timer_us_cnt >= T_6_4US_CYCLES);
    assign timeout_12_8us = (timer_us_cnt >= T_12_8US_CYCLES);


    typedef enum logic [2:0] {
        ERRO_RESET = 3'b000,
        ERRO_WAIT = 3'b001,
        READY = 3'b010,
        STARTED = 3'b011,
        CONNECTING = 3'b100,
        RUN = 3'b101
    } state_t;

    state_t current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ERRO_RESET;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        timer_en = 1'b0;
        timer_clear = 1'b0;

        case (current_state)
            ERRO_RESET: begin
                timer_en = 1'b1; 
                if (timeout_6_4us) begin
                    next_state = ERRO_WAIT;
                    timer_clear = 1'b1;
                end
            end

            ERRO_WAIT: begin
                timer_en = 1'b1;
                if (rx_Error | got_FCT | got_N_Char | got_TimeCode) begin
                    next_state = ERRO_RESET;
                    timer_clear = 1'b1;
                end else if (timeout_12_8us) begin
                    next_state = READY;
                    timer_clear = 1'b1;
                end 
            end

            READY: begin
                if (rx_Error | got_FCT | got_N_Char | got_TimeCode) begin
                    next_state = ERRO_RESET;
                    timer_clear = 1'b1;
                end else if (!link_disabled && (start_link || (auto_start && got_bit))) begin
                    next_state = STARTED;
                    timer_clear = 1'b1;
                end
            end

            STARTED: begin
                timer_en = 1'b1;
                if (timeout_12_8us | rx_Error | got_FCT | got_N_Char | got_TimeCode) begin
                    next_state = ERRO_RESET;
                    timer_clear = 1'b1;
                end else if (got_null) begin
                    next_state = CONNECTING;
                    timer_clear = 1'b1;
                end
            end

            CONNECTING: begin
                timer_en = 1'b1;
                if (timeout_12_8us | rx_Error | got_N_Char | got_TimeCode) begin
                    next_state = ERRO_RESET;
                    timer_clear = 1'b1;
                end else if (got_FCT) begin
                    next_state = RUN;
                    timer_clear = 1'b1;
                end
            end

            RUN: begin
                //no 4link, usa diferente, usa isso:
                // if ((! (!link_disabled && (start_link || (auto_start and got_bit))) )|| rx_Error) begin
                if (link_disabled || rx_Error) begin
                    next_state = ERRO_RESET;
                    timer_clear = 1'b1;
                end
            end

            default: begin
                next_state = ERRO_RESET;
            end
        endcase
    end

    // saídas
    always_comb begin
        en_rx = 1'b0;
        rst_rx = 1'b0;
        en_tx = 1'b0;
        rst_tx = 1'b0;
        send_FCT = 1'b0;
        send_Null = 1'b0;
        send_NChar = 1'b0;
        run_state = 1'b0;

        case (current_state)
            ERRO_RESET: begin
                rst_tx = 1'b1;
                rst_rx = 1'b1;
            end

            ERRO_WAIT: begin
                rst_tx = 1'b1;
                en_rx = 1'b1;
            end

            READY: begin
                rst_tx = 1'b1;
                en_rx = 1'b1;
            end

            STARTED: begin
                en_tx = 1'b1;
                send_Null = 1'b1;
                en_rx = 1'b1;
            end

            CONNECTING: begin
                en_tx = 1'b1;
                send_FCT = 1'b1;
                send_Null = 1'b1;
                en_rx = 1'b1;
            end

            RUN: begin
                en_tx = 1'b1;
                send_FCT = 1'b1;
                send_NChar = 1'b1;
                send_Null = 1'b1;
                en_rx = 1'b1;
                run_state = 1'b1;
            end
        endcase
    end

endmodule
