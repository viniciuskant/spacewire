`timescale 1ns/1ps

module tb_rmap_crc8;
    logic clk;
    logic valid;
    logic [7:0] crc_in;
    logic [7:0] data_in;
    logic [7:0] crc_out;
    
    rmap_crc8 dut (
        .clk(clk),
        .crc_in(crc_in),
        .data_in(data_in),
        .crc_out(crc_out),
        .valid(valid)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function automatic [7:0] calc_crc8_ref(input [7:0] seed, input [7:0] data);
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

    int errors = 0;
    int tests = 0;

    task run_test(input [7:0] seed, input [7:0] data);
        logic [7:0] expected;
 
        @(negedge clk);
        crc_in = seed;
        data_in = data;
        valid = 1'b1;

        @(posedge clk);
        #1;

        expected = calc_crc8_ref(seed, data);
        tests++;

        if (crc_out !== expected) begin
            $error("FALHA! Seed: %02h, Data: %02h | DUT: %02h, Esperado: %02h", seed, data, crc_out, expected);
            errors++;
        end
        
        @(negedge clk);
        valid = 1'b0;
    endtask

    logic [7:0] seed;
    logic [7:0] pkt[0:2];
    
    initial begin
        valid = 1'b0;
        crc_in = 8'h00;
        data_in = 8'h00;

        $display("\nTestando sequencia especifica:");
        seed = 8'h00;
        pkt[0] = 8'hFE;
        pkt[1] = 8'h01;
        pkt[2] = 8'h4C;
        
        foreach (pkt[i]) begin
            logic [7:0] expected_crc = calc_crc8_ref(seed, pkt[i]);
            run_test(seed, pkt[i]);
            $display("  Byte %0d: Data=0x%02h -> CRC=0x%02h", i+1, pkt[i], crc_out);
            seed = crc_out;
        end

        // iterações aleatórias
        $display("\nBatch Test (10.000 iteracoes aleatorias)...");
        for (int i = 0; i < 10000; i++) begin
            run_test($urandom_range(0, 255), $urandom_range(0, 255));
        end

        if (errors == 0) begin
            $display("PASS", tests);
        end else begin
            $display("ERRO! %0d/%0d tests.", errors, tests);
        end

        $finish;
    end

endmodule