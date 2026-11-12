`timescale 1ns/1ps

// unidade de time-code
module tb_sw_tc_unit;

    logic clk, rst_n;
    int   n_pass = 0;
    int   n_fail = 0;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz (clk_system)

    // DUT com N = 4
    localparam int N4 = 4;

    logic              en4;
    logic [N4:1]       run4, got4, send4;
    logic [N4:1][7:0]  rx4;
    logic [7:0]        tx4;
    logic [5:0]        reg4;

    sw_tc_unit #(.N_PORTS(N4)) dut4 (
        .clk(clk), .rst_n(rst_n),
        .tc_en_i(en4), .link_run_i(run4),
        .tc_got_i(got4), .tc_rx_i(rx4),
        .tc_send_o(send4), .tc_tx_o(tx4), .tc_reg_o(reg4)
    );

    // DUT com N = 8
    localparam int N8 = 8;

    logic              en8;
    logic [N8:1]       run8, got8, send8;
    logic [N8:1][7:0]  rx8;
    logic [7:0]        tx8;
    logic [5:0]        reg8;

    sw_tc_unit #(.N_PORTS(N8)) dut8 (
        .clk(clk), .rst_n(rst_n),
        .tc_en_i(en8), .link_run_i(run8),
        .tc_got_i(got8), .tc_rx_i(rx8),
        .tc_send_o(send8), .tc_tx_o(tx8), .tc_reg_o(reg8)
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

    // Porta p recebe o time-code v (pulso de 1 ciclo); volta logo depois do posedge.
    task rx_tc4(input int p, input logic [7:0] v);
        got4[p] = 1'b1; rx4[p] = v;
        tick();
        got4 = '0;
    endtask

    // Checa as saídas do dut4 agora (logo depois do posedge que latchou o time-code).
    task check4(input string name, input logic [N4:1] e_send, input logic [7:0] e_tx,
                input logic [5:0] e_reg);
        pass_fail(name, send4 === e_send && tx4 === e_tx && reg4 === e_reg,
                  $sformatf("send=%b tx=%08b reg=%0d (esperado send=%b tx=%08b reg=%0d)",
                            send4, tx4, reg4, e_send, e_tx, e_reg));
    endtask

    // Depois de um ciclo, nenhum pulso.
    task check_quiet4(input string name);
        tick();
        pass_fail(name, send4 === '0, $sformatf("send=%b um ciclo depois", send4));
    endtask

    // Monitor + modelo de referência
    int          mon_cycles = 0;
    int          mon_err    = 0;
    int          n_pulse4   = 0;   // ciclos com algum tc_send4 = 1
    logic [5:0]  m_reg      = '0;  // modelo: tc_reg
    logic [7:0]  m_val      = '0;  // modelo: tc_val
    logic [N4:1] m_send     = '0;  // modelo: tc_send esperado no próximo ciclo
    int          m_src      = 0;   // origem do time-code aceito no ciclo anterior (0 = nenhum)
    logic [N4:1] m_run      = '0;  // link_run no ciclo do recebimento
    int          m_src8     = 0;
    logic [N8:1] m_run8     = '0;

    // initial + forever no lugar de always, por causa do Verilator
    initial forever begin
        int         p;
        logic [7:0] v;
        @(negedge clk);
        if (!rst_n) begin
            m_reg = '0; m_val = '0; m_send = '0; m_src = 0; m_src8 = 0;
        end else begin
            // dut4: saídas de agora contra o que o modelo previu no ciclo anterior
            if (send4 !== m_send) begin
                $display("[FAIL] monitor: send4=%b, modelo=%b t=%0t", send4, m_send, $time); mon_err++;
            end
            if (tx4 !== m_val) begin
                $display("[FAIL] monitor: tx4=%08b, modelo=%08b t=%0t", tx4, m_val, $time); mon_err++;
            end
            if (reg4 !== m_reg) begin
                $display("[FAIL] monitor: reg4=%0d, modelo=%0d t=%0t", reg4, m_reg, $time); mon_err++;
            end
            if (send4 != '0) begin
                n_pulse4++;
                if (m_src == 0) begin
                    $display("[FAIL] monitor: send4 sem time-code válido no ciclo anterior t=%0t", $time); mon_err++;
                end else if (send4[m_src]) begin
                    $display("[FAIL] monitor: send4 na porta de origem %0d t=%0t", m_src, $time); mon_err++;
                end
                if ((send4 & ~m_run) != '0 || (send4 & ~run4) != '0) begin
                    $display("[FAIL] monitor: send4 em porta sem Run (%b) t=%0t", send4, $time); mon_err++;
                end
            end

            // dut4: modelo do próximo ciclo a partir das entradas de agora
            m_send = '0;
            m_src  = 0;
            p      = 0;
            for (int i = N4; i >= 1; i--) if (got4[i]) p = i;
            if (p != 0) begin
                v = rx4[p];
                if (v[5:0] == 6'(m_reg + 6'd1) && en4) begin
                    m_val = v;
                    m_src = p;
                    m_run = run4;
                    for (int i = 1; i <= N4; i++) m_send[i] = run4[i] && (i != p);
                end
                m_reg = v[5:0];
            end

            // dut8: origem e Run
            if (send8 != '0) begin
                if (m_src8 == 0) begin
                    $display("[FAIL] monitor: send8 sem time-code no ciclo anterior t=%0t", $time); mon_err++;
                end else if (send8[m_src8]) begin
                    $display("[FAIL] monitor: send8 na porta de origem %0d t=%0t", m_src8, $time); mon_err++;
                end
                if ((send8 & ~m_run8) != '0) begin
                    $display("[FAIL] monitor: send8 em porta sem Run t=%0t", $time); mon_err++;
                end
            end
            m_src8 = 0;
            for (int i = N8; i >= 1; i--) if (got8[i]) m_src8 = i;
            m_run8 = run8;
            mon_cycles++;
        end
    end

    // Sequência de testes
    initial begin
        logic ok;
        $dumpfile("waves/tb_sw_tc_unit.vcd");
        $dumpvars(0, tb_sw_tc_unit);


        rst_n = 1'b0;
        en4 = 1'b1; run4 = '1; got4 = '0; rx4 = '0;
        en8 = 1'b1; run8 = '1; got8 = '0; rx8 = '0;
        repeat (2) tick();
        rst_n = 1'b1;
        tick();

        // 1. Após reset
        ok = 1'b1;
        for (int c = 0; c < 3; c++) begin
            if (reg4 !== 6'd0 || send4 !== '0 || tx4 !== 8'd0) ok = 1'b0;
            tick();
        end
        pass_fail("T1 reset: reg=0, sem pulso", ok, $sformatf("reg=%0d send=%b tx=%0d", reg4, send4, tx4));

        // 2. Porta 1 recebe 1
        rx_tc4(1, 8'd1);
        check4("T2 porta 1 recebe 1 -> repassa para 2,3,4", 4'b1110, 8'd1, 6'd1);
        check_quiet4("T2 pulso de 1 ciclo");

        // 3. Duplicado
        rx_tc4(2, 8'd1);
        check4("T3 duplicado não repassa", 4'b0000, 8'd1, 6'd1);
        check_quiet4("T3 continua sem pulso");

        // 4. Salto (não é +1) e depois o seguinte
        rx_tc4(3, 8'd5);
        check4("T4 porta 3 recebe 5: não repassa, reg=5", 4'b0000, 8'd1, 6'd5);
        tick();
        rx_tc4(1, 8'd6);
        check4("T4 porta 1 recebe 6 -> repassa para 2,3,4", 4'b1110, 8'd6, 6'd6);
        check_quiet4("T4 pulso de 1 ciclo");

        // 5. Volta de 63 para 0
        rx_tc4(1, 8'd63);
        check4("T5 reg=63 (salto, sem pulso)", 4'b0000, 8'd6, 6'd63);
        tick();
        rx_tc4(2, 8'd0);
        check4("T5 chega 0 depois de 63 -> repassa para 1,3,4", 4'b1101, 8'd0, 6'd0);
        check_quiet4("T5 pulso de 1 ciclo");

        // 6. Porta 4 sem Run
        run4 = 4'b0111;
        rx_tc4(1, 8'd1);
        check4("T6 porta 4 sem Run não recebe", 4'b0110, 8'd1, 6'd1);
        check_quiet4("T6 pulso de 1 ciclo");
        run4 = '1;

        // 7. Portas 2 e 3 no mesmo ciclo: a 2 vence
        got4[2] = 1'b1; rx4[2] = 8'd2;
        got4[3] = 1'b1; rx4[3] = 8'd2;
        tick();
        got4 = '0;
        check4("T7 portas 2 e 3 juntas: só a 2 (pulso para 1,3,4)", 4'b1101, 8'd2, 6'd2);
        check_quiet4("T7 porta 3 ignorada (sem segundo pulso)");

        // 8. Flags repassadas como vieram
        rx_tc4(1, 8'd6);
        check4("T8 reg=6 (salto, sem pulso)", 4'b0000, 8'd2, 6'd6);
        tick();
        rx_tc4(1, 8'b11_000111);
        check4("T8 flags 11 repassadas", 4'b1110, 8'b11_000111, 6'd7);
        check_quiet4("T8 pulso de 1 ciclo");

        // 9. Repasse desligado
        en4 = 1'b0;
        rx_tc4(1, 8'd8);
        check4("T9 tc_en=0: sem pulso, reg=8, tx mantido", 4'b0000, 8'b11_000111, 6'd8);
        check_quiet4("T9 continua sem pulso");
        en4 = 1'b1;

        // 10. Válidos em ciclos seguidos: 1, 2, 3
        rx_tc4(1, 8'd0);                       // reg = 0 (salto)
        tick();
        got4[1] = 1'b1; rx4[1] = 8'd1;
        tick();
        check4("T10 ciclo 1: tx=1", 4'b1110, 8'd1, 6'd1);
        rx4[1] = 8'd2;
        tick();
        check4("T10 ciclo 2: tx=2", 4'b1110, 8'd2, 6'd2);
        rx4[1] = 8'd3;
        tick();
        got4 = '0;
        check4("T10 ciclo 3: tx=3", 4'b1110, 8'd3, 6'd3);
        check_quiet4("T10 sem quarto pulso");

        // 11. N = 8: porta 8 recebe 1
        got8[8] = 1'b1; rx8[8] = 8'd1;
        tick();
        got8 = '0;
        pass_fail("T11 N=8 porta 8 -> pulso para 1..7",
                  send8 === 8'b0111_1111 && tx8 === 8'd1 && reg8 === 6'd1,
                  $sformatf("send8=%b tx8=%0d reg8=%0d", send8, tx8, reg8));
        tick();
        pass_fail("T11 N=8 pulso de 1 ciclo", send8 === '0, $sformatf("send8=%b", send8));
        repeat (2) tick();

        // Monitor
        pass_fail("Monitor modelo / origem / Run / pulso de 1 ciclo",
                  mon_err == 0 && mon_cycles > 0 && n_pulse4 == 9,
                  $sformatf("%0d ciclos checados, %0d pulsos (esperado 9), %0d erros",
                            mon_cycles, n_pulse4, mon_err));

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
