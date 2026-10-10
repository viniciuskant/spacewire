`timescale 1ns/1ps

module tb_rx_char;

    // parametros
    //   ref_rx_clk : 200 MHz (5 ns)
    //   rx_clk : 20 MHz (50 ns)
    //   bit period : rx_clk / 2 = 25 ns (duas bordas)

    localparam REF_PERIOD = 5;
    localparam RX_DIV = 11;
    localparam MAX_CHARS = 32;

    logic ref_rx_clk = 1;
    logic rx_clk = 0;
    logic rst_n = 0;

    always #(REF_PERIOD/2) ref_rx_clk = ~ref_rx_clk; // 200 MHz

    // Divisor: rx_clk a cada RX_DIV ciclos de ref
    logic [2:0] rx_div_cnt;
    always @(posedge ref_rx_clk) begin
        if (rx_div_cnt == RX_DIV - 1) begin
            rx_div_cnt <= 0;
            rx_clk <= ~rx_clk;
        end else begin
            rx_div_cnt <= rx_div_cnt + 1;
        end
    end

    // dut
    logic bit_valid_i = 0;
    logic bit_i = 0;
    logic [9:0] data_o;
    logic data_valid_o;
    logic parity_err_o;
    logic escape_err_o;

    rx_char dut (
        .ref_rx_clk (ref_rx_clk),
        .rst_n (rst_n),
        .bit_valid_i (bit_valid_i),
        .bit_i (bit_i),
        .data_o (data_o),
        .data_valid_o (data_valid_o),
        .parity_err_o (parity_err_o),
        .escape_err_o (escape_err_o)
    );

    //buffer de caracteres
    localparam logic [2:0]
        CH_DATA     = 3'd0,
        CH_FCT      = 3'd1,
        CH_EOP      = 3'd2,
        CH_EEP      = 3'd3,
        CH_NULL     = 3'd4,
        CH_TIMECODE = 3'd5;

    logic [2:0] tx_type    [0:MAX_CHARS-1];
    logic [7:0] tx_payload [0:MAX_CHARS-1];
    int tx_count;

    // Buffer de bits serializado
    logic bit_stream [0:4096];
    int bit_count;

    // converte um char_t em sequência de bits (inclui paridade)
    // P = ~(data ^ F_next)
    function automatic int encode_char(input logic [2:0] t, input logic [7:0] payload, input logic next_flag, output logic [15:0] bits);
        logic p;
        bits = '0;

        case (t)
            // DATA : [P F D0..D7] (10 bits)
            CH_DATA: begin
                p = ~(1'b0 ^ (^payload) ^ next_flag);
                bits[9:0] = {payload, 1'b0, p};
                return 10;
            end

            // FCT: [P F 0 0] (4 bits)
            CH_FCT: begin
                p = ~((^3'b001) ^ next_flag);
                bits[3:0] = {3'b001, p};
                return 4;
            end

            // EOP: [P F 1 0] (4 bits)
            CH_EOP: begin
                p = ~((^3'b101) ^ next_flag);
                bits[3:0] = {3'b101, p};
                return 4;
            end

            // EEP: [P F 0 1] (4 bits)
            CH_EEP: begin
                p = ~((^3'b011) ^ next_flag);
                bits[3:0] = {3'b011, p};
                return 4;
            end

            // NULL: ESC + FCT (8 bits)
            CH_NULL: begin
                p = ~((^7'b0010111) ^ next_flag);
                bits[7:0] = {7'b0010111, p};
                return 8;
            end

            // TIMECODE: ESC + 10 bits (14 total)
            CH_TIMECODE: begin
                p = ~((^payload) ^ (^5'b01111) ^ next_flag);
                bits[13:0] = {payload, 5'b01111, p};
                return 14;
            end

            default: return 0;
        endcase
    endfunction

    //serializa a fila em um bit_stream
    task automatic build_bit_stream();
        logic [15:0] bits;
        int n;
        logic next_flag;
        bit_count = 0;
        for (int i = 0; i < tx_count; i++) begin
            if (i + 1 < tx_count)
                next_flag = (tx_type[i+1] == CH_DATA) ? 1'b0 : 1'b1;
            else
                next_flag = 1'b0;
            n = encode_char(tx_type[i], tx_payload[i], next_flag, bits);
            for (int k = 0; k < n; k++) begin
                bit_stream[bit_count] = bits[k];
                bit_count++;
            end
        end
    endtask


    // envia o bit_stream: 1 bit por período, alinhado ao edge de rx_clk
    task automatic send_bit_stream();
        for (int i = 0; i < bit_count; i++) begin
            @(posedge ref_rx_clk);
            bit_i <= bit_stream[i];
            bit_valid_i <= 1'b1;
            @(posedge ref_rx_clk);
            bit_valid_i <= 1'b0;
            repeat (RX_DIV - 2) @(posedge ref_rx_clk);
        end
    endtask

    int data_count = 0;
    int fct_count = 0;
    int eep_count = 0;
    int eop_count = 0;
    int null_count = 0;
    int tc_count = 0;

    localparam logic [1:0] T_DATA = 2'b00,
                          T_CTRL = 2'b01,
                          T_NULL = 2'b10,
                          T_TC   = 2'b11;

    localparam logic [1:0] C_FCT = 2'b00,
                          C_EEP = 2'b01,
                          C_EOP = 2'b10;

    always @(posedge ref_rx_clk) begin
        if (data_valid_o) begin
            case (data_o[1:0])

                T_DATA: begin
                    data_count++;
                    $display("[%0t] DATA : data=0x%02X (data_o=0b%b)",
                             $time, data_o[9:2], data_o);
                end

                T_CTRL: begin
                    case (data_o[3:2])
                        C_FCT: begin
                            fct_count++;
                            $display("[%0t] GOT FCT", $time);
                        end
                        C_EEP: begin
                            eep_count++;
                            $display("[%0t] GOT EEP", $time);
                        end
                        C_EOP: begin
                            eop_count++;
                            $display("[%0t] GOT EOP", $time);
                        end
                        default: begin
                            $error("[%0t] *** FAIL: subtype de controle inválido = %b ***",
                                   $time, data_o[3:2]);
                        end
                    endcase
                end

                T_NULL: begin
                    null_count++;
                    $display("[%0t] GOT NULL", $time);
                end

                T_TC: begin
                    tc_count++;
                    $display("[%0t] TCODE : 0x%02X", $time, data_o[9:2]);
                end

            endcase
        end
    end

    int i;
    int exp_data = 0;
    int exp_tc = 0;
    int exp_null = 0;
    int exp_fct  = 0;
    int exp_eop = 0;
    int exp_eep = 0;

    initial begin
        $dumpfile("waves/tb_rx_char.vcd");
        $dumpvars(0, tb_rx_char);

        // fila de transmissão
        tx_type[0]  = CH_FCT;      tx_payload[0]  = 8'h00;
        tx_type[1]  = CH_DATA;     tx_payload[1]  = 8'h11;
        tx_type[2]  = CH_TIMECODE; tx_payload[2]  = 8'h22;
        tx_type[3]  = CH_DATA;     tx_payload[3]  = 8'h5A;
        tx_type[4]  = CH_DATA;     tx_payload[4]  = 8'hAA;
        tx_type[5]  = CH_EEP;      tx_payload[5]  = 8'h00;
        tx_type[6]  = CH_DATA;     tx_payload[6]  = 8'h55;
        tx_type[7]  = CH_TIMECODE; tx_payload[7]  = 8'h88;
        tx_type[8]  = CH_EOP;      tx_payload[8]  = 8'h00;
        tx_type[9]  = CH_NULL;     tx_payload[9]  = 8'h00;
        tx_type[10] = CH_NULL;     tx_payload[10] = 8'h00;

        tx_type[11] = CH_DATA;     tx_payload[11] = 8'hFF;
        tx_type[12] = CH_DATA;     tx_payload[12] = 8'h00;
        tx_type[13] = CH_DATA;     tx_payload[13] = 8'hAA;
        tx_type[14] = CH_DATA;     tx_payload[14] = 8'h55;
        tx_type[15] = CH_TIMECODE; tx_payload[15] = 8'h3C;
        tx_type[16] = CH_DATA;     tx_payload[16] = 8'hF0;
        tx_type[17] = CH_DATA;     tx_payload[17] = 8'h0F;
        tx_type[18] = CH_FCT;      tx_payload[18] = 8'h00;
        tx_type[19] = CH_DATA;     tx_payload[19] = 8'hCC;
        tx_type[20] = CH_DATA;     tx_payload[20] = 8'h33;
        tx_type[21] = CH_NULL;     tx_payload[21] = 8'h00;
        tx_type[22] = CH_DATA;     tx_payload[22] = 8'hA5;
        tx_type[23] = CH_TIMECODE; tx_payload[23] = 8'h5A;
        tx_type[24] = CH_DATA;     tx_payload[24] = 8'h96;
        tx_type[25] = CH_DATA;     tx_payload[25] = 8'h69;
        tx_type[26] = CH_EEP;      tx_payload[26] = 8'h00;
        tx_type[27] = CH_DATA;     tx_payload[27] = 8'h81;
        tx_type[28] = CH_DATA;     tx_payload[28] = 8'h7E;
        tx_type[29] = CH_EOP;      tx_payload[29] = 8'h00;
        tx_type[30] = CH_NULL;     tx_payload[30] = 8'h00;
        tx_count = 31;
    
        for (i = 0; i < tx_count; i++) begin
            case (tx_type[i])
                CH_DATA:     exp_data++;
                CH_TIMECODE: exp_tc++;
                CH_NULL:     exp_null++;
                CH_FCT:      exp_fct++;
                CH_EOP:      exp_eop++;
                CH_EEP:      exp_eep++;
            endcase
        end

        repeat (10) @(posedge ref_rx_clk);
        rst_n = 1;
        repeat (5)  @(posedge ref_rx_clk);

        build_bit_stream();
        $display("Sending %0d bits", bit_count);

        send_bit_stream();

        repeat (50) @(posedge ref_rx_clk);

        $display("RESULTS");
        $display("Data chars  : %0d (expected %0d)", data_count, exp_data);
        $display("Timecodes   : %0d (expected %0d)", tc_count,   exp_tc);
        $display("NULL Counter: %0d (expected %0d)", null_count, exp_null);
        $display("FCT Counter : %0d (expected %0d)", fct_count,  exp_fct);
        $display("EOP Counter : %0d (expected %0d)", eop_count,  exp_eop);
        $display("EEP Counter : %0d (expected %0d)", eep_count,  exp_eep);

        if (data_count !== exp_data || tc_count   !== exp_tc ||
            null_count !== exp_null || fct_count  !== exp_fct ||
            eop_count  !== exp_eop  || eep_count  !== exp_eep) begin
            $display("*** FAIL ***");
            $fatal(1);
        end

        $display("\n\n*** PASS ***");

        $finish;
    end

    initial begin
        #15000;
        $display("[%0t] *** TIMEOUT ***", $time);
        $finish;
    end

    always @(posedge parity_err_o) begin
        $error("[%0t] *** FAIL: PARITY ERROR ***", $time);
    end

    always @(posedge escape_err_o) begin
        $error("[%0t] *** FAIL: ESCAPE ERROR ***", $time);
    end


endmodule
