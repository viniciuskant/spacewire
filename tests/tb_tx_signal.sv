`timescale 1ns/1ps

module tb_tx_signal;
    logic clk;
    logic rst_n;
    logic bit_valid_i;
    logic bit_i;
    logic d_o;
    logic s_o;

    tx_signal dut (
        .clk (clk),
        .rst_n (rst_n),
        .bit_valid_i (bit_valid_i),
        .bit_i (bit_i),
        .d_o (d_o),
        .s_o (s_o)
    );

    always #5 clk = ~clk;

    // envia um bit de forma simplificada
    task send_bit(input logic b);
        begin
            @(posedge clk);
            bit_valid_i = 1'b1;
            bit_i = b;
            @(posedge clk);
            bit_valid_i = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("waves/tb_tx_signal.vcd");
        $dumpvars(0, tb_tx_signal);

        clk = 1'b0;
        rst_n = 1'b0;
        bit_valid_i = 1'b0;
        bit_i = 1'b0;

        #15;
        rst_n = 1'b1;
        #10;

        $display("[TB] Iniciando o envio de bits...");

        @(posedge clk);
        bit_valid_i = 1'b1;
        bit_i = 1'b1;
        @(posedge clk);
        bit_valid_i = 1'b0;
        #10;
        if (d_o != 1'b1 || s_o != 1'b0) begin
            $display("ERROR");
            $finish;
        end

        @(posedge clk);
        bit_valid_i = 1'b1;
        bit_i = 1'b1;
        @(posedge clk);
        bit_valid_i = 1'b0;
        #10;
        if (d_o != 1'b1 || s_o != 1'b1)
            $error("d_o != 1'b1 || s_o != 1'b1");

        @(posedge clk);
        bit_valid_i = 1'b1;
        bit_i = 1'b0;
        @(posedge clk);
        bit_valid_i = 1'b0;
        #10;
        if (d_o != 1'b0 || s_o != 1'b1)
            $error("d_o != 1'b0 || s_o != 1'b1");

        @(posedge clk);
        bit_valid_i = 1'b1;
        bit_i = 1'b0;
        @(posedge clk);
        bit_valid_i = 1'b0;
        #10;
        if (d_o != 1'b0 || s_o != 1'b0)
            $error("d_o != 1'b0 || s_o != 1'b0");

        @(posedge clk);
        bit_valid_i = 1'b1;
        bit_i = 1'b1;
        @(posedge clk);
        bit_valid_i = 1'b0;
        #10;
        if (d_o != 1'b1 || s_o != 1'b0)
            $error("d_o != 1'b1 || s_o != 1'b0");

        // Espera uns ciclos finais e encerra
        #50;
        $display("[TB] Teste finalizado com sucesso.");
        $finish;
    end

endmodule
