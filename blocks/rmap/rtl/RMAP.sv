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

    output logic init_busy
);

    typedef enum logic [3:0] {
        CMD_READ_SINGLE = 4'b0010,
        CMD_READ_INC = 4'b0011,
        CMD_READ_MODIFY_WRITE = 4'b0111,
        CMD_WRITE = 4'b1110
    } command_t;

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

    typedef enum logic [4:0] {
        RST_STATE,
        IDLE,
        PROTOCOL_ID,
        COMMAND_BYTE,
        DESTINATION_KEY,
        SRC_PATH_ADDRESS,
        SRC_LOGICAL_ADDRESS,
        TRANSACTION_ID_MS,
        TRANSACTION_ID_LS,
        EXTENDED_ADDRESS, // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 8'h00
        TARGET_ADDRESS,  // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 4 bytes
        DATA_LENGTH, // vou usar para os 4 comandos, pois todos nesse ponto tem que receber 3 bytes
        HEADER_CRC,
        DATA_CRC,
        EOP_STATE,
        DATA_STATE,
        MASK_STATE,
        ERROR_STATE // TODO falta as respostas
    } state_t;

    state_t state, next_state;

    logic [7:0] crc_reg;
    logic [7:0] crc_next;
    logic [7:0] crc_data_in;

    rmap_crc8 crc_inst (
        .clk(clk),
        .crc_in(crc_reg),
        .data_in(crc_data_in),
        .crc_out(crc_next),
        .valid(rx_valid)
    );
    

    logic [1:0] reg_packet_type;
    logic [3:0] reg_command;
    logic [3:0] reg_src_path_addr_len, cnt_src_path_addr;
    logic [7:0] bank_src_path_addr [0:11];
    logic src_path_addr_zero_detected;
    logic src_path_addr_nonzero_detected;
    logic [7:0] reg_src_logical_addr;
    logic [15:0] transaction_id;
    logic [31:0] target_addr;
    logic [2:0] cnt_target_addr;

    logic [23:0] data_len;
    logic [1:0] cnt_data_len;

    logic [31:0] data_write;
    logic [31:0] mask_write;
    logic [2:0] cnt_data;
    logic [2:0] cnt_mask;

    logic [3:0] error_code, error_code_reg;

    always_comb begin
        next_state = state;
        crc_data_in = rx_data[7:0];
        reg_bank_w_en = 1'b0;
        reg_bank_w_addr = 9'h0;
        reg_bank_r_en = 1'b0;
        reg_bank_r_addr = 9'h0;
        tx_data = 8'h00;
        tx_valid = 1'b0;
        error_code = '0;

        if (rx_valid && (rx_data == EOP_PACKET) && (state != EOP_STATE)) begin
            next_state = ERROR_STATE;
            error_code = 4'h5; //Early EOP
        end else if (rx_valid && (rx_data == EEP_PACKET)) begin // TODO não sei se deveria ter algum estado específico
            next_state = ERROR_STATE;
            error_code = 4'h7; //Early EEP
        end else begin
            case (state)
                RST_STATE: begin
                    if (cnt_rst == REG_END_ADDR) begin
                        next_state = IDLE;
                    end
                end

                IDLE: begin
                    if (rx_valid) begin
                        if (rx_data == 9'h0fe) begin
                            next_state = PROTOCOL_ID;
                        end else begin
                            next_state = ERROR_STATE;
                            error_code = 4'hC; // Invalid Destination Logical Address
                        end
                    end
                end

                PROTOCOL_ID: begin
                    if (rx_valid) begin
                        if (rx_data == 9'h001) begin
                            next_state = COMMAND_BYTE;
                        end else begin // Error -> but no Reply Packet
                            next_state = EOP_STATE; 
                        end
                    end
                end

                COMMAND_BYTE: begin
                    if (rx_valid) begin
                        if (rx_data[7:6] != 2'b01) begin
                            next_state = ERROR_STATE;
                            error_code = 4'h2; // Unused packet type
                        end else begin
                            case (rx_data[5:2])
                                CMD_READ_SINGLE, 
                                CMD_READ_INC, 
                                CMD_READ_MODIFY_WRITE, 
                                CMD_WRITE: begin
                                    next_state = DESTINATION_KEY;
                                    reg_bank_r_addr = REG_BASE_ADDR + 9'd9;
                                    reg_bank_r_en = 1'b1;
                                end

                                4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1111: begin
                                    next_state = ERROR_STATE;
                                    error_code = 4'h3; // RMAP Command not implemented or not authorised
                                end

                                default: begin
                                    next_state = ERROR_STATE;
                                    error_code = 4'h2; // Unused RMAP command
                                end
                            endcase
                        end
                    end
                end

                DESTINATION_KEY: begin // TODO aqui pode ter um erro se não vir no ciclo seguinte
                    if (rx_valid) begin
                        if (reg_bank_r_data == {24'h0, rx_data[7:0]}) begin
                            if (reg_src_path_addr_len == 2'b00) next_state = SRC_LOGICAL_ADDRESS;
                            else next_state = SRC_PATH_ADDRESS;
                        end else begin
                            next_state = ERROR_STATE;
                            error_code = 4'h3; // Invalid Destination Key
                        end
                    end
                end


                SRC_PATH_ADDRESS: begin
                    if (rx_valid) begin
                        if ( (!src_path_addr_nonzero_detected && (!(|rx_data)) && (cnt_src_path_addr == reg_src_path_addr_len)) ||
                            (src_path_addr_nonzero_detected && (!(|rx_data))) ) begin
                            next_state = EOP_STATE; // Error -> but no Reply Packet
                        end 
                        else if (cnt_src_path_addr == reg_src_path_addr_len) begin
                            next_state = SRC_LOGICAL_ADDRESS;
                        end
                    end
                end

                SRC_LOGICAL_ADDRESS: begin
                    if (rx_valid) begin
                        if (8'h20 <= rx_data[7:0] && rx_data[7:0] <= 8'hff) begin
                            next_state = TRANSACTION_ID_MS;
                        end else begin // Error -> but no Reply Packet
                            next_state = EOP_STATE;
                        end
                    end
                end

                TRANSACTION_ID_MS: begin
                    if (rx_valid) begin
                        next_state = TRANSACTION_ID_LS;
                    end
                end

                TRANSACTION_ID_LS: begin
                    if (rx_valid) begin
                        next_state = EXTENDED_ADDRESS;
                    end
                end

                EXTENDED_ADDRESS: begin
                    if (rx_valid) begin
                        if (rx_data[7:0] == 8'h00) begin
                            next_state = TARGET_ADDRESS;
                        end else begin
                            next_state = ERROR_STATE; //TODO arrumar depois
                        end
                    end
                end

                TARGET_ADDRESS: begin
                    if (rx_valid && cnt_target_addr == 3'b100) begin
                        if (target_addr < REG_BASE_ADDR_32 || target_addr > REG_END_ADDR_32) begin
                            next_state = ERROR_STATE;
                            error_code = 4'hA; //RMAP Command not implemented or not authorised
                        end else if ((reg_command == CMD_WRITE || reg_command == CMD_READ_MODIFY_WRITE) && 
                                (target_addr == ADDR_NETWORK_DISCOVERY || 
                                target_addr == ADDR_ROUTER_IDENTITY || 
                                target_addr == ADDR_DEVICE_MANUFACTURER_ID)) begin // reg READ-ONLY
                            next_state = ERROR_STATE;
                            error_code = 4'hA; // RMAP Command not implemented or not authorised
                        end else begin
                            next_state = DATA_LENGTH; 
                        end
                    end
                end

                DATA_LENGTH: begin
                    if (cnt_data_len == 2'b10) begin
                        case (reg_command)
                            CMD_READ_SINGLE: begin
                                if (data_len == 24'h004) begin
                                    next_state = HEADER_CRC; 
                                end else begin
                                    next_state = ERROR_STATE; 
                                    error_code = 4'hA; // Invalid Data Length
                                end
                            end

                            CMD_READ_INC: begin
                                if (24'h004 <= data_len && data_len <= 24'h428 && data_len[1:0] == 2'b00) begin
                                    next_state = HEADER_CRC; 
                                end else begin
                                    next_state = ERROR_STATE; 
                                    error_code = 4'hA; // Invalid Data Length
                                end
                            end

                            CMD_READ_MODIFY_WRITE: begin
                                if (data_len == 24'h008) begin
                                    next_state = HEADER_CRC; 
                                end else begin
                                    next_state = ERROR_STATE; 
                                    error_code = 4'hB; //RMW Data Length Error
                                end
                            end

                            CMD_WRITE: begin
                                if (data_len == 24'h004) begin
                                    next_state = HEADER_CRC; 
                                end else begin
                                    next_state = ERROR_STATE;
                                    error_code = 4'h9; // Verify Buffer Overrun
                                end
                            end
                        endcase
                    end
                end

                HEADER_CRC: begin
                    if (rx_valid) begin
                        if (rx_data[7:0] == crc_reg) begin
                            case (reg_command)
                                CMD_READ_SINGLE: next_state = EOP_STATE; 
                                CMD_READ_INC: next_state = EOP_STATE; 
                                CMD_READ_MODIFY_WRITE: next_state = DATA_STATE; 
                                CMD_WRITE: next_state = DATA_STATE; 
                            endcase
                        end else begin // Error -> but no Reply Packet
                            next_state = EOP_STATE;
                        end
                    end
                end

                DATA_STATE: begin
                    if (cnt_data == 3'b100) begin
                        case (reg_command)
                            CMD_READ_MODIFY_WRITE: next_state = MASK_STATE; 
                            CMD_WRITE: next_state = DATA_CRC;
                        endcase
                    end
                end

                MASK_STATE: begin
                    if (cnt_mask == 3'b100) begin
                        next_state = DATA_CRC; 
                    end
                end

                DATA_CRC: begin
                    if (rx_data[7:0] == crc_next) begin // TODO verificar se seria isso mesmo para verificar
                        next_state = EOP_STATE;
                    end else begin
                        next_state = ERROR_STATE;
                        error_code = 4'h4; // Invalid Data CRC
                    end
                end

                EOP_STATE: begin // TODO incompleto, não esquever de verificar se de fato chega um EOP
                    if (rx_valid) begin
                        if (rx_data == EOP_PACKET) begin
                            next_state = IDLE;
                        end else begin 
                            next_state = ERROR_STATE;
                            error_code = 4'h6; // Cargo too large
                        end
                    end
                end

                ERROR_STATE: begin
                    next_state = ERROR_STATE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    always_comb begin
        reg_bank_w_data = 32'h0;
        reg_bank_w_addr = 9'h0;
        reg_bank_w_en = 1'b0;
        next_state = state;

        case (state)
            RST_STATE: begin
                
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

            default: begin
                reg_bank_w_data = '0;
                reg_bank_w_addr = '0;
                reg_bank_w_en = '0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RST_STATE;
            crc_reg <= 8'h00;
            src_path_addr_zero_detected <= '0;
            cnt_rst <= '0;
            init_busy <= 1'b1;
            cnt_src_path_addr <= '0;
            cnt_target_addr <= '0;
            target_addr <= '0;
            cnt_data_len <= 8'h00;
            cnt_data <= '0;
            cnt_mask <= '0;
        end else begin

            state <= next_state;
            init_busy <= 1'b0;
            if (~rx_valid) begin
                crc_reg <= crc_next;
                error_code_reg <= error_code;
            end 

            case (state)
                RST_STATE: begin
                    init_busy <= 1'b1;
                    cnt_rst <= cnt_rst + 9'h001;
                end

                IDLE: begin
                    cnt_src_path_addr <= '0;
                    src_path_addr_zero_detected <= '0;
                    src_path_addr_nonzero_detected <= '0;
                    cnt_target_addr <= '0;
                    target_addr <= '0;
                    crc_reg <= 8'h00;
                    data_len <= '0;
                    cnt_data_len <= 8'h00;
                    cnt_data <= '0;
                    cnt_mask <= '0;
                end

                PROTOCOL_ID: begin
                end

                COMMAND_BYTE: begin
                    {reg_packet_type, reg_command, reg_src_path_addr_len} <= {rx_data[7:0], 2'b00};
                end

                SRC_PATH_ADDRESS: begin
                    if (rx_valid) begin
                        if (|rx_data) begin
                            src_path_addr_nonzero_detected <= 1'b1;
                        end

                        if (src_path_addr_nonzero_detected || (|rx_data)) begin
                            bank_src_path_addr[cnt_src_path_addr] <= rx_data[7:0];
                        end
                        cnt_src_path_addr <= cnt_src_path_addr + 1;
                    end
                end 

                SRC_LOGICAL_ADDRESS: begin
                    if (rx_valid) begin
                        reg_src_logical_addr <= rx_data[7:0];
                    end
                end

                TRANSACTION_ID_MS: begin
                    if (rx_valid) begin 
                        transaction_id[15:8] <= rx_data[7:0];
                    end
                end

                TRANSACTION_ID_LS: begin
                    if (rx_valid) begin
                        transaction_id[7:0] <= rx_data[7:0];
                    end
                end

                TARGET_ADDRESS: begin
                    if (rx_valid) begin
                        cnt_target_addr <= cnt_target_addr + 1;
                        target_addr <= {target_addr[23:0], rx_data[7:0]};
                    end
                end 

                DATA_LENGTH: begin
                    if (rx_valid) begin
                        cnt_data_len <= cnt_data_len + 1;
                        data_len <= {data_len[15:0], rx_data[7:0]};
                    end
                end 

                HEADER_CRC: begin
                    crc_reg <= 8'h00;
                end

                DATA_STATE: begin
                    if (rx_valid) begin
                        cnt_data <= cnt_data + 1;
                        data_write <= {data_write[23:0], rx_data[7:0]};
                    end
                end

                MASK_STATE: begin
                    if (rx_valid) begin
                        cnt_mask <= cnt_mask + 1;
                        mask_write <= {mask_write[23:0], rx_data[7:0]};
                    end
                end

                EOP_STATE: begin
                    crc_reg <= '0;
                end
            endcase
        end
    end

endmodule
