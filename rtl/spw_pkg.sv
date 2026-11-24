
package spw_pkg;
    typedef enum logic [1:0] {
        CODE_FCT = 2'b00,
        CODE_EOP = 2'b01,
        CODE_EEP = 2'b10,
        CODE_ESC = 2'b11
    } e_ctl_char;
    typedef enum logic [2:0] {
        PAYLOAD_DATA = 3'd0,
        PAYLOAD_EOP = 3'd1,
        PAYLOAD_EEP = 3'd2,
        PAYLOAD_FCT = 3'd3,
        PAYLOAD_TC = 3'd4,
        PAYLOAD_NULL = 3'd5
    } e_payload_type;

    typedef enum logic [2:0] {
        LINK_ST_ERROR_RESET = 3'b000,
        LINK_ST_ERROR_WAIT = 3'b001,
        LINK_ST_READY = 3'b010,
        LINK_ST_STARTED = 3'b011,
        LINK_ST_CONNECTING = 3'b100,
        LINK_ST_RUN = 3'b101
    } e_link_state;


    parameter  int SYS_CLK_MHZ = 50;
    // 6.4us * freq(MHz) = 64us * freq(MHz) / 10
    localparam int T_6U4_CYCLES = (64 * SYS_CLK_MHZ) / 10;   // 320
    localparam int T_12U8_CYCLES = T_6U4_CYCLES * 2;   // 640
    // disconnect window = 850ns * freq(GHz) = 850ns * freq(MHz) / 1000
    localparam int DISCONNECT_CYCLES = (850 * SYS_CLK_MHZ) / 1_000;   // 42
    localparam int MAX_CREDITS = 56;
    localparam int FCT_GRANT   = 8;

    localparam logic [8:0] CONST_EOP = {1'b1, 8'b0};
    localparam logic [8:0] CONST_EEP = {1'b1, 8'b1};
endpackage
