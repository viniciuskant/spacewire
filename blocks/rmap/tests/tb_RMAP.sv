`timescale 1ns / 1ps

module tb_RMAP;

    // Sinais do DUT
    logic clk;
    logic rst_n;

    logic [7:0] rx_data;
    logic rx_valid;
    logic [7:0] tx_data;
    logic tx_valid;

    logic [31:0] reg_bank_w_data;
    logic [8:0] reg_bank_w_addr;
    logic reg_bank_w_en;

    logic [31:0] reg_bank_r_data;
    logic [8:0] reg_bank_r_addr;
    logic reg_bank_r_en;
    logic init_busy;

    // Instância do DUT
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
        .init_busy(init_busy)
    );

    // Geração do Clock (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Função para calcular o CRC-8 (Padrão RMAP: Polinômio 0x07, Init 0x00)
    function automatic [7:0] calc_crc8(input [7:0] seed, input [7:0] data);
        logic [7:0] c;
        c = seed ^ data;
        for (int i = 0; i < 8; i++) begin
            if (c[7])
                c = (c << 1) ^ 8'h07;
            else
                c = (c << 1);
        end
        return c;
    endfunction

    task send_byte(input logic [7:0] data);
        begin
            @(negedge clk);
            rx_data = data;
            rx_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            rx_valid = 1'b0;
        end
    endtask

    // Task de Reset
    task do_reset();
        begin
            rst_n <= 1'b0;
            rx_valid <= 1'b0;
            rx_data <= 8'h00;
            repeat(3) @(posedge clk);
            rst_n <= 1'b1;
            @(posedge clk);
            wait (init_busy == 0)
            @(posedge clk);
        end
    endtask

    // Variáveis para o cálculo do CRC no testbench
    logic [7:0] crc_h;
    logic [7:0] crc_d;
    logic [7:0] data_in;

    // Task para testar o Read Single
    task test_read_single();
        begin
            $display("[TB] Iniciando Teste: Read Single");
            crc_h = 8'h00;
            
            send_byte(8'hFE); crc_h = calc_crc8(8'hFE, crc_h);
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h);
            send_byte(8'h48); crc_h = calc_crc8(8'h48, crc_h); // Packet Type, Cmd, Src Len
            send_byte(8'hAA); crc_h = calc_crc8(8'hAA, crc_h); // Destination Key
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Source Logical Address
            send_byte(8'h12); crc_h = calc_crc8(8'h12, crc_h); // Transaction ID MS
            send_byte(8'h34); crc_h = calc_crc8(8'h34, crc_h); // Transaction ID LS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Extended Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h); // Target Addr
            send_byte(8'h02); crc_h = calc_crc8(8'h02, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length
            send_byte(8'h04); crc_h = calc_crc8(8'h04, crc_h); // Data Length LS
            
            send_byte(crc_h);                                  // Header CRC
        end
    endtask

    // Task para testar o Read Incrementing
    task test_read_inc();
        begin
            $display("[TB] Iniciando Teste: Read Incrementing");
            crc_h = 8'h00;
            
            send_byte(8'hFE); crc_h = calc_crc8(8'hFE, crc_h);
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h);
            send_byte(8'h4C); crc_h = calc_crc8(8'h4C, crc_h); // Packet Type: 01, Command: 0011 (Read Inc), Src Len: 00
            send_byte(8'hAA); crc_h = calc_crc8(8'hAA, crc_h); // Destination Key
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h); // Source Logical Address
            send_byte(8'h16); crc_h = calc_crc8(8'h16, crc_h); // Transaction ID MS
            send_byte(8'h80); crc_h = calc_crc8(8'h80, crc_h); // Transaction ID LS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Extended Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h06); crc_h = calc_crc8(8'h06, crc_h); // Target Addr
            send_byte(8'h08); crc_h = calc_crc8(8'h08, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length
            send_byte(8'h04); crc_h = calc_crc8(8'h04, crc_h); // Data Length LS
            send_byte(crc_h);                                  // Header CRC
        end
    endtask

    // Task para testar o Read Modify Write
    task test_rmw();
        begin
            $display("[TB] Iniciando Teste: Read Modify Write");
            crc_h = 8'h00;
            crc_d = 8'h00;
            
            send_byte(8'hFE); crc_h = calc_crc8(8'hFE, crc_h);
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h);
            send_byte(8'h5C); crc_h = calc_crc8(8'h5C, crc_h); // Packet Type: 01, Command: 0111 (RMW), Src Len: 00
            send_byte(8'hAA); crc_h = calc_crc8(8'hAA, crc_h); // Destination Key
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Source Logical Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Transaction ID MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Transaction ID LS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Extended Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length
            send_byte(8'h08); crc_h = calc_crc8(8'h08, crc_h); // Data Length LS
            send_byte(crc_h);                                  // Header CRC

            // Data e Mask
            send_byte(8'h11); crc_d = calc_crc8(8'h11, crc_d);
            send_byte(8'h22); crc_d = calc_crc8(8'h22, crc_d);
            send_byte(8'h33); crc_d = calc_crc8(8'h33, crc_d);
            send_byte(8'h44); crc_d = calc_crc8(8'h44, crc_d);
            send_byte(8'hFF); crc_d = calc_crc8(8'hFF, crc_d);
            send_byte(8'hFF); crc_d = calc_crc8(8'hFF, crc_d);
            send_byte(8'hFF); crc_d = calc_crc8(8'hFF, crc_d);
            send_byte(8'hFF); crc_d = calc_crc8(8'hFF, crc_d);
            send_byte(crc_d);                                  // Data/Mask CRC
        end
    endtask

    // Task para testar o Write
    task test_write();
        begin
            $display("[TB] Iniciando Teste: Write");
            crc_h = 8'h00;
            crc_d = 8'h00;
            
            send_byte(8'hFE); crc_h = calc_crc8(8'hFE, crc_h);
            send_byte(8'h01); crc_h = calc_crc8(8'h01, crc_h);
            send_byte(8'h78); crc_h = calc_crc8(8'h78, crc_h); // Packet Type: 01, Command: 1110 (Write), Src Len: 00
            send_byte(8'hAA); crc_h = calc_crc8(8'hAA, crc_h); // Destination Key
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Source Logical Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Transaction ID MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Transaction ID LS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Extended Address
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Target Addr
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length MS
            send_byte(8'h00); crc_h = calc_crc8(8'h00, crc_h); // Data Length
            send_byte(8'h04); crc_h = calc_crc8(8'h04, crc_h); // Data Length LS
            send_byte(crc_h);                                  // Header CRC

            // Data
            send_byte(8'hAA); crc_d = calc_crc8(8'hAA, crc_d);
            send_byte(8'hBB); crc_d = calc_crc8(8'hBB, crc_d);
            send_byte(8'hCC); crc_d = calc_crc8(8'hCC, crc_d);
            send_byte(8'hDD); crc_d = calc_crc8(8'hDD, crc_d);
            send_byte(crc_d);                                  // Data CRC
        end
    endtask

    // Bloco principal de testes
    initial begin
        $dumpfile("waves/tb_RMAP.vcd");
        $dumpvars(0, tb_RMAP);

        // Inicializa sinais
        rst_n = 1'b0;
        rx_valid = 1'b0;
        rx_data = 8'h00;

        // Simula a Destination Key salva no banco de registradores
        force reg_bank_r_data = 32'hAA; 

        do_reset();

        // 1. Teste Read Single
        test_read_single();
        wait(dut.state == dut.EOP_STATE);
        $display("[TB] Estado EOP_STATE atingido - Read Single OK");
        
        send_byte(8'h04); // EOP
        repeat(10) @(posedge clk);


        // 2. Teste Read Incrementing
        test_read_inc();
        wait(dut.state == dut.EOP_STATE);
        $display("[TB] Estado EOP_STATE atingido - Read Incrementing OK");
        
        send_byte(8'h04); // EOP
        repeat(10) @(posedge clk);

        // 3. Teste Read Modify Write
        test_rmw();
        wait(dut.state == dut.EOP_STATE);
        $display("[TB] Estado EOP_STATE atingido - Read Modify Write OK");
        
        send_byte(8'h04); 
        do_reset();

        // 4. Teste Write
        test_write();
        wait(dut.state == dut.EOP_STATE);
        $display("[TB] Estado EOP_STATE atingido - Write OK");
        
        send_byte(8'h04); 
        do_reset();

        $display("[TB] Todos os testes finalizados.");
        $finish;
    end

    // Timeout global para evitar travamento na simulação
    initial begin
        #50000;
        $display("[TB] ERRO: Timeout da simulação. O estado EOP_STATE não foi atingido.");
        $finish;
    end

endmodule
