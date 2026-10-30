module RMAP (
    input logic clk,
    input logic rst_n,

    input logic [7:0] rx_data,
    input logic rx_valid,
    output logic [7:0] tx_data,
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

    logic [8:0] cnt_rst;
    localparam logic [8:0] REG_BASE_ADDR = 9'h100; 
    localparam logic [8:0] REG_END_ADDR  = 9'h10A; // 0x109 + 1

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
    logic reg_detect_zero_src_path_addr;
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

    always_comb begin
        next_state = state;
        crc_data_in = rx_data;
        reg_bank_w_en = 1'b0;
        reg_bank_w_addr = 9'h0;
        reg_bank_r_en = 1'b0;
        reg_bank_r_addr = 9'h0;
        tx_data = 8'h00;
        tx_valid = 1'b0;

        case (state)
            RST_STATE: begin
                if (cnt_rst == REG_END_ADDR) begin
                    next_state = IDLE;
                end
            end

            IDLE: begin
                if (rx_valid) begin
                    if (rx_data == 8'hfe) begin
                        next_state = PROTOCOL_ID;
                    end else begin
                        next_state = ERROR_STATE; //TODO arrumar depois
                    end
                end
            end

            PROTOCOL_ID: begin
                if (rx_valid) begin
                    if (rx_data == 8'h01) begin
                        next_state = COMMAND_BYTE;
                    end else begin
                        next_state = ERROR_STATE; //TODO arrumar depois
                    end
                end
            end

            COMMAND_BYTE: begin
                if (rx_valid) begin
                    next_state = DESTINATION_KEY;
                    reg_bank_r_addr =  REG_BASE_ADDR + 9'd9;
                    reg_bank_r_en = 1'b1;
                end
            end

            DESTINATION_KEY: begin // TODO aqui pode ter um erro se não vir no ciclo seguinte
                if (rx_valid) begin
                    if (reg_bank_r_data == {24'h0, rx_data}) begin
                        if (reg_src_path_addr_len == 2'b00) next_state = SRC_LOGICAL_ADDRESS;
                        else next_state = SRC_PATH_ADDRESS;
                    end else begin
                        next_state = ERROR_STATE; //TODO arrumar depois
                    end
                end
            end


            SRC_PATH_ADDRESS: begin
                if (rx_valid) begin
                    if (reg_detect_zero_src_path_addr & (~(|rx_data))) begin
                        next_state = ERROR_STATE; //TODO arrumar depois
                    end else if (cnt_src_path_addr == reg_src_path_addr_len) begin
                        next_state = SRC_LOGICAL_ADDRESS;
                    end
                end
            end

            SRC_LOGICAL_ADDRESS: begin
                if (rx_valid) begin
                    next_state = TRANSACTION_ID_MS;
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
                    if (rx_data == 8'h00) begin
                        next_state = TARGET_ADDRESS;
                    end else begin
                        next_state = ERROR_STATE; //TODO arrumar depois
                    end
                end
            end

            TARGET_ADDRESS: begin
                if (cnt_target_addr == 3'b100) begin
                    next_state = DATA_LENGTH; // TODO acho que é necessário uma verificação se o endereço é válido, se os 2 bytes mais significativos são '0
                end
            end

            DATA_LENGTH: begin
                if (cnt_data_len == 2'b11) begin
                    case (reg_command)
                        CMD_READ_SINGLE: begin
                            if (data_len == 24'h004) next_state = HEADER_CRC; 
                            else next_state = ERROR_STATE; //TODO arrumar depois
                        end

                        CMD_READ_INC: begin
                            if (24'h004 <= data_len && data_len <= 24'h428 && data_len[1:0] == 2'b00) next_state = HEADER_CRC; 
                            else next_state = ERROR_STATE; //TODO arrumar depois
                        end

                        CMD_READ_MODIFY_WRITE: begin
                            if (data_len == 24'h008) next_state = HEADER_CRC; 
                            else next_state = ERROR_STATE; //TODO arrumar depois
                        end

                        CMD_WRITE: begin
                            if (data_len == 24'h004) next_state = HEADER_CRC; 
                            else next_state = ERROR_STATE; //TODO arrumar depois
                        end
                    endcase
                end
            end

            HEADER_CRC: begin
                if (rx_valid) begin
                    if (rx_data == crc_reg) begin // TODO verificar se seria isso mesmo para verificar
                        case (reg_command)
                            CMD_READ_SINGLE: next_state = EOP_STATE; 
                            CMD_READ_INC: next_state = EOP_STATE; 
                            CMD_READ_MODIFY_WRITE: next_state = DATA_STATE; 
                            CMD_WRITE: next_state = DATA_STATE; 
                        endcase
                    end else begin
                        next_state = ERROR_STATE; //TODO arrumar depois
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
                if (rx_data == crc_next) begin // TODO verificar se seria isso mesmo para verificar
                    next_state = EOP_STATE;
                end else begin
                    next_state = ERROR_STATE; //TODO arrumar depois
                end
            end

            EOP_STATE: begin // TODO incompleto, não esquever de verificar se de fato chega um EOP
                if (rx_valid) begin
                    if (rx_data == 8'h04) next_state = IDLE; //TODO verificar a codificação do EOP
                    else next_state = ERROR_STATE;
                end
            end

            ERROR_STATE: begin
                next_state = ERROR_STATE;
            end

            default: next_state = IDLE;
        endcase
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
            reg_detect_zero_src_path_addr <= '0;
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
            if (~rx_valid) crc_reg <= crc_next;

            case (state)
                RST_STATE: begin
                    init_busy <= 1'b1;
                    cnt_rst <= cnt_rst + 9'h001;
                end

                IDLE: begin
                    cnt_src_path_addr <= '0;
                    reg_detect_zero_src_path_addr <= '0;
                    cnt_target_addr <= '0;
                    target_addr <= '0;
                    crc_reg <= 8'h00;
                    cnt_data_len <= 8'h00;
                    cnt_data <= '0;
                    cnt_mask <= '0;
                end

                PROTOCOL_ID: begin
                end

                COMMAND_BYTE: begin
                    {reg_packet_type, reg_command, reg_src_path_addr_len} <= {rx_data, 2'b00};
                end

                SRC_PATH_ADDRESS: begin
                    if (rx_valid) begin
                        reg_detect_zero_src_path_addr <= reg_detect_zero_src_path_addr ? 1'b1 : ~(|rx_data);
                        cnt_src_path_addr = cnt_src_path_addr + 1;
                        bank_src_path_addr[cnt_src_path_addr] = rx_data;
                    end
                end 

                SRC_LOGICAL_ADDRESS: begin
                    if (rx_valid) begin
                        reg_src_logical_addr <= rx_data;
                    end
                end
                TRANSACTION_ID_MS: begin
                    if (rx_valid) begin 
                        transaction_id[15:8] <= rx_data;
                    end
                end

                TRANSACTION_ID_LS: begin
                    if (rx_valid) begin
                        transaction_id[7:0] <= rx_data;
                    end
                end

                TARGET_ADDRESS: begin
                    if (rx_valid) begin
                        cnt_target_addr <= cnt_target_addr + 1;
                        target_addr <= {target_addr[23:0], rx_data};
                    end
                end 

                DATA_LENGTH: begin
                    if (rx_valid) begin
                        cnt_data_len <= cnt_data_len + 1;
                        data_len <= {data_len[15:0], rx_data};
                    end
                end 

                HEADER_CRC: begin
                    crc_reg <= 8'h00;
                end

                DATA_STATE: begin
                    if (rx_valid) begin
                        cnt_data <= cnt_data + 1;
                        data_write <= {data_write[23:0], rx_data};
                    end
                end

                MASK_STATE: begin
                    if (rx_valid) begin
                        cnt_mask <= cnt_mask + 1;
                        mask_write <= {mask_write[23:0], rx_data};
                    end
                end

                EOP_STATE: begin
                    crc_reg <= '0;
                end
            endcase
        end
    end

endmodule
