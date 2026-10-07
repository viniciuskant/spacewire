`timescale 1ns/1ps

module tb_rx_signal;

    logic ref_rx_clk, rx_clk, rst_n;
    logic d_i, s_i;
    logic bit_valid_o, bit_o;

    rx_signal dut_rx_signal (
        .ref_rx_clk(ref_rx_clk), 
        .rx_clk(rx_clk),
        .rst_n(rst_n),
        .d_i(d_i),
        .s_i(s_i),
        .bit_valid_o(bit_valid_o),
        .bit_o(bit_o)
    );

    initial ref_rx_clk = 0;
    always #2.5 ref_rx_clk = ~ref_rx_clk; // 200 MHz

    localparam int N = 200;

    logic [N-1:0] tx_bits;
    logic [N-1:0] rx_bits;
    int rx_count;
    int errors;

    always @(posedge ref_rx_clk) begin
        if (bit_valid_o && rx_count < N) begin
            rx_bits[rx_count] = bit_o;
            rx_count++;
        end
    end

    task automatic run_test(input real period_ns, input int seed, input string name);
        int   i, errs;
        logic prev;

        rst_n = 0; d_i = 0; s_i = 0;
        rx_count = 0; rx_bits = '0;

        repeat (10) @(posedge ref_rx_clk);
        rst_n = 1;
        repeat (10) @(posedge ref_rx_clk);

        for (i = 0; i < N; i++)
            tx_bits[i] = $urandom(seed + i) & 1'b1;

        prev = 1'b0;
        for (i = 0; i < N; i++) begin
            if (tx_bits[i] != prev)
                d_i = tx_bits[i]; // bit mudou -> alterna d (1 transição)
            else
                s_i = ~s_i; // bit repetiu -> alterna s (1 transição)
            prev = tx_bits[i];
            #(period_ns);
        end

        #(period_ns * 10);

        errs = 0;
        if (rx_count !== N) begin
            $display("[%s] rx_count = %0d (esperado %0d)", name, rx_count, N);
            errs++;
        end
        for (i = 0; i < N && i < rx_count; i++) begin
            if (rx_bits[i] !== tx_bits[i]) begin
                if (errs < 5)
                    $display("[%s] bit[%0d]: got %b exp %b", name, i, rx_bits[i], tx_bits[i]);
                errs++;
            end
        end

        if (errs == 0) $display("[%s] PASS (%0d bits recebidos)", name, rx_count);
        else $display("[%s] FAIL (%0d erros)", name, errs);
        errors += errs;
    endtask

    initial begin
        $dumpfile("waves/tb_rx_signal.vcd");
        $dumpvars(0, tb_rx_signal);

        errors = 0;
        $display("=== Teste rx_signal — data-strobe ===");
        run_test(100.0, 1000, "10  MHz");
        run_test( 20.0, 2000, "50  MHz");
        run_test( 10.0, 3000, "100 MHz");
        run_test(  5.0, 4000, "200 MHz");

        $display("");
        if (errors == 0) $display("*** PASS ***");
        else             $display("*** FAIL (%0d erros totais) ***", errors);
        $finish;
    end

endmodule