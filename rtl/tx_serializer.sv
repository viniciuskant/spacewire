`include "tx_serializer_typ.svh"

// Serializes NULLs/FCTs/NCHARs/TIMECODEs into
// the spacewire protocol. The output is not yet
// Data-Strobe encoded.
module tx_serializer (
    // connected to the 200MHz clock
    input clk,
    // asynchronous reset
    input rst_n,
    // connected to the TX enable generator
    input bit_en,
    // connected to the FSM `tx_enable`
    input tx_enable,
    // the character type to send:
    // DATA     = 000; 0x0
    // EOP      = 001; 0x1
    // EEP      = 010; 0x2
    // FCT      = 011; 0x3
    // NULL     = 100; 0x4
    // TIMECODE = 101; 0x5
    input [2:0] payload_type,
    // only read if the payload type is DATA or TIMECODE
    input [7:0] payload,
    // asserted when the payload is valid
    input valid,
    // connected to the FIFO `i_rd`
    output pop,
    // the serialized data bit
    output data_out,
    // asserted when `data_out` is valid
    output valid_out
);
    // localparam [2:0] TYP_DATA = 0;
    // localparam [2:0] TYP_EOP  = 1;
    // localparam [2:0] TYP_EEP  = 2;
    // localparam [2:0] TYP_FCT  = 3;
    // localparam [2:0] TYP_NULL = 4;
    // localparam [2:0] TYP_TC   = 5;

    // character codes as defined per the spec
    localparam [0:1] CODE_FCT  = 2'b00;
    localparam [0:1] CODE_EOP  = 2'b01;
    localparam [0:1] CODE_EEP  = 2'b10;
    localparam [0:1] CODE_ESC  = 2'b11;


    // register for sending serialized bits
    logic [0:13] shift_reg;
    logic [3:0] shift_counter;
    // running parity is calculated on the data of the previous character.
    // this flipflop stores it.
    logic prev_xor;

    // value and payload size that gets loaded into the shift register.
    logic [0:13] shift_value;
    logic [3:0] shift_size;
    logic next_xor;

    // character boundary: the current character's last bit ends here
    wire boundary = tx_enable && bit_en && (shift_counter <= 1);

    // pop the payload from the fifo at a boundary; while disabled, keep popping to flush
    assign pop = (boundary && valid) || !tx_enable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 14'b0;
            shift_counter <= 4'b0;
            prev_xor <= 0;
        end else if (!tx_enable) begin
            shift_reg <= 14'b0;
            shift_counter <= 4'b0;
            prev_xor <= 0;
        end else if (boundary) begin
            // after finishing sending the current character,
            // load the next from the FIFO if there is one
            shift_counter <= shift_size;
            shift_reg <= shift_value;
            prev_xor <= next_xor;
        end else if (bit_en && shift_counter != 0) begin
            shift_reg <= shift_reg << 1;
            shift_counter <= shift_counter - 1;
        end
    end

    // calculated parity for the next character
    always_comb begin
        // if the FIFO is empty (!valid),
        // send a NULL to keep the link alive
        shift_size = 8;
        shift_value = 0;
        // first shift the ESC
        shift_value[0:3] = {prev_xor, 1'b1, CODE_ESC};
        // the FCT parity bit is 0 and the control flag is 1
        shift_value[4:7] = {2'b01, CODE_FCT};
        next_xor = ^CODE_FCT;

        if (valid) begin
            case (payload_type)
                TYP_FCT: begin
                    shift_size = 4;
                    // parity, control flag and control code
                    shift_value[0:3] = {prev_xor, 1'b1, CODE_FCT};
                    next_xor = ^CODE_FCT;
                end
                TYP_EOP: begin
                    shift_size = 4;
                    // parity, control flag and control code
                    shift_value[0:3] = {prev_xor, 1'b1, CODE_EOP};
                    next_xor = ^CODE_EOP;
                end
                TYP_EEP: begin
                    shift_size = 4;
                    shift_value[0:3] = {prev_xor, 1'b1, CODE_EEP};
                    next_xor = ^CODE_EEP;
                end
                TYP_DATA: begin
                    shift_size = 10;
                    shift_value[0] = !prev_xor;
                    // control flag = 0 for data characters
                    shift_value[1] = 0;
                    next_xor = ^payload;
                    // this for loop reverses the data bits into LSB-first
                    for (int i = 0; i < 8; ++i) begin
                        shift_value[i+2] = payload[i];
                    end
                end
                TYP_TC: begin
                    shift_size = 14;
                    // first shift the ESC
                    shift_value[0:3] = {prev_xor, 1'b1, CODE_ESC};
                    // the TC parity bit is 1 and the control flag is 0
                    shift_value[4:5] = 2'b10;
                    next_xor = ^payload;
                    // this for loop reverses the data bits into LSB-first
                    for (int i = 0; i < 8; ++i) begin
                        shift_value[i+6] = payload[i];
                    end
                end
                default: begin // TYP_NULL and unused codes
                    shift_size = 8;
                    // first shift the ESC
                    shift_value[0:3] = {prev_xor, 1'b1, CODE_ESC};
                    // the FCT parity bit is 0 and the control flag is 1
                    shift_value[4:7] = {2'b01, CODE_FCT};
                    next_xor = ^CODE_FCT;
                end
            endcase
            
        end

    end

    assign data_out = shift_reg[0];
    assign valid_out = shift_counter != 0;

    `ifndef SYNTHESIS
    assert property (@(posedge clk) disable iff (!rst_n)
        (boundary && valid) |-> payload_type inside {TYP_DATA, TYP_EOP, TYP_EEP, TYP_FCT, TYP_TC});
    `endif
endmodule
