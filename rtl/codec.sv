module codec #(
    parameter int DEPTH_FIFO = 64,
    parameter int DATA_WIDTH_FIFO = 9,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int REF_TX_FREQ_HZ = 200_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850,
    parameter int DSIZE = 10,
    parameter int ASIZE = 4
)(
    input clk_system, // máquina de estados 50 MHz
    input clk_ref_tx, // referência do tx 200 MHz
    input [7:0] div_counter_tx,

    input rst_n,

    input S_in,
    input D_in,
    output S_out,
    output D_out,

    //matrix de roteamento
    input [8:0] SpW_Packet_TX, 
    input SpW_Packet_TX_en,
    output full_tx_fifo,
    output [8:0] SpW_Packet_RX,
    input SpW_Packet_RX_en,
    output empty_rx_fifo,

    // timecode
    input [7:0] Time_Code_TX,
    input Time_Code_TX_valid,
    output [7:0] Time_Code_RX,
    output Time_Code_RX_valid
);

    localparam int DIV_10MHz = (REF_TX_FREQ_HZ / (2*CLK_FREQ));

    logic clk_tx;
    logic [7:0] limit_counter_tx;
    assign limit_counter_tx = run_state ? div_counter_tx : DIV_10MHz;

    var_clk_divider u_var_clk_divider (
        .clk(clk_ref_tx),
        .rst_n(rst_n),
        .new_limit(limit_counter_tx),
        .clk_out(clk_tx)
    );

    logic [8:0] wr_data_fifo_rx, rd_data_fifo_tx, rd_data_fifo_tx_temp;
    logic wr_en_fifo_rx, rd_en_fifo_tx, rd_en_fifo_tx_temp, empty_tx_fifo, empty_tx_fifo_temp;

    logic credit_err;
    logic [$clog2(DEPTH_FIFO+1)-1:0] free_slots_fifo_rx, free_slots_fifo_tx;


    rx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) u_rx_fifo (
        .wr_clk_i(clk_system),
        .rd_clk_i(clk_system), //TODO verificar se o clock da fifo é o clock do sistema
        .rst_n(rst_n),

        .wr_data_i(wr_data_fifo_rx),
        .wr_en_i(wr_en_fifo_rx),

        // saída do módulo
        .rd_en_i(SpW_Packet_RX_en),
        .rd_data_o(SpW_Packet_RX),
        .empty_o(empty_rx_fifo),
        .free_space_o(free_slots_fifo_rx)
    );

    assign credit_err = (free_slots_fifo_rx == '0) & wr_en_fifo_rx;
    assign full_tx_fifo = free_slots_fifo_tx == '0;

    rx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) u_tx_fifo (
        .wr_clk_i(clk_system),
        .rd_clk_i(clk_tx),
        .rst_n(rst_n), // TODO ver a questão de cdc

        .wr_data_i(SpW_Packet_TX),
        .wr_en_i(SpW_Packet_TX_en),

        .rd_en_i(rd_en_fifo_tx_temp),
        .rd_data_o(rd_data_fifo_tx_temp),
        .empty_o(empty_tx_fifo_temp),
        .free_space_o(free_slots_fifo_tx)
    );

    // Módulo para lisar com os erros, colocando EEP no final e esvaziando até o EOP
    // TODO verificar se isso pode dar conflito se o EOP estiver muito longo

    error_cleanup_fsm u_error_cleanup_fsm (
        .clk_system (clk_system),
        .clk_tx (clk_tx),
        .rst_n (rst_n),
        .run_state (run_state),
        .rx_Error (rx_Error),
        .disconnect (disconnect),
        .credit_err (credit_err),
        .rd_en_fifo_tx (rd_en_fifo_tx),
        .empty_tx_fifo_temp (empty_tx_fifo_temp),
        .rd_data_fifo_tx_temp (rd_data_fifo_tx_temp),
        .rd_data_fifo_tx (rd_data_fifo_tx),
        .rd_en_fifo_tx_temp (rd_en_fifo_tx_temp),
        .empty_tx_fifo (empty_tx_fifo)
    );

    logic run_state;
    logic got_data, got_fct, got_eop, got_eep, got_null, got_timecode;

    logic [7:0] payload;
    logic sending_allowed;
    logic send_fct, send_fct_fc, send_fct_sm;
    assign send_fct = send_fct_fc | send_fct_sm;

    logic rst_n_rx, rst_n_tx;

    flow_control #(.DEPTH_FIFO(DEPTH_FIFO)) u_fc(
        .clk(clk_system),
        .rst_n(rst_n & rst_n_rx & rst_n_tx), // TODO falta arrumar aqui para ele funcionar com o rst da máquina de estado quadno rst o tx eo rx
        .run_state(run_state),
        .en_out_fifo_tx(!empty_tx_fifo_temp & rd_data_fifo_tx),
        .got_FCT_rx(got_fct),
        .sending_allowed(sending_allowed),
        .en_in_fifo_rx(wr_en_fifo_rx),
        .free_slots_fifo_rx(free_slots_fifo_rx),
        .send_FCT(send_fct_fc)
    );

    logic got_bit;
    logic rx_Error, parity_err, escape_err;
    assign rx_Error = escape_err | parity_err;

    logic en_rx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic en_tx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic send_null;
    logic disconnect, start_link;
    assign start_link = 1; // TODO verificar o que seria essa start_link, mas creio
                           // que seja um sinal externo para controle de quandoa ativar o rx

    state_machine #(.CLK_FREQ(SYS_CLK_FREQ_HZ))u_sm( // a máquina de estados roda em clk_system
        .clk(clk_system),
        .rst_n(rst_n),

        // RX
        .en_rx(en_rx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_rx(rst_n_rx),
        .got_bit(got_bit),
        .got_FCT(got_fct),
        .got_null(got_null),
        .got_TimeCode(got_timecode),
        .got_N_Char(got_data),
        .rx_Error(rx_Error),

        // TX
        .en_tx(en_tx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_tx(rst_n_tx),
        .send_FCT(send_fct_sm),
        .send_Null(send_null),

        // FSM
        .disconnect(disconnect),
        .start_link(start_link),
        .run_state(run_state)
    );

    logic [9:0] wr_data_fifo_sync, rd_data_fifo_sync;
    logic wr_en_fifo_sync, rd_en_fifo_sync, rd_empty_fifo_sync;
    logic got_bit_clk_ref_tx, parity_err_clk_ref_tx, escape_err_clk_ref_tx;

    rx u_rx (
        .clk(clk_ref_tx),
        .rst_n(rst_n_rx),
        .D_in(D_in),
        .S_in(S_in),
        .data_o(wr_data_fifo_sync),
        .data_valid_o(wr_en_fifo_sync),
        .got_bit_o(got_bit_clk_ref_tx),
        .parity_err_o(parity_err_clk_ref_tx),
        .escape_err_o(escape_err_clk_ref_tx)
    );

    cdc_sync #(.STAGES(2)) u_got_bit_sync (
        .clk(clk_system),
        .d(got_bit_clk_ref_tx),
        .q(got_bit)
    );

    cdc_sync #(.STAGES(2)) u_parity_err_sync (
        .clk(clk_system),
        .d(parity_err_clk_ref_tx),
        .q(parity_err)
    );

    cdc_sync #(.STAGES(2)) u_escape_err_sync (
        .clk(clk_system),
        .d(escape_err_clk_ref_tx),
        .q(escape_err)
    );

    logic [1:0] wrst_n_sync_ff;
    logic  wrst_n_sync;

    logic rst_n_rx_final;
    assign rst_n_rx_final = rst_n & rst_n_rx;

    always_ff @(posedge clk_ref_tx or negedge rst_n_rx_final) begin
        if (!rst_n)
            wrst_n_sync_ff <= 2'b00;
        else
            wrst_n_sync_ff <= {wrst_n_sync_ff[0], 1'b1};
    end

    assign wrst_n_sync = wrst_n_sync_ff[1];

    fifo1 #(.DSIZE(DSIZE), .ASIZE(ASIZE)) u_fifo_sync_rx(  
        .wfull(), // TODO colocar isso no teste, se der alto sinalizar erro
        .rempty(rd_empty_fifo_sync),
        .wdata(wr_data_fifo_sync),
        .winc(wr_en_fifo_sync), 
        .wclk(clk_ref_tx),
        .wrst_n(wrst_n_sync),
        .rdata(rd_data_fifo_sync),
        .rinc(rd_en_fifo_sync),
        .rclk(clk_system),
        .rrst_n(rst_n)
    );

    localparam int unsigned DISCONNECT_TIMEOUT_CYCLES =
        int'((longint'(DISCONNECT_TIMEOUT_NS) * longint'(SYS_CLK_FREQ_HZ)) / 1_000_000_000);

    localparam int CNT_WIDTH = $clog2(DISCONNECT_TIMEOUT_CYCLES + 1);

    logic [CNT_WIDTH-1:0]  disconnect_cnt;

    always_ff @(posedge clk_system or negedge rst_n) begin
        if (!rst_n) begin
            disconnect_cnt <= '0;
            disconnect     <= 1'b0;
        end
        else if (!run_state) begin
            disconnect_cnt <= '0;
            disconnect     <= 1'b0;
        end
        else begin
            disconnect <= 1'b0;
            if (got_bit) begin
                disconnect_cnt <= '0;
            end
            else if (disconnect_cnt == (DISCONNECT_TIMEOUT_CYCLES - 1)) begin
                disconnect     <= 1'b1;
                disconnect_cnt <= '0;
            end
            else begin
                disconnect_cnt <= disconnect_cnt + 1'b1;
            end
        end
    end


    // decode
    spw_char_decode u_spw_char_decode(
        .clk_system(clk_system),
        .rst_n(rst_n),
        .rd_data_fifo_sync(rd_data_fifo_sync),
        .rd_en_fifo_sync(rd_en_fifo_sync),
        .rd_empty_fifo_sync(rd_empty_fifo_sync),
        .payload(payload),
        .is_data(got_data),
        .is_fct(got_fct),
        .is_eep(got_eep),
        .is_eop(got_eop),
        .is_null(got_null),
        .is_timecode(got_timecode)
    );

    assign Time_Code_RX = (got_timecode == 1) ? payload : '0;
    assign Time_Code_RX_valid = got_timecode;
    assign wr_en_fifo_rx = got_data | got_eep | got_eop;

    always_comb begin
        case ({got_data, got_eep, got_eop})
            3'b001: wr_data_fifo_rx = {1'b1, 6'b0, 2'b10}; // eop
            3'b010: wr_data_fifo_rx = {1'b1, 6'b0, 2'b01}; // eep
            3'b100: wr_data_fifo_rx = {1'b0, payload}; // data
            default: wr_data_fifo_rx = '0;
        endcase
    end

    logic bit_tick; //TODO falta conectar

    tx u_tx(
        .clk_tx(clk_tx),
        .clk_system(clk_system),
        .rst_n(rst_n_tx),
        .D_out(D_out),
        .S_out(S_out),
        .rd_en_fifo(rd_en_fifo_tx),
        .rd_data_fifo(rd_data_fifo_tx), 
        .empty_fifo(empty_tx_fifo),
        .run_state(run_state),
        .bit_tick_i(1), // TODO perguntar o que seria isso
        .send_fct_i(send_fct),
        .send_null_i(send_null),
        .send_timecode_i(Time_Code_TX_valid),
        .timecode_i(Time_Code_TX)
    );

endmodule
