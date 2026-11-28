`timescale 1ns/1ps

module tb_flow_control_rx;

localparam int DEPTH = 256;

logic clk, rst_n;
logic run_state, en_in_fifo_rx;
logic [$clog2(DEPTH)-1:0] free_slots_fifo;
logic send_FCT;

flow_control_rx #(.DEPTH_FIFO(DEPTH)) dut (.*);

initial clk = 0;
always #5 clk = ~clk;

task automatic tick();
    @(posedge clk); #1;
endtask

task automatic do_reset();
    rst_n = 0;
    run_state = 0;
    en_in_fifo_rx = 0;
    free_slots_fifo = DEPTH;
    repeat(2) tick();
    rst_n = 1;
endtask

/*
  Casos:
    Reset: send_FCT=0
    run_state=0: FCT bloqueado mesmo com FIFO vazio
    run_state=1, FIFO vazio: FCT dispara
    7 FCTs consecutivos saturam credits em 56, send_FCT cai
    8 leituras: credits=48, send_FCT volta a disparar
    FIFO com 4 slots livres: FCT bloqueado
    FIFO com 8 slots livres: FCT dispara
*/
initial begin
    $dumpfile("waves/tb_flow_control_rx.vcd");
    $dumpvars(0, tb_flow_control_rx);
    do_reset();
    if (send_FCT !== 1'b0) $error("case 1 failed");

    run_state = 0;
    free_slots_fifo = 128;
    tick();
    if (send_FCT !== 1'b0) $error("case 2 failed");

    run_state = 1;
    tick();
    if (send_FCT !== 1'b1) $error("case 3 failed");

    repeat(7) tick();
    if (send_FCT !== 1'b0) $error("case 4 failed");

    en_in_fifo_rx = 1;
    repeat(8) tick();
    en_in_fifo_rx = 0;
    if (send_FCT !== 1'b1) $error("case 5 failed");

    run_state = 0;
    tick();
    run_state = 1;
    free_slots_fifo = 4;
    tick();
    if (send_FCT !== 1'b0) $error("case 6 failed");

    free_slots_fifo = 8;
    tick();
    if (send_FCT !== 1'b1) $error("case 7 failed");

    $display("tb_flow_control_rx: all cases passed");
    $finish;
end

endmodule