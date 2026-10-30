`include "tx_serializer_typ.svh"

// this module chooses which characters to send to the
// serializer, according to the priority rule:
// TC > FCT > NCHAR > NULL.
// NULLs are generated directly in the serializer, so we
// ignore them here.
// CDC: It communicates with the serializer through
// the asynchronous FIFO, so this module stays in the
// system domain.
module tx_selector (
    input link_connecting,
    input link_run,
    input fct_due,
    input tc_valid,
    input [7:0] tc_data,
    input nchar_valid,
    input [8:0] nchar_data,
    input has_credit,
    input wr_ready,
    output wr_valid,
    output [2:0] wr_payload_type,
    output [7:0] wr_payload,
    output fct_accept,
    output tc_accept,
    output nchar_accept
);
wire fct_ok = fct_due && (link_connecting || link_run);
wire tc_ok = tc_valid && link_run;
wire nchar_ok = nchar_valid && has_credit && link_run;

// one-hot grant
wire grant_tc = tc_ok;
wire grant_fct = !tc_ok && fct_ok;
wire grant_nchar = !tc_ok && !fct_ok && nchar_ok;

assign wr_valid = grant_tc || grant_fct || grant_nchar;

always_comb begin
    wr_payload = 0;
    wr_payload_type = 0;
    if (grant_tc) begin
        wr_payload_type = TYP_TC;
        wr_payload = tc_data;
    end else if (grant_tc) begin
        wr_payload_type = TYP_FCT;
    end else if (grant_nchar) begin
        if (!nchar_data[8]) begin // it's a data NCHAR
            wr_payload_type = TYP_DATA;
            wr_payload = nchar_data[7:0];
        end else if (!nchar_data[0]) wr_payload_type = TYP_EOP;
        else wr_payload_type = TYP_EEP;
    end
end

assign fct_accept = wr_ready && grant_fct;
assign nchar_accept = wr_ready && grant_nchar;
assign tc_accept = wr_ready && grant_tc;
endmodule