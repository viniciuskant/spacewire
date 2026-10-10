`timescale 1ns / 1ps

module tb_codec #(
    parameter int DEPTH_FIFO = 2048,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 8500
);

    logic system_clk;
    logic ref_tx_clk;
    logic [7:0] div_counter_tx;
    assign div_counter_tx = 10;
    logic rst_n;

    // CODEC A 
    logic [8:0] SpW_Packet_TX_A;
    logic [8:0] SpW_Packet_RX_A;
    logic SpW_Packet_TX_en_A;
    logic SpW_Packet_RX_en_A;
    logic empty_rx_fifo_A;
    logic full_tx_fifo_A;

    logic [7:0] Time_Code_TX_A;
    logic [7:0] Time_Code_RX_A;
    logic Time_Code_TX_valid_A;
    logic Time_Code_RX_valid_A;


    // CODEC B
    logic [8:0] SpW_Packet_TX_B;
    logic [8:0] SpW_Packet_RX_B;
    logic SpW_Packet_TX_en_B;
    logic SpW_Packet_RX_en_B;
    logic empty_rx_fifo_B;
    logic full_tx_fifo_B;

    logic [7:0] Time_Code_TX_B;
    logic [7:0] Time_Code_RX_B;
    logic Time_Code_TX_valid_B;
    logic Time_Code_RX_valid_B;


    logic S_A_to_B, D_A_to_B; // TX do codec A para RX o B
    logic S_B_to_A, D_B_to_A; // TX do codec B para RX o A

    // Codec A
    codec #(
        .DEPTH_FIFO (DEPTH_FIFO),
        .CLK_FREQ (CLK_FREQ),
        .SYS_CLK_FREQ_HZ (SYS_CLK_FREQ_HZ),
        .DISCONNECT_TIMEOUT_NS (DISCONNECT_TIMEOUT_NS)
    ) u_codec_A (
        .system_clk (system_clk),
        .ref_tx_clk (ref_tx_clk),
        .div_counter_tx(div_counter_tx),
        .rst_n (rst_n),
        .S_in (S_B_to_A),
        .D_in (D_B_to_A),
        .S_out (S_A_to_B),
        .D_out (D_A_to_B),
        .SpW_Packet_TX (SpW_Packet_TX_A),  
        .SpW_Packet_RX (SpW_Packet_RX_A),
        .SpW_Packet_TX_en(SpW_Packet_TX_en_A),
        .SpW_Packet_RX_en(SpW_Packet_RX_en_A),
        .empty_rx_fifo(empty_rx_fifo_A),
        .full_tx_fifo(full_tx_fifo_A),
        .Time_Code_TX(Time_Code_TX_A),
        .Time_Code_RX(Time_Code_RX_A),
        .Time_Code_TX_valid(Time_Code_TX_valid_A),
        .Time_Code_RX_valid(Time_Code_RX_valid_A)
    );

    // Codec B
    codec #(
        .DEPTH_FIFO (DEPTH_FIFO),
        .CLK_FREQ (CLK_FREQ),
        .SYS_CLK_FREQ_HZ (SYS_CLK_FREQ_HZ),
        .DISCONNECT_TIMEOUT_NS (DISCONNECT_TIMEOUT_NS)
    ) u_codec_B (
        .system_clk (system_clk),
        .ref_tx_clk (ref_tx_clk),
        .div_counter_tx(div_counter_tx),
        .rst_n (rst_n),
        .S_in (S_A_to_B),
        .D_in (D_A_to_B),
        .S_out (S_B_to_A),
        .D_out (D_B_to_A),

        .SpW_Packet_TX (SpW_Packet_TX_B),
        .SpW_Packet_RX (SpW_Packet_RX_B),
        .SpW_Packet_TX_en(SpW_Packet_TX_en_B),
        .SpW_Packet_RX_en(SpW_Packet_RX_en_B),
        .empty_rx_fifo(empty_rx_fifo_B),
        .full_tx_fifo(full_tx_fifo_B),

        .Time_Code_TX(Time_Code_TX_B),
        .Time_Code_RX(Time_Code_RX_B),
        .Time_Code_TX_valid(Time_Code_TX_valid_B),
        .Time_Code_RX_valid(Time_Code_RX_valid_B)
    );

    //clock
    initial system_clk = 0;
    always #20 system_clk = ~system_clk;

    initial ref_tx_clk = 0;
    always #55 ref_tx_clk = ~ref_tx_clk;

    logic [8:0] data_test;
    logic [7:0] timecode_test;

    logic [8:0] stim_buf [0:15];
    logic [8:0] ref_buf  [0:15];

    // Irei seguir a lógica de mandar dados do A para o B, ou seja ver se o dado colocado no tx do A chega ao rx do B
    initial begin
        $dumpfile("waves/tb_codec.vcd");
        $dumpvars(0, tb_codec);

        // generate stimulus
        for (int i = 0; i < 16; i++) begin
            stim_buf[i] = i[8:0];
            ref_buf[i]  = i[8:0];
        end

        rst_n  = 0;
        repeat (10) @(posedge system_clk);
        rst_n = 1;
        $display("\n\nwaiting for SpW Uplink to Connect");

        wait(u_codec_A.run_state && u_codec_B.run_state);
        $display("SpW Uplink Connected !\n");

        repeat (10) @(posedge system_clk); // TODO para teste, ver como isso tem que ficar depois


        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        data_test = 9'b0_0101_0110;
        $display("SpW Data Loaded (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        // send time code and check for received time code
        timecode_test = 9'b1011_1100;
        $display("sending time code (A -> B) : %x", timecode_test);
        send_tc_A_to_B_and_check(timecode_test);

        repeat (13) @(posedge system_clk); // TODO para teste, ver como isso tem que ficar depois  

        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        data_test = 9'b0_0101_1110;
        $display("SpW Data Loaded (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        repeat (13) @(posedge system_clk); // TODO para teste, ver como isso tem que ficar depois  

        $display("sending 8 bytes of data (A -> B) : %x", data_test);
        for (int i = 0; i < 16; i++) begin
            @(negedge system_clk);
            SpW_Packet_TX_A = stim_buf[i];
            SpW_Packet_TX_en_A = 1;
            Time_Code_TX_valid_A = 0;

            @(negedge system_clk);
            SpW_Packet_TX_en_A = 1'b0;
        end

        repeat (3) @(posedge system_clk); // TODO para teste, ver como isso tem que ficar depois  
        
        $display("getting Rx Data:");
        for (int i = 0; i < 16; i++) begin
            fork
                wait (!empty_rx_fifo_B);
                begin
                    repeat (50) @(posedge system_clk);
                    $error("Timeout: !empty_rx_fifo_B did not assert within 50 cycles (idx %0d).", i);
                    $finish;
                end
            join_any
            disable fork;
            @(posedge system_clk);
            if (SpW_Packet_RX_B === ref_buf[i])
                $display("OK  [%0d]: received = %x", i, SpW_Packet_RX_B);
            else begin
                $error("MISMATCH [%0d]: expected = %x | received = %x", i, ref_buf[i], SpW_Packet_RX_B);
                $finish;
            end
            SpW_Packet_RX_en_B = 1;
            @(posedge system_clk);
            SpW_Packet_RX_en_B = 0;
        end

        // Test Sending EOP and receve EOP
        data_test = 9'b1_0000_0010; // set control bit + EOP 
        $display("sending EOP (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

		// Test Sending EEP and receve EEP
        data_test = 9'b1_0000_0001; // set control bit + EEP
        $display("sending EEP (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        $display(">>>>>>>>>>>> TEST OK");

    end


    task automatic check_rx(input [8:0] expected, input [8:0] received, input string side);
        begin
            if (received === expected)
                $display("OK [%s]: received = %x\n", side, received);
            else begin
                #200;
                $error("MISMATCH [%s]: expected = %x | received = %x",
                       side, expected, received);
                $finish;
            end
        end
    endtask

    task automatic check_tc(input [7:0] expected, input [7:0] received, input string side);
        begin
            if (received === expected)
                $display("OK [%s]: received = %x\n", side, received);
            else begin
                $error("MISMATCH [%s]: expected = %x | received = %x",
                       side, expected, received);
                $finish;
            end
        end
    endtask


    task automatic wait_rx_valid_B();
        begin
            fork
                wait (!empty_rx_fifo_B);
                begin
                    repeat (50) @(posedge system_clk);
                    $error("Timeout: empty_rx_fifo_B did not arrive within 50 cycles.");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask

    task automatic wait_rx_valid_A();
        begin
            fork
                wait (!empty_rx_fifo_A);
                begin
                    repeat (50) @(posedge system_clk);
                    $error("Timeout: empty_rx_fifo_A did not arrive within 50 cycles.");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask

    task automatic wait_tc_valid_B();
        begin
            fork
                wait (Time_Code_RX_valid_B);
                begin
                    repeat (50) @(posedge system_clk);
                    $error("Timeout: Time_Code_RX_valid_B did not arrive within 50 cycles.");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask

    task automatic wait_tc_valid_A();
        begin
            fork
                wait (Time_Code_RX_valid_A);
                begin
                    repeat (50) @(posedge system_clk);
                    $error("Timeout: Time_Code_RX_valid_A did not arrive within 50 cycles.");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask

    task automatic send_packet_A(input [8:0] data);
        begin
            @(posedge system_clk);
            SpW_Packet_TX_A       = data;
            SpW_Packet_TX_en_A = 1;
            Time_Code_TX_valid_A  = 0;

            @(posedge system_clk);
            SpW_Packet_TX_en_A = 0;
        end
    endtask

    task automatic send_packet_B(input [8:0] data);
        begin
            @(posedge system_clk);
            SpW_Packet_TX_B       = data;
            SpW_Packet_TX_en_B = 1;
            Time_Code_TX_valid_B  = 0;

            @(posedge system_clk);
            SpW_Packet_TX_en_B = 0;
        end
    endtask


    task automatic send_tc_A(input [7:0] data);
        begin
            @(posedge system_clk);
            Time_Code_TX_A        = data;
            Time_Code_TX_valid_A  = 1;
            SpW_Packet_TX_en_A = 0;

            @(posedge system_clk);
            Time_Code_TX_valid_A  = 0;
        end
    endtask


    task automatic send_tc_B(input [7:0] data);
        begin
            @(posedge system_clk);
            Time_Code_TX_B        = data;
            Time_Code_TX_valid_B  = 1;
            SpW_Packet_TX_en_B = 0;

            @(posedge system_clk);
            Time_Code_TX_valid_B  = 0;
        end
    endtask

    task automatic send_A_to_B_and_check(input [8:0] data);
        begin
            send_packet_A(data);
            wait_rx_valid_B();
            @(posedge system_clk);
            check_rx(data, SpW_Packet_RX_B, "A->B");
            SpW_Packet_RX_en_B = 1;
            @(posedge system_clk);
            SpW_Packet_RX_en_B = 0;
        end
    endtask

    task automatic send_B_to_A_and_check(input [8:0] data);
        begin
            send_packet_B(data);
            wait_rx_valid_A();
            @(posedge system_clk);
            check_rx(data, SpW_Packet_RX_A, "B->A");
            SpW_Packet_RX_en_A = 1;
            @(posedge system_clk);
            SpW_Packet_RX_en_A = 0;

        end
    endtask

    task automatic send_tc_A_to_B_and_check(input [7:0] data);
        begin
            send_tc_A(data);
            wait_tc_valid_B();
            check_tc(data, Time_Code_RX_B, "A->B [TIME CODE]");
        end
    endtask

    task automatic send_tc_B_to_A_and_check(input [7:0] data);
        begin
            send_tc_B(data);
            wait_tc_valid_A();
            check_tc(data, Time_Code_RX_A, "B->A [TIME CODE]");
        end
    endtask

endmodule
