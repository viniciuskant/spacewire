module rmap_crc8 (
    input logic clk,
    input logic [7:0] crc_in,
    input logic [7:0] data_in,
    output logic [7:0] crc_out,
    input valid
);
    always_ff @(posedge clk) begin
        if (valid) begin
            crc_out[0] <= crc_in[0] ^ crc_in[6] ^ crc_in[7] ^ data_in[0] ^ data_in[6] ^ data_in[7];
            crc_out[1] <= crc_in[0] ^ crc_in[1] ^ crc_in[6] ^ data_in[0] ^ data_in[1] ^ data_in[6];
            crc_out[2] <= crc_in[0] ^ crc_in[1] ^ crc_in[2] ^ crc_in[6] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[6];
            crc_out[3] <= crc_in[1] ^ crc_in[2] ^ crc_in[3] ^ crc_in[7] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[7];
            crc_out[4] <= crc_in[2] ^ crc_in[3] ^ crc_in[4] ^ data_in[2] ^ data_in[3] ^ data_in[4];
            crc_out[5] <= crc_in[3] ^ crc_in[4] ^ crc_in[5] ^ data_in[3] ^ data_in[4] ^ data_in[5];
            crc_out[6] <= crc_in[4] ^ crc_in[5] ^ crc_in[6] ^ data_in[4] ^ data_in[5] ^ data_in[6];
            crc_out[7] <= crc_in[5] ^ crc_in[6] ^ crc_in[7] ^ data_in[5] ^ data_in[6] ^ data_in[7];
        end
    end

endmodule