`timescale 1ns/1ps

// controle de entrada
module tb_sw_in_ctrl;

    logic clk, rst_n;
    int   n_pass = 0;
    int   n_fail = 0;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz (clk_system)

    // DUT com N = 4
    localparam int N4  = 4;
    localparam int PW4 = $clog2(N4 + 1);

    localparam int RX_ASIZE = 6;             // 64 palavras (DEPTH_FIFO do codec)
    localparam int RX_DEPTH = 1 << RX_ASIZE;

    logic [8:0]           rxq [$];      // palavras que ainda vão entrar na rx_fifo
    logic                 rx_winc4 = 1'b0;
    logic [8:0]           rx_wdata4 = '0;
    logic [RX_ASIZE:0]    rx_free4;
    logic [8:0]           in_data4;
    logic                 in_empty4;
    logic                 rd4;

    sync_fifo #(.DSIZE(9), .ASIZE(RX_ASIZE)) u_rx4 (
        .clk(clk), .rst_n(rst_n),
        .winc(rx_winc4), .wdata(rx_wdata4),
        .rinc(rd4), .rdata(in_data4), .rempty(in_empty4),
        .free_space_o(rx_free4)
    );

    logic                 tbl_wr4, tbl_valid4;
    logic [7:0]           tbl_addr4;
    logic [PW4-1:0]       tbl_wport4;
    logic [N4:0][7:0]     look4;
    // verilator lint_off UNUSEDSIGNAL
    logic [N4:0]          hit4;         // só a consulta 0 é usada
    logic [N4:0][PW4-1:0] lport4;
    // verilator lint_on UNUSEDSIGNAL

    logic [N4:0]          run4, full4, req4;
    logic                 gnt4 = 1'b0;
    // verilator lint_off UNUSEDSIGNAL
    logic [PW4-1:0]       dest4;
    // verilator lint_on UNUSEDSIGNAL
    logic                 wv4, err4;
    logic [8:0]           wd4;

    assign look4 = {32'd0, in_data4[7:0]};   // só a consulta 0 é usada

    sw_route_table #(.N_PORTS(N4)) tbl4 (
        .clk(clk), .rst_n(rst_n),
        .tbl_wr_en_i(tbl_wr4), .tbl_addr_i(tbl_addr4),
        .tbl_port_i(tbl_wport4), .tbl_valid_i(tbl_valid4),
        .lookup_addr_i(look4), .lookup_hit_o(hit4), .lookup_port_o(lport4)
    );

    sw_in_ctrl #(.N_PORTS(N4), .MY_PORT(1)) dut4 (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data4), .in_empty_i(in_empty4), .in_rd_en_o(rd4),
        .lookup_hit_i(hit4[0]), .lookup_port_i(lport4[0]),
        .link_run_i(run4), .out_full_i(full4),
        .req_o(req4), .gnt_i(gnt4),
        .dest_o(dest4), .wvalid_o(wv4), .wdata_o(wd4), .err_o(err4)
    );

    // DUT com N = 8
    localparam int N8  = 8;
    localparam int PW8 = $clog2(N8 + 1);

    logic [8:0]           in_data8;
    logic                 in_empty8;
    logic                 rd8;

    logic                 tbl_wr8, tbl_valid8;
    logic [7:0]           tbl_addr8;
    logic [PW8-1:0]       tbl_wport8;
    logic [N8:0][7:0]     look8;
    // verilator lint_off UNUSEDSIGNAL
    logic [N8:0]          hit8;
    logic [N8:0][PW8-1:0] lport8;
    // verilator lint_on UNUSEDSIGNAL

    logic [N8:0]          run8, full8, req8;
    logic                 gnt8;
    logic [PW8-1:0]       dest8;
    logic                 wv8, err8;
    logic [8:0]           wd8;

    assign look8 = {64'd0, in_data8[7:0]};

    sw_route_table #(.N_PORTS(N8)) tbl8 (
        .clk(clk), .rst_n(rst_n),
        .tbl_wr_en_i(tbl_wr8), .tbl_addr_i(tbl_addr8),
        .tbl_port_i(tbl_wport8), .tbl_valid_i(tbl_valid8),
        .lookup_addr_i(look8), .lookup_hit_o(hit8), .lookup_port_o(lport8)
    );

    sw_in_ctrl #(.N_PORTS(N8), .MY_PORT(1)) dut8 (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data8), .in_empty_i(in_empty8), .in_rd_en_o(rd8),
        .lookup_hit_i(hit8[0]), .lookup_port_i(lport8[0]),
        .link_run_i(run8), .out_full_i(full8),
        .req_o(req8), .gnt_i(gnt8),
        .dest_o(dest8), .wvalid_o(wv8), .wdata_o(wd8), .err_o(err8)
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

    // O monitor coloca as palavras na rx_fifo, uma por ciclo.
    task push4(input logic [8:0] w);
        rxq.push_back(w);
    endtask

    // Palavras ainda não lidas: a entrar + em trânsito + dentro da rx_fifo.
    function automatic int rx_left();
        return rxq.size() + int'(rx_winc4) + (RX_DEPTH - int'(rx_free4));
    endfunction

    // Espera o cabeçalho passar pela rx_fifo e o pedido subir (ST_REQ).
    task wait_req();
        for (int t = 0; t < 20 && req4 == '0; t++) tick();
    endtask

    task prog4(input logic [7:0] a, input logic [PW4-1:0] p);
        tbl_wr4 = 1'b1; tbl_addr4 = a; tbl_wport4 = p; tbl_valid4 = 1'b1;
        tick();
        tbl_wr4 = 1'b0;
    endtask

    task prog8(input logic [7:0] a, input logic [PW8-1:0] p);
        tbl_wr8 = 1'b1; tbl_addr8 = a; tbl_wport8 = p; tbl_valid8 = 1'b1;
        tick();
        tbl_wr8 = 1'b0;
    endtask

    // Espera a fila esvaziar e o pedido cair.
    task drain(input string name);
        int t;
        t = 0;
        while ((rx_left() != 0 || req4 != '0) && t < 200) begin tick(); t++; end
        tick();
        if (t >= 200) pass_fail({name, " drain"}, 1'b0, "timeout esperando a fila esvaziar");
    endtask

    // Compara o que saiu (outq) com exp_w[0..n-1] e limpa outq.
    // exp_w fica no módulo.
    logic [8:0] outq [$];
    logic [8:0] exp_w [0:15];

    task check_out(input string name, input int n);
        string got, want;
        logic  ok;
        got = ""; want = "";
        ok  = (outq.size() == n);
        for (int k = 0; k < outq.size(); k++) got = {got, $sformatf("%03h ", outq[k])};
        for (int k = 0; k < n; k++) begin
            want = {want, $sformatf("%03h ", exp_w[k])};
            if (k < outq.size() && outq[k] !== exp_w[k]) ok = 1'b0;
        end
        pass_fail(name, ok, {"saída [ ", got, "] (esperado [ ", want, "])"});
        outq.delete();
    endtask

    // Monitor + escrita na rx_fifo + modelo do gnt
    int          gnt_delay  = 0;     // ciclos de espera antes do gnt
    int          gnt_cnt    = 0;
    logic [N4:0] req_seen   = '0;    // OR de todos os req4 vistos
    int          err_cnt    = 0;     // ciclos com err4 = 1
    int          n_req_drop = 0;     // vezes que req4 = 0 logo depois de um EOP/EEP
    int          mon_cycles = 0;
    int          mon_err    = 0;
    logic        prev_err4  = 1'b0;
    logic        prev_err8  = 1'b0;
    logic        eop_prev   = 1'b0;
    logic        err_open   = 1'b0;  // já houve err neste descarte (até voltar a ST_IDLE)

    // initial + forever no lugar de always, por causa do Verilator
    // Amostra no negedge; aplica escrita na rx_fifo (se tem espaço) e gnt logo depois do posedge.
    initial forever begin
        logic       gnt_next;
        int         ones4, ones8;
        @(negedge clk);
        gnt_next = gnt4;
        if (rst_n) begin
            // dut4
            ones4 = 0;
            for (int i = 0; i <= N4; i++) if (req4[i]) ones4++;
            if (ones4 > 1) begin
                $display("[FAIL] monitor: req4 não one-hot (%b) t=%0t", req4, $time); mon_err++;
            end
            if (wv4 && !gnt4) begin
                $display("[FAIL] monitor: wvalid4 sem gnt t=%0t", $time); mon_err++;
            end
            if (wv4 && ((full4 & req4) != '0)) begin
                $display("[FAIL] monitor: wvalid4 com saída cheia t=%0t", $time); mon_err++;
            end
            if (rd4 && in_empty4) begin
                $display("[FAIL] monitor: rd_en4 com fila vazia t=%0t", $time); mon_err++;
            end
            if (eop_prev) begin
                if (req4 != '0) begin
                    $display("[FAIL] monitor: req4 ligado logo após EOP/EEP t=%0t", $time); mon_err++;
                end else begin
                    n_req_drop++;
                end
            end
            if (err4 && prev_err4) begin
                $display("[FAIL] monitor: err4 com mais de 1 ciclo t=%0t", $time); mon_err++;
            end
            if (err4 && err_open) begin
                $display("[FAIL] monitor: err4 pulsou 2 vezes no mesmo descarte t=%0t", $time); mon_err++;
            end
            if (err4) err_open = 1'b1;
            else if (int'(dut4.state) == 0) err_open = 1'b0;
            if (int'(dut4.state) == 3 && wv4 && wd4 !== 9'h101) begin
                $display("[FAIL] monitor: ST_EEP gravou %03h (só 101) t=%0t", wd4, $time); mon_err++;
            end
            if (err4) err_cnt++;
            prev_err4 = err4;
            eop_prev  = wv4 && wd4[8];
            req_seen  = req_seen | req4;
            if (wv4) outq.push_back(wd4);

            // gnt: sobe gnt_delay ciclos depois do pedido; cai com o EOP/EEP ou sem pedido
            if (req4 == '0 || (wv4 && wd4[8])) begin
                gnt_next = 1'b0;
                gnt_cnt  = 0;
            end else if (!gnt4) begin
                gnt_cnt++;
                if (gnt_cnt > gnt_delay) gnt_next = 1'b1;
            end

            // dut8
            ones8 = 0;
            for (int i = 0; i <= N8; i++) if (req8[i]) ones8++;
            if (ones8 > 1) begin
                $display("[FAIL] monitor: req8 não one-hot (%b) t=%0t", req8, $time); mon_err++;
            end
            if (wv8 && !gnt8) begin
                $display("[FAIL] monitor: wvalid8 sem gnt t=%0t", $time); mon_err++;
            end
            if (err8 && prev_err8) begin
                $display("[FAIL] monitor: err8 com mais de 1 ciclo t=%0t", $time); mon_err++;
            end
            prev_err8 = err8;
            mon_cycles++;
        end
        @(posedge clk);
        #0.5;
        rx_winc4 = 1'b0;
        if (rxq.size() != 0 && rx_free4 != '0) begin   // não escreve com a rx_fifo cheia
            rx_winc4  = 1'b1;
            rx_wdata4 = rxq[0];
            void'(rxq.pop_front());
        end
        gnt4 = gnt_next;
    end

    // Sequência de testes
    initial begin
        int   e0, d0;
        logic ok;
        string msg;
        $dumpfile("waves/tb_sw_in_ctrl.vcd");
        $dumpvars(0, tb_sw_in_ctrl);


        rst_n = 1'b0;
        rxq.delete();
        tbl_wr4 = 1'b0; tbl_valid4 = 1'b0; tbl_addr4 = '0; tbl_wport4 = '0;
        run4 = 5'b11111; full4 = '0;
        in_data8 = '0; in_empty8 = 1'b1; gnt8 = 1'b0;
        tbl_wr8 = 1'b0; tbl_valid8 = 1'b0; tbl_addr8 = '0; tbl_wport8 = '0;
        run8 = '1; full8 = '0;
        repeat (2) tick();
        rst_n = 1'b1;
        tick();

        prog4(8'd44, 3'd3);    // lógico 44 para porta 3
        prog8(8'd100, 4'd8);   // lógico 100 para porta 8 (N = 8)

        // 1. Caminho 2: cabeçalho apagado
        req_seen = '0;
        push4(9'h002); push4(9'h0A5); push4(9'h03C); push4(9'h102);
        drain("T1");
        exp_w[0] = 9'h0A5; exp_w[1] = 9'h03C; exp_w[2] = 9'h102;
        check_out("T1 caminho 2", 3);
        pass_fail("T1 req só no bit 2", req_seen == 5'b00100, $sformatf("req visto=%b", req_seen));

        // 2. Lógico 44 para porta 3: cabeçalho mantido
        req_seen = '0;
        push4(9'h02C); push4(9'h011); push4(9'h022); push4(9'h102);
        drain("T2");
        exp_w[0] = 9'h02C; exp_w[1] = 9'h011; exp_w[2] = 9'h022; exp_w[3] = 9'h102;
        check_out("T2 lógico 44", 4);
        pass_fail("T2 req só no bit 3", req_seen == 5'b01000, $sformatf("req visto=%b", req_seen));

        // 3. gnt atrasado 5 ciclos: pede, mas não retira nem grava
        gnt_delay = 5;
        push4(9'h002); push4(9'h055); push4(9'h102);
        wait_req();   // IDLE para REQ
        ok = 1'b1;
        msg = "";
        for (int c = 0; c < 5; c++) begin
            if (req4 !== 5'b00100 || rd4 !== 1'b0 || wv4 !== 1'b0 || gnt4 !== 1'b0 || rx_left() != 3) begin
                ok  = 1'b0;
                msg = $sformatf("ciclo %0d: req=%b rd=%b wv=%b gnt=%b fila=%0d",
                                c, req4, rd4, wv4, gnt4, rx_left());
            end
            tick();
        end
        if (ok) msg = "req=00100, nada retirado/gravado";
        pass_fail("T3 espera em ST_REQ por 5 ciclos", ok, msg);
        drain("T3");
        exp_w[0] = 9'h055; exp_w[1] = 9'h102;
        check_out("T3 pacote depois do gnt", 2);
        gnt_delay = 0;

        // 4. Pacote chegando devagar
        push4(9'h003);
        repeat (3) tick();
        push4(9'h0AA);
        repeat (2) tick();
        push4(9'h0BB);
        repeat (4) tick();
        push4(9'h0CC);
        tick();
        push4(9'h102);
        drain("T4");
        exp_w[0] = 9'h0AA; exp_w[1] = 9'h0BB; exp_w[2] = 9'h0CC; exp_w[3] = 9'h102;
        check_out("T4 chegada lenta", 4);

        // 5. out_full oscilando (a porta 4 cheia o tempo todo não deve importar)
        push4(9'h002);
        for (int k = 0; k < 6; k++) push4(9'h010 + 9'(k));
        push4(9'h102);
        for (int c = 0; c < 40 && rx_left() != 0; c++) begin
            full4 = ((c % 3) != 2) ? 5'b10100 : 5'b10000;
            tick();
        end
        full4 = '0;
        drain("T5");
        for (int k = 0; k < 6; k++) exp_w[k] = 9'h010 + 9'(k);
        exp_w[6] = 9'h102;
        check_out("T5 saída cheia oscilando", 7);

        // 6. Dois pacotes seguidos para a mesma saída
        d0 = n_req_drop;
        push4(9'h002); push4(9'h0A1); push4(9'h102);
        push4(9'h002); push4(9'h0A2); push4(9'h102);
        drain("T6");
        exp_w[0] = 9'h0A1; exp_w[1] = 9'h102; exp_w[2] = 9'h0A2; exp_w[3] = 9'h102;
        check_out("T6 dois pacotes", 4);
        pass_fail("T6 req cai depois de cada EOP", (n_req_drop - d0) == 2,
                  $sformatf("%0d quedas de req (esperado 2)", n_req_drop - d0));

        // 7. EOP sozinho e EEP sozinho
        e0 = err_cnt;
        push4(9'h102); push4(9'h101);
        drain("T7");
        check_out("T7 marcadores sozinhos não gravam", 0);
        pass_fail("T7 sem err", err_cnt == e0 && rx_left() == 0,
                  $sformatf("err=%0d fila=%0d", err_cnt - e0, rx_left()));

        // 8. Cabeçalhos inválidos: 6, 5, 31, 255, lógico 50 sem rota (0 agora é a porta 0)
        e0 = err_cnt;
        req_seen = '0;
        push4(9'h006); push4(9'h0AA); push4(9'h102);
        push4(9'h005); push4(9'h0BB); push4(9'h102);
        push4(9'h01F); push4(9'h0CC); push4(9'h101);
        push4(9'h0FF); push4(9'h0DD); push4(9'h102);
        push4(9'h032); push4(9'h0EE); push4(9'h102);
        push4(9'h002); push4(9'h0F0); push4(9'h102);   // válido depois
        drain("T8");
        exp_w[0] = 9'h0F0; exp_w[1] = 9'h102;
        check_out("T8 só o pacote válido sai", 2);
        pass_fail("T8 err pulsou 5 vezes", (err_cnt - e0) == 5,
                  $sformatf("%0d pulsos (esperado 5)", err_cnt - e0));
        pass_fail("T8 inválido não vai para a porta 0", req_seen == 5'b00100, $sformatf("req visto=%b", req_seen));

        // 9. Destino com link fora de Run (porta 3)
        e0 = err_cnt;
        run4 = 5'b10111;
        push4(9'h003); push4(9'h0AB); push4(9'h102);   // caminho 3
        push4(9'h02C); push4(9'h0AC); push4(9'h102);   // lógico 44 para 3
        push4(9'h004); push4(9'h0AD); push4(9'h102);   // válido
        drain("T9");
        run4 = 5'b11111;
        exp_w[0] = 9'h0AD; exp_w[1] = 9'h102;
        check_out("T9 descarta destino sem Run", 2);
        pass_fail("T9 err pulsou 2 vezes", (err_cnt - e0) == 2,
                  $sformatf("%0d pulsos (esperado 2)", err_cnt - e0));

        // 10. Pacote terminado em EEP
        push4(9'h004); push4(9'h077); push4(9'h101);
        drain("T10");
        exp_w[0] = 9'h077; exp_w[1] = 9'h101;
        check_out("T10 EEP repassado", 2);
        pass_fail("T10 volta para ST_IDLE", int'(dut4.state) == 0 && req4 == '0,
                  $sformatf("state=%0d req=%b", int'(dut4.state), req4));

        // 12. Destino cai em ST_REQ (gnt atrasado)
        e0 = err_cnt;
        gnt_delay = 5;
        push4(9'h002); push4(9'h0B1); push4(9'h102);
        wait_req();                           // em ST_REQ esperando gnt
        ok  = (int'(dut4.state) == 1) && (req4 == 5'b00100);
        msg = $sformatf("antes: state=%0d req=%b", int'(dut4.state), req4);
        run4 = 5'b11011;                       // porta 2 cai
        tick();
        ok  = ok && err4 && (req4 == '0) && (int'(dut4.state) == 4);
        msg = {msg, $sformatf("; depois: err=%b req=%b state=%0d", err4, req4, int'(dut4.state))};
        pass_fail("T12 err e req cai no ciclo seguinte", ok, msg);
        drain("T12");
        gnt_delay = 0;
        run4 = 5'b11111;
        check_out("T12 pacote some inteiro", 0);
        push4(9'h004); push4(9'h0B2); push4(9'h102);
        drain("T12b");
        exp_w[0] = 9'h0B2; exp_w[1] = 9'h102;
        check_out("T12 pacote seguinte passa", 2);
        pass_fail("T12 err pulsou 1 vez", (err_cnt - e0) == 1,
                  $sformatf("%0d pulsos (esperado 1)", err_cnt - e0));

        // 13. Destino cai no meio do envio
        e0 = err_cnt;
        push4(9'h002); push4(9'h0C1); push4(9'h0C2); push4(9'h0C3); push4(9'h0C4); push4(9'h102);
        push4(9'h004); push4(9'h0C5); push4(9'h102);   // próximo pacote
        while (outq.size() < 2) tick();                // C1 e C2 já gravados
        run4 = 5'b11011;                                // porta 2 cai
        drain("T13");
        run4 = 5'b11111;
        exp_w[0] = 9'h0C1; exp_w[1] = 9'h0C2; exp_w[2] = 9'h101;
        exp_w[3] = 9'h0C5; exp_w[4] = 9'h102;
        check_out("T13 palavras enviadas + EEP, resto descartado", 5);
        pass_fail("T13 err pulsou 1 vez", (err_cnt - e0) == 1,
                  $sformatf("%0d pulsos (esperado 1)", err_cnt - e0));

        // 14. Igual ao 13, mas a saída está cheia quando o link cai
        e0 = err_cnt;
        push4(9'h002); push4(9'h0D1); push4(9'h0D2); push4(9'h0D3); push4(9'h102);
        push4(9'h004); push4(9'h0D4); push4(9'h102);
        while (outq.size() < 1) tick();                // D1 gravado
        run4 = 5'b11011; full4 = 5'b00100;
        ok = 1'b1;
        msg = "";
        tick();                                        // ST_SEND para ST_EEP
        for (int c = 0; c < 4; c++) begin
            if (int'(dut4.state) != 3 || wv4 !== 1'b0 || req4 !== 5'b00100) begin
                ok  = 1'b0;
                msg = $sformatf("ciclo %0d: state=%0d wv=%b req=%b", c, int'(dut4.state), wv4, req4);
            end
            tick();
        end
        if (ok) msg = "4 ciclos em ST_EEP com req=00100, sem gravar";
        pass_fail("T14 EEP espera a saída liberar", ok, msg);
        full4 = '0;
        drain("T14");
        run4 = 5'b11111;
        exp_w[0] = 9'h0D1; exp_w[1] = 9'h101; exp_w[2] = 9'h0D4; exp_w[3] = 9'h102;
        check_out("T14 EEP gravado depois de liberar", 4);
        pass_fail("T14 err pulsou 1 vez", (err_cnt - e0) == 1,
                  $sformatf("%0d pulsos (esperado 1)", err_cnt - e0));

        // 15. Link da entrada cai no meio do pacote, fila vazia (sem EOP)
        e0 = err_cnt;
        push4(9'h002); push4(9'h0E1); push4(9'h0E2);
        while (outq.size() < 2) tick();
        tick();                                        // fila vazia, ST_SEND esperando
        run4 = 5'b11101;                                // porta 1 (esta entrada) cai
        drain("T15");
        exp_w[0] = 9'h0E1; exp_w[1] = 9'h0E2; exp_w[2] = 9'h101;
        check_out("T15 palavras + EEP", 3);
        pass_fail("T15 err 1 vez e volta para ST_IDLE",
                  (err_cnt - e0) == 1 && int'(dut4.state) == 0,
                  $sformatf("%0d pulsos, state=%0d", err_cnt - e0, int'(dut4.state)));
        run4 = 5'b11111;                                // reconecta
        tick();
        push4(9'h002); push4(9'h0E3); push4(9'h102);
        drain("T15b");
        exp_w[0] = 9'h0E3; exp_w[1] = 9'h102;
        check_out("T15 pacote novo roteado (cabeçalho não engolido)", 2);

        // 16. Link da entrada cai, mas a fila ainda tem palavras
        e0 = err_cnt;
        full4 = 5'b00100;                               // segura a saída 2
        push4(9'h002); push4(9'h0F1); push4(9'h0F2); push4(9'h0F3);
        repeat (6) tick();                             // tudo já na rx_fifo, ST_SEND
        run4 = 5'b11101;
        repeat (2) tick();
        ok  = int'(dut4.state) == 2 && rx_left() == 3 && (err_cnt - e0) == 0;
        pass_fail("T16 continua em ST_SEND com palavras na fila", ok,
                  $sformatf("state=%0d fila=%0d err=%0d", int'(dut4.state), rx_left(), err_cnt - e0));
        full4 = '0;
        drain("T16");
        run4 = 5'b11111;
        exp_w[0] = 9'h0F1; exp_w[1] = 9'h0F2; exp_w[2] = 9'h0F3; exp_w[3] = 9'h101;
        check_out("T16 copia o resto e só então EEP", 4);
        pass_fail("T16 err 1 vez e volta para ST_IDLE",
                  (err_cnt - e0) == 1 && int'(dut4.state) == 0,
                  $sformatf("%0d pulsos, state=%0d", err_cnt - e0, int'(dut4.state)));

        // 17. Link da entrada cai em ST_IDLE, sem pacote
        e0 = err_cnt;
        run4 = 5'b11101;
        ok = 1'b1;
        for (int c = 0; c < 6; c++) begin
            if (int'(dut4.state) != 0 || req4 != '0 || wv4 || rd4) ok = 1'b0;
            tick();
        end
        run4 = 5'b11111;
        pass_fail("T17 nada acontece", ok && (err_cnt - e0) == 0 && outq.size() == 0,
                  $sformatf("err=%0d escritas=%0d", err_cnt - e0, outq.size()));

        // 18. Caminho 0: cabeçalho apagado
        req_seen = '0;
        push4(9'h000); push4(9'h0A7); push4(9'h102);
        drain("T18");
        exp_w[0] = 9'h0A7; exp_w[1] = 9'h102;
        check_out("T18 caminho 0", 2);
        pass_fail("T18 req só no bit 0", req_seen == 5'b00001, $sformatf("req visto=%b", req_seen));

        // 19. Porta 0 fora de Run
        e0 = err_cnt;
        run4 = 5'b11110;
        push4(9'h000); push4(9'h0A8); push4(9'h102);
        push4(9'h004); push4(9'h0A9); push4(9'h102);   // válido
        drain("T19");
        run4 = 5'b11111;
        exp_w[0] = 9'h0A9; exp_w[1] = 9'h102;
        check_out("T19 descarta pacote para a porta 0", 2);
        pass_fail("T19 err pulsou 1 vez", (err_cnt - e0) == 1,
                  $sformatf("%0d pulsos (esperado 1)", err_cnt - e0));

        // 11. N = 8: caminho 8 ok, 9 é erro, lógico 100 para 8
        ok = 1'b1;
        msg = "";
        in_data8 = 9'h008; in_empty8 = 1'b0; #1;
        if (rd8 !== 1'b0) begin ok = 1'b0; msg = {msg, "IDLE retirou cabeçalho válido; "}; end
        tick();
        if (req8 !== 9'h100 || dest8 !== 4'd8) begin ok = 1'b0; msg = {msg, $sformatf("req8=%b dest8=%0d; ", req8, dest8)}; end
        gnt8 = 1'b1; #1;
        if (rd8 !== 1'b1 || wv8 !== 1'b0) begin ok = 1'b0; msg = {msg, "cabeçalho não apagado; "}; end
        tick();
        in_data8 = 9'h0A8; #1;
        if (!(wv8 && rd8 && wd8 == 9'h0A8)) begin ok = 1'b0; msg = {msg, "dado não copiado; "}; end
        tick();
        in_data8 = 9'h102; #1;
        if (!(wv8 && rd8 && wd8 == 9'h102)) begin ok = 1'b0; msg = {msg, "EOP não copiado; "}; end
        tick();
        in_empty8 = 1'b1; gnt8 = 1'b0; #1;
        if (req8 !== '0 || int'(dut8.state) != 0) begin ok = 1'b0; msg = {msg, "não voltou a IDLE; "}; end
        if (ok) msg = "req8=1_0000_0000, cabeçalho apagado, A8+EOP";
        pass_fail("T11 N=8 caminho 8", ok, msg);

        ok = 1'b1;
        msg = "";
        in_data8 = 9'h009; in_empty8 = 1'b0; #1;
        if (rd8 !== 1'b1) begin ok = 1'b0; msg = {msg, "cabeçalho 9 não retirado; "}; end
        tick();
        if (err8 !== 1'b1 || req8 !== '0) begin ok = 1'b0; msg = {msg, $sformatf("err8=%b req8=%b; ", err8, req8)}; end
        in_data8 = 9'h102; #1;   // EOP do pacote descartado
        if (rd8 !== 1'b1 || wv8 !== 1'b0) begin ok = 1'b0; msg = {msg, "spill não retirou EOP; "}; end
        tick();
        in_empty8 = 1'b1; #1;
        if (err8 !== 1'b0 || int'(dut8.state) != 0) begin ok = 1'b0; msg = {msg, "err8 > 1 ciclo ou não voltou a IDLE; "}; end
        if (ok) msg = "err8 pulsou, pacote descartado";
        pass_fail("T11 N=8 caminho 9 é erro", ok, msg);

        ok = 1'b1;
        msg = "";
        in_data8 = 9'h064; in_empty8 = 1'b0;
        tick();
        if (req8 !== 9'h100 || dest8 !== 4'd8) begin ok = 1'b0; msg = {msg, $sformatf("req8=%b dest8=%0d; ", req8, dest8)}; end
        gnt8 = 1'b1; #1;
        if (rd8 !== 1'b0) begin ok = 1'b0; msg = {msg, "cabeçalho lógico apagado; "}; end
        tick();
        #1;
        if (!(wv8 && wd8 == 9'h064)) begin ok = 1'b0; msg = {msg, "cabeçalho lógico não gravado; "}; end
        tick();
        in_data8 = 9'h102;
        tick();
        in_empty8 = 1'b1; gnt8 = 1'b0; #1;
        if (int'(dut8.state) != 0) begin ok = 1'b0; msg = {msg, "não voltou a IDLE; "}; end
        if (ok) msg = "req8=1_0000_0000, cabeçalho 064 mantido";
        pass_fail("T11 N=8 lógico 100 -> 8", ok, msg);
        repeat (2) tick();

        // Monitor
        pass_fail("Monitor req one-hot / wvalid só com gnt / err e EEP", mon_err == 0 && mon_cycles > 0,
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
        #200000;
        $display("RESUMO: %0d PASS, %0d FAIL (parou no timeout)", n_pass, n_fail);
        $display("*** FAIL (timeout) ***");
        $finish;
    end

endmodule
