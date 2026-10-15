`timescale 1ns / 1ps

module tb_fifo1;

    parameter DSIZE = 10;
    parameter ASIZE = 4; // profundidade da FIFO é (2^ASIZE) posições

    logic [DSIZE-1:0] rdata;
    logic wfull;
    logic rempty;
    logic [DSIZE-1:0] wdata;
    logic winc, wclk, wrst_n;
    logic rinc, rclk, rrst_n;

    fifo1 #(
        .DSIZE(DSIZE),
        .ASIZE(ASIZE)
    ) dut (
        .rdata(rdata),
        .wfull(wfull),
        .rempty(rempty),
        .wdata(wdata),
        .winc(winc),
        .wclk(wclk),
        .wrst_n(wrst_n),
        .rinc(rinc),
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    always #5 wclk = ~wclk;
    always #12.5 rclk = ~rclk;


    // resetar o sistema com segurança
    task reset_system;
        begin
            wclk = 0;
            rclk = 0;
            wrst_n = 0;
            rrst_n = 0;
            winc = 0;
            rinc = 0;
            wdata = 0;
            #50;
            @(posedge wclk); wrst_n = 1;
            @(posedge rclk); rrst_n = 1;
            $display("[TB] Resets liberados.");
        end
    endtask

    task write_data(input [DSIZE-1:0] data);
        begin
            @(posedge wclk);
            if (wfull) begin
                $display("[AVISO WR] Tentativa de escrita com FIFO CHEIA! Dado ignorado: %h", data);
                winc = 0;
            end else begin
                winc = 1;
                wdata = data;
                $display("[ESCRITA] Dado escrito: %d (Hex: %h)", data, data);
            end
            @(posedge wclk);
            winc = 0; // Desativa após 1 ciclo
        end
    endtask

    // Task para ler um dado da FIFO
    task read_data;
        begin
            @(posedge rclk);
            if (rempty) begin
                $display("[AVISO RD] Tentativa de leitura com FIFO VAZIA!");
                rinc = 0;
            end else begin
                rinc = 1;
                $display("[LEITURA] Dado lido: %d (Hex: %h)", rdata, rdata);
                @(posedge rclk);
            end
            rinc = 0;
        end
    endtask


    initial begin
        $dumpfile("waves/tb_fifo1.vcd");
        $dumpvars(0, tb_fifo1);

        reset_system();
        #20;

        // TESTE 1: tenta ler com ela vazia
        $display("\n Teste 1: Lendo com FIFO vazia");
        read_data();

        // TESTE 2: escrita até encher 
        $display("\n Teste 2: Enchendo a FIFO (Capacidade: 16)");
        for (int i = 1; i <= 18; i = i + 1) begin
            write_data(i * 10);
        end

        #50; 
        if (wfull) $display("[SUCESSO] Flag wfull ativada corretamente!");

        // TESTE 3: ler até Esvaziar
        $display("\n Teste 3: Esvaziando a FIFO");
        for (int i = 1; i <= 18; i = i + 1) begin
            read_data();
        end

        #50;
        if (rempty) $display("[SUCESSO] Flag rempty ativada corretamente!");

// TESTE 4: Escrita e Leitura Simultâneas (Velocidades Diferentes)
        $display("\n Teste 4: Escrita e Leitura Simultâneas (Estresse de CDC)");
        
        fork
            // Processo A: Escrita contínua (Rodando a 100MHz)
            begin
                integer j;
                for(j = 100; j < 115; j++) begin
                    @(posedge wclk);
                    if(!wfull) begin
                        winc  = 1;
                        wdata = j;
                        $display("[SIMULTÂNEO WR] Escrevendo: %d", j);
                    end else begin
                        winc  = 0;
                    end
                end
                @(posedge wclk);
                winc  = 0;
                wdata = '0;
            end
            
            // Processo B: Leitura contínua na velocidade dela (Rodando a 40MHz)
            begin
                integer k;
                #30; 
                for(k = 0; k < 15; k++) begin
                    if(!rempty) begin
                        rinc = 1;
                        $display("[SIMULTÂNEO RD] Lendo: %d", rdata);
                    end else begin
                        rinc = 0;
                    end
                    @(posedge rclk);
                end
                @(posedge rclk);
                rinc = 0;
            end
        join

        #200;
        $display("=== FIM DA SIMULAÇÃO ===");
        $finish;
    end

endmodule
