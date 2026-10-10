module spw_char_decode (
    input logic system_clk,
    input logic rst_n,
    input logic [9:0] rd_data_fifo_sync,
    input logic rd_empty_fifo_sync,
    output logic rd_en_fifo_sync,

    output logic [7:0] payload,
    output logic is_data,
    output logic is_fct,
    output logic is_eep,
    output logic is_eop,
    output logic is_null,
    output logic is_timecode

);

    always_ff @(posedge system_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_en_fifo_sync <= 1'b0;
            payload <= 8'h00;
        end else begin
            rd_en_fifo_sync <= 1'b0;

            if (!rd_empty_fifo_sync) begin
                rd_en_fifo_sync <= 1'b1; // pop da FIFO
                payload <= rd_data_fifo_sync[9:2];
                is_fct <= 1'b0;
                is_eep <= 1'b0;
                is_eop <= 1'b0;
                is_null <= 1'b0;
                is_timecode <= 1'b0;

                case (rd_data_fifo_sync[1:0])
                    2'b00: begin
                        is_data <= 1'b1;
                    end
                    2'b01: begin
                        is_fct <= (rd_data_fifo_sync[3:2] == 2'b00);
                        is_eep <= (rd_data_fifo_sync[3:2] == 2'b01);
                        is_eop <= (rd_data_fifo_sync[3:2] == 2'b10);
                    end
                    2'b10: begin
                        is_null <= 1'b1;
                    end
                    2'b11: begin
                        is_timecode <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
