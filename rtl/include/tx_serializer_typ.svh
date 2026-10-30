`ifndef TX_SERIALIZER_TYP_SVH
`define TX_SERIALIZER_TYP_SVH


typedef enum logic [2:0] {
    TYP_DATA = 3'd0,
    TYP_EOP = 3'd1,
    TYP_EEP = 3'd2,
    TYP_FCT = 3'd3,
    TYP_NULL = 3'd4,
    TYP_TC = 3'd5
} char_typ;

`endif