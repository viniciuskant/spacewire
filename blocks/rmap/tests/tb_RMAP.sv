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
        .tx_fifo_full(0),
        .busy(busy)
    );

    // enum errors
    localparam logic [4:0] RMAP_ERR_NONE = 5'd0; // Nenhum erro
    localparam logic [4:0] RMAP_ERR_INVALID_HEADER_CRC = 5'd1;
    localparam logic [4:0] RMAP_ERR_UNSUPPORTED_PROTOCOL = 5'd2;
    localparam logic [4:0] RMAP_ERR_SRC_LOGICAL_ADDR = 5'd3;
    localparam logic [4:0] RMAP_ERR_SRC_PATH_SEQ = 5'd4;
    localparam logic [4:0] RMAP_ERR_UNUSED_CMD_PKT = 5'd5;
    localparam logic [4:0] RMAP_ERR_INVALID_DEST_KEY = 5'd6;
    localparam logic [4:0] RMAP_ERR_INVALID_DATA_CRC = 5'd7;
    localparam logic [4:0] RMAP_ERR_EARLY_EOP = 5'd8;
    localparam logic [4:0] RMAP_ERR_CARGO_TOO_LARGE = 5'd9;
    localparam logic [4:0] RMAP_ERR_EARLY_EEP = 5'd10;
    localparam logic [4:0] RMAP_ERR_VERIFY_BUFFER_OVERRUN = 5'd11;
    localparam logic [4:0] RMAP_ERR_CMD_NOT_IMPLEMENTED = 5'd12; 
    localparam logic [4:0] RMAP_ERR_INVALID_DATA_LENGH = 5'd13; 
    localparam logic [4:0] RMAP_ERR_INVALID_REGISTER_ADDRESS = 5'd14;
    localparam logic [4:0] RMAP_ERR_RMW_DATA_LENGH_ERROR = 5'd15;
    localparam logic [4:0] RMAP_ERR_INVALID_DESTINATION_LOGICAL_ADDRESS = 5'd16;

    // enum code errors
    localparam logic [7:0] RMAP_CODE_NONE = 8'h00;
    localparam logic [7:0] RMAP_CODE_NO_REPLY = 8'hFF;

    localparam logic [7:0] RMAP_CODE_UNUSED_CMD_PKT = 8'h02;
    localparam logic [7:0] RMAP_CODE_INVALID_DEST_KEY = 8'h03;
    localparam logic [7:0] RMAP_CODE_INVALID_DATA_CRC = 8'h04;
    localparam logic [7:0] RMAP_CODE_EARLY_EOP = 8'h05;
    localparam logic [7:0] RMAP_CODE_CARGO_TOO_LARGE = 8'h06;
    localparam logic [7:0] RMAP_CODE_EARLY_EEP = 8'h07;
    localparam logic [7:0] RMAP_CODE_VERIFY_BUFFER_OVERRUN = 8'h09;
    localparam logic [7:0] RMAP_CODE_CMD_NOT_IMPLEMENTED = 8'h0A;
    localparam logic [7:0] RMAP_CODE_INVALID_DATA_LENGH = 8'h0A;
    localparam logic [7:0] RMAP_CODE_INVALID_REGISTER_ADDRESS = 8'h0A;
    localparam logic [7:0] RMAP_CODE_RMW_DATA_LENGH_ERROR = 8'h0B;
    localparam logic [7:0] RMAP_CODE_INVALID_DESTINATION_LOGICAL_ADDRESS = 8'h0C;
        
        

    function automatic logic [7:0] get_expected_status(input logic [4:0] err_type);
        case (err_type)
            RMAP_ERR_NONE: return RMAP_CODE_NONE; 
            
            // Erros que NÃO geram resposta
            RMAP_ERR_INVALID_HEADER_CRC: return RMAP_CODE_NO_REPLY; 
            RMAP_ERR_UNSUPPORTED_PROTOCOL: return RMAP_CODE_NO_REPLY; 
            RMAP_ERR_SRC_LOGICAL_ADDR: return RMAP_CODE_NO_REPLY; 
            RMAP_ERR_SRC_PATH_SEQ: return RMAP_CODE_NO_REPLY; 

            // Erros que GERAM resposta
            RMAP_ERR_UNUSED_CMD_PKT: return RMAP_CODE_UNUSED_CMD_PKT; 
            RMAP_ERR_INVALID_DEST_KEY: return RMAP_CODE_INVALID_DEST_KEY; 
            RMAP_ERR_INVALID_DATA_CRC: return RMAP_CODE_INVALID_DATA_CRC; 
            RMAP_ERR_EARLY_EOP: return RMAP_CODE_EARLY_EOP;
            RMAP_ERR_CARGO_TOO_LARGE: return RMAP_CODE_CARGO_TOO_LARGE;
            RMAP_ERR_EARLY_EEP: return RMAP_CODE_EARLY_EEP;
            RMAP_ERR_VERIFY_BUFFER_OVERRUN: return RMAP_CODE_VERIFY_BUFFER_OVERRUN;
            RMAP_ERR_CMD_NOT_IMPLEMENTED: return RMAP_CODE_CMD_NOT_IMPLEMENTED;
            RMAP_ERR_INVALID_DATA_LENGH: return RMAP_CODE_INVALID_DATA_LENGH;
            RMAP_ERR_INVALID_REGISTER_ADDRESS: return RMAP_CODE_INVALID_REGISTER_ADDRESS;
            RMAP_ERR_RMW_DATA_LENGH_ERROR: return RMAP_CODE_RMW_DATA_LENGH_ERROR;
            RMAP_ERR_INVALID_DESTINATION_LOGICAL_ADDRESS: return RMAP_CODE_INVALID_DESTINATION_LOGICAL_ADDRESS;

            default: return RMAP_CODE_NONE; 
        endcase
    endfunction

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
        output logic [7:0] header_crc,
        input logic [7:0]  destination_key, // Corrigido de 'estination_key'
        input logic [4:0] type_erro
    );
        logic [7:0] b;
        begin
            header_crc = 8'h00;
            
            if (type_erro == RMAP_ERR_INVALID_DESTINATION_LOGICAL_ADDRESS) begin
                b = 8'hFF; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            end else begin
                b = 8'hFE; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            end
            
            b = 8'h01; 
            if (type_erro == RMAP_ERR_UNSUPPORTED_PROTOCOL) b = 8'hFF; // Injeta erro
            send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            
            b = instruction; 
            if (type_erro == RMAP_ERR_UNUSED_CMD_PKT) b = 8'h3D; // Injeta erro (Packet Type/Command inválido)
            send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            
            b = destination_key; 
            if (type_erro == RMAP_ERR_INVALID_DEST_KEY) b = ~destination_key; // Injeta erro (Key invertida)
            send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            
            source_path_base = 8'h20;
            for (int i = 0;i < instruction[1:0];i++) begin
                b = source_path_base + (4*i) + 0; 
                if (type_erro == RMAP_ERR_SRC_PATH_SEQ && i == 0) b = 8'h00; // Injeta erro no primeiro byte do path
                send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                
                b = source_path_base + (4*i) + 1; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 2; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 3; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            end

            b = 8'h30; 
            if (type_erro == RMAP_ERR_SRC_LOGICAL_ADDR) b = 8'h1F; // Injeta erro (Valor fora do range 20h-FFh)
            send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);

            b = transaction_id[15:8];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = transaction_id[7:0];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = 8'h00; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);// Extended address

            b = address[31:24]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[23:16]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[15:8]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = address[7:0]; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);

            b = data_length[23:16];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = data_length[15:8];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = data_length[7:0];
            if (type_erro == RMAP_ERR_INVALID_DATA_LENGH) b = b + 8'h01;
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            if (type_erro == RMAP_ERR_EARLY_EEP) send_byte({1'b1, 8'h01}); // EEP

            b = header_crc;
            if (type_erro == RMAP_ERR_INVALID_HEADER_CRC) b = ~header_crc; // Injeta erro (CRC invertido)
            send_byte({1'b0, b});

            if (type_erro == RMAP_ERR_EARLY_EOP) send_byte({1'b1, 8'h02});
            
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

            $display("Aguardando resposta: %s", test_name);

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
                $error("Timeout esperando a resposta de: %s", test_name);
                $fatal(1);
            end

            if (count == 0) begin
                $error("EOP recebido, mas nenhum byte de resposta foi capturado: %s",
                       test_name);
                $fatal(1);
            end

            $display("Resposta de '%s' recebida: %0d bytes + EOP.\n",
                     test_name, count);
        end
    endtask

    task automatic finish_write_command(
        input string test_name,
        input logic [1:0] source_path_len, 
        input logic [15:0] expected_tid, 
        input logic [7:0] expected_status,
        input logic [4:0] type_erro
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        logic [7:0] status_to_wait;
        begin
            if (type_erro == RMAP_ERR_CARGO_TOO_LARGE) send_byte(9'h1ff);
            else send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            // Verifica qual o status esperado baseado no tipo de erro
            status_to_wait = get_expected_status(type_erro);

            // Tratamento exclusivo para erros que NÃO geram resposta
            if (status_to_wait == RMAP_CODE_NO_REPLY) begin
                cycles = 0;
                // Espera o DUT retornar ao estado IDLE (ignorando estados de TX)
                while ((dut.state !== dut.RX_IDLE) && cycles < 10000) begin
                    @(negedge clk);
                    cycles = cycles + 1;
                end

                if (cycles >= 10000) begin
                    $error("DUT nao chegou a RX_IDLE (esperado para erro sem resposta) em: %s", test_name);
                    $fatal(1);
                end

                $display("Erro sem resposta verificado com sucesso: %s\n\n", test_name);
                return; // Encerra a task, pois não há resposta para ser verificada
            end

            // Fluxo normal (Para erros que GERAM resposta)
            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
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
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command / Src Path Addr Len
            // Ajuste dinâmico baseado no tipo de erro
            if (type_erro == RMAP_ERR_UNUSED_CMD_PKT)
                b = {2'b00, 4'b1111, source_path_len}; // Comando inválido (eco do 0x3C)
            else if (type_erro == RMAP_ERR_RMW_DATA_LENGH_ERROR)
                b = {2'b00, 4'b0111, source_path_len};
            else
                b = {2'b00, 4'b1110, source_path_len}; // WRITE normal (0x38)

            // Como o comando foi enviado errado, forço não chegar ele
            if (reply_buf[idx] !== b && type_erro != RMAP_ERR_CMD_NOT_IMPLEMENTED) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status (Preenchido dinamicamente com base no erro testado)
            b = expected_status;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reply CRC
            b = expected_crc;
            if (reply_buf[idx] !== b && type_erro != RMAP_ERR_CMD_NOT_IMPLEMENTED) $error("Erro no Byte %0d (CRC). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);

            $display("Resposta de WRITE verificada com sucesso para erro: %0d\n\n", type_erro);
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
        input integer num_words,
        input logic [4:0] type_erro
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        integer data_bytes;
        logic [31:0] current_word;
        logic [7:0] status_to_wait;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            // Verifica qual o status esperado baseado no tipo de erro
            status_to_wait = get_expected_status(type_erro);

            // Tratamento exclusivo para erros que NÃO geram resposta
            if (status_to_wait == RMAP_CODE_NO_REPLY) begin
                cycles = 0;
                // Espera o DUT retornar ao estado IDLE (ignorando estados de TX)
                while ((dut.state !== dut.RX_IDLE) && cycles < 10000) begin
                    @(negedge clk);
                    cycles = cycles + 1;
                end

                if (cycles >= 10000) begin
                    $error("DUT nao chegou a RX_IDLE (esperado para erro sem resposta) em: %s", test_name);
                    $fatal(1);
                end

                $display("Erro sem resposta verificado com sucesso: %s\n\n", test_name);
                return; // Encerra a task, pois não há resposta para ser verificada
            end

            // Fluxo normal (Para erros que GERAM resposta)
            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
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
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command(0010 Read Single) / Src Path Addr Len
            b = {2'b00, command_read, source_path_len};
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status
            b = expected_status;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reserved = 0
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Calcula o Data Length em bytes (cada palavra = 4 bytes)
            data_bytes = num_words * 4;

            // Data Length (MS)
            b = data_bytes[23:16];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length
            b = data_bytes[15:8];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (LS)
            b = data_bytes[7:0];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Header CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("Erro no Header CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            idx = idx + 1;

            // Zera o CRC para calcular o Data CRC
            expected_crc = 8'h00;

            // Loop para verificar os dados
            for (int w = 0;w < num_words;w++) begin
                current_word = expected_data_list[data_start_idx + w];
                
                // Data (MSB)
                b = current_word[31:24];
                if (reply_buf[idx] !== b) $error("Erro no Data MSB (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data
                b = current_word[23:16];
                if (reply_buf[idx] !== b) $error("Erro no Data (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data
                b = current_word[15:8];
                if (reply_buf[idx] !== b) $error("Erro no Data (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                // Data (LSB)
                b = current_word[7:0];
                if (reply_buf[idx] !== b) $error("Erro no Data LSB (Word %0d, Byte %0d). Esp: 0x%02h, Obt: 0x%02h", w, idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Data CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("Erro no Data CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            
            if (command_read == 4'h02) $display("Resposta de READ SINGLE verificada com sucesso!\n\n");
            else $display("Resposta de READ INCREMENTING verificada com sucesso!\n\n");
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic finish_rmw_command(
        input string test_name,
        input logic [1:0] source_path_len, 
        input logic [15:0] expected_tid, 
        input logic [7:0] expected_status,
        input logic [31:0] expected_data,
        input logic [4:0] type_erro
    );
        integer cycles;
        logic [7:0] expected_crc;
        logic [7:0] b;
        integer idx;
        logic [7:0] status_to_wait;
        begin
            send_byte(9'h102);
            
            @(posedge clk);
            rx_valid <= 1'b0;
            @(posedge clk);

            // Verifica qual o status esperado baseado no tipo de erro
            status_to_wait = get_expected_status(type_erro);

            // Tratamento exclusivo para erros que NÃO geram resposta
            if (status_to_wait == RMAP_CODE_NO_REPLY) begin
                cycles = 0;
                // Espera o DUT retornar ao estado IDLE (ignorando estados de TX)
                while ((dut.state !== dut.RX_IDLE) && cycles < 10000) begin
                    @(negedge clk);
                    cycles = cycles + 1;
                end

                if (cycles >= 10000) begin
                    $error("DUT nao chegou a RX_IDLE (esperado para erro sem resposta) em: %s", test_name);
                    $fatal(1);
                end

                $display("Erro sem resposta verificado com sucesso: %s\n\n", test_name);
                return; // Encerra a task, pois não há resposta para ser verificada
            end

            // Fluxo normal (Para erros que GERAM resposta)
            cycles = 0;
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && (dut.state !== dut.TX_SRC_LOGICAL_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles >= 10000) begin
                $error("DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
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
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 1;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 2;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;

                b = source_path_base_reply + (4*i) + 3;
                if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
                expected_crc = calc_crc8(expected_crc, b);
                idx = idx + 1;
            end

            // Source Logical Address
            b = 8'h30;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Protocol Identifier
            b = 8'h01;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Packet Type(00) / Command(0111 RMW) / Src Path Addr Len
            b = {2'b00, 4'b0111, source_path_len};
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Status
            b = expected_status;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Destination Logical Address
            b = 8'hFE;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (MS)
            b = expected_tid[15:8];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Transaction Identifier (LS)
            b = expected_tid[7:0];
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Reserved = 0
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (MS)
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length
            b = 8'h00;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data Length (LS) = 04 (Fixo para RMW, conforme imagem)
            b = 8'h04;
            if (reply_buf[idx] !== b) $error("Erro no Byte %0d. Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Header CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("Erro no Header CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            idx = idx + 1;

            // Zera o CRC para calcular o Data CRC
            expected_crc = 8'h00;

            // Data (Word 0 MSB)
            b = expected_data[31:24];
            if (reply_buf[idx] !== b) $error("Erro no Data MSB (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data
            b = expected_data[23:16];
            if (reply_buf[idx] !== b) $error("Erro no Data (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data
            b = expected_data[15:8];
            if (reply_buf[idx] !== b) $error("Erro no Data (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data (Word 0 LSB)
            b = expected_data[7:0];
            if (reply_buf[idx] !== b) $error("Erro no Data LSB (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);
            expected_crc = calc_crc8(expected_crc, b);
            idx = idx + 1;

            // Data CRC
            b = expected_crc;
            if (reply_buf[idx] !== b) $error("Erro no Data CRC (Byte %0d). Esp: 0x%02h, Obt: 0x%02h", idx, b, reply_buf[idx]);

            $display("Resposta de READ MODIFY WRITE verificada com sucesso!\n\n");
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
            $display("Reset concluido.\n");
        end
    endtask

    task automatic test_write_reg(input logic [31:0] address, input logic [31:0] value, input logic [15:0] transaction_id, logic [7:0] expected_status, input logic [7:0] destination_key, input logic [4:0] type_erro);
        logic [7:0] header_crc;
        logic [7:0] data_crc;
        logic [7:0] b;
        logic [7:0] command_write;
        begin
            $display("WRITE addr=0x%08h data=0x%08h", address, value);


            if (type_erro == RMAP_ERR_CMD_NOT_IMPLEMENTED) command_write = 8'h61;
            else if (type_erro == RMAP_ERR_VERIFY_BUFFER_OVERRUN) command_write = 8'h78;
            else command_write = 8'h79;

            send_header(command_write, transaction_id, address, 24'd4, header_crc, destination_key, type_erro);

            data_crc = 8'h00;
            b = value[31:24]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[23:16]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[15:8]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = value[7:0]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            
            // Injeção do erro de Data CRC
            b = data_crc;
            if (type_erro == RMAP_ERR_INVALID_DATA_CRC) begin
                b = ~data_crc; // Inverte o CRC calculado para forçar a falha no DUT
            end
            send_byte({1'b0, b});

            finish_write_command($sformatf("WRITE 0x%08h", address), command_write[1:0], transaction_id, expected_status, type_erro);
        end
    endtask

    task automatic test_read(
        input string test_name,
        input logic [7:0] instruction,
        input logic [31:0] address,
        input logic [23:0] data_length,
        input logic [15:0] transaction_id,
        input logic [31:0] expected_data_list[],
        input integer num_words,
        input logic [31:0] expected_status,
        input logic [7:0]  destination_key,
        input logic [4:0] type_erro
    );
        logic [7:0] header_crc;
        begin
            $display("%s addr=0x%08h length=%0d",
                     test_name, address, data_length);

            send_header(instruction, transaction_id, address, data_length, header_crc, destination_key, type_erro);

            finish_read_command(test_name, instruction[5:2], instruction[1:0], transaction_id, expected_status, expected_data_list, 0, num_words, type_erro);
        end
    endtask

    task automatic test_rmw(
        input logic [31:0] address,
        input logic [31:0] data_value,
        input logic [31:0] mask_value,
        input logic [15:0] transaction_id,
        input logic [31:0] expected_data,
        input logic [31:0] expected_status,
        input logic [7:0]  destination_key,
        input logic [4:0] type_erro
    );
        logic [7:0] header_crc;
        logic [7:0] data_crc;
        logic [7:0] b;
        logic [7:0] instruction;
        begin
            $display("RMW addr=0x%08h data=0x%08h mask=0x%08h",
                     address, data_value, mask_value);

            instruction = 8'h5C;
            if (type_erro == RMAP_ERR_RMW_DATA_LENGH_ERROR) send_header(instruction, transaction_id, address, 24'd9, header_crc, destination_key, type_erro);
            else send_header(instruction, transaction_id, address, 24'd8, header_crc, destination_key, type_erro);

            data_crc = 8'h00;
            b = data_value[31:24]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[23:16]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[15:8]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = data_value[7:0]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);

            b = mask_value[31:24]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[23:16]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[15:8]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            b = mask_value[7:0]; send_byte({1'b0, b});data_crc = calc_crc8(data_crc, b);
            send_byte({1'b0, data_crc});

            if (type_erro == RMAP_ERR_RMW_DATA_LENGH_ERROR)
                finish_write_command($sformatf("RMW 0x%08h", address), instruction[1:0], transaction_id, expected_status, type_erro);
            else
                finish_rmw_command($sformatf("RMW 0x%08h", address), instruction[1:0], transaction_id, expected_status, expected_data, type_erro);

        end
    endtask

    logic [31:0] expected_single_data[0:9];
    logic [7:0] destination_key;
    logic [7:0] status;
    logic [4:0] type_erro;
    logic [4:0] cnt_test;
    initial begin
        $dumpfile("waves/tb_RMAP.vcd");
        $dumpvars(0, tb_RMAP);

        rst_n = 1'b0;
        rx_valid = 1'b0;
        rx_data = 9'h000;
        destination_key = 8'hAA;
        status = 8'h00;
        cnt_test = 5'b0;
        do_reset();

        // TESTES SEQUENCIAIS

        // Dois WRITEs em palavras consecutivas
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        test_write_reg(32'h00000004, 32'h11223344, 16'h0001, status, destination_key, type_erro);
        cnt_test = 5'h01;

        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        test_write_reg(32'h00000008, 32'h55667788, 16'h0002, status, destination_key, type_erro);
        cnt_test = 5'h02;

        // WRITE
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'h99AABBCC, 16'h00010, status, destination_key, type_erro);
        cnt_test = 5'h03;

        // READ SINGLE do primeiro endereço
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        expected_single_data[0] = 32'h11223344;
        test_read("READ SINGLE", 8'h48, 32'h00000004, 24'd4, 16'h0003, expected_single_data, 1, status, destination_key, type_erro);
        cnt_test = 5'h04;


        // READ INCREMENTING dos dois endereços
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        expected_single_data[0] = 32'h11223344;
        expected_single_data[1] = 32'h55667788;
        test_read("READ INCREMENTING", 8'h4C, 32'h00000004, 24'd8, 16'h0004, expected_single_data, 2, status, destination_key, type_erro);
        cnt_test = 5'h05;

        // RMW
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        test_rmw(32'h0000000C, 32'hAABBCCDD, 32'hFFFFFFFF, 16'h0005, 32'h99AABBCC, status, destination_key, type_erro);
        cnt_test = 5'h06;

        // READ SINGLE do RMW
        type_erro = RMAP_ERR_NONE;
        status = get_expected_status(type_erro);
        expected_single_data[0] = 32'hAABBCCDD;
        test_read("READ SINGLE apos RMW", 8'h48, 32'h0000000C, 24'd4, 16'h0006, expected_single_data, 1, status, destination_key, type_erro);
        cnt_test = 5'h07;

        // TESTES DE ERROS QUE NÃO GERAM RESPOSTA (No Reply Packet)

        // Erro: CRC do Header Inválido
        $display("\nTestando Erro: CRC do Header Invalido (No Reply Packet)");
        type_erro = RMAP_ERR_INVALID_HEADER_CRC;
        status = get_expected_status(type_erro); // Retornará RMAP_CODE_NO_REPLY
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h0007, status, destination_key, type_erro);
        cnt_test = 5'h08;

        // Erro: Protocolo Não Suportado (Protocol ID != 01h)
        $display("\nTestando Erro: Protocolo Nao Suportado (No Reply Packet)");
        type_erro = RMAP_ERR_UNSUPPORTED_PROTOCOL;
        status = get_expected_status(type_erro); // Retornará RMAP_CODE_NO_REPLY
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h0008, status, destination_key, type_erro);
        cnt_test = 5'h09;

        // Erro: Source Logical Address Inválido (Fora do range 20h-FFh)
        $display("\nTestando Erro: Source Logical Address Invalido (No Reply Packet)");
        type_erro = RMAP_ERR_SRC_LOGICAL_ADDR;
        status = get_expected_status(type_erro); // Retornará RMAP_CODE_NO_REPLY
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h0009, status, destination_key, type_erro);
        cnt_test = 5'h0A;

        // Erro: Sequência do Source Path Address Inválida
        $display("\nTestando Erro: Sequencia do Source Path Address Invalida (No Reply Packet)");
        type_erro = RMAP_ERR_SRC_PATH_SEQ;
        status = get_expected_status(type_erro); // Retornará RMAP_CODE_NO_REPLY
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000A, status, destination_key, type_erro);
        cnt_test = 5'h0B;


        // TESTES DE ERROS QU GERAM RESPOSTA (With Reply Packet)
        // TODO apenas implementei os type_erro detro do test_write_reg, ou seja, seria interessante implementar nos outros

        // Erro: Unused RMAP command or packet type
        $display("\nTestando Erro: Unused RMAP command or packet type (With Reply Packet)");
        type_erro = RMAP_ERR_UNUSED_CMD_PKT;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000B, status, destination_key, type_erro);
        cnt_test = 5'h0C;

        // Erro: Invalid Destination Key
        $display("\nTestando Erro: Invalid Destination Key (With Reply Packet)");
        type_erro = RMAP_ERR_INVALID_DEST_KEY;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000C, status, destination_key, type_erro);
        cnt_test = 5'h0D;

        // Erro: Invalid Data CRC
        $display("\nTestando Erro: Invalid Data CRC (With Reply Packet)");
        type_erro = RMAP_ERR_INVALID_DATA_CRC;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h0E;

        // Erro: Early EOP
        $display("\nTestando Erro: EARLY EOP (With Reply Packet)");
        type_erro = RMAP_ERR_EARLY_EOP;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h0F;

        // Erro: Cargo too large
        $display("\nTestando Erro: CARGO TOO LARGE (With Reply Packet)");
        type_erro = RMAP_ERR_CARGO_TOO_LARGE;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h10;

        // Erro: Early EEP
        $display("\nTestando Erro: EARLY EEP (With Reply Packet)");
        type_erro = RMAP_ERR_EARLY_EEP;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h11;

        // Erro: Verify Buffer Overrun
        $display("\nTestando Erro: VERIFY BUFFER OVERRUN (With Reply Packet)");
        type_erro = RMAP_ERR_VERIFY_BUFFER_OVERRUN;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h12;

        // Erro: Commmand not implemented
        $display("\nTestando Erro: COMMAND NOT IMPLEMENTED (With Reply Packet)");
        type_erro = RMAP_ERR_CMD_NOT_IMPLEMENTED;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h13;

        // Erro: Invalid data length
        $display("\nTestando Erro: INVALID DATA LENTH (With Reply Packet)");
        type_erro = RMAP_ERR_INVALID_DATA_LENGH;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h14;

        // Erro: Invalid Register Address
        // o error depende apenas do endereço que é colocado
        $display("\nTestando Erro: INVALID REGISTER ADDRESS (With Reply Packet)");
        type_erro = RMAP_ERR_INVALID_REGISTER_ADDRESS;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000_0101, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);
        cnt_test = 5'h15;


        // Erro: Invalid Register Address
        // depende apenas do endereço que é colocado
        $display("\nTestando Erro: RMW DATA LENGH ERROR (With Reply Packet)");
        type_erro = RMAP_ERR_RMW_DATA_LENGH_ERROR;
        status = get_expected_status(type_erro);
        test_rmw(32'h0000000C, 32'hAABBCCDD, 32'hFFFFFFFF, 16'h0005, 32'h99AABBCC, status, destination_key, type_erro);
        cnt_test = 5'h16;

        // Erro: Invalid destination logical address
        // depende apenas do endereço que é colocado
        $display("\nTestando Erro: INVALID DESTINATION LOGICAL ADDRESS (With Reply Packet)");
        type_erro = RMAP_ERR_INVALID_DESTINATION_LOGICAL_ADDRESS;
        status = get_expected_status(type_erro);
        test_write_reg(32'h0000000C, 32'hDEADBEEF, 16'h000D, status, destination_key, type_erro);

        $display("Todos os testes da sequencia foram finalizados.");
        $finish;
    end

    initial begin
        #10000;
        $error("Timeout global da simulacao.");
        $fatal(1);
    end

endmodule
