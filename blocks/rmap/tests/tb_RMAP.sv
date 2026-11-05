`timescale 1ns / 1ps

module tb_RMAP;
    logic clk;
    logic rst_n;

    logic [8:0] rx_data;
    logic rx_valid;
    logic [8:0] tx_data;
    logic tx_valid;

    logic [31:0] reg_bank_w_data;
    logic [8:0] reg_bank_w_addr;
    logic reg_bank_w_en;

    logic [31:0] reg_bank_r_data;
    logic [8:0] reg_bank_r_addr;
    logic reg_bank_r_en;
    logic busy;

    // banco de registradores simulado
    logic [31:0] reg_mem [0:511];

    // para guardar e imprimir as respostas.
    logic [7:0] reply_buf [0:255];

    integer i;

    RMAP dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .reg_bank_w_data(reg_bank_w_data),
        .reg_bank_w_addr(reg_bank_w_addr),
        .reg_bank_w_en(reg_bank_w_en),
        .reg_bank_r_data(reg_bank_r_data),
        .reg_bank_r_addr(reg_bank_r_addr),
        .reg_bank_r_en(reg_bank_r_en),
        .busy(busy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    always_ff @(posedge clk) begin
        if (reg_bank_r_en)
            reg_bank_r_data = reg_mem[reg_bank_r_addr];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (integer k = 0;k < 512;k = k + 1)
                reg_mem[k] <= 32'h00000000;
        end else if (reg_bank_w_en) begin
            reg_mem[reg_bank_w_addr] <= reg_bank_w_data;
            $display("[TB][REG] WRITE addr_bus=0x%03h data=0x%08h", reg_bank_w_addr, reg_bank_w_data);
        end
    end

    function automatic logic [7:0] calc_crc8(input logic [7:0] seed, input logic [7:0] data);
        logic [7:0] c;
        begin
            c = seed ^ data;
            for (integer j = 0;j < 8;j = j + 1) begin
                if (c[7])
                    c = (c << 1) ^ 8'h07;
                else
                    c = c << 1;
            end
            return c;
        end
    endfunction

    task automatic send_byte(input logic [8:0] data);
        @(posedge clk);
        // #1;
        rx_valid <= 1'b1;
        rx_data <= data;
    endtask

    logic [7:0] source_path_base;
    task automatic send_header(
        input  logic [7:0] instruction,
        input  logic [15:0] transaction_id,
        input  logic [31:0] address,
        input  logic [23:0] data_length,
        output logic [7:0] header_crc
    );
        logic [7:0] b;
        begin
            header_crc = 8'h00;

            b = 8'hFE;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = 8'h01;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = instruction;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = 8'hAA;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            
            source_path_base = 8'h20;
            for (int i = 0;i < instruction[1:0];i++) begin
                b = source_path_base + (4*i) + 0;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 1;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 2;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 3;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            end

            b = 8'h30;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);

            b = transaction_id[15:8];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = transaction_id[7:0];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = 8'h00;send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);// Extended address

            b = address[31:24];send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = address[23:16];send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = address[15:8];send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);
            b = address[7:0];send_byte({1'b0, b});header_crc = calc_crc8(header_crc, b);

            b = data_length[23:16];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = data_length[15:8];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = data_length[7:0];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            send_byte({1'b0, header_crc});
        end
    endtask


    task automatic wait_reply(input string test_name);
        integer cycles;
        integer count;
        logic eop_seen;
        begin
            cycles   = 0;
            count    = 0;
            eop_seen = 1'b0;

            $display("[TB] Aguardando resposta: %s", test_name);

            while (!eop_seen && cycles < 10000) begin
                cycles = cycles + 1;

                if (tx_valid == 1'b1) begin
                    if (tx_data[8] == 1'b1) begin
                        eop_seen = 1'b1;
                        $display("[TB][RX] EOP da resposta: tx_data=0x%03h", tx_data);
                    end else begin
                        if (count < 256)
                            reply_buf[count] = tx_data[7:0];

                        $display("[TB][RX] resposta[%0d] = 0x%02h",
                                 count, tx_data[7:0]);
                        count = count + 1;
                    end
                end
                @(negedge clk);
            end

            if (!eop_seen) begin
                $error("[TB] Timeout esperando a resposta de: %s", test_name);
                $fatal(1);
            end

            if (count == 0) begin
                $error("[TB] EOP recebido, mas nenhum byte de resposta foi capturado: %s",
                       test_name);
                $fatal(1);
            end

            $display("[TB] Resposta de '%s' recebida: %0d bytes + EOP.\n",
                     test_name, count);
        end
    endtask

    task automatic finish_command(input string test_name);
        integer cycles;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("[TB] DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
                $fatal(1);
            end

            wait_reply(test_name);
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic finish_write_command(
        input string test_name,
        input logic [1:0] source_path_len, 
        input logic [15:0] expected_tid, 
        input logic [7:0] expected_status
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("[TB] DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
                $fatal(1);
            end

            // coleta a resposta na reply_buf
            wait_reply(test_name);

            // similar ao send_header
            expected_crc = 8'h00;
            idx = 0;

            source_path_base_reply = 8'h20;
            for (int i = 0;i < source_path_len;i++) begin
                b = source_path_base_reply + (4*i) + 0;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command(1110) / Src Path Addr Len(00) = 0x38
            b = {2'b00, 4'b1110, source_path_len};
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status
            b = expected_status;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reply CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d (CRC). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);

            $display("[TB] Resposta de WRITE verificada com sucesso!\n\n");
            repeat (2) @(posedge clk);
        end
    endtask


    logic [7:0] source_path_base_reply;
        task automatic finish_read_command(
        input string test_name,
        input logic [3:0] command_read, 
        input logic [1:0] source_path_len, 
        input logic [15:0] expected_tid, 
        input logic [7:0] expected_status,
        input logic [31:0] expected_data_list[],
        input integer data_start_idx,
        input integer num_words
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        integer data_bytes;
        logic [31:0] current_word;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("[TB] DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
                $fatal(1);
            end

            // coleta a resposta na reply_buf
            wait_reply(test_name);

            // similar ao send_header
            expected_crc = 8'h00;
            idx = 0;

            // Source Path Address (Variável)
            source_path_base_reply = 8'h20;
            for (int i = 0;i < source_path_len;i++) begin
                b = source_path_base_reply + (4*i) + 0;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command(0010 Read Single) / Src Path Addr Len
            b = {2'b00, command_read, source_path_len};
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status
            b = expected_status;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reserved = 0
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Calcula o Data Length em bytes (cada palavra = 4 bytes)
            data_bytes = num_words * 4;

            // Data Length (MS)
            b = data_bytes[23:16];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length
            b = data_bytes[15:8];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (LS)
            b = data_bytes[7:0];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Header CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Header CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            idx = idx + 1;

            // Zera o CRC para calcular o Data CRC
            expected_crc = 8'h00;

            // Loop para verificar os dados
            for (int w = 0;w < num_words;w++) begin
                current_word = expected_data_list[data_start_idx + w];
                
                // Data (MSB)
                b = current_word[31:24];
                if (reply_buf[idx] !== b) $error("[TB] Erro no Data MSB (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data
                b = current_word[23:16];
                if (reply_buf[idx] !== b) $error("[TB] Erro no Data (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data
                b = current_word[15:8];
                if (reply_buf[idx] !== b) $error("[TB] Erro no Data (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data (LSB)
                b = current_word[7:0];
                if (reply_buf[idx] !== b) $error("[TB] Erro no Data LSB (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Data CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            
            if (command_read == 4'h02) $display("[TB] Resposta de READ SINGLE verificada com sucesso!\n\n");
            else $display("[TB] Resposta de READ INCREMENTING verificada com sucesso!\n\n");
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic finish_rmw_command(
        input string test_name,
        input logic [1:0] source_path_len, 
        input logic [15:0] expected_tid, 
        input logic [7:0] expected_status,
        input logic [31:0] expected_data
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("[TB] DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
                $fatal(1);
            end

            // coleta a resposta na reply_buf
            wait_reply(test_name);

            // similar ao send_header
            expected_crc = 8'h00;
            idx = 0;

            // Source Path Address (Variável)
            source_path_base_reply = 8'h20;
            for (int i = 0;i < source_path_len;i++) begin
                b = source_path_base_reply + (4*i) + 0;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command(0111 RMW) / Src Path Addr Len
            b = {2'b00, 4'b0111, source_path_len};
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status
            b = expected_status;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reserved = 0
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (MS)
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (LS) = 04 (Fixo para RMW, conforme imagem)
            b = 8'h04;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Header CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Header CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            idx = idx + 1;

            // Zera o CRC para calcular o Data CRC
            expected_crc = 8'h00;

            // Data (Word 0 MSB)
            b = expected_data[31:24];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data MSB (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data
            b = expected_data[23:16];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data
            b = expected_data[15:8];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data (Word 0 LSB)
            b = expected_data[7:0];
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data LSB (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("[TB] Erro no Data CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);

            $display("[TB] Resposta de READ MODIFY WRITE verificada com sucesso!\n\n");
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic do_reset;
        begin
            rst_n = 1'b0;
            rx_valid = 1'b0;
            rx_data = 9'h000;

            repeat (3) @(negedge clk);
            rst_n = 1'b1;

            wait (busy == 1'b0);
            @(posedge clk);
            $display("[TB] Reset concluido.\n");
        end
    endtask

    task automatic test_write_reg(input logic [31:0] address, input logic [31:0] value, input logic [15:0] transaction_id);
        logic [7:0] header_crc;
        logic [7:0] data_crc;
        logic [7:0] b;
        logic [7:0] command_write;
        begin
            $display("[TB] WRITE addr=0x%08h data=0x%08h", address, value);

            command_write = 8'h79;
            send_header(command_write, transaction_id, address, 24'd4, header_crc);

            data_crc = 8'h00;
            b = value[31:24];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[23:16];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[15:8];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[7:0];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            send_byte({1'b0, data_crc});

            finish_write_command($sformatf("WRITE 0x%08h", address), command_write[1:0], transaction_id, 8'h00);
        end
    endtask

    task automatic test_read(
        input string test_name,
        input logic [7:0] instruction,
        input logic [31:0] address,
        input logic [23:0] data_length,
        input logic [15:0] transaction_id,
        input logic [31:0] expected_data_list[],
        input integer num_words
    );
        logic [7:0] header_crc;
        begin
            $display("[TB] %s addr=0x%08h length=%0d",
                     test_name, address, data_length);

            send_header(instruction, transaction_id, address,
                        data_length, header_crc);

            finish_read_command(test_name, instruction[5:2], instruction[1:0], transaction_id, 8'h00, expected_data_list, 0, num_words);
        end
    endtask

    task automatic test_rmw(
        input logic [31:0] address,
        input logic [31:0] data_value,
        input logic [31:0] mask_value,
        input logic [15:0] transaction_id,
        input logic [31:0] expected_data
    );
        logic [7:0] header_crc;
        logic [7:0] data_crc;
        logic [7:0] b;
        logic [7:0] instruction;
        begin
            $display("[TB] RMW addr=0x%08h data=0x%08h mask=0x%08h",
                     address, data_value, mask_value);

            instruction = 8'h5C;
            send_header(instruction, transaction_id, address, 24'd8, header_crc);

            data_crc = 8'h00;
            b = data_value[31:24];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[23:16];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[15:8];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[7:0];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);

            b = mask_value[31:24];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[23:16];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[15:8];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[7:0];send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            send_byte({1'b0, data_crc});

            finish_rmw_command($sformatf("RMW 0x%08h", address), instruction[1:0], transaction_id, 8'h00, expected_data);

        end
    endtask

    logic [31:0] expected_single_data[0:9];
    initial begin
        $dumpfile("waves/tb_RMAP.vcd");
        $dumpvars(0, tb_RMAP);

        rst_n = 1'b0;
        rx_valid = 1'b0;
        rx_data = 9'h000;

        do_reset();

        // Dois WRITEs em palavras consecutivas
        test_write_reg(32'h00000004, 32'h11223344, 16'h0001);
        
        test_write_reg(32'h00000008, 32'h55667788, 16'h0002);

        // WRITE
        test_write_reg(32'h0000000C, 32'h99AABBCC, 16'h00010);

        // READ SINGLE do primeiro endereço
        expected_single_data[0] = 32'h11223344;
        test_read("READ SINGLE", 8'h48, 32'h00000004, 24'd4, 16'h0003, expected_single_data, 1);


        // READ INCREMENTING dos dois endereços
        expected_single_data[0] = 32'h11223344;
        expected_single_data[1] = 32'h55667788;
        test_read("READ INCREMENTING", 8'h4C, 32'h00000004, 24'd8, 16'h0004, expected_single_data, 2);

        // RMW
        test_rmw(32'h0000000C, 32'hAABBCCDD, 32'hFFFFFFFF, 16'h0005, 32'h99AABBCC);

        // READ SINGLE do RMW
        expected_single_data[0] = 32'hAABBCCDD;
        test_read("READ SINGLE apos RMW", 8'h48, 32'h0000000C, 24'd4, 16'h0006, expected_single_data, 1);

        $display("[TB] Todos os testes da sequencia foram finalizados.");
        $finish;
    end

    initial begin
        #200000;
        $error("[TB] Timeout global da simulacao.");
        $fatal(1);
    end

endmodule
