`timescale 1ns / 1ps

module tb_codec #(
    parameter int DEPTH_FIFO = 64,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850
);

    logic clk_system;
    logic clk_ref_tx;
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

    logic [7:0] div_counter_tx_A;
    assign div_counter_tx_A = 2;

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

    logic [7:0] div_counter_tx_B;
    assign div_counter_tx_B = 2;

    logic S_A_to_B, D_A_to_B; // TX do codec A para RX o B
    logic S_B_to_A, D_B_to_A; // TX do codec B para RX o A

    logic S_A_out, D_A_out;

    // error tests
    logic enable_disconnect_A_to_B; // deixa o sinal D sempre zero
    logic enable_parity_err_A_to_B; //inverte o D e o S

    logic clk_tx;
    assign clk_tx = D_A_out ^ S_A_out;
    logic [2:0] counter_err;

    logic data_A_to_B;
    logic strobe_A_to_B;
    always_ff @(posedge clk_tx or negedge clk_tx or negedge rst_n) begin
        if (!rst_n) begin
            counter_err <= 0;
        end else begin
            counter_err <= counter_err + 1;
            if (counter_err == 3'b110) begin
                data_A_to_B = ~D_A_out;
                strobe_A_to_B = ~S_A_out;
            end else begin
                data_A_to_B = D_A_out;
                strobe_A_to_B = S_A_out;
            end
        end
    end

    always_comb begin
        if (enable_disconnect_A_to_B) begin
            D_A_to_B = 1'b0;
            S_A_to_B = S_A_out;
        end else if (enable_parity_err_A_to_B) begin
            D_A_to_B = data_A_to_B;
            S_A_to_B = strobe_A_to_B;
        end else begin
            D_A_to_B = D_A_out;
            S_A_to_B = S_A_out;
        end
    end

    // Codec A
    codec #(
        .DEPTH_FIFO (DEPTH_FIFO),
        .CLK_FREQ (CLK_FREQ),
        .SYS_CLK_FREQ_HZ (SYS_CLK_FREQ_HZ),
        .DISCONNECT_TIMEOUT_NS (DISCONNECT_TIMEOUT_NS)
    ) dut_codec_A (
        .clk_system (clk_system),
        .clk_ref_tx (clk_ref_tx),
        .div_counter_tx(div_counter_tx_A),
        .rst_n (rst_n),
        .S_in (S_B_to_A),
        .D_in (D_B_to_A),
        .S_out (S_A_out),
        .D_out (D_A_out),
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
    ) dut_codec_B (
        .clk_system (clk_system),
        .clk_ref_tx (clk_ref_tx),
        .div_counter_tx(div_counter_tx_B),
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
    initial clk_system = 0;
    always #10 clk_system = ~clk_system;

    initial clk_ref_tx = 0;
    always #2.5 clk_ref_tx = ~clk_ref_tx;

    logic [8:0] data_test;
    logic [7:0] timecode_test;

    logic [8:0] stim_buf [0:15];
    logic [8:0] ref_buf  [0:15];

    initial begin
        #100000;
        $display("\n\nTIMEOUT");
        $finish;
    end
    // Irei seguir a lógica de mandar dados do A para o B, ou seja ver se o dado colocado no tx do A chega ao rx do B
    initial begin
        $dumpfile("waves/tb_codec.vcd");
        $dumpvars(0, tb_codec);

        // generate stimulus
        for (int i = 0; i < 16; i++) begin
            stim_buf[i] = i[8:0];
            ref_buf[i]  = i[8:0];
        end

        enable_disconnect_A_to_B = 0;
        enable_parity_err_A_to_B = 0;

        rst_n  = 0;
        repeat (10) @(posedge clk_system);
        rst_n = 1;
        $display("\n\nwaiting for SpW Uplink to Connect");

        wait(dut_codec_A.run_state && dut_codec_B.run_state);
        $display("SpW Uplink Connected !\n");

        @(posedge clk_system); // TODO para teste, ver como isso tem que ficar depois

        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        data_test = 9'b0_0101_0110;
        $display("SpW Data Loaded (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        data_test = 9'b0_0000_1110;
        $display("SpW Data Loaded (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        // send time code and check for received time code
        timecode_test = 8'b1011_1100;
        $display("sending time code (A -> B) : %x", timecode_test);
        send_tc_A_to_B_and_check(timecode_test);

        repeat (2) @(posedge clk_system); // TODO para teste, ver como isso tem que ficar depois  

        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        data_test = 9'b0_0101_1110;
        $display("SpW Data Loaded (A -> B) : %x", data_test);
        send_A_to_B_and_check(data_test);

        repeat (13) @(posedge clk_system); // TODO para teste, ver como isso tem que ficar depois  

        $display("sending 8 bytes of data (A -> B):");
        for (int i = 0; i < 16; i++) begin
            wait(!full_tx_fifo_A);
            @(posedge clk_system);
            SpW_Packet_TX_A = stim_buf[i];
            SpW_Packet_TX_en_A = 1;
            Time_Code_TX_valid_A = 0;

            @(posedge clk_system);
            SpW_Packet_TX_en_A = 1'b0;
        end
        
        $display("getting Rx Data:");
        for (int i = 0; i < 16; i++) begin
            fork
                wait (!empty_rx_fifo_B);
                begin
                    repeat (50) @(posedge clk_system);
                    $error("Timeout: !empty_rx_fifo_B did not assert within 50 cycles (idx %0d).", i);
                    $finish;
                end
            join_any
            disable fork;
            @(posedge clk_system);
            if (SpW_Packet_RX_B === ref_buf[i])
                $display("OK  [%0d]: received = %x", i, SpW_Packet_RX_B);
            else begin
                $error("MISMATCH [%0d]: expected = %x | received = %x", i, ref_buf[i], SpW_Packet_RX_B);
                $finish;
            end
            SpW_Packet_RX_en_B = 1;
            @(posedge clk_system);
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


        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        enable_disconnect_A_to_B = 0;
        enable_parity_err_A_to_B = 1;
        data_test = 9'b0_0100_1111;
        $display("SpW Data Loaded (A -> B) : %x\n", data_test);
        send_packet_A(data_test); // TODO não tem o check pq vai ser enviado errado

        data_test = 9'b0_1111_0000;
        $display("Wait error parity B");
        send_packet_A(data_test);
        wait_parity_err_B();

        repeat (10) @(posedge clk_system); // TODO para teste, ver como isso tem que ficar depois
        enable_disconnect_A_to_B = 0;
        enable_parity_err_A_to_B = 0;

        $display("\n\nWaiting for SpW Uplink to Connect");

        wait(dut_codec_A.run_state && dut_codec_B.run_state);
        $display("SpW Uplink Connected !\n");
        
        // load Tx data to send and  wait for valid data to appear on SpW Rx output
        enable_disconnect_A_to_B = 1;
        enable_parity_err_A_to_B = 0;
        data_test = 9'b0_0101_1110;
        $display("Wait disconnect A to B",);
        send_packet_A(data_test);
        wait_disconnect_A_to_B();

        $display(">>>>>>>>>>>> TEST OK");
        $finish;
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
                    repeat (50) @(posedge clk_system);
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
                    repeat (50) @(posedge clk_system);
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
                    repeat (50) @(posedge clk_system);
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
                    repeat (50) @(posedge clk_system);
                    $error("Timeout: Time_Code_RX_valid_A did not arrive within 50 cycles.");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask

    task automatic wait_disconnect_A_to_B();
        fork
            begin
                @(posedge dut_codec_A.disconnect);
                $display("Disconnect detectado.");
            end
            begin
                #(DISCONNECT_TIMEOUT_NS * 2);
                $error("Timeout: disconnect não detectado.");
            end
        join_any
        disable fork;
    endtask

    task automatic wait_parity_err_B();
        fork
            begin
                @(posedge dut_codec_B.parity_err);
                $display("parity_err detectado em %0t.", $time);
            end
            begin
                #(DISCONNECT_TIMEOUT_NS * 2);
                $error("Timeout: parity_err não detectado.");
            end
        join_any
        disable fork;
    endtask

    task automatic send_packet_A(input [8:0] data);
        begin
            wait(!full_tx_fifo_A);
            @(posedge clk_system);
            SpW_Packet_TX_A = data;
            SpW_Packet_TX_en_A = 1;
            Time_Code_TX_valid_A  = 0;

            @(posedge clk_system);
            SpW_Packet_TX_en_A = 0;
        end
    endtask

    task automatic send_packet_B(input [8:0] data);
        begin
            wait(!full_tx_fifo_B);
            @(posedge clk_system);
            SpW_Packet_TX_B = data;
            SpW_Packet_TX_en_B = 1;
            Time_Code_TX_valid_B  = 0;

            @(posedge clk_system);
            SpW_Packet_TX_en_B = 0;
        end
    endtask


    task automatic send_tc_A(input [7:0] data);
        begin
            @(posedge clk_system);
            Time_Code_TX_A        = data;
            Time_Code_TX_valid_A  = 1;
            SpW_Packet_TX_en_A = 0;

            @(posedge clk_system);
            Time_Code_TX_valid_A  = 0;
        end
    endtask


    task automatic send_tc_B(input [7:0] data);
        begin
            @(posedge clk_system);
            Time_Code_TX_B        = data;
            Time_Code_TX_valid_B  = 1;
            SpW_Packet_TX_en_B = 0;

            @(posedge clk_system);
            Time_Code_TX_valid_B  = 0;
        end
    endtask

    task automatic send_A_to_B_and_check(input [8:0] data);
        begin
            send_packet_A(data);
            wait_rx_valid_B();
            @(posedge clk_system);
            check_rx(data, SpW_Packet_RX_B, "A->B");
            SpW_Packet_RX_en_B = 1;
            @(posedge clk_system);
            SpW_Packet_RX_en_B = 0;
        end
    endtask

    task automatic send_B_to_A_and_check(input [8:0] data);
        begin
            send_packet_B(data);
            wait_rx_valid_A();
            @(posedge clk_system);
            check_rx(data, SpW_Packet_RX_A, "B->A");
            SpW_Packet_RX_en_A = 1;
            @(posedge clk_system);
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
