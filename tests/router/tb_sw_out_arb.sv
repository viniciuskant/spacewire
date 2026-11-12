`timescale 1ns/1ps

// árbitro de saída
module tb_sw_out_arb;

    logic clk, rst_n;
    int   n_pass = 0;
    int   n_fail = 0;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz (clk_system)

    // DUT com N = 4
    localparam int N4  = 4;
    localparam int PW4 = $clog2(N4 + 1);

    logic [N4:0]    req4;
    logic           wr_en4, marker4;
    logic [N4:0]    gnt4;
    logic           busy4;
    logic [PW4-1:0] owner4;

    sw_out_arb #(.N_PORTS(N4)) dut4 (
        .clk(clk), .rst_n(rst_n),
        .req_i(req4), .wr_en_i(wr_en4), .wr_marker_i(marker4),
        .gnt_o(gnt4), .busy_o(busy4), .owner_o(owner4)
    );

    // DUT com N = 8
    localparam int N8  = 8;
    localparam int PW8 = $clog2(N8 + 1);

    logic [N8:0]    req8;
    logic           wr_en8, marker8;
    logic [N8:0]    gnt8;
    logic           busy8;
    logic [PW8-1:0] owner8;

    sw_out_arb #(.N_PORTS(N8)) dut8 (
        .clk(clk), .rst_n(rst_n),
        .req_i(req8), .wr_en_i(wr_en8), .wr_marker_i(marker8),
        .gnt_o(gnt8), .busy_o(busy8), .owner_o(owner8)
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

    // Confere gnt/busy/owner do dut4.
    task check4(input string name, input logic [N4:0] exp_gnt,
                input logic exp_busy, input logic [PW4-1:0] exp_owner);
        pass_fail(name,
                  gnt4 === exp_gnt && busy4 === exp_busy && owner4 === exp_owner,
                  $sformatf("gnt=%b busy=%0b owner=%0d (esperado gnt=%b busy=%0b owner=%0d)",
                            gnt4, busy4, owner4, exp_gnt, exp_busy, exp_owner));
    endtask

    // Reset curto: volta last_q = N (a próxima busca começa pela porta 0).
    task do_reset();
        rst_n = 1'b0;
        req4 = '0; wr_en4 = 1'b0; marker4 = 1'b0;
        req8 = '0; wr_en8 = 1'b0; marker8 = 1'b0;
        repeat (2) tick();
        rst_n = 1'b1;
        tick();
    endtask

    // dut4: espera ganhar um dono, manda 2 palavras normais + EOP.
    // Os pedidos (req4) ficam como estão. Devolve o dono que ganhou.
    task packet4(output int who);
        int t;
        t = 0;
        while (!busy4 && t < 10) begin tick(); t++; end
        who = int'(owner4);
        wr_en4 = 1'b1; marker4 = 1'b0;
        repeat (2) tick();
        marker4 = 1'b1;
        tick();
        wr_en4 = 1'b0; marker4 = 1'b0;
    endtask

    task packet8(output int who);
        int t;
        t = 0;
        while (!busy8 && t < 10) begin tick(); t++; end
        who = int'(owner8);
        wr_en8 = 1'b1; marker8 = 1'b1;   // pacote de 1 palavra (só EOP)
        tick();
        wr_en8 = 1'b0; marker8 = 1'b0;
    endtask

    // Confere a sequência de donos de vários pacotes seguidos.
    // exp_seq fica no módulo.
    int exp_seq [0:6];

    task check_seq4(input string name, input int n);
        int who;
        string got, want;
        logic ok;
        got = ""; want = ""; ok = 1'b1;
        for (int p = 0; p < n; p++) begin
            packet4(who);
            got  = {got,  $sformatf("%0d ", who)};
            want = {want, $sformatf("%0d ", exp_seq[p])};
            if (who != exp_seq[p]) ok = 1'b0;
        end
        pass_fail(name, ok, {"donos ", got, "(esperado ", want, ")"});
    endtask

    // Monitor (teste 8)
    int mon_cycles = 0;
    int mon_err    = 0;

    // initial + forever no lugar de always, por causa do Verilator
    initial forever begin
        int ones4, ones8;
        @(negedge clk);
        if (rst_n) begin
            ones4 = 0;
            for (int i = 0; i <= N4; i++) if (gnt4[i]) ones4++;
            ones8 = 0;
            for (int i = 0; i <= N8; i++) if (gnt8[i]) ones8++;

            if (ones4 > 1 || ones8 > 1) begin
                $display("[FAIL] T8 monitor: gnt não one-hot (gnt4=%b gnt8=%b) t=%0t", gnt4, gnt8, $time);
                mon_err++;
            end
            if (busy4 && (!gnt4[owner4] || ones4 != 1)) begin
                $display("[FAIL] T8 monitor: dut4 busy mas gnt4=%b owner=%0d t=%0t", gnt4, owner4, $time);
                mon_err++;
            end
            if (busy8 && (!gnt8[owner8] || ones8 != 1)) begin
                $display("[FAIL] T8 monitor: dut8 busy mas gnt8=%b owner=%0d t=%0t", gnt8, owner8, $time);
                mon_err++;
            end
            if ((!busy4 && ones4 != 0) || (!busy8 && ones8 != 0)) begin
                $display("[FAIL] T8 monitor: livre mas gnt != 0 t=%0t", $time);
                mon_err++;
            end
            mon_cycles++;
        end
    end

    // Sequência de testes
    initial begin
        int who;
        logic ok;
        $dumpfile("waves/tb_sw_out_arb.vcd");
        $dumpvars(0, tb_sw_out_arb);


        do_reset();

        // 1. Após o reset: livre
        check4("T1 reset", 5'b00000, 1'b0, 3'd0);

        // 2. Pedido da entrada 2: ganha no ciclo seguinte e segura
        req4 = 5'b00100;
        #1;
        check4("T2 mesmo ciclo do pedido (ainda livre)", 5'b00000, 1'b0, 3'd0);
        tick();
        check4("T2 entrada 2 ganha", 5'b00100, 1'b1, 3'd2);
        req4 = 5'b01100;   // entrada 3 também pede
        repeat (3) tick();
        check4("T2 segura com entrada 3 pedindo", 5'b00100, 1'b1, 3'd2);

        // 3. Escritas SEM marcador não soltam
        wr_en4 = 1'b1; marker4 = 1'b0;
        repeat (3) tick();
        check4("T3 escritas sem marcador", 5'b00100, 1'b1, 3'd2);

        // 4. Escrita COM marcador solta; entrada 3 ganha no ciclo depois
        marker4 = 1'b1;
        req4    = 5'b01000;   // entrada 2 terminou o pacote
        tick();
        wr_en4 = 1'b0; marker4 = 1'b0;
        check4("T4 marcador solta (sem novo dono no mesmo ciclo)", 5'b00000, 1'b0, 3'd0);
        tick();
        check4("T4 entrada 3 ganha no ciclo seguinte", 5'b01000, 1'b1, 3'd3);
        req4 = '0;
        tick();   // dono desistiu, solta

        // 5. Justiça (round-robin)
        do_reset();
        req4 = 5'b01010;
        exp_seq[0] = 1; exp_seq[1] = 3; exp_seq[2] = 1; exp_seq[3] = 3;
        check_seq4("T5 entradas 1 e 3", 4);
        do_reset();
        req4 = 5'b11110;
        exp_seq[0] = 1; exp_seq[1] = 2; exp_seq[2] = 3; exp_seq[3] = 4; exp_seq[4] = 1;
        check_seq4("T5 entradas 1..4", 5);

        // 6. Dono desiste sem marcador
        do_reset();
        req4 = 5'b00010;
        tick();
        check4("T6 entrada 1 ganha", 5'b00010, 1'b1, 3'd1);
        req4 = 5'b00000;
        tick();
        check4("T6 dono desistiu -> livre", 5'b00000, 1'b0, 3'd0);
        tick();
        check4("T6 continua livre sem pedidos", 5'b00000, 1'b0, 3'd0);

        // 7. Quem não é dono nunca recebe gnt enquanto ocupada
        do_reset();
        req4 = 5'b00010;
        tick();
        req4 = 5'b11110;
        ok = 1'b1;
        for (int c = 0; c < 6; c++) begin
            if (gnt4 !== 5'b00010 || owner4 !== 3'd1) ok = 1'b0;
            tick();
        end
        pass_fail("T7 entradas 2,3,4 sem gnt por 6 ciclos", ok,
                  $sformatf("gnt=%b owner=%0d", gnt4, owner4));
        req4 = '0;
        tick();

        // 9. Instância com N = 8: entradas 8 e 1, ordem 1, 8, 1
        do_reset();
        req8 = 9'b1_0000_0010;
        ok = 1'b1;
        packet8(who); if (who != 1) ok = 1'b0;
        $display("       T9 dono 1: %0d", who);
        packet8(who); if (who != 8) ok = 1'b0;
        $display("       T9 dono 2: %0d", who);
        packet8(who); if (who != 1) ok = 1'b0;
        $display("       T9 dono 3: %0d", who);
        pass_fail("T9 N=8 entradas 8 e 1", ok, "sequência esperada 1, 8, 1");
        req8 = '0;
        repeat (2) tick();

        // 10. Round-robin com a porta 0
        do_reset();
        req4 = 5'b00001;
        tick();
        check4("T10 entrada 0 ganha (owner 0 com busy)", 5'b00001, 1'b1, 3'd0);
        req4 = '0;
        tick();
        check4("T10 dono 0 desistiu", 5'b00000, 1'b0, 3'd0);
        do_reset();
        req4 = 5'b11111;
        exp_seq[0] = 0; exp_seq[1] = 1; exp_seq[2] = 2; exp_seq[3] = 3;
        exp_seq[4] = 4; exp_seq[5] = 0; exp_seq[6] = 1;
        check_seq4("T10 entradas 0..4 e volta", 7);
        do_reset();
        req4 = 5'b00101;
        exp_seq[0] = 0; exp_seq[1] = 2; exp_seq[2] = 0; exp_seq[3] = 2;
        check_seq4("T10 entradas 0 e 2", 4);
        req4 = '0;
        repeat (2) tick();

        // 8. Resultado do monitor
        pass_fail("T8 monitor one-hot e gnt[owner]", mon_err == 0 && mon_cycles > 0,
                  $sformatf("%0d ciclos checados, %0d erros", mon_cycles, mon_err));

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
