
package spw_pkg;
    typedef enum bit [1:0] {
        CODE_FCT = 2'b00,
        CODE_EOP = 2'b01,
        CODE_EEP = 2'b10,
        CODE_ESC = 2'b11
    } e_ctl_char;
    typedef enum bit [2:0] {
        PAYLOAD_DATA = 3'd0,
        PAYLOAD_EOP = 3'd1,
        PAYLOAD_EEP = 3'd2,
        PAYLOAD_FCT = 3'd3,
        PAYLOAD_TC = 3'd4,
        PAYLOAD_NULL = 3'd5
    } e_payload_type;
endpackage
