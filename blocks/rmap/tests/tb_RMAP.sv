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
            for (integer k = 0; k < 512; k = k + 1)
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
            for (integer j = 0; j < 8; j = j + 1) begin
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
        input  logic [7:0]  instruction,
        input  logic [15:0] transaction_id,
        input  logic [31:0] address,
        input  logic [23:0] data_length,
        output logic [7:0]  header_crc
    );
        logic [7:0] b;
        begin
            header_crc = 8'h00;

            b = 8'hFE; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = 8'h01; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = instruction; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            b = 8'hAA; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            
            source_path_base = 8'h20;
            for (int i = 0; i < instruction[1:0]; i++) begin
                b = source_path_base + (4*i) + 0; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 1; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 2; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
                b = source_path_base + (4*i) + 3; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);
            end

            b = 8'h30; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b);

            b = transaction_id[15:8];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = transaction_id[7:0];
            send_byte({1'b0, b});
            header_crc = calc_crc8(header_crc, b);

            b = 8'h00; send_byte({1'b0, b}); header_crc = calc_crc8(header_crc, b); // Extended address

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
                @(negedge clk);
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
            while ((dut.state !== dut.TX_SRC_PATH_ADDRESS) && cycles < 10000) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (dut.state !== dut.TX_SRC_PATH_ADDRESS) begin
                $error("[TB] DUT nao chegou a TX_SRC_PATH_ADDRESS em: %s", test_name);
                $fatal(1);
            end

            wait_reply(test_name);
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
        begin
            $display("[TB] WRITE addr=0x%08h data=0x%08h", address, value);

            send_header(8'h79, transaction_id, address, 24'd4, header_crc);

            data_crc = 8'h00;
            b = value[31:24]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[23:16]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[15:8]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = value[7:0]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            send_byte({1'b0, data_crc});

            finish_command($sformatf("WRITE 0x%08h", address));
        end
    endtask

    task automatic test_read(
        input string test_name,
        input logic [7:0] instruction,
        input logic [31:0] address,
        input logic [23:0] data_length,
        input logic [15:0] transaction_id
    );
        logic [7:0] header_crc;
        begin
            $display("[TB] %s addr=0x%08h length=%0d",
                     test_name, address, data_length);

            send_header(instruction, transaction_id, address,
                        data_length, header_crc);

            finish_command(test_name);
        end
    endtask

    task automatic test_rmw(
        input logic [31:0] address,
        input logic [31:0] data_value,
        input logic [31:0] mask_value,
        input logic [15:0] transaction_id
    );
        logic [7:0] header_crc;
        logic [7:0] data_crc;
        logic [7:0] b;
        begin
            $display("[TB] RMW addr=0x%08h data=0x%08h mask=0x%08h",
                     address, data_value, mask_value);

            send_header(8'h5C, transaction_id, address, 24'd8, header_crc);

            data_crc = 8'h00;
            b = data_value[31:24]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = data_value[23:16]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = data_value[15:8]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = data_value[7:0]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);

            b = mask_value[31:24]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = mask_value[23:16]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = mask_value[15:8]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            b = mask_value[7:0]; send_byte({1'b0, b}); data_crc = calc_crc8(data_crc, b);
            send_byte({1'b0, data_crc});

            finish_command($sformatf("RMW 0x%08h", address));
        end
    endtask

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
        test_read("READ SINGLE", 8'h48, 32'h00000004, 24'd4, 16'h0003);

        // READ INCREMENTING dos dois endereços
        test_read("READ INCREMENTING", 8'h4C, 32'h00000004, 24'd8, 16'h0004);

        // RMW
        test_rmw(32'h0000000C, 32'hAABBCCDD, 32'hFFFFFFFF, 16'h0005);

        // READ SINGLE do RMW
        test_read("READ SINGLE apos RMW", 8'h48, 32'h0000000C, 24'd4, 16'h0006);

        $display("[TB] Todos os testes da sequencia foram finalizados.");
        $finish;
    end

    initial begin
        #100000;
        $error("[TB] Timeout global da simulacao.");
        $fatal(1);
    end

endmodule
