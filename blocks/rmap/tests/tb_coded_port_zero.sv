`timescale 1ns / 1ps

module tb_coded_port_zero;
    localparam int DATA_WIDTH_FIFO = 9;
    localparam int DEPTH_FIFO = 16;

    logic clk;
    logic rst_n;

    logic [DATA_WIDTH_FIFO-1:0] spw_rx_data;
    logic spw_rx_valid;
    logic spw_rx_ready;

    logic [DATA_WIDTH_FIFO-1:0] spw_tx_data;
    logic spw_tx_valid;
    logic spw_tx_ready;

    logic [31:0] reg_bank_w_data;
    logic [8:0] reg_bank_w_addr;
    logic reg_bank_w_en;

    logic [31:0] reg_bank_r_data;
    logic [8:0] reg_bank_r_addr;
    logic reg_bank_r_en;

    logic [31:0] reg_mem [0:511];
    logic [7:0] reply_buf [0:255];
    integer reply_count;

    coded_port_zero #(
        .DATA_WIDTH_FIFO(DATA_WIDTH_FIFO),
        .DEPTH_FIFO (DEPTH_FIFO)
    ) dut (
        .clk (clk),
        .rst_n (rst_n),

        .spw_rx_data (spw_rx_data),
        .spw_rx_valid (spw_rx_valid),
        .spw_rx_ready (spw_rx_ready),

        .spw_tx_data (spw_tx_data),
        .spw_tx_valid (spw_tx_valid),
        .spw_tx_ready (spw_tx_ready),

        .reg_bank_w_data (reg_bank_w_data),
        .reg_bank_w_addr (reg_bank_w_addr),
        .reg_bank_w_en (reg_bank_w_en),

        .reg_bank_r_data (reg_bank_r_data),
        .reg_bank_r_addr (reg_bank_r_addr),
        .reg_bank_r_en (reg_bank_r_en)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int k = 0; k < 512; k++) reg_mem[k] <= 32'h0;
        end else if (reg_bank_w_en) begin
            reg_mem[reg_bank_w_addr] <= reg_bank_w_data;
            $display("[REG] WRITE addr=0x%03h data=0x%08h", reg_bank_w_addr, reg_bank_w_data);
        end
    end

    always_ff @(posedge clk) begin
        if (reg_bank_r_en)
            reg_bank_r_data <= reg_mem[reg_bank_r_addr];
    end

    function automatic logic [7:0] calc_crc8(input logic [7:0] seed, input logic [7:0] data);
        logic [7:0] c;
        c = seed ^ data;
        for (int j = 0; j < 8; j++)
            c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
        return c;
    endfunction

    task automatic send_byte(input logic [8:0] data);
        begin
            @(posedge clk);
            spw_rx_data <= data;
            spw_rx_valid <= 1'b1;
            @(posedge clk);
            while (!spw_rx_ready) @(posedge clk);
            spw_rx_valid <= 1'b0;
        end
    endtask


    task automatic send_header(
        input logic [7:0]  instruction,
        input logic [15:0] transaction_id,
        input logic [31:0] address,
        input logic [23:0] data_length,
        input logic [7:0]  destination_key
    );
        logic [7:0] b;
        logic [7:0] header_crc;
        logic [7:0] source_path_base;
        begin
            header_crc = 8'h00;
            source_path_base = 8'h20;

            b = 8'hFE; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = 8'h01; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = instruction; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = destination_key;send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);

            for (int i = 0; i < instruction[1:0]; i++) begin
                b = source_path_base + (4*i) + 0; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 1; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 2; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 3; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            end

            b = 8'h30; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = transaction_id[15:8]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = transaction_id[7:0]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = 8'h00; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[31:24]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[23:16]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[15:8]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[7:0]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = data_length[23:16]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = data_length[15:8]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = data_length[7:0]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = header_crc; send_byte({1'b0, b});
        end
    endtask

    task automatic wait_reply(input string name);
        integer cycles;
        begin
            reply_count = 0;
            cycles = 0;
            while (cycles < 10000) begin
                @(negedge clk);
                if (spw_tx_valid) begin
                    if (spw_tx_data[8]) begin
                        $display("[%s] EOP @ cycle %0d. Total bytes: %0d",
                                 name, cycles, reply_count);
                        cycles = 10000;
                    end else begin
                        reply_buf[reply_count] = spw_tx_data[7:0];
                        $display("[%s] reply[%0d] = 0x%02h",
                                 name, reply_count, spw_tx_data[7:0]);
                        reply_count = reply_count + 1;
                    end
                end
                cycles = cycles + 1;
            end
            if (cycles >= 10000 && reply_count == 0)
                $error("[%s] Timeout: nenhuma resposta recebida", name);
        end
    endtask

    task automatic do_write(
        input logic [31:0] addr,
        input logic [31:0] value,
        input logic [15:0] tid
    );
        logic [7:0] data_crc, b;
        begin
            $display("\n=== WRITE addr=0x%08h data=0x%08h tid=0x%04h ===",
                     addr, value, tid);
            send_header(8'h79, tid, addr, 24'd4, 8'hAA);

            data_crc = 8'h00;
            b = value[31:24]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[23:16]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[15:8]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[7:0]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = data_crc; send_byte({1'b0, b});

            wait_reply("WRITE");

            if (reply_count > 7) begin
                if (reply_buf[6] !== 8'h39)
                    $error("WRITE cmd=0x%02h (esp 0x39)", reply_buf[6]);
                if (reply_buf[7] !== 8'h00)
                    $error("WRITE status=0x%02h (esp 0x00)", reply_buf[7]);
            end
        end
    endtask

    task automatic do_read(
        input string       name,
        input logic [7:0]  instr,
        input logic [31:0] addr,
        input logic [23:0] dlen,
        input logic [15:0] tid
    );
        begin
            $display("\n=== %s addr=0x%08h dlen=%0d tid=0x%04h ===",
                     name, addr, dlen, tid);
            send_header(instr, tid, addr, dlen, 8'hAA);
            wait_reply(name);
            if (reply_count > 3) begin
                if (reply_buf[3] !== 8'h00)
                    $error("%s status=0x%02h (esp 0x00)", name, reply_buf[3]);
            end
        end
    endtask

    task automatic do_reset;
        begin
            rst_n = 1'b0;
            spw_rx_valid = 1'b0;
            spw_rx_data = 9'h000;
            spw_tx_ready = 1'b1;   // sempre pronto para drenar o TX FIFO
            repeat (5)  @(posedge clk);
            rst_n = 1'b1;
            repeat (10) @(posedge clk);
            $display("Reset concluido.\n");
        end
    endtask

    initial begin
        $dumpfile("tb_coded_port_zero.vcd");
        $dumpvars(0, tb_coded_port_zero);

        do_reset();

        do_write(32'h00000004, 32'h11223344, 16'h0001);
        do_write(32'h00000008, 32'h55667788, 16'h0002);

        do_read("READ SINGLE", 8'h48, 32'h00000004, 24'd4, 16'h0003);
        if (reply_count >= 16) begin
            if ({reply_buf[12], reply_buf[13], reply_buf[14], reply_buf[15]} !== 32'h11223344)
                $error("READ SINGLE data mismatch: 0x%02h%02h%02h%02h (esp 0x11223344)",
                       reply_buf[12], reply_buf[13], reply_buf[14], reply_buf[15]);
            else
                $display("READ SINGLE: dados corretos (0x11223344)");
        end

        do_read("READ INCREMENTING", 8'h4C, 32'h00000004, 24'd8, 16'h0004);
        if (reply_count >= 20) begin
            if ({reply_buf[12], reply_buf[13], reply_buf[14], reply_buf[15]} !== 32'h11223344)
                $error("READ INC word0 mismatch");
            else
                $display("READ INC: word0 = 0x11223344 (correto)");

            if ({reply_buf[16], reply_buf[17], reply_buf[18], reply_buf[19]} !== 32'h55667788)
                $error("READ INC word1 mismatch");
            else
                $display("READ INC: word1 = 0x55667788 (correto)");
        end

        #1000;
        $display("\n=== Simulacao concluida ===");
        $finish;
    end

    // Timeout global
    initial begin
        #500000;
        $error("Timeout global da simulacao");
        $fatal(1);
    end

endmodule