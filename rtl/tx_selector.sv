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
    input i_link_connecting,
    input i_link_run,
    input i_fct_due,
    input i_tc_valid,
    input [7:0] i_tc_data,
    input i_nchar_valid,
    input [8:0] i_nchar_data,
    input i_has_credit,
    input i_wr_ready,
    output o_wr_valid,
    output logic [2:0] o_wr_payload_type,
    output logic [7:0] o_wr_payload,
    output o_fct_accept,
    output o_tc_accept,
    output o_nchar_accept
);
wire fct_ok = i_fct_due && (i_link_connecting || i_link_run);
wire tc_ok = i_tc_valid && i_link_run;
wire nchar_ok = i_nchar_valid && i_has_credit && i_link_run;

// one-hot grant
wire grant_tc = tc_ok;
wire grant_fct = !tc_ok && fct_ok;
wire grant_nchar = !tc_ok && !fct_ok && nchar_ok;

assign o_wr_valid = grant_tc || grant_fct || grant_nchar;

always_comb begin
    o_wr_payload = 0;
    o_wr_payload_type = 0;
    if (grant_tc) begin
        o_wr_payload_type = TYP_TC;
        o_wr_payload = i_tc_data;
    end else if (grant_fct) begin
        o_wr_payload_type = TYP_FCT;
    end else if (grant_nchar) begin
        if (!i_nchar_data[8]) begin // it's a data NCHAR
            o_wr_payload_type = TYP_DATA;
            o_wr_payload = i_nchar_data[7:0];
        end else if (!i_nchar_data[0]) o_wr_payload_type = TYP_EOP;
        else o_wr_payload_type = TYP_EEP;
    end
end

assign o_fct_accept = i_wr_ready && grant_fct;
assign o_nchar_accept = i_wr_ready && grant_nchar;
assign o_tc_accept = i_wr_ready && grant_tc;
endmodule