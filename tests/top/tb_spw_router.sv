`timescale 1ns/1ps

// roteador (matriz + porta 0 com RMAP + rmap_reg_bank)
module tb_spw_router;

    logic clk, rst_n;
    int   n_pass = 0;
    int   n_fail = 0;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz (clk_system)

    // leitura das tx_fifo em outro clock, sem bordas junto com clk
    logic rclk;
    initial begin
        rclk = 1'b0;
        #1.3;
        forever #2.5 rclk = ~rclk;   // 200 MHz (como clk_ref_tx do codec)
    end

    localparam int N        = 4;
    localparam int PW       = $clog2(N + 1);
    localparam int RX_ASIZE = 6;             // sync_fifo: 64 palavras
    localparam int TX_ASIZE = 4;             // async_fifo: 16 palavras

    localparam logic [8:0] EOP = 9'h102;

    // RMAP
    localparam logic [7:0] KEY       = 8'hAA;      // DESTINATION_KEY do reset do RMAP
    localparam logic [7:0] I_WRITE   = 8'h79;      // 01 1110 01: escrita, verify, reply, 4 bytes de reply address
    localparam logic [7:0] I_READ    = 8'h49;      // 01 0010 01: leitura simples, reply
    localparam logic [31:0] A_GP     = 32'h0000_0418;  // GENERAL_PURPOSE
    localparam logic [7:0] INIT_LA   = 8'h30;      // initiator logical address

    // portas físicas (índice 1..N)
    logic [N:1][8:0]       in_data, out_data;
    logic [N:1]            in_empty, rd, full, wr;
    logic [N:1]            rx_winc = '0;
    logic [N:1][8:0]       rx_wdata = '0;
    logic [N:1][RX_ASIZE:0] rx_free;
    logic [N:1]            tx_rinc = '0;
    logic [N:1]            tx_empty;
    logic [N:1][8:0]       tx_rdata;
    logic [N:1]            run;
    logic                  tc_en;
    logic [N:1]            tc_got;
    logic [N:1][7:0]       tc_rx;
    logic                  tbl_wr, tbl_valid;
    logic [7:0]            tbl_addr;
    logic [PW-1:0]         tbl_port;
    logic [N:0]            err_route, out_busy;
    // verilator lint_off UNUSEDSIGNAL
    logic [N:1]            tc_send;
    logic [7:0]            tc_tx;
    logic [5:0]            tc_reg;
    // verilator lint_on UNUSEDSIGNAL

    spw_router #(.N_PORTS(N)) dut (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data), .in_empty_i(in_empty), .in_rd_en_o(rd),
        .out_data_o(out_data), .out_full_i(full), .out_wr_en_o(wr),
        .link_run_i(run),
        .tc_en_i(tc_en), .tc_got_i(tc_got), .tc_rx_i(tc_rx),
        .tc_send_o(tc_send), .tc_tx_o(tc_tx), .tc_reg_o(tc_reg),
        .tbl_wr_en_i(tbl_wr), .tbl_addr_i(tbl_addr), .tbl_port_i(tbl_port), .tbl_valid_i(tbl_valid),
        .err_route_o(err_route), .out_busy_o(out_busy)
    );

    // FIFOs reais nas portas físicas
    for (genvar p = 1; p <= N; p++) begin : g_fifo
        sync_fifo #(.DSIZE(9), .ASIZE(RX_ASIZE)) u_rx (
            .clk(clk), .rst_n(rst_n),
            .winc(rx_winc[p]), .wdata(rx_wdata[p]),
            .rinc(rd[p]), .rdata(in_data[p]), .rempty(in_empty[p]),
            .free_space_o(rx_free[p])
        );

        async_fifo #(.DSIZE(9), .ASIZE(TX_ASIZE)) u_tx (
            .wclk(clk), .wrst_n(rst_n),
            .winc(wr[p]), .wdata(out_data[p]), .wfull(full[p]),
            .rclk(rclk), .rrst_n(rst_n),
            .rinc(tx_rinc[p]), .rdata(tx_rdata[p]), .rempty(tx_empty[p])
        );
    end

    // filas do tb
    logic [8:0] rxq [1:N][$];          // a entrar na rx_fifo da porta p
    logic [8:0] cap [1:N][$];          // lido da tx_fifo da porta p
    logic [N:1] rd_stop = '0;          // para a leitura da tx_fifo (teste)

    // Tarefas auxiliares
    task tick();
        @(posedge clk); #1;
    endtask

    task pass_fail(input string name, input logic ok, input string got);
        if (ok) begin
            $display("[PASS] %s: %s", name, got);
            n_pass++;
        end else begin
            $error("[FAIL] %s: %s", name, got);
            n_fail++;
        end
    endtask

    // CRC do tb_coded_port_zero
    function automatic logic [7:0] calc_crc8(input logic [7:0] seed, input logic [7:0] data);
        logic [7:0] c;
        c = seed ^ data;
        for (int j = 0; j < 8; j++)
            c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
        return c;
    endfunction

    task push_rx(input int p, input logic [8:0] w);
        rxq[p].push_back(w);
    endtask

    task push_crc(input int p, input logic [7:0] b, inout logic [7:0] crc);
        push_rx(p, {1'b0, b});
        crc = calc_crc8(crc, b);
    endtask

    // Comando RMAP pela porta p (mesmo formato do tb_coded_port_zero, com o 0 na frente).
    // bad_hcrc/bad_dcrc: inverte o CRC do cabeçalho/dos dados.
    task send_cmd(input int p, input logic [7:0] instr, input logic [7:0] key,
                  input logic [15:0] tid, input logic [31:0] addr, input logic [23:0] dlen,
                  input logic [31:0] data, input logic bad_hcrc, input logic bad_dcrc);
        logic [7:0] crc;
        crc = 8'h00;
        push_rx(p, 9'h000);                           // cabeçalho: porta 0
        push_crc(p, 8'hFE, crc);                      // target logical address
        push_crc(p, 8'h01, crc);                      // protocolo RMAP
        push_crc(p, instr, crc);
        push_crc(p, key, crc);
        push_crc(p, 8'h01, crc);                      // reply address: porta 1
        push_crc(p, 8'h00, crc);
        push_crc(p, 8'h00, crc);
        push_crc(p, 8'h00, crc);
        push_crc(p, INIT_LA, crc);
        push_crc(p, tid[15:8], crc);
        push_crc(p, tid[7:0], crc);
        push_crc(p, 8'h00, crc);                      // extended address
        push_crc(p, addr[31:24], crc);
        push_crc(p, addr[23:16], crc);
        push_crc(p, addr[15:8], crc);
        push_crc(p, addr[7:0], crc);
        push_crc(p, dlen[23:16], crc);
        push_crc(p, dlen[15:8], crc);
        push_crc(p, dlen[7:0], crc);
        push_rx(p, {1'b0, bad_hcrc ? ~crc : crc});
        if (instr[5]) begin                           // escrita: dados + CRC
            crc = 8'h00;
            push_crc(p, data[31:24], crc);
            push_crc(p, data[23:16], crc);
            push_crc(p, data[15:8], crc);
            push_crc(p, data[7:0], crc);
            push_rx(p, {1'b0, bad_dcrc ? ~crc : crc});
        end
        push_rx(p, EOP);
    endtask

    // Pacote comum: cabeçalho hdr + nbytes aleatórios + EOP. Guarda o que deve sair em exp_pkt.
    logic [8:0] exp_pkt [$];
    task send_pkt(input int p, input logic [8:0] hdr, input logic keep_hdr, input int nbytes);
        logic [8:0] b;
        exp_pkt.delete();
        push_rx(p, hdr);
        if (keep_hdr) exp_pkt.push_back(hdr);
        for (int k = 0; k < nbytes; k++) begin
            b = {1'b0, 8'($urandom_range(255))};
            push_rx(p, b);
            exp_pkt.push_back(b);
        end
        push_rx(p, EOP);
        exp_pkt.push_back(EOP);
    endtask

    // Retira um pacote (até EOP/EEP) da saída p. Espera até max_cycles.
    logic [8:0] pkt [$];
    task get_pkt(input int p, input int max_cycles, output logic got);
        int t;
        logic done;
        pkt.delete();
        got = 1'b0;
        t = 0;
        done = 1'b0;
        while (!done && t < max_cycles) begin
            while (cap[p].size() != 0 && !done) begin
                pkt.push_back(cap[p].pop_front());
                if (pkt[pkt.size() - 1][8]) done = 1'b1;
            end
            if (!done) begin tick(); t++; end
        end
        got = done;
    endtask

    function automatic string pkt_str();
        string s;
        s = "";
        for (int k = 0; k < pkt.size() && k < 24; k++) s = {s, $sformatf("%03h ", pkt[k])};
        return s;
    endfunction

    // Confere a resposta que chega na porta 1.
    //   escrita: 30 01 cmd st FE tid tid crc EOP
    //   leitura: 30 01 cmd st FE tid tid 00 len len len crc d d d d crc EOP
    task check_reply(input string name, input logic [3:0] cmd, input logic [15:0] tid,
                     input logic [7:0] exp_st, input logic is_read, input logic [31:0] exp_data);
        logic       got, hdr_ok, data_ok;
        logic [7:0] crc, crc01, st;
        int         hlen;
        get_pkt(1, 3000, got);
        pass_fail({name, " resposta chegou na porta 1 com EOP"}, got && pkt[pkt.size() - 1] == EOP,
                  $sformatf("%0d palavras: %s", pkt.size(), pkt_str()));
        if (!got || pkt.size() < 9) return;

        hdr_ok = pkt[0] == {1'b0, INIT_LA} && pkt[1] == 9'h001 &&
                 pkt[2] == {1'b0, 2'b00, cmd, 2'b01} && pkt[4] == 9'h0FE &&
                 pkt[5] == {1'b0, tid[15:8]} && pkt[6] == {1'b0, tid[7:0]};
        pass_fail({name, " cabeçalho da resposta (init LA, protocolo, comando, FE, tid)"}, hdr_ok,
                  $sformatf("%02h %02h %02h .. %02h %02h %02h", pkt[0][7:0], pkt[1][7:0], pkt[2][7:0],
                            pkt[4][7:0], pkt[5][7:0], pkt[6][7:0]));

        st = pkt[3][7:0];
        pass_fail({name, " status"}, st == exp_st, $sformatf("status = %02h (esperado %02h)", st, exp_st));

        // CRC do cabeçalho da resposta: do init LA até o byte antes do CRC
        hlen = (is_read && st == 8'h00) ? 11 : 7;
        crc = 8'h00;
        for (int k = 0; k < hlen; k++) crc = calc_crc8(crc, pkt[k][7:0]);
        crc01 = calc_crc8(8'h00, 8'h01);              // mesmo CRC contando o 01 do reply address (diagnóstico)
        for (int k = 0; k < hlen; k++) crc01 = calc_crc8(crc01, pkt[k][7:0]);
        pass_fail({name, " CRC do cabeçalho da resposta"}, pkt.size() > hlen && pkt[hlen] == {1'b0, crc},
                  $sformatf("recebido %02h, calculado %02h (com o 01 do reply address: %02h)",
                            pkt[hlen][7:0], crc, crc01));

        if (is_read) begin
            data_ok = pkt.size() == 18 && pkt[8] == 9'h000 && pkt[9] == 9'h000 && pkt[10] == 9'h004 &&
                      {pkt[12][7:0], pkt[13][7:0], pkt[14][7:0], pkt[15][7:0]} == exp_data;
            pass_fail({name, " dados lidos"}, data_ok,
                      (pkt.size() == 18) ? $sformatf("lido %02h%02h%02h%02h (esperado %08h)",
                                                     pkt[12][7:0], pkt[13][7:0], pkt[14][7:0], pkt[15][7:0], exp_data)
                                         : $sformatf("resposta sem dados (%0d palavras, status %02h)", pkt.size(), st));
        end
    endtask

    // Nada saiu nas portas da lista (máscara)
    task check_quiet(input string name, input logic [N:1] mask);
        int n;
        n = 0;
        for (int p = 1; p <= N; p++) if (mask[p]) n += cap[p].size();
        pass_fail(name, n == 0, $sformatf("%0d palavras inesperadas", n));
        for (int p = 1; p <= N; p++) if (mask[p]) cap[p].delete();
    endtask

    task prog4(input logic [7:0] a, input logic [PW-1:0] p);
        tbl_wr = 1'b1; tbl_addr = a; tbl_port = p; tbl_valid = 1'b1;
        tick();
        tbl_wr = 1'b0;
    endtask

    // espera as rx_fifo do tb esvaziarem e a matriz/RMAP ficarem livres
    task settle(input int max_cycles);
        int t;
        logic busy_any;
        t = 0;
        busy_any = 1'b1;
        while (busy_any && t < max_cycles) begin
            busy_any = (out_busy != '0) || (dut.u_port0.u_rmap.state != dut.u_port0.u_rmap.RX_IDLE);
            for (int p = 1; p <= N; p++) if (rxq[p].size() != 0 || !in_empty[p]) busy_any = 1'b1;
            tick(); t++;
        end
        repeat (20) tick();
    endtask

    // Monitor
    int mon_cycles = 0;
    int mon_err    = 0;
    int err_cnt    = 0;     // pulsos de err_route
    int cfg_full   = 0;     // ciclos com a rx_fifo do RMAP cheia (matriz esperando)
    int wait_busy  = 0;     // ciclos com comando na rx_fifo do RMAP e RMAP ocupado
    int par04      = 0;     // ciclos com porta 0 e saída 4 gravando juntas
    int full1      = 0;     // ciclos com a tx_fifo da porta 1 cheia

    // initial + forever no lugar de always, por causa do Verilator
    // Amostra no negedge; escreve nas rx_fifo (se tem espaço) logo depois do posedge.
    initial forever begin
        @(negedge clk);
        if (rst_n) begin
            for (int p = 1; p <= N; p++) begin
                if (wr[p] && full[p]) begin
                    $display("[FAIL] monitor: escrita na saída %0d cheia t=%0t", p, $time); mon_err++;
                end
                if (rd[p] && in_empty[p]) begin
                    $display("[FAIL] monitor: rd_en da porta %0d com fila vazia t=%0t", p, $time); mon_err++;
                end
            end
            if (dut.cfg_out_wr_en && dut.cfg_out_full) begin
                $display("[FAIL] monitor: escrita na porta 0 cheia t=%0t", $time); mon_err++;
            end
            if (dut.cfg_in_rd_en && dut.cfg_in_empty) begin
                $display("[FAIL] monitor: leitura da porta 0 vazia t=%0t", $time); mon_err++;
            end
            if (err_route != '0) err_cnt++;
            if (dut.cfg_out_full) cfg_full++;
            if (!dut.u_port0.rx_fifo_rempty && dut.u_port0.busy) wait_busy++;
            if (dut.cfg_out_wr_en && wr[4]) par04++;
            if (full[1]) full1++;
            mon_cycles++;
        end
        @(posedge clk);
        #0.5;
        for (int p = 1; p <= N; p++) begin
            rx_winc[p] = 1'b0;
            if (rxq[p].size() != 0 && rx_free[p] != '0) begin   // não escreve com a rx_fifo cheia
                rx_winc[p]  = 1'b1;
                rx_wdata[p] = rxq[p].pop_front();
            end
        end
    end

    // Leitura das tx_fifo: decide no negedge de rclk, a retirada vale no posedge.
    initial forever begin
        @(negedge rclk);
        for (int p = 1; p <= N; p++) begin
            tx_rinc[p] = rst_n && !tx_empty[p] && !rd_stop[p];
            if (tx_rinc[p]) cap[p].push_back(tx_rdata[p]);
        end
    end

    // Sequência de testes
    initial begin
        logic        got, ok;
        int          f0, c0, t;
        logic [31:0] v1, v2;
        $dumpfile("waves/tb_spw_router.vcd");
        $dumpvars(0, tb_spw_router);


        rst_n = 1'b0;
        run = '1;
        tc_en = 1'b0;
        tc_got = '0;
        tc_rx = '0;
        tbl_wr = 1'b0; tbl_addr = '0; tbl_port = '0; tbl_valid = 1'b0;
        repeat (5) tick();
        rst_n = 1'b1;
        repeat (40) tick();                 // RMAP grava os valores de reset no banco
        prog4(8'h40, PW'(4));                // rota lógica 0x40 -> porta 4 (pelas portas tbl_*)

        // 0. banco ligado: o RMAP gravou os valores de reset
        pass_fail("T0 banco inicializado pelo RMAP (0x109 = DESTINATION_KEY = AA)",
                  dut.u_bank.mem[9'h109] == 32'h0000_00AA,
                  $sformatf("mem[109] = %08h", dut.u_bank.mem[9'h109]));

        // escrita em GENERAL_PURPOSE pela porta 1
        v1 = 32'hCAFE_F00D;
        send_cmd(1, I_WRITE, KEY, 16'h0001, A_GP, 24'd4, v1, 1'b0, 1'b0);
        check_reply("Ta escrita 0x106", 4'b1110, 16'h0001, 8'h00, 1'b0, '0);
        settle(2000);
        check_quiet("Ta nada nas portas 2..4", 4'b1110);
        pass_fail("Ta valor gravado no banco em 0x106", dut.u_bank.mem[9'h106] == v1,
                  $sformatf("mem[106] = %08h, mem[041] = %08h (addr[10:2])",
                            dut.u_bank.mem[9'h106], dut.u_bank.mem[9'h041]));

        // leitura de 0x106
        send_cmd(1, I_READ, KEY, 16'h0002, A_GP, 24'd4, '0, 1'b0, 1'b0);
        check_reply("Tb leitura 0x106", 4'b0010, 16'h0002, 8'h00, 1'b1, v1);
        settle(2000);

        // dois comandos seguidos: escrita + leitura na fila
        v2 = 32'h1234_5678;
        c0 = wait_busy;
        f0 = cfg_full;
        send_cmd(1, I_WRITE, KEY, 16'h0003, A_GP, 24'd4, v2, 1'b0, 1'b0);
        send_cmd(1, I_READ,  KEY, 16'h0004, A_GP, 24'd4, '0, 1'b0, 1'b0);
        check_reply("Tc 1o comando (escrita)", 4'b1110, 16'h0003, 8'h00, 1'b0, '0);
        check_reply("Tc 2o comando (leitura)", 4'b0010, 16'h0004, 8'h00, 1'b1, v2);
        pass_fail("Tc 2o comando esperou na rx_fifo do RMAP enquanto ele respondia o 1o", wait_busy > c0,
                  $sformatf("%0d ciclos com dado na fila e RMAP ocupado, %0d ciclos com a porta 0 cheia",
                            wait_busy - c0, cfg_full - f0));
        settle(2000);

        // tráfego 2 -> 4 (rota lógica 0x40) junto com um comando RMAP pela porta 1
        c0 = par04;
        send_pkt(2, 9'h040, 1'b1, 60);
        send_cmd(1, I_WRITE, KEY, 16'h0005, A_GP, 24'd4, v1, 1'b0, 1'b0);
        get_pkt(4, 3000, got);
        ok = got && pkt.size() == exp_pkt.size();
        for (int k = 0; k < pkt.size() && k < exp_pkt.size(); k++) if (pkt[k] !== exp_pkt[k]) ok = 1'b0;
        pass_fail("Td pacote 2 -> 4 inteiro", ok,
                  $sformatf("%0d de %0d palavras", pkt.size(), exp_pkt.size()));
        check_reply("Td escrita junto com 2 -> 4", 4'b1110, 16'h0005, 8'h00, 1'b0, '0);
        pass_fail("Td porta 0 e saída 4 gravando no mesmo ciclo", par04 > c0,
                  $sformatf("%0d ciclos em paralelo", par04 - c0));
        settle(2000);
        check_quiet("Td nada nas portas 2 e 3", 4'b0110);

        // tx_fifo da porta 1 cheia durante a resposta
        rd_stop[1] = 1'b1;
        f0 = full1;
        send_pkt(3, 9'h001, 1'b0, 15);       // 15 + EOP = 16 palavras: enche a tx_fifo da porta 1
        t = 0;
        while (!full[1] && t < 500) begin tick(); t++; end
        send_cmd(1, I_READ, KEY, 16'h0006, A_GP, 24'd4, '0, 1'b0, 1'b0);
        repeat (400) tick();
        pass_fail("Te resposta esperando: tx_fifo 1 cheia e saída 1 com dono",
                  full[1] && out_busy[1] && dut.cfg_in_empty == 1'b0,
                  $sformatf("full=%b busy=%b cfg_in_empty=%b", full[1], out_busy[1], dut.cfg_in_empty));
        rd_stop[1] = 1'b0;
        get_pkt(1, 3000, got);
        ok = got && pkt.size() == exp_pkt.size();
        for (int k = 0; k < pkt.size() && k < exp_pkt.size(); k++) if (pkt[k] !== exp_pkt[k]) ok = 1'b0;
        pass_fail("Te pacote 3 -> 1 inteiro antes da resposta", ok,
                  $sformatf("%0d de %0d palavras", pkt.size(), exp_pkt.size()));
        check_reply("Te leitura com a porta 1 cheia", 4'b0010, 16'h0006, 8'h00, 1'b1, v1);
        pass_fail("Te tx_fifo da porta 1 ficou cheia", full1 > f0, $sformatf("%0d ciclos", full1 - f0));
        settle(2000);

        // erros
        send_cmd(1, I_WRITE, 8'h55, 16'h0007, A_GP, 24'd4, 32'h0BAD_0BAD, 1'b0, 1'b0);
        check_reply("Tf destination key errada", 4'b1110, 16'h0007, 8'h03, 1'b0, '0);
        settle(2000);

        send_cmd(1, I_WRITE, KEY, 16'h0008, A_GP, 24'd4, 32'h0BAD_0BAD, 1'b1, 1'b0);
        get_pkt(1, 2000, got);
        pass_fail("Tf CRC do cabeçalho errado: sem resposta", !got && pkt.size() == 0,
                  got ? $sformatf("veio resposta: %s", pkt_str()) : "nenhuma resposta");
        settle(2000);

        send_cmd(1, I_WRITE, KEY, 16'h0009, A_GP, 24'd4, 32'h0BAD_0BAD, 1'b0, 1'b1);
        check_reply("Tf CRC dos dados errado", 4'b1110, 16'h0009, 8'h04, 1'b0, '0);
        settle(2000);

        // Monitor
        check_quiet("Fim nada sobrando nas saídas", '1);
        pass_fail("Monitor sem escrita em fila cheia / leitura de fila vazia", mon_err == 0 && mon_cycles > 0,
                  $sformatf("%0d ciclos checados, %0d erros", mon_cycles, mon_err));
        pass_fail("Monitor sem err_route", err_cnt == 0, $sformatf("%0d ciclos com err_route", err_cnt));

        // Resumo
        $display("--------------------------------------------");
        $display("RESUMO: %0d PASS, %0d FAIL", n_pass, n_fail);
        if (n_fail == 0) $display("*** PASS ***");
        else             $display("*** FAIL (%0d erros totais) ***", n_fail);
        $finish;
    end

    // trava de segurança
    initial begin
        #5000000;
        $display("RESUMO: %0d PASS, %0d FAIL (parou no timeout)", n_pass, n_fail);
        $error("Timeout global da simulacao");
        $fatal(1);
    end

endmodule
