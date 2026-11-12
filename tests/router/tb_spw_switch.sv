`timescale 1ns/1ps

//topo da matriz
module tb_spw_switch;

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

    localparam int RX_ASIZE = 6;             // sync_fifo: 64 palavras (DEPTH_FIFO do codec)
    localparam int RX_DEPTH = 1 << RX_ASIZE;
    localparam int TX_ASIZE = 4;             // async_fifo: 16 palavras (sync_r2w/sync_w2r só têm ADDRSIZE = 4)

    // DUT com N = 4
    localparam int N4    = 4;
    localparam int PW4   = $clog2(N4 + 1);
    localparam int DEPTH = 4096;            // palavras por buffer (sem dar a volta)

    // índice 0 = porta de configuração (cfg_*)
    logic [N4:0][8:0]     in_data4;
    logic [N4:0]          in_empty4, rd4;
    logic [N4:0][8:0]     out_data4;
    logic [N4:0]          full4;                  // wfull da async_fifo
    logic [N4:0]          wr4;
    logic [N4:0]          rx_winc4 = '0;          // escrita na sync_fifo
    logic [N4:0][8:0]     rx_wdata4 = '0;
    logic [N4:0][RX_ASIZE:0] rx_free4;            // free_space_o da sync_fifo
    logic [N4:0]          tx_rinc4 = '0;          // leitura da async_fifo
    logic [N4:0]          tx_empty4;
    logic [N4:0][8:0]     tx_rdata4;
    logic [N4:1]          run4;
    logic                 cfg_ready4;
    logic                 tc_en4;
    logic [N4:1]          tc_got4, tc_send4;
    logic [N4:1][7:0]     tc_rx4;
    logic [7:0]           tc_tx4;
    logic [5:0]           tc_reg4;
    logic                 tbl_wr4, tbl_valid4;
    logic [7:0]           tbl_addr4;
    logic [PW4-1:0]       tbl_port4;
    logic [N4:0]          err4, busy4;

    spw_switch #(.N_PORTS(N4)) dut4 (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data4[N4:1]), .in_empty_i(in_empty4[N4:1]), .in_rd_en_o(rd4[N4:1]),
        .out_data_o(out_data4[N4:1]), .out_full_i(full4[N4:1]), .out_wr_en_o(wr4[N4:1]),
        .link_run_i(run4),
        .cfg_in_data_i(in_data4[0]), .cfg_in_empty_i(in_empty4[0]), .cfg_in_rd_en_o(rd4[0]),
        .cfg_out_data_o(out_data4[0]), .cfg_out_full_i(full4[0]), .cfg_out_wr_en_o(wr4[0]),
        .cfg_ready_i(cfg_ready4),
        .tc_en_i(tc_en4), .tc_got_i(tc_got4), .tc_rx_i(tc_rx4),
        .tc_send_o(tc_send4), .tc_tx_o(tc_tx4), .tc_reg_o(tc_reg4),
        .tbl_wr_en_i(tbl_wr4), .tbl_addr_i(tbl_addr4), .tbl_port_i(tbl_port4), .tbl_valid_i(tbl_valid4),
        .err_route_o(err4), .out_busy_o(busy4)
    );

    // vistas unpacked dos vetores 2D
    logic [7:0]     tc_r  [1:N4];
    wire  [PW4-1:0] m_dest [0:N4];         // dest_o de cada sw_in_ctrl
    wire  [N4:0]    m_gnt  [0:N4];         // gnt_o de cada árbitro

    for (genvar p = 1; p <= N4; p++) begin : g_tc4
        assign tc_rx4[p]   = tc_r[p];
    end

    for (genvar p = 0; p <= N4; p++) begin : g_view4
        assign m_dest[p]   = dut4.ic_dest[p];
        assign m_gnt[p]    = dut4.arb_gnt[p];

        sync_fifo #(.DSIZE(9), .ASIZE(RX_ASIZE)) u_rx (
            .clk(clk), .rst_n(rst_n),
            .winc(rx_winc4[p]), .wdata(rx_wdata4[p]),
            .rinc(rd4[p]), .rdata(in_data4[p]), .rempty(in_empty4[p]),
            .free_space_o(rx_free4[p])
        );

        async_fifo #(.DSIZE(9), .ASIZE(TX_ASIZE)) u_tx (
            .wclk(clk), .wrst_n(rst_n),
            .winc(wr4[p]), .wdata(out_data4[p]), .wfull(full4[p]),
            .rclk(rclk), .rrst_n(rst_n),
            .rinc(tx_rinc4[p]), .rdata(tx_rdata4[p]), .rempty(tx_empty4[p])
        );
    end

    // DUT com N = 8
    localparam int N8  = 8;
    localparam int PW8 = $clog2(N8 + 1);

    logic [N8:0][8:0]     in_data8;
    logic [N8:0]          in_empty8, rd8;
    logic [N8:0][8:0]     out_data8;
    logic [N8:0]          wr8, full8;
    logic                 rx8_winc = 1'b0;        // só a porta 1 recebe
    logic [8:0]           rx8_wdata = '0;
    logic [N8:0]          tx8_rinc = '0;
    logic [N8:0]          tx8_empty;
    logic [N8:0][8:0]     tx8_rdata;
    logic                 tbl_wr8, tbl_valid8;
    logic [7:0]           tbl_addr8;
    logic [PW8-1:0]       tbl_port8;
    // verilator lint_off UNUSEDSIGNAL
    logic [N8:1]          tc_send8;
    logic [N8:0]          err8, busy8;
    logic [7:0]           tc_tx8;
    logic [5:0]           tc_reg8;
    logic [N8:0][RX_ASIZE:0] rx8_free;            // portas sem dados: nunca enche
    // verilator lint_on UNUSEDSIGNAL

    spw_switch #(.N_PORTS(N8)) dut8 (
        .clk(clk), .rst_n(rst_n),
        .in_data_i(in_data8[N8:1]), .in_empty_i(in_empty8[N8:1]), .in_rd_en_o(rd8[N8:1]),
        .out_data_o(out_data8[N8:1]), .out_full_i(full8[N8:1]), .out_wr_en_o(wr8[N8:1]),
        .link_run_i('1),
        .cfg_in_data_i(in_data8[0]), .cfg_in_empty_i(in_empty8[0]), .cfg_in_rd_en_o(rd8[0]),
        .cfg_out_data_o(out_data8[0]), .cfg_out_full_i(full8[0]), .cfg_out_wr_en_o(wr8[0]),
        .cfg_ready_i(1'b1),
        .tc_en_i(1'b1), .tc_got_i('0), .tc_rx_i('0),
        .tc_send_o(tc_send8), .tc_tx_o(tc_tx8), .tc_reg_o(tc_reg8),
        .tbl_wr_en_i(tbl_wr8), .tbl_addr_i(tbl_addr8), .tbl_port_i(tbl_port8), .tbl_valid_i(tbl_valid8),
        .err_route_o(err8), .out_busy_o(busy8)
    );

    for (genvar p = 0; p <= N8; p++) begin : g_view8
        sync_fifo #(.DSIZE(9), .ASIZE(RX_ASIZE)) u_rx (
            .clk(clk), .rst_n(rst_n),
            .winc((p == 1) ? rx8_winc : 1'b0), .wdata(rx8_wdata),
            .rinc(rd8[p]), .rdata(in_data8[p]), .rempty(in_empty8[p]),
            .free_space_o(rx8_free[p])
        );

        async_fifo #(.DSIZE(9), .ASIZE(TX_ASIZE)) u_tx (
            .wclk(clk), .wrst_n(rst_n),
            .winc(wr8[p]), .wdata(out_data8[p]), .wfull(full8[p]),
            .rclk(rclk), .rrst_n(rst_n),
            .rinc(tx8_rinc[p]), .rdata(tx8_rdata[p]), .rempty(tx8_empty[p])
        );
    end

    // Estímulo e scoreboard
    // palavras que ainda vão entrar na sync_fifo de p: rxm[p][rx_h..rx_t-1]
    logic [8:0] rxm  [0:N4][0:DEPTH-1];
    int         rx_h [0:N4];
    int         rx_t [0:N4];
    // esperado por par (entrada i, saída j): expm[i][j][ex_h..ex_t-1]
    logic [8:0] expm [0:N4][0:N4][0:DEPTH-1];
    int         ex_h [0:N4][0:N4];
    int         ex_t [0:N4][0:N4];
    // lido da async_fifo de cada saída: capm[j][cp_h..cp_t-1]
    logic [8:0] capm [0:N4][0:DEPTH-1];
    int         cp_h [0:N4];
    int         cp_t [0:N4];
    int         n_wr [0:N4];                // palavras gravadas em cada async_fifo

    // N = 8: estímulo só da porta 1, leitura de todas as saídas
    logic [8:0] rx8m [0:63];
    int         rx8_h = 0, rx8_t = 0;
    logic [8:0] cap8m [0:N8][0:63];
    int         cp8_t [0:N8];

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

    // O monitor coloca as palavras na sync_fifo, uma por ciclo.
    task push_rx(input int p, input logic [8:0] w);
        if (rx_t[p] >= DEPTH) begin
            $display("[FAIL] tb: rx_fifo %0d estourou o buffer", p); n_fail++;
        end else begin
            rxm[p][rx_t[p]] = w;
            rx_t[p]++;
        end
    endtask

    task push_exp(input int i, input int j, input logic [8:0] w);
        if (ex_t[i][j] >= DEPTH) begin
            $display("[FAIL] tb: esperado %0d->%0d estourou o buffer", i, j); n_fail++;
        end else begin
            expm[i][j][ex_t[i][j]] = w;
            ex_t[i][j]++;
        end
    endtask

    // Pacote de i para j. Caminho: cabeçalho = j
    // Lógico: cabeçalho = 50 + j (tabela 51..54 para 1..4, mantido na saída).
    // mk = marcador final (102 = EOP, 101 = EEP); exp = 0 não registra o esperado.
    logic [8:0] last_body [0:31];           // bytes do último pacote enviado
    task send_pkt(input int i, input int j, input logic logical, input int nbytes,
                  input logic [8:0] mk, input logic exp);
        logic [8:0] hdr, b;
        hdr = logical ? 9'(50 + j) : 9'(j);
        push_rx(i, hdr);
        if (exp && logical) push_exp(i, j, hdr);
        for (int k = 0; k < nbytes; k++) begin
            b = {1'b0, 8'($urandom_range(255))};
            last_body[k] = b;
            push_rx(i, b);
            if (exp) push_exp(i, j, b);
        end
        push_rx(i, mk);
        if (exp) push_exp(i, j, mk);
    endtask

    function automatic int rx_left();
        int s;
        s = 0;
        // a entrar + em trânsito + dentro da sync_fifo
        for (int p = 0; p <= N4; p++)
            s += (rx_t[p] - rx_h[p]) + int'(rx_winc4[p]) + (RX_DEPTH - int'(rx_free4[p]));
        return s;
    endfunction

    // Palavras gravadas nas async_fifo e ainda não lidas.
    function automatic int tx_left();
        int s;
        s = 0;
        for (int j = 0; j <= N4; j++) s += n_wr[j] - cp_t[j];
        return s;
    endfunction

    // Espera as rx_fifo esvaziarem, as saídas soltarem e as tx_fifo serem lidas.
    task drain(input string name, input int max_cycles);
        int t;
        t = 0;
        while ((rx_left() != 0 || busy4 != '0 || tx_left() != 0) && t < max_cycles) begin tick(); t++; end
        repeat (3) tick();
        if (t >= max_cycles) pass_fail({name, " drain"}, 1'b0, "timeout esperando as filas esvaziarem");
    endtask

    // Scoreboard: confere os pacotes que saíram em cada saída
    logic [8:0] pkt [0:63];
    task sb_check(input string name);
        int  n_pkt, n_bad, len, left;
        logic match, found;
        string msg;
        n_pkt = 0; n_bad = 0; msg = "";
        for (int j = 0; j <= N4; j++) begin
            len = 0;
            while (cp_h[j] != cp_t[j]) begin
                if (len < 64) pkt[len] = capm[j][cp_h[j]];
                len++;
                cp_h[j]++;
                if (pkt[(len - 1) % 64][8]) begin            // fim de pacote
                    found = 1'b0;
                    for (int i = 0; i <= N4 && !found; i++) begin
                        if (ex_t[i][j] - ex_h[i][j] >= len) begin
                            match = 1'b1;
                            for (int k = 0; k < len; k++)
                                if (expm[i][j][ex_h[i][j] + k] !== pkt[k]) match = 1'b0;
                            if (match) begin
                                found = 1'b1;
                                ex_h[i][j] += len;
                            end
                        end
                    end
                    if (found) n_pkt++;
                    else begin
                        n_bad++;
                        if (n_bad <= 3) msg = {msg, $sformatf("saída %0d: pacote de %0d palavras sem par (início %03h); ", j, len, pkt[0])};
                    end
                    len = 0;
                end
            end
            if (len != 0) begin
                n_bad++;
                msg = {msg, $sformatf("saída %0d: %0d palavras sem EOP/EEP; ", j, len)};
            end
        end
        left = 0;
        for (int i = 0; i <= N4; i++)
            for (int j = 0; j <= N4; j++) left += ex_t[i][j] - ex_h[i][j];
        if (left != 0) msg = {msg, $sformatf("%0d palavras esperadas não chegaram; ", left)};
        pass_fail(name, n_bad == 0 && left == 0,
                  $sformatf("%0d pacotes conferidos. %s", n_pkt, msg));
    endtask

    // Palavras gravadas na saída j ainda não conferidas (lado de escrita da tx_fifo).
    // verilator lint_off UNUSEDSIGNAL
    function automatic int cap_cnt(input int j);
        return n_wr[j] - cp_h[j];
    endfunction
    // verilator lint_on UNUSEDSIGNAL

    task prog4(input logic [7:0] a, input logic [PW4-1:0] p);
        tbl_wr4 = 1'b1; tbl_addr4 = a; tbl_port4 = p; tbl_valid4 = 1'b1;
        tick();
        tbl_wr4 = 1'b0;
    endtask

    task prog8(input logic [7:0] a, input logic [PW8-1:0] p);
        tbl_wr8 = 1'b1; tbl_addr8 = a; tbl_port8 = p; tbl_valid8 = 1'b1;
        tick();
        tbl_wr8 = 1'b0;
    endtask

    // Monitor + escrita nas rx_fifo + leitura das tx_fifo
    int          mon_cycles = 0;
    int          mon_err    = 0;
    int          err_cnt [0:N4];       // pulsos de err_route por entrada
    int          par24      = 0;       // ciclos com as saídas 2 e 4 gravando
    int          par23      = 0;       // ciclos com as saídas 2 e 3 gravando
    int          all4       = 0;       // ciclos com as 4 saídas gravando
    int          max_wr     = 0;       // máximo de saídas gravando no mesmo ciclo
    int          full_cyc   = 0;       // ciclos com alguma tx_fifo cheia
    logic        stress     = 1'b0;    // leitura das tx_fifo mais lenta que a escrita
    logic [N4:0] rd_stop    = '0;      // para a leitura da tx_fifo (teste)

    // initial + forever no lugar de always, por causa do Verilator
    // Amostra no negedge; escreve nas rx_fifo (se tem espaço) logo depois do posedge.
    initial forever begin
        int          nw, ng, nwr;
        @(negedge clk);
        if (rst_n) begin
            nwr = 0;
            for (int j = 0; j <= N4; j++) begin
                // gravadores candidatos (wvalid com destino j): 0 ou 1
                nw = 0;
                for (int i = 0; i <= N4; i++)
                    if (dut4.ic_wvalid[i] && m_dest[i] == PW4'(j)) nw++;
                if (nw > 1) begin
                    $display("[FAIL] monitor: saída %0d com %0d gravadores t=%0t", j, nw, $time); mon_err++;
                end
                ng = 0;
                for (int i = 0; i <= N4; i++) if (m_gnt[j][i]) ng++;
                if (ng > 1) begin
                    $display("[FAIL] monitor: gnt do árbitro %0d não one-hot (%b) t=%0t", j, m_gnt[j], $time); mon_err++;
                end
                if (wr4[j] && !busy4[j]) begin
                    $display("[FAIL] monitor: escrita na saída %0d sem dono t=%0t", j, $time); mon_err++;
                end
                if (wr4[j] && full4[j]) begin
                    $display("[FAIL] monitor: escrita na saída %0d cheia t=%0t", j, $time); mon_err++;
                end
                if (wr4[j]) nwr++;
                if (wr4[j] && !full4[j]) n_wr[j]++;
            end
            for (int i = 0; i <= N4; i++) begin
                if (rd4[i] && in_empty4[i]) begin
                    $display("[FAIL] monitor: rd_en da porta %0d com fila vazia t=%0t", i, $time); mon_err++;
                end
                if (err4[i]) err_cnt[i]++;
            end
            if (wr4[2] && wr4[4]) par24++;
            if (wr4[2] && wr4[3]) par23++;
            if (wr4[N4:1] == '1) all4++;
            if (nwr > max_wr) max_wr = nwr;
            if (full4 != '0) full_cyc++;

            // N = 8
            if ((rd8 & ~9'h002) != '0) begin
                $display("[FAIL] monitor: dut8 leu porta sem dados t=%0t", $time); mon_err++;
            end
            mon_cycles++;
        end
        @(posedge clk);
        #0.5;
        for (int p = 0; p <= N4; p++) begin
            rx_winc4[p] = 1'b0;
            if (rx_h[p] != rx_t[p] && rx_free4[p] != '0) begin   // não escreve com a rx_fifo cheia
                rx_winc4[p]  = 1'b1;
                rx_wdata4[p] = rxm[p][rx_h[p]];
                rx_h[p]++;
            end
        end
        rx8_winc = 1'b0;
        if (rx8_h != rx8_t && rx8_free[1] != '0) begin
            rx8_winc  = 1'b1;
            rx8_wdata = rx8m[rx8_h];
            rx8_h++;
        end
    end

    // Leitura das tx_fifo: decide no negedge de rclk, a retirada vale no posedge.
    initial forever begin
        @(negedge rclk);
        for (int j = 0; j <= N4; j++) begin
            tx_rinc4[j] = rst_n && !tx_empty4[j] && !rd_stop[j] &&
                          (!stress || $urandom_range(99) < 10);   // estresse: ~20 MHz
            if (tx_rinc4[j] && cp_t[j] < DEPTH) begin
                capm[j][cp_t[j]] = tx_rdata4[j];
                cp_t[j]++;
            end
        end
        for (int j = 0; j <= N8; j++) begin
            tx8_rinc[j] = rst_n && !tx8_empty[j];
            if (tx8_rinc[j] && cp8_t[j] < 64) begin
                cap8m[j][cp8_t[j]] = tx8_rdata[j];
                cp8_t[j]++;
            end
        end
    end

    // Sequência de testes
    initial begin
        int   e0, p0, a0, nb, dj;
        logic ok;
        logic [8:0] we;
        $dumpfile("waves/tb_spw_switch.vcd");
        $dumpvars(0, tb_spw_switch);


        rst_n = 1'b0;
        for (int p = 0; p <= N4; p++) begin
            rx_h[p] = 0; rx_t[p] = 0; cp_h[p] = 0; cp_t[p] = 0; n_wr[p] = 0; err_cnt[p] = 0;
            for (int q = 0; q <= N4; q++) begin ex_h[p][q] = 0; ex_t[p][q] = 0; end
        end
        for (int p = 1; p <= N4; p++) tc_r[p] = '0;
        for (int p = 0; p <= N8; p++) cp8_t[p] = 0;
        run4 = '1; cfg_ready4 = 1'b1; tc_en4 = 1'b1; tc_got4 = '0;
        tbl_wr4 = 1'b0; tbl_valid4 = 1'b0; tbl_addr4 = '0; tbl_port4 = '0;
        tbl_wr8 = 1'b0; tbl_valid8 = 1'b0; tbl_addr8 = '0; tbl_port8 = '0;
        repeat (2) tick();
        rst_n = 1'b1;
        tick();

        prog4(8'd44, 3'd2);                                  // lógico 44 para 2
        for (int p = 1; p <= N4; p++) prog4(8'(50 + p), PW4'(p));   // 51..54 para 1..4
        prog8(8'd100, 4'd5);                                 // N = 8: lógico 100 para 5

        // 1. Caminho 1 para 3
        push_rx(1, 9'h003); push_rx(1, 9'h0A5); push_rx(1, 9'h03C); push_rx(1, 9'h102);
        push_exp(1, 3, 9'h0A5); push_exp(1, 3, 9'h03C); push_exp(1, 3, 9'h102);
        drain("T1", 200);
        sb_check("T1 caminho 1 -> 3 sem cabeçalho");

        // 2. Lógico 44 para 2
        push_rx(1, 9'h02C); push_rx(1, 9'h011); push_rx(1, 9'h022); push_rx(1, 9'h102);
        push_exp(1, 2, 9'h02C); push_exp(1, 2, 9'h011); push_exp(1, 2, 9'h022); push_exp(1, 2, 9'h102);
        drain("T2", 200);
        sb_check("T2 lógico 44 -> 2 com cabeçalho");

        // 3. Duas entradas para a mesma saída
        send_pkt(1, 2, 1'b0, 8, 9'h102, 1'b1);
        send_pkt(3, 2, 1'b0, 8, 9'h102, 1'b1);
        drain("T3", 200);
        sb_check("T3 1 -> 2 e 3 -> 2: inteiros, sem misturar");

        // 4. Paralelo: 1 para 2 e 3 para 4
        p0 = par24;
        send_pkt(1, 2, 1'b0, 8, 9'h102, 1'b1);
        send_pkt(3, 4, 1'b0, 8, 9'h102, 1'b1);
        drain("T4", 200);
        sb_check("T4 1 -> 2 e 3 -> 4");
        pass_fail("T4 gravações nos mesmos ciclos", (par24 - p0) >= 8,
                  $sformatf("%0d ciclos com as saídas 2 e 4 gravando juntas", par24 - p0));

        // 5. Permutação completa
        a0 = all4;
        send_pkt(1, 2, 1'b0, 6, 9'h102, 1'b1);
        send_pkt(2, 3, 1'b1, 6, 9'h102, 1'b1);
        send_pkt(3, 4, 1'b0, 6, 9'h102, 1'b1);
        send_pkt(4, 1, 1'b1, 6, 9'h102, 1'b1);
        drain("T5", 200);
        sb_check("T5 permutação 1->2, 2->3, 3->4, 4->1");
        pass_fail("T5 as 4 saídas gravando no mesmo ciclo", (all4 - a0) > 0,
                  $sformatf("%0d ciclos com as 4 gravando", all4 - a0));

        // 6. Cabeçalho inválido na porta 2 (caminho 5 > N)
        e0 = err_cnt[2];
        push_rx(2, 9'h005); push_rx(2, 9'h0EE); push_rx(2, 9'h0EF); push_rx(2, 9'h102);
        send_pkt(2, 3, 1'b0, 4, 9'h102, 1'b1);
        drain("T6", 200);
        sb_check("T6 só o pacote válido sai");
        pass_fail("T6 err_route[2] pulsou 1 vez", (err_cnt[2] - e0) == 1,
                  $sformatf("%0d pulsos", err_cnt[2] - e0));

        // 7. Saída cheia no meio do pacote: para de ler a tx_fifo 3 até a wfull subir
        rd_stop[3] = 1'b1;
        send_pkt(1, 3, 1'b0, 24, 9'h102, 1'b1);              // 25 palavras > 16 da tx_fifo
        for (int c = 0; c < 200 && !full4[3]; c++) tick();
        ok = full4[3];
        repeat (2) tick();
        nb = cap_cnt(3);
        repeat (6) tick();
        if (cap_cnt(3) != nb) ok = 1'b0;
        rd_stop[3] = 1'b0;
        pass_fail("T7 nada gravado com a saída cheia", ok,
                  $sformatf("%0d palavras antes, %0d depois", nb, cap_cnt(3)));
        drain("T7", 200);
        sb_check("T7 nada perdido nem duplicado");

        // 8. Link de destino cai no meio do pacote (1 para 2)
        e0 = err_cnt[1];
        send_pkt(1, 2, 1'b0, 10, 9'h102, 1'b0);
        while (cap_cnt(2) < 3) tick();                         // 3 bytes gravados
        run4 = 4'b1101;
        for (int k = 0; k < 3; k++) push_exp(1, 2, last_body[k]);
        push_exp(1, 2, 9'h101);
        drain("T8", 200);
        run4 = '1;
        sb_check("T8 bytes enviados + EEP");
        pass_fail("T8 err_route[1] pulsou 1 vez, resto descartado",
                  (err_cnt[1] - e0) == 1 && rx_left() == 0,
                  $sformatf("%0d pulsos, %0d palavras na fila", err_cnt[1] - e0, rx_left()));

        // 9. Time-code
        ok = 1'b1;
        tc_got4[1] = 1'b1; tc_r[1] = {2'b00, 6'(tc_reg4 + 6'd1)};  // conta em 6 bits, flags = 00
        tick();
        tc_got4 = '0;
        if (tc_send4 !== 4'b1110 || tc_tx4 !== 8'd1 || tc_reg4 !== 6'd1) ok = 1'b0;
        tick();
        if (tc_send4 !== '0) ok = 1'b0;
        pass_fail("T9 time-code porta 1 -> 2, 3, 4 (1 ciclo)", ok,
                  $sformatf("tx=%0d reg=%0d", tc_tx4, tc_reg4));

        // 10. Estresse: 200 pacotes aleatórios, leitura das tx_fifo lenta (enche de verdade)
        e0 = err_cnt[1] + err_cnt[2] + err_cnt[3] + err_cnt[4];
        stress = 1'b1;
        for (int n = 0; n < 200; n++) begin
            dj = $urandom_range(N4 - 1) + 1;
            send_pkt((n % N4) + 1, dj, 1'($urandom_range(1)), $urandom_range(20),
                     ($urandom_range(9) == 0) ? 9'h101 : 9'h102, 1'b1);
        end
        drain("T10", 50000);
        stress = 1'b0;
        sb_check("T10 estresse 200 pacotes");
        pass_fail("T10 sem err_route", err_cnt[1] + err_cnt[2] + err_cnt[3] + err_cnt[4] == e0,
                  $sformatf("%0d pulsos no estresse",
                            err_cnt[1] + err_cnt[2] + err_cnt[3] + err_cnt[4] - e0));
        pass_fail("T10 saídas em paralelo", max_wr == 4, $sformatf("até %0d saídas no mesmo ciclo", max_wr));
        pass_fail("T10 tx_fifo cheia durante o estresse", full_cyc > 0, $sformatf("%0d ciclos com wfull", full_cyc));

        // 11. N = 8: caminho 8 e lógico 100 para 5, entrando pela porta 1
        rx8m[0] = 9'h008; rx8m[1] = 9'h0AA; rx8m[2] = 9'h0BB; rx8m[3] = 9'h102;
        rx8m[4] = 9'h064; rx8m[5] = 9'h0CC; rx8m[6] = 9'h102;
        rx8_t = 7;
        for (int c = 0; c < 100 && (rx8_h != rx8_t || rx8_winc || !in_empty8[1]); c++) tick();
        repeat (5) tick();
        ok = cp8_t[8] == 3 && cap8m[8][0] == 9'h0AA && cap8m[8][1] == 9'h0BB && cap8m[8][2] == 9'h102;
        pass_fail("T11 N=8 caminho 8", ok,
                  $sformatf("saída 8: %0d palavras [%03h %03h %03h]", cp8_t[8], cap8m[8][0], cap8m[8][1], cap8m[8][2]));
        ok = cp8_t[5] == 3 && cap8m[5][0] == 9'h064 && cap8m[5][1] == 9'h0CC && cap8m[5][2] == 9'h102;
        nb = 0;
        for (int j = 0; j <= N8; j++) nb += cp8_t[j];
        pass_fail("T11 N=8 lógico 100 -> 5", ok && nb == 6,
                  $sformatf("saída 5: %0d palavras [%03h %03h %03h], total %0d", cp8_t[5],
                            cap8m[5][0], cap8m[5][1], cap8m[5][2], nb));

        // 12. Porta 1 para a porta 0: chega em cfg_out sem o byte 0
        push_rx(1, 9'h000); push_rx(1, 9'h0D1); push_rx(1, 9'h0D2); push_rx(1, 9'h102);
        push_exp(1, 0, 9'h0D1); push_exp(1, 0, 9'h0D2); push_exp(1, 0, 9'h102);
        drain("T12", 200);
        sb_check("T12 caminho 0 em cfg_out sem cabeçalho");

        // 13. Pacote vindo de cfg_in
        push_rx(0, 9'h002); push_rx(0, 9'h0E1); push_rx(0, 9'h0E2); push_rx(0, 9'h102);
        push_exp(0, 2, 9'h0E1); push_exp(0, 2, 9'h0E2); push_exp(0, 2, 9'h102);
        drain("T13", 200);
        sb_check("T13 cfg_in caminho 2 sem cabeçalho");
        push_rx(0, 9'h02C); push_rx(0, 9'h0E3); push_rx(0, 9'h102);
        push_exp(0, 2, 9'h02C); push_exp(0, 2, 9'h0E3); push_exp(0, 2, 9'h102);
        drain("T13", 200);
        sb_check("T13 cfg_in lógico 44 com cabeçalho");
        e0 = err_cnt[0];
        push_rx(0, 9'h032); push_rx(0, 9'h0E4); push_rx(0, 9'h102);   // lógico 50 sem rota
        drain("T13", 200);
        pass_fail("T13 cfg_in lógico sem rota: err_route[0]", (err_cnt[0] - e0) == 1,
                  $sformatf("%0d pulsos", err_cnt[0] - e0));
        prog4(8'd60, 3'd5);                                  // porta 5 > N: não é rota
        e0 = err_cnt[1];
        push_rx(1, 9'h03C); push_rx(1, 9'h0E5); push_rx(1, 9'h102);
        drain("T13", 200);
        pass_fail("T13 rota para a porta N+1 não existe", (err_cnt[1] - e0) == 1,
                  $sformatf("%0d pulsos", err_cnt[1] - e0));
        sb_check("T13 pacotes descartados não saem");

        // 14. Portas 1 e 3 para a porta 0 ao mesmo tempo (último atendido: 1)
        for (int pk = 0; pk < 2; pk++) begin
            for (int b = 0; b < 2; b++) begin
                int src;
                src = (b == 0) ? 1 : 3;
                push_rx(src, 9'h000);
                for (int k = 0; k < 4; k++) begin
                    we = ((b == 0) ? 9'h0A0 : 9'h0C0) + 9'(k);
                    push_rx(src, we);
                    push_exp(src, 0, we);
                end
                push_rx(src, 9'h102);
                push_exp(src, 0, 9'h102);
            end
        end
        drain("T14", 400);
        ok = (cp_t[0] - cp_h[0]) == 20;
        for (int pk = 0; pk < 4 && ok; pk++) begin
            for (int k = 0; k < 5; k++) begin
                we = (k == 4) ? 9'h102 : (((pk % 2) == 0) ? 9'h0C0 : 9'h0A0) + 9'(k);
                if (capm[0][cp_h[0] + (pk * 5) + k] !== we) ok = 1'b0;
            end
        end
        pass_fail("T14 ordem round-robin 3, 1, 3, 1", ok,
                  $sformatf("%0d palavras na saída 0", cp_t[0] - cp_h[0]));
        sb_check("T14 pacotes inteiros, sem misturar");

        // 15. cfg_ready_i = 0: descarta e gera pulso
        e0 = err_cnt[3];
        a0 = n_wr[0];
        cfg_ready4 = 1'b0;
        push_rx(3, 9'h000); push_rx(3, 9'h0F1); push_rx(3, 9'h102);
        drain("T15", 200);
        cfg_ready4 = 1'b1;
        pass_fail("T15 err_route[3] pulsou 1 vez, nada em cfg_out",
                  (err_cnt[3] - e0) == 1 && n_wr[0] == a0,
                  $sformatf("%0d pulsos, %0d palavras", err_cnt[3] - e0, n_wr[0] - a0));
        sb_check("T15 nada sai");

        // 16. Paralelo: 0 para 2 e 1 para 3
        p0 = par23;
        send_pkt(0, 2, 1'b0, 8, 9'h102, 1'b1);
        send_pkt(1, 3, 1'b0, 8, 9'h102, 1'b1);
        drain("T16", 200);
        sb_check("T16 0 -> 2 e 1 -> 3");
        pass_fail("T16 gravações nos mesmos ciclos", (par23 - p0) >= 8,
                  $sformatf("%0d ciclos com as saídas 2 e 3 gravando juntas", par23 - p0));

        // 17. cfg_out_full_i = 1: para de ler a tx_fifo 0 até a wfull subir
        rd_stop[0] = 1'b1;
        send_pkt(1, 0, 1'b0, 24, 9'h102, 1'b1);              // 25 palavras > 16 da tx_fifo
        for (int c = 0; c < 200 && !full4[0]; c++) tick();
        ok = full4[0];
        repeat (2) tick();
        nb = cap_cnt(0);
        repeat (6) tick();
        if (cap_cnt(0) != nb) ok = 1'b0;
        rd_stop[0] = 1'b0;
        pass_fail("T17 nada gravado com cfg_out cheia", ok,
                  $sformatf("%0d palavras antes, %0d depois", nb, cap_cnt(0)));
        drain("T17", 200);
        sb_check("T17 nada perdido nem duplicado");

        // 18. cfg_ready_i cai no meio de um pacote vindo de cfg_in (fila vazia)
        e0 = err_cnt[0];
        push_rx(0, 9'h003); push_rx(0, 9'h0B1); push_rx(0, 9'h0B2);
        while (cap_cnt(3) < 2) tick();
        repeat (2) tick();
        cfg_ready4 = 1'b0;
        push_exp(0, 3, 9'h0B1); push_exp(0, 3, 9'h0B2); push_exp(0, 3, 9'h101);
        drain("T18", 200);
        cfg_ready4 = 1'b1;
        sb_check("T18 palavras + EEP");
        pass_fail("T18 err_route[0] pulsou 1 vez", (err_cnt[0] - e0) == 1,
                  $sformatf("%0d pulsos", err_cnt[0] - e0));

        // 19. Estresse com a porta 0: 200 pacotes aleatórios
        e0 = err_cnt[0] + err_cnt[1] + err_cnt[2] + err_cnt[3] + err_cnt[4];
        stress = 1'b1;
        for (int n = 0; n < 200; n++) begin
            dj = $urandom_range(N4);
            send_pkt(n % (N4 + 1), dj, (dj != 0) && 1'($urandom_range(1)), $urandom_range(20),
                     ($urandom_range(9) == 0) ? 9'h101 : 9'h102, 1'b1);
        end
        drain("T19", 50000);
        stress = 1'b0;
        sb_check("T19 estresse com a porta 0");
        nb = err_cnt[0] + err_cnt[1] + err_cnt[2] + err_cnt[3] + err_cnt[4] - e0;
        pass_fail("T19 sem err_route", nb == 0, $sformatf("%0d pulsos", nb));

        // Monitor
        pass_fail("Monitor 1 gravador por saída / gnt one-hot / escrita só com dono",
                  mon_err == 0 && mon_cycles > 0,
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
        #5000000;
        $display("RESUMO: %0d PASS, %0d FAIL (parou no timeout)", n_pass, n_fail);
        $display("*** FAIL (timeout) ***");
        $finish;
    end

endmodule
