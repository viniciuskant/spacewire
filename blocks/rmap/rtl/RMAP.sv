module RMAP (
    input logic clk,
    input logic rst_n,

    input logic [8:0] rx_data,
    input logic rx_valid,
    output logic [8:0] tx_data,
    output logic tx_valid,

    output logic [31:0] reg_bank_w_data,
    output logic [8:0] reg_bank_w_addr,
    output logic reg_bank_w_en,

    input logic [31:0] reg_bank_r_data,
    output logic [8:0] reg_bank_r_addr,
    output logic reg_bank_r_en,

    output logic busy
);

    logic [8:0] rx_data_reg;
    logic rx_valid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg  <= '0;
            rx_valid_reg <= '0;
        end else begin
            rx_data_reg  <= rx_data;
            rx_valid_reg <= rx_valid;
        end
    end

    localparam logic [3:0] CMD_READ_SINGLE = 4'b0010;
    localparam logic [3:0] CMD_READ_INC = 4'b0011;
    localparam logic [3:0] CMD_READ_MODIFY_WRITE = 4'b0111;
    localparam logic [3:0] CMD_WRITE = 4'b1110;

    localparam logic [8:0] EEP_PACKET = 9'h101;
    localparam logic [8:0] EOP_PACKET = 9'h102;

    logic [8:0] cnt_rst;
    localparam logic [8:0] REG_BASE_ADDR = 9'h100; 
    localparam logic [8:0] REG_END_ADDR = 9'h10A; // 0x109 + 1

    localparam logic [31:0] REG_BASE_ADDR_32 = 32'h0000_0000; // all registers
    localparam logic [31:0] REG_END_ADDR_32 = 32'h0000_0109; 

    localparam logic [31:0] ADDR_NETWORK_DISCOVERY = 32'h0000_0100;
    localparam logic [31:0] ADDR_ROUTER_IDENTITY = 32'h0000_0101;
    localparam logic [31:0] ADDR_ROUTER_CONTROL = 32'h0000_0102;
    localparam logic [31:0] ADDR_ERROR_ACTIVE = 32'h0000_0103;
    localparam logic [31:0] ADDR_TIME_CODE = 32'h0000_0104;
    localparam logic [31:0] ADDR_DEVICE_MANUFACTURER_ID = 32'h0000_0105;
    localparam logic [31:0] ADDR_GENERAL_PURPOSE = 32'h0000_0106;
    localparam logic [31:0] ADDR_TIME_CODE_ENABLE = 32'h0000_0107;
    localparam logic [31:0] ADDR_CLOCK_CONTROL = 32'h0000_0108;
    localparam logic [31:0] ADDR_DESTINATION_KEY = 32'h0000_0109;

    localparam logic [31:0] NETWORK_DISCOVERY_REGISTER = 32'h0000_0000;
    localparam logic [31:0] ROUTER_IDENTITY_REGISTER = 32'h0000_0000;
    localparam logic [31:0] ROUTER_CONTROL_REGISTER = 32'h0000_0000;
    localparam logic [31:0] ERROR_ACTIVE_REGISTER = 32'h0000_0000;
    localparam logic [31:0] TIME_CODE_REGISTER = 32'h0000_0000;
    localparam logic [31:0] DEVICE_MANUFACTURER_ID_REGISTER = 32'h0000_0000;
    localparam logic [31:0] GENERAL_PURPOSE_REGISTER = 32'h0000_0000;
    localparam logic [31:0] TIME_CODE_ENABLE_REGISTER = 32'h0000_0000;
    localparam logic [31:0] CLOCK_CONTROL_REGISTER = 32'h0000_0000;
    localparam logic [31:0] DESTINATION_KEY_REGISTER = 32'h0000_00AA; // TODO verificar o valor

    logic [7:0] bank_src_path_addr [0:11]; // TODO pensar se poderia haver uma sobrescrita
    logic [31:0] reg_bank_r_data_reg;



    typedef enum logic [5:0] {
        RX_RST_STATE,
        RX_IDLE,
        RX_PROTOCOL_ID,
        RX_COMMAND_BYTE,
        RX_DESTINATION_KEY,
        RX_SRC_PATH_ADDRESS,
        RX_SRC_LOGICAL_ADDRESS,
        RX_TRANSACTION_ID_MS,
        RX_TRANSACTION_ID_LS,
        RX_EXTENDED_ADDRESS, // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 8'h00
        RX_TARGET_ADDRESS,  // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 4 bytes
        RX_DATA_LENGTH, // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 3 bytes
        RX_HEADER_CRC,
        RX_DATA_CRC,
        RX_DATA_STATE,
        RX_MASK_STATE,
        RX_EOP_STATE,


        TX_SRC_PATH_ADDRESS,
        TX_SRC_LOGICAL_ADDRESS,
        TX_PROTOCOL_ID,
        TX_COMMAND_BYTE,
        TX_STATUS_STATE,
        TX_DESTINATION_LOGICAL_ADDRESS,
        TX_TRANSACTION_ID_MS,
        TX_TRANSACTION_ID_LS,
        TX_RESERVED,
        TX_DATA_LENGTH_MS,
        TX_DATA_LENGTH,
        TX_DATA_LENGTH_LS,
        TX_HEADER_CRC,
        TX_DATA_STATE,
        TX_DATA_CRC,
        TX_EOP_STATE,
        TX_COMMAND_RMW_READ_STATE,
        TX_COMMAND_RMW_MODIFY_WRITE_STATE,
        TX_COMMAND_RMW_STATE,
        TX_REPLY_CRC
    } state_t;

    state_t state, next_state;

    logic [7:0] rx_crc_reg;
    logic [7:0] rx_crc_next;
    logic [7:0] rx_crc_data_in;
    logic rx_crc_valid;

    rmap_crc8 rx_crc_inst (
        .clk(clk),
        .crc_in(rx_crc_reg),
        .data_in(rx_crc_data_in),
        .crc_out(rx_crc_next),
        .valid(rx_crc_valid)
    );

    logic [7:0] tx_crc_reg;
    logic [7:0] tx_crc_next;
    logic [7:0] tx_crc_data_in;

    rmap_crc8 tx_crc_inst (
        .clk(clk),
        .crc_in(tx_crc_reg),
        .data_in(tx_crc_data_in),
        .crc_out(tx_crc_next),
        .valid(tx_valid)
    );
    

    logic [1:0] rx_reg_packet_type;
    logic [3:0] rx_reg_command;
    logic [3:0] rx_reg_src_path_addr_len, rx_cnt_src_path_addr, rx_src_path_valid_len;
    logic rx_src_path_addr_zero_detected;
    logic rx_src_path_addr_nonzero_detected;
    logic [7:0] rx_reg_src_logical_addr, tx_reg_src_logical_addr;
    logic [15:0] rx_transaction_id;
    logic [31:0] rx_target_addr;
    logic [1:0] rx_cnt_target_addr;

    logic [23:0] rx_data_len;
    logic [1:0] rx_cnt_data_len;

    logic [31:0] rx_data_write;
    logic [31:0] rx_mask_write;
    logic [1:0] rx_cnt_data;
    logic [1:0] rx_cnt_mask;

    logic rx_error_detect;
    logic [3:0] rx_error_code, rx_error_code_reg;


    logic tx_reg_bank_r_en;
    logic [8:0] tx_reg_bank_r_addr;

    logic [3:0] tx_cnt_src_path_addr;
    logic [3:0] tx_reg_src_path_addr_valid_len;
    logic [3:0] tx_reg_src_path_addr_len;
    logic [15:0] tx_transaction_id;
    logic [3:0] tx_status;
    logic [23:0] tx_data_len;
    logic [23:0] tx_data_words;
    logic [3:0] tx_reg_command;
    logic [23:0] tx_cnt_data;
    logic [1:0] tx_cnt_data_byte;

    logic [31:0] tx_reg_rmw_data;
    logic no_reply_packet, no_reply_packet_reg;

    always_comb begin
        next_state = state;
        rx_crc_data_in = rx_data[7:0];
        reg_bank_w_en = 1'b0;
        reg_bank_w_addr = 9'h0;
        reg_bank_w_data = 32'h0;
        rx_error_code = '0;
        tx_crc_data_in = tx_data[7:0];
        reg_bank_r_addr = tx_reg_bank_r_addr;
        reg_bank_r_en = tx_reg_bank_r_en;
        rx_crc_valid = rx_valid_reg;
        busy = 1'b0;
        tx_valid = 1'b0;
        rx_error_detect = 1'b0;
        no_reply_packet = 1'b0;

        case (state)
            RX_RST_STATE: begin
                busy = 1'b1;

                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else begin
                    if (cnt_rst == REG_END_ADDR) begin
                        next_state = RX_IDLE;
                    end
                    reg_bank_w_addr = cnt_rst;
                    reg_bank_w_en = 1'b1;
                    case (cnt_rst)
                        REG_BASE_ADDR + 9'd0: reg_bank_w_data = NETWORK_DISCOVERY_REGISTER;
                        REG_BASE_ADDR + 9'd1: reg_bank_w_data = ROUTER_IDENTITY_REGISTER;
                        REG_BASE_ADDR + 9'd2: reg_bank_w_data = ROUTER_CONTROL_REGISTER;
                        REG_BASE_ADDR + 9'd3: reg_bank_w_data = ERROR_ACTIVE_REGISTER;
                        REG_BASE_ADDR + 9'd4: reg_bank_w_data = TIME_CODE_REGISTER;
                        REG_BASE_ADDR + 9'd5: reg_bank_w_data = DEVICE_MANUFACTURER_ID_REGISTER;
                        REG_BASE_ADDR + 9'd6: reg_bank_w_data = GENERAL_PURPOSE_REGISTER;
                        REG_BASE_ADDR + 9'd7: reg_bank_w_data = TIME_CODE_ENABLE_REGISTER;
                        REG_BASE_ADDR + 9'd8: reg_bank_w_data = CLOCK_CONTROL_REGISTER;
                        REG_BASE_ADDR + 9'd9: reg_bank_w_data = DESTINATION_KEY_REGISTER;
                        default: reg_bank_w_data = 32'h0;
                    endcase
                end
            end

            RX_IDLE: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg == 9'h0fe) begin
                        next_state = RX_PROTOCOL_ID;
                    end else begin
                        // next_state = RX_EOP_STATE;
                        next_state = RX_PROTOCOL_ID;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'hC; // Invalid Destination Logical Address
                    end
                end
            end

            RX_PROTOCOL_ID: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg == 9'h001) begin
                        next_state = RX_COMMAND_BYTE;
                    end else begin // Error -> but no Reply Packet
                        next_state = RX_EOP_STATE; 
                        no_reply_packet = 1;
                    end
                end
            end

            RX_COMMAND_BYTE: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg[7:6] != 2'b01) begin
                        reg_bank_r_addr = ADDR_DESTINATION_KEY;
                        reg_bank_r_en = 1'b1;
                        next_state = RX_DESTINATION_KEY;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'h2; // Unused packet type
                    end else begin
                        case (rx_data_reg[5:2])
                            CMD_READ_SINGLE, 
                            CMD_READ_INC, 
                            CMD_READ_MODIFY_WRITE: begin
                                reg_bank_r_addr = ADDR_DESTINATION_KEY;
                                reg_bank_r_en = 1'b1;
                                next_state = RX_DESTINATION_KEY;
                            end
                            CMD_WRITE: begin
                                reg_bank_r_addr = ADDR_DESTINATION_KEY;
                                reg_bank_r_en = 1'b1;
                                next_state = RX_DESTINATION_KEY;
                                if (rx_data_reg[1:0] != 2'b01) begin
                                    rx_error_code = 4'h9; // Verify Buffer Overrun
                                    rx_error_detect = 1'b1;
                                end
                            end

                            4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1111: begin
                                reg_bank_r_addr = ADDR_DESTINATION_KEY;
                                reg_bank_r_en = 1'b1;
                                next_state = RX_DESTINATION_KEY;
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'hA; // RMAP Command not implemented or not authorised
                            end

                            default: begin
                                reg_bank_r_addr = ADDR_DESTINATION_KEY;
                                reg_bank_r_en = 1'b1;
                                next_state = RX_DESTINATION_KEY;
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'h2; // Unused RMAP command
                            end
                        endcase
                    end
                end
            end

            RX_DESTINATION_KEY: begin // TODO aqui pode ter um erro se não vir no ciclo seguinte
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (reg_bank_r_data == {24'h0, rx_data_reg[7:0]}) begin
                        if (rx_reg_src_path_addr_len == 2'b00) next_state = RX_SRC_LOGICAL_ADDRESS;
                        else next_state = RX_SRC_PATH_ADDRESS;
                    end else begin
                        if (rx_reg_src_path_addr_len == 2'b00) next_state = RX_SRC_LOGICAL_ADDRESS;
                        else next_state = RX_SRC_PATH_ADDRESS;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'h3; // Invalid Destination Key
                    end
                end
            end


            RX_SRC_PATH_ADDRESS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if ( (!rx_src_path_addr_nonzero_detected && (!(|rx_data_reg)) && (rx_cnt_src_path_addr == (0))) ||
                        (rx_src_path_addr_zero_detected && (|rx_data_reg)) ) begin
                        next_state = RX_EOP_STATE; // Error -> but no Reply Packet
                        no_reply_packet = 1;
                    end 
                    else if (rx_cnt_src_path_addr == (rx_reg_src_path_addr_len - 1)) begin
                        next_state = RX_SRC_LOGICAL_ADDRESS;
                    end
                end
            end

            RX_SRC_LOGICAL_ADDRESS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (8'h20 <= rx_data_reg[7:0] && rx_data_reg[7:0] <= 8'hff) begin
                        next_state = RX_TRANSACTION_ID_MS;
                    end else begin // Error -> but no Reply Packet
                        next_state = RX_EOP_STATE;
                        no_reply_packet = 1;
                    end
                end
            end

            RX_TRANSACTION_ID_MS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    next_state = RX_TRANSACTION_ID_LS;
                end
            end

            RX_TRANSACTION_ID_LS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_error_code_reg != 0) begin
                    next_state = RX_EOP_STATE;
                end else if (rx_valid_reg) begin
                    next_state = RX_EXTENDED_ADDRESS;
                end
            end

            RX_EXTENDED_ADDRESS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg[7:0] == 8'h00) begin
                        next_state = RX_TARGET_ADDRESS;
                    end else begin
                        next_state = RX_EOP_STATE; //TODO arrumar depois
                    end
                end
            end

            RX_TARGET_ADDRESS: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg && rx_cnt_target_addr == 2'b11) begin
                    if ({rx_target_addr[23:0], rx_data_reg} < REG_BASE_ADDR_32 || {rx_target_addr[23:0], rx_data_reg} > REG_END_ADDR_32) begin
                        next_state = RX_EOP_STATE;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'hA; //RMAP Command not implemented or not authorised
                    end else if ((rx_reg_command == CMD_WRITE || rx_reg_command == CMD_READ_MODIFY_WRITE) && 
                            ({rx_target_addr[23:0], rx_data_reg} == ADDR_NETWORK_DISCOVERY || 
                            {rx_target_addr[23:0], rx_data_reg} == ADDR_ROUTER_IDENTITY || 
                            {rx_target_addr[23:0], rx_data_reg} == ADDR_DEVICE_MANUFACTURER_ID)) begin // reg READ-ONLY
                        next_state = RX_EOP_STATE;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'hA; // RMAP Command not implemented or not authorised
                    end else begin
                        next_state = RX_DATA_LENGTH; 
                    end
                end
            end

            RX_DATA_LENGTH: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_cnt_data_len == 2'b10) begin
                    case (rx_reg_command)
                        CMD_READ_SINGLE: begin
                            if ({rx_data_len[15:0], rx_data_reg[7:0]} == 24'h004) begin
                                next_state = RX_HEADER_CRC; 
                            end else begin
                                next_state = RX_EOP_STATE; 
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'hA; // Invalid Data Length
                            end
                        end

                        CMD_READ_INC: begin
                            if (24'h004 <= {rx_data_len[15:0], rx_data_reg[7:0]} && {rx_data_len[15:0], rx_data_reg[7:0]} <= 24'h428 && rx_data_reg[1:0] == 2'b00) begin
                                next_state = RX_HEADER_CRC; 
                            end else begin
                                next_state = RX_EOP_STATE; 
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'hA; // Invalid Data Length
                            end
                        end

                        CMD_READ_MODIFY_WRITE: begin
                            if ({rx_data_len[15:0], rx_data_reg[7:0]} == 24'h008) begin
                                next_state = RX_HEADER_CRC; 
                            end else begin
                                next_state = RX_EOP_STATE; 
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'hB; //RMW Data Length Error
                            end
                        end

                        CMD_WRITE: begin
                            if ({rx_data_len[15:0], rx_data_reg[7:0]} == 24'h004) begin
                                next_state = RX_HEADER_CRC; 
                            end else begin
                                next_state = RX_EOP_STATE;
                                rx_error_detect = 1'b1;
                                rx_error_code = 4'hA; // Verify Buffer Overrun
                            end
                        end
                    endcase
                end
            end

            RX_HEADER_CRC: begin
                rx_crc_valid = 0;
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg[7:0] == rx_crc_next) begin
                        case (rx_reg_command)
                            CMD_READ_SINGLE: next_state = RX_EOP_STATE; 
                            CMD_READ_INC: next_state = RX_EOP_STATE; 
                            CMD_READ_MODIFY_WRITE: next_state = RX_DATA_STATE; 
                            CMD_WRITE: next_state = RX_DATA_STATE; 
                        endcase
                    end else begin // Error -> but no Reply Packet
                        next_state = RX_EOP_STATE;
                        no_reply_packet = 1;
                    end
                end
            end

            RX_DATA_STATE: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_cnt_data == 2'b11) begin
                    case (rx_reg_command)
                        CMD_READ_MODIFY_WRITE: next_state = RX_MASK_STATE; 
                        CMD_WRITE: next_state = RX_DATA_CRC;
                    endcase
                end
            end

            RX_MASK_STATE: begin
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_cnt_mask == 2'b11) begin
                    next_state = RX_DATA_CRC; 
                end
            end

            RX_DATA_CRC: begin
                rx_crc_valid = 0;
                if (rx_valid_reg && (rx_data_reg == EOP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h5;
                end else if (rx_valid_reg && (rx_data_reg == EEP_PACKET)) begin
                    rx_error_detect = 1'b1;
                    rx_error_code = 4'h7;
                end else if (rx_valid_reg) begin
                    if (rx_data_reg[7:0] == rx_crc_next) begin
                        next_state = RX_EOP_STATE;
                    end else begin
                        next_state = RX_EOP_STATE;
                        rx_error_detect = 1'b1;
                        rx_error_code = 4'h4; // Invalid Data CRC
                    end
                end
            end

            RX_EOP_STATE: begin // TODO incompleto, não esquever de verificar se de fato chega um EOP
                if (rx_valid_reg) begin
                    if (rx_error_code_reg == '0) begin
                        rx_error_code = 4'h0;
                        if (rx_data_reg == EOP_PACKET) begin
                            if (rx_src_path_valid_len == '0) next_state = TX_SRC_LOGICAL_ADDRESS;
                            else next_state = TX_SRC_PATH_ADDRESS;
                            rx_error_code = 4'h0;
                        end else if (!no_reply_packet_reg) begin 
                            if (rx_src_path_valid_len == '0) next_state = TX_SRC_LOGICAL_ADDRESS;
                            else next_state = TX_SRC_PATH_ADDRESS;
                            rx_error_detect = 1'b1;
                            rx_error_code = 4'h6; // Cargo too large
                        end
                    end else begin
                        if (rx_valid_reg) begin
                            if (rx_data_reg == EOP_PACKET) begin
                                if (rx_src_path_valid_len == '0) next_state = TX_SRC_LOGICAL_ADDRESS;
                                else next_state = TX_SRC_PATH_ADDRESS;
                                rx_error_code = 4'h0;
                            end
                        end
                    end
                end
            end



            // ####################### TX #######################

            TX_SRC_PATH_ADDRESS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, bank_src_path_addr[tx_cnt_src_path_addr]};
                if (tx_cnt_src_path_addr == tx_reg_src_path_addr_valid_len - 1) next_state = TX_SRC_LOGICAL_ADDRESS;
            end

            TX_SRC_LOGICAL_ADDRESS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, tx_reg_src_logical_addr};
                next_state = TX_PROTOCOL_ID;
            end

            TX_PROTOCOL_ID: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = 8'h01;
                next_state = TX_COMMAND_BYTE;
            end

            TX_COMMAND_BYTE: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, 2'b00, tx_reg_command, tx_reg_src_path_addr_len[3:2]};
                next_state = TX_STATUS_STATE;
            end

            TX_STATUS_STATE: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {4'h0, tx_status};
                next_state = TX_DESTINATION_LOGICAL_ADDRESS;
            end

            TX_DESTINATION_LOGICAL_ADDRESS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = 9'h0fe;
                next_state = TX_TRANSACTION_ID_MS;
            end

            TX_TRANSACTION_ID_MS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = tx_transaction_id[15:8];
                next_state = TX_TRANSACTION_ID_LS;
            end

            TX_TRANSACTION_ID_LS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = tx_transaction_id[7:0];
                if (tx_status == '0)
                    case(tx_reg_command)
                        CMD_READ_SINGLE: next_state = TX_RESERVED; 
                        CMD_READ_INC: next_state = TX_RESERVED; 
                        CMD_READ_MODIFY_WRITE: next_state = TX_RESERVED; 
                        CMD_WRITE: next_state = TX_REPLY_CRC; 
                    endcase
                else begin // TODO tratamento de erro, não sei se está correto
                    next_state = TX_REPLY_CRC; 
                end
            end 

            TX_RESERVED: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = '0;
                next_state = TX_DATA_LENGTH_MS;
            end

            TX_DATA_LENGTH_MS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = tx_data_len[23:16];
                next_state = TX_DATA_LENGTH;
            end

            TX_DATA_LENGTH: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = tx_data_len[15:8];
                next_state = TX_DATA_LENGTH_LS;
            end

            TX_DATA_LENGTH_LS: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = tx_data_len[7:0];
                next_state = TX_HEADER_CRC;
            end

            TX_HEADER_CRC: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, tx_crc_reg};
                case(tx_reg_command)
                    CMD_READ_SINGLE: begin
                        next_state = TX_DATA_STATE; 
                        tx_reg_bank_r_en = 1'b1;
                    end
                    CMD_READ_INC: begin
                        next_state = TX_DATA_STATE; 
                        tx_reg_bank_r_en = 1'b1;
                    end
                    CMD_READ_MODIFY_WRITE: begin
                        reg_bank_r_addr = tx_reg_bank_r_addr;
                        reg_bank_r_en = 1'b1;
                        next_state = TX_COMMAND_RMW_STATE; 
                    end
                    default: next_state = TX_EOP_STATE;
                endcase
            end


            TX_COMMAND_RMW_STATE: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                case (tx_cnt_data_byte) 
                    2'b00: begin
                        reg_bank_w_addr = tx_reg_bank_r_addr;
                        reg_bank_w_en = 1'b1;
                        reg_bank_w_data = (rx_mask_write & rx_data_write) | ((~rx_mask_write) & reg_bank_r_data);

                        tx_data = {1'b0, reg_bank_r_data[31:24]};
                    end
                    2'b01: tx_data = {1'b0, tx_reg_rmw_data[23:16]};
                    2'b10: tx_data = {1'b0, tx_reg_rmw_data[15:8]};
                    2'b11: tx_data = {1'b0, tx_reg_rmw_data[7:0]};
                endcase
                if (tx_cnt_data == tx_data_words - 1 && tx_cnt_data_byte == 2'b11) begin
                    next_state = TX_DATA_CRC;
                end
            end

            TX_DATA_STATE: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                case (tx_cnt_data_byte) 
                    2'b00: tx_data = {1'b0, reg_bank_r_data[31:24]};
                    2'b01: tx_data = {1'b0, reg_bank_r_data_reg[23:16]};
                    2'b10: tx_data = {1'b0, reg_bank_r_data_reg[15:8]};
                    2'b11: tx_data = {1'b0, reg_bank_r_data_reg[7:0]};
                endcase
                if (tx_cnt_data == tx_data_words - 1 && tx_cnt_data_byte == 2'b11) begin
                    next_state = TX_DATA_CRC;
                end else if (tx_cnt_data_byte == 2'b11) begin
                    tx_reg_bank_r_en = 1'b1;
                end else begin
                    tx_reg_bank_r_en = 1'b0; // Desativa após pedir
                end
            end

            TX_DATA_CRC: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, tx_crc_reg};
                next_state = TX_EOP_STATE;
            end

            TX_REPLY_CRC: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = {1'b0, tx_crc_reg};
                reg_bank_w_addr = tx_reg_bank_r_addr;
                reg_bank_w_en = 1'b1;
                reg_bank_w_data = rx_data_write;
                next_state = TX_EOP_STATE;
            end 

            TX_EOP_STATE: begin
                busy = 1'b1;
                tx_valid = 1'b1;
                tx_data = EOP_PACKET;
                next_state = RX_IDLE;
            end

            default: next_state = RX_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RX_RST_STATE;
            rx_crc_reg <= 8'h00;
            rx_src_path_addr_zero_detected <= '0;
            rx_src_path_addr_nonzero_detected <= '0;
            cnt_rst <= REG_BASE_ADDR;
            rx_cnt_src_path_addr <= '0;
            rx_src_path_valid_len <= '0;
            rx_cnt_target_addr <= '0;
            rx_target_addr <= '0;
            rx_cnt_data_len <= 8'h00;
            rx_cnt_data <= '0;
            rx_cnt_mask <= '0;

            tx_crc_reg <= '0;
            tx_reg_bank_r_addr <= '0;

            tx_reg_rmw_data <= '0;
        end else begin

            state <= next_state;

            // para preservar o primeiro erro detectado
            if (no_reply_packet) no_reply_packet_reg <= 1;
            if (rx_error_detect && rx_error_code_reg == '0) rx_error_code_reg <= rx_error_code;

            if (rx_valid_reg) rx_crc_reg <= rx_crc_next;
            if (tx_valid) tx_crc_reg <= tx_crc_next;

            case (state)
                RX_RST_STATE: begin
                    cnt_rst <= cnt_rst + 9'h001;
                    rx_crc_reg <= 8'h00;
                end

                RX_IDLE: begin
                    rx_error_code_reg <= rx_error_detect ? rx_error_code : '0;
                    rx_src_path_valid_len <= '0;
                    rx_cnt_src_path_addr <= '0;
                    rx_src_path_addr_zero_detected <= '0;
                    rx_src_path_addr_nonzero_detected <= '0;
                    rx_cnt_target_addr <= '0;
                    rx_target_addr <= '0;
                    rx_data_len <= '0;
                    rx_cnt_data_len <= 8'h00;
                    rx_cnt_data <= '0;
                    rx_cnt_mask <= '0;
                    no_reply_packet_reg <= '0;
                end

                RX_PROTOCOL_ID: begin
                end

                RX_COMMAND_BYTE: begin
                    {rx_reg_packet_type, rx_reg_command, rx_reg_src_path_addr_len} <= {rx_data_reg[7:0], 2'b00};
                end

                RX_SRC_PATH_ADDRESS: begin
                    if (rx_valid) begin
                        if (|rx_data_reg) begin
                            rx_src_path_addr_nonzero_detected <= 1'b1;
                        end

                        if ((!|rx_data_reg)) begin
                            rx_src_path_addr_zero_detected <= 1'b1;
                        end

                        if ((|rx_data_reg) && !rx_src_path_addr_zero_detected) begin
                            bank_src_path_addr[rx_src_path_valid_len] <= rx_data_reg[7:0];
                            rx_src_path_valid_len <= rx_src_path_valid_len + 1'b1; 
                        end
                        
                        rx_cnt_src_path_addr <= rx_cnt_src_path_addr + 1'b1;
                    end
                end 

                RX_SRC_LOGICAL_ADDRESS: begin
                    if (rx_valid) begin
                        rx_reg_src_logical_addr <= rx_data_reg[7:0];
                    end
                end

                RX_TRANSACTION_ID_MS: begin
                    if (rx_valid) begin 
                        rx_transaction_id[15:8] <= rx_data_reg[7:0];
                    end
                end

                RX_TRANSACTION_ID_LS: begin
                    if (rx_valid) begin
                        rx_transaction_id[7:0] <= rx_data_reg[7:0];
                    end
                end

                RX_TARGET_ADDRESS: begin
                    if (rx_valid) begin
                        rx_cnt_target_addr <= rx_cnt_target_addr + 1;
                        rx_target_addr <= {rx_target_addr[23:0], rx_data_reg[7:0]};
                    end
                end 

                RX_DATA_LENGTH: begin
                    if (rx_valid) begin
                        rx_cnt_data_len <= rx_cnt_data_len + 1;
                        rx_data_len <= {rx_data_len[15:0], rx_data_reg[7:0]};
                    end
                end 

                RX_HEADER_CRC: begin
                    rx_crc_reg <= 8'h00;
                end

                RX_DATA_STATE: begin
                    if (rx_valid) begin
                        rx_cnt_data <= rx_cnt_data + 1;
                        rx_data_write <= {rx_data_write[23:0], rx_data_reg[7:0]};
                    end
                end

                RX_MASK_STATE: begin
                    if (rx_valid) begin
                        rx_cnt_mask <= rx_cnt_mask + 1;
                        rx_mask_write <= {rx_mask_write[23:0], rx_data_reg[7:0]};
                    end
                end

                RX_EOP_STATE: begin
                    rx_crc_reg <= '0;
                    tx_cnt_data <= '0;
                    tx_cnt_data_byte <= '0;
                    tx_cnt_src_path_addr <= '0;
                    tx_crc_reg <= '0;

                    tx_reg_src_logical_addr <= rx_reg_src_logical_addr;
                    tx_reg_src_path_addr_valid_len <= rx_src_path_valid_len;
                    tx_reg_src_path_addr_len <= rx_reg_src_path_addr_len;
                    tx_transaction_id <= rx_transaction_id;
                    tx_status <= (rx_error_detect == 1'b1 && rx_error_code_reg == '0)? 4'h6: rx_error_code_reg;
                    if (rx_reg_command == CMD_READ_MODIFY_WRITE) begin
                        tx_data_len <= 24'h000004;
                        tx_data_words <= 24'h000001;
                    end else begin
                        tx_data_len <= rx_data_len;
                        tx_data_words <= {2'b00, rx_data_len[23:2]};
                    end
                    tx_reg_command <= rx_reg_command;
                    tx_reg_bank_r_addr <= rx_target_addr[10:2]; 
                end

                // ####################### TX #######################


                TX_SRC_PATH_ADDRESS: begin
                    if (tx_cnt_src_path_addr < tx_reg_src_path_addr_valid_len) begin
                        tx_cnt_src_path_addr <= tx_cnt_src_path_addr + 1;
                    end
                end

                TX_HEADER_CRC: begin
                    tx_crc_reg <= 8'h00;
                    if (tx_reg_command == CMD_READ_SINGLE || tx_reg_command == CMD_READ_INC) begin
                            tx_reg_bank_r_addr = tx_reg_bank_r_addr + 1;
                    end else if  (tx_reg_command == CMD_READ_MODIFY_WRITE) begin
                        tx_cnt_data_byte <= '0; // Reseta o contador de bytes
                        tx_cnt_data <= '0;
                        tx_reg_rmw_data <= reg_bank_r_data;
                    end
                end

                TX_DATA_STATE: begin
                    tx_cnt_data_byte <= tx_cnt_data_byte + 1;
                    if (tx_cnt_data_byte == 2'b11) begin
                        tx_cnt_data <= tx_cnt_data + 1;
                        tx_reg_bank_r_addr <= tx_reg_bank_r_addr + 9'b1;
                    end else if (tx_cnt_data_byte == 2'b00) begin
                        reg_bank_r_data_reg <= reg_bank_r_data;
                    end
                end

                TX_COMMAND_RMW_STATE: begin
                    if (tx_cnt_data_byte == 2'b11) begin
                        tx_cnt_data_byte <= '0;
                        tx_cnt_data <= tx_cnt_data + 1;
                    end else begin
                        tx_cnt_data_byte <= tx_cnt_data_byte + 1;
                    end
                end

            endcase
        end
    end

endmodule
