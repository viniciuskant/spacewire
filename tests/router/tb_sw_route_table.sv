`timescale 1ns/1ps

// tabela de roteamento
module tb_sw_route_table;

    logic clk, rst_n;
    int   n_pass = 0;
    int   n_fail = 0;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz (clk_system)

    // DUT com N = 4
    localparam int N4  = 4;
    localparam int PW4 = $clog2(N4 + 1);

    logic               wr_en4;
    logic [7:0]         wr_addr4;
    logic [PW4-1:0]     wr_port4;
    logic               wr_valid4;
    logic [N4:0][7:0]   addr4;
    logic [N4:0]        hit4;
    logic [N4:0][PW4-1:0] port4;

    sw_route_table #(.N_PORTS(N4)) dut4 (
        .clk(clk), .rst_n(rst_n),
        .tbl_wr_en_i(wr_en4), .tbl_addr_i(wr_addr4),
        .tbl_port_i(wr_port4), .tbl_valid_i(wr_valid4),
        .lookup_addr_i(addr4), .lookup_hit_o(hit4), .lookup_port_o(port4)
    );

    // DUT com N = 8
    localparam int N8  = 8;
    localparam int PW8 = $clog2(N8 + 1);

    logic               wr_en8;
    logic [7:0]         wr_addr8;
    logic [PW8-1:0]     wr_port8;
    logic               wr_valid8;
    logic [N8:0][7:0]   addr8;
    logic [N8:0]        hit8;
    logic [N8:0][PW8-1:0] port8;

    sw_route_table #(.N_PORTS(N8)) dut8 (
        .clk(clk), .rst_n(rst_n),
        .tbl_wr_en_i(wr_en8), .tbl_addr_i(wr_addr8),
        .tbl_port_i(wr_port8), .tbl_valid_i(wr_valid8),
        .lookup_addr_i(addr8), .lookup_hit_o(hit8), .lookup_port_o(port8)
    );

    // Tarefas auxiliares
    task tick();
        @(posedge clk); #1;
    endtask

    task pass_fail(input string name, input logic ok, input string got);
        if (ok) begin
            $display("[PASS] %s: %s", name, got);
            n_pass++;
        end else begin
            $display("[FAIL] %s: %s", name, got);
            n_fail++;
        end
    endtask

    // Grava (ou apaga, com valid = 0) uma rota no dut4: dura 1 ciclo.
    task prog4(input logic [7:0] a, input logic [PW4-1:0] p, input logic v);
        wr_en4 = 1'b1; wr_addr4 = a; wr_port4 = p; wr_valid4 = v;
        tick();
        wr_en4 = 1'b0;
    endtask

    task prog8(input logic [7:0] a, input logic [PW8-1:0] p, input logic v);
        wr_en8 = 1'b1; wr_addr8 = a; wr_port8 = p; wr_valid8 = v;
        tick();
        wr_en8 = 1'b0;
    endtask

    // Consulta o endereço a pela entrada in do dut4 e confere hit/porta.
    // Quando não há hit, a porta esperada é sempre 0.
    task check4(input string name, input int in, input logic [7:0] a,
                input logic exp_hit, input logic [PW4-1:0] exp_port);
        addr4[in] = a;
        #1;
        if (hit4[in] === exp_hit && port4[in] === exp_port)
            pass_fail(name, 1'b1, $sformatf("entrada %0d, end %0d -> hit=%0b porta=%0d",
                                            in, a, hit4[in], port4[in]));
        else
            pass_fail(name, 1'b0, $sformatf("entrada %0d, end %0d -> hit=%0b porta=%0d (esperado hit=%0b porta=%0d)",
                                            in, a, hit4[in], port4[in], exp_hit, exp_port));
    endtask

    task check8(input string name, input int in, input logic [7:0] a,
                input logic exp_hit, input logic [PW8-1:0] exp_port);
        addr8[in] = a;
        #1;
        if (hit8[in] === exp_hit && port8[in] === exp_port)
            pass_fail(name, 1'b1, $sformatf("entrada %0d, end %0d -> hit=%0b porta=%0d",
                                            in, a, hit8[in], port8[in]));
        else
            pass_fail(name, 1'b0, $sformatf("entrada %0d, end %0d -> hit=%0b porta=%0d (esperado hit=%0b porta=%0d)",
                                            in, a, hit8[in], port8[in], exp_hit, exp_port));
    endtask

    // Confere o resultado de uma entrada SEM mudar o endereço dela
    // (usado no teste de consultas simultâneas).
    task expect4(input string name, input int in,
                 input logic exp_hit, input logic [PW4-1:0] exp_port);
        if (hit4[in] === exp_hit && port4[in] === exp_port)
            pass_fail(name, 1'b1, $sformatf("entrada %0d -> hit=%0b porta=%0d", in, hit4[in], port4[in]));
        else
            pass_fail(name, 1'b0, $sformatf("entrada %0d -> hit=%0b porta=%0d (esperado hit=%0b porta=%0d)",
                                            in, hit4[in], port4[in], exp_hit, exp_port));
    endtask

    // Sequência de testes
    initial begin
        $dumpfile("waves/tb_sw_route_table.vcd");
        $dumpvars(0, tb_sw_route_table);

        // Estado inicial e reset
        rst_n  = 1'b0;
        wr_en4 = 1'b0; wr_addr4 = '0; wr_port4 = '0; wr_valid4 = 1'b0; addr4 = '0;
        wr_en8 = 1'b0; wr_addr8 = '0; wr_port8 = '0; wr_valid8 = 1'b0; addr8 = '0;
        repeat (2) tick();
        rst_n = 1'b1;
        tick();

        // 1. Após o reset, nenhuma rota
        check4("T1 reset", 1, 8'd32,  1'b0, 3'd0);
        check4("T1 reset", 1, 8'd100, 1'b0, 3'd0);
        check4("T1 reset", 1, 8'd254, 1'b0, 3'd0);

        // 2. Grava 44 para porta 3
        prog4(8'd44, 3'd3, 1'b1);
        check4("T2 grava 44->3", 1, 8'd44, 1'b1, 3'd3);

        // 3. Consultas simultâneas, no mesmo ciclo, em entradas diferentes
        addr4[1] = 8'd44;   // tem rota, porta 3
        addr4[2] = 8'd50;   // endereço lógico sem rota
        addr4[3] = 8'd2;    // endereço de caminho: não passa pela tabela
        addr4[4] = 8'd44;   // mesma rota que a entrada 1, ao mesmo tempo
        #1;
        expect4("T3 simultaneo (44)",      1, 1'b1, 3'd3);
        expect4("T3 simultaneo (50)",      2, 1'b0, 3'd0);
        expect4("T3 simultaneo (caminho 2)", 3, 1'b0, 3'd0);
        expect4("T3 simultaneo (44 de novo)", 4, 1'b1, 3'd3);

        // 4. Apaga 44 (valid = 0)
        prog4(8'd44, 3'd3, 1'b0);
        check4("T4 apaga 44", 1, 8'd44, 1'b0, 3'd0);

        // 5. Escritas fora da faixa são ignoradas
        prog4(8'd5,   3'd2, 1'b1);
        prog4(8'd31,  3'd2, 1'b1);
        prog4(8'd255, 3'd2, 1'b1);
        check4("T5 fora da faixa (5)",   1, 8'd5,   1'b0, 3'd0);
        check4("T5 fora da faixa (31)",  1, 8'd31,  1'b0, 3'd0);
        check4("T5 fora da faixa (255)", 1, 8'd255, 1'b0, 3'd0);
        // "nada muda": as entradas vizinhas continuam sem rota
        check4("T5 vizinho 32 intacto",  1, 8'd32,  1'b0, 3'd0);
        check4("T5 vizinho 254 intacto", 1, 8'd254, 1'b0, 3'd0);

        // 6. Porta inválida (0 e 5, com N = 4) conta como sem rota
        prog4(8'd70, 3'd0, 1'b1);
        check4("T6 porta 0 invalida", 2, 8'd70, 1'b0, 3'd0);
        prog4(8'd71, 3'd5, 1'b1);
        check4("T6 porta 5 invalida", 2, 8'd71, 1'b0, 3'd0);

        // 7. Sobrescrever: 60 para 1, depois 60 para 4
        prog4(8'd60, 3'd1, 1'b1);
        check4("T7 grava 60->1", 3, 8'd60, 1'b1, 3'd1);
        prog4(8'd60, 3'd4, 1'b1);
        check4("T7 sobrescreve 60->4", 3, 8'd60, 1'b1, 3'd4);

        // 8. Instância com N = 8: porta 8 é válida, porta 9 não
        check8("T8 N=8 reset",            1, 8'd200, 1'b0, 4'd0);
        prog8(8'd200, 4'd8, 1'b1);
        check8("T8 N=8 grava 200->8",     8, 8'd200, 1'b1, 4'd8);
        prog8(8'd32, 4'd5, 1'b1);
        check8("T8 N=8 grava 32->5",      5, 8'd32,  1'b1, 4'd5);
        prog8(8'd254, 4'd9, 1'b1);
        check8("T8 N=8 porta 9 invalida", 2, 8'd254, 1'b0, 4'd0);
        check8("T8 N=8 caminho 8",        3, 8'd8,   1'b0, 4'd0);
        // o dut4 não foi afetado pelas escritas no dut8
        check4("T8 dut4 independente (200)", 1, 8'd200, 1'b0, 3'd0);

        // 9. Consulta pela porta 0
        prog4(8'd80, 3'd2, 1'b1);
        check4("T9 consulta pela porta 0", 0, 8'd80, 1'b1, 3'd2);
        check8("T9 N=8 consulta pela porta 0", 0, 8'd200, 1'b1, 4'd8);

        // Resumo
        $display("--------------------------------------------");
        $display("RESUMO: %0d PASS, %0d FAIL", n_pass, n_fail);
        if (n_fail == 0) $display("*** PASS ***");
        else             $display("*** FAIL (%0d erros totais) ***", n_fail);
        $finish;
    end

    // trava de segurança
    initial begin
        #100000;
        $display("RESUMO: %0d PASS, %0d FAIL (parou no timeout)", n_pass, n_fail);
        $display("*** FAIL (timeout) ***");
        $finish;
    end

endmodule
