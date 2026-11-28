`timescale 1ns/1ps

module tb_flow_control_tx;

logic clk, rst_n;
logic run_state, en_out_fifo_tx, got_FCT_rx;
logic sending_allowed;

flow_control_tx dut (.*);

initial clk = 0;
always #5 clk = ~clk;

task automatic tick();
    @(posedge clk); #1;
endtask

task automatic do_reset();
    rst_n = 0;
    run_state = 0;
    en_out_fifo_tx = 0;
    got_FCT_rx = 0;
    repeat(2) tick();
    rst_n = 1;
endtask

/*
  Testes:
        Reset: credits=0, sending_allowed=0
        run_state=0: FCT ignorado
        run_state=1 + 1 FCT: credits=8, sending_allowed=1
        3 envios: credits=5, sending_allowed=1
        mais 5 envios: credits=0, sending_allowed=0
        10 FCTs consecutivos saturam em 56; 56 envios zeram
        FCT e envio no mesmo ciclo: credits += 7
        run_state cai: credits zera
*/
initial begin
    $dumpfile("waves/tb_flow_control_tx.vcd");
    $dumpvars(0, tb_flow_control_tx);
    do_reset();
    if (sending_allowed !== 1'b0) $error("case 1 failed");

    run_state = 0;
    got_FCT_rx = 1;
    tick();
    got_FCT_rx = 0;
    if (sending_allowed !== 1'b0) $error("case 2 failed");

    run_state = 1;
    got_FCT_rx = 1;
    tick();
    got_FCT_rx = 0;
    if (sending_allowed !== 1'b1) $error("case 3 failed");

    en_out_fifo_tx = 1;
    repeat(3) tick();
    en_out_fifo_tx = 0;
    if (sending_allowed !== 1'b1) $error("case 4 failed");

    en_out_fifo_tx = 1;
    repeat(5) tick();
    en_out_fifo_tx = 0;
    if (sending_allowed !== 1'b0) $error("case 5 failed");

    got_FCT_rx = 1;
    repeat(10) tick();
    got_FCT_rx = 0;
    en_out_fifo_tx = 1;
    repeat(56) tick();
    en_out_fifo_tx = 0;
    if (sending_allowed !== 1'b0) $error("case 6 failed");

    got_FCT_rx = 1;
    en_out_fifo_tx = 1;
    tick();
    got_FCT_rx = 0;
    en_out_fifo_tx = 0;
    if (sending_allowed !== 1'b1) $error("case 7 failed");

    run_state = 0;
    tick();
    if (sending_allowed !== 1'b0) $error("case 8 failed");

    $display("tb_flow_control_tx: all cases passed");
    $finish;
end

endmodule