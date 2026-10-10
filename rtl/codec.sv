module codec #(
    parameter int DEPTH_FIFO = 2048,
    parameter int DATA_WIDTH_FIFO = 9,
    parameter int CLK_FREQ = 10_000_000,
    parameter int SYS_CLK_FREQ_HZ = 50_000_000,
    parameter int REF_TX_FREQ_HZ = 200_000_000,
    parameter int DISCONNECT_TIMEOUT_NS = 850,
    parameter int DSIZE = 10,
    parameter int ASIZE = 4
)(
    input system_clk, // máquina de estados 50 MHz
    input ref_tx_clk, // referência do tx 200 MHz
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

    logic tx_clk_div; // clock programável durante o  Run
    logic tx_clk_10MHz; //clock fixo para deteccao de disconnect (fora de Run)
    logic tx_clk; // clock efetivo do TX selecionado pelo estado do link
    logic rx_clk; // clock reconstinuido do rx

    logic [7:0] counter_tx_div;
    always_ff @(posedge ref_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_tx_div <= 8'd0;
            tx_clk_div <= 1'b0;
        end else if (counter_tx_div >= div_counter_tx) begin
            counter_tx_div <= 8'd0;
            tx_clk_div <= ~tx_clk_div;
        end else begin
            counter_tx_div <= counter_tx_div + 8'd1;
        end
    end

    localparam int DIV_10MHz = (REF_TX_FREQ_HZ / (2*CLK_FREQ));

    logic [7:0] counter_tx_10MHz;
    always_ff @(posedge ref_tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_tx_10MHz <= 8'd0;
            tx_clk_10MHz     <= 1'b0;
        end else if (counter_tx_10MHz >= DIV_10MHz[7:0]) begin
            counter_tx_10MHz <= 8'd0;
            tx_clk_10MHz     <= ~tx_clk_10MHz;
        end else begin
            counter_tx_10MHz <= counter_tx_10MHz + 8'd1;
        end
    end

    // TODO eu estaja errado, arrumar isso, é so um clk o que musa é o contador
    assign tx_clk = run_state ? tx_clk_div : tx_clk_10MHz;

    logic [8:0] wr_data_fifo_rx; // TODO verificar a largura de bits
    logic wr_en_fifo_rx;
    logic [8:0] wr_data_fifo_tx; // TODO verificar a largura de bits
    logic wr_en_fifo_tx;
    logic empty_tx_fifo;

    logic [$clog2(DEPTH_FIFO)-1:0] free_slots_fifo_rx;


    rx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) dut_rx_fifo (
        .wr_clk_i(system_clk),
        .rd_clk_i(system_clk), //TODO verificar se o clock da fifo é o clock do systema
        .rst_n(rst_n),

        .wr_data_i(wr_data_fifo_rx),
        .wr_en_i(wr_en_fifo_rx),

        // saída do módulo
        .rd_en_i(SpW_Packet_RX_en),
        .rd_data_o(SpW_Packet_RX),
        .empty_o(empty_rx_fifo),
        .free_space_o(free_slots_fifo_rx)
    );

    tx_fifo #(.DEPTH(DEPTH_FIFO), .DATA_WIDTH(DATA_WIDTH_FIFO)) dut_tx_fifo (
        .clk(tx_clk_div),
        .rst_n(rst_n),

        .wr_data_i(SpW_Packet_TX),
        .wr_en_i(SpW_Packet_TX_en),
        .full_o(full_tx_fifo),

        .rd_data_o(wr_data_fifo_tx),
        .rd_en_i(wr_en_fifo_tx),
        .empty_o(empty_tx_fifo)
    );

    logic run_state;
    logic en_out_fifo_tx;
    logic got_data, got_fct, got_eop, got_eep, got_null, got_timecode;

    logic [7:0] payload;
    logic sending_allowed;
    logic send_fct, send_fct_fc, send_fct_sm;
    assign send_fct = send_fct_fc | send_fct_sm;

    flow_control #(.DEPTH_FIFO(DEPTH_FIFO)) dut_fc(
        .clk(system_clk),
        .rst_n(rst_n), // TODO falta arrumar aqui para ele funcionar com o rst da máquina de estado quadno rst o tx eo rx
        .run_state(run_state),
        .en_out_fifo_tx(en_out_fifo_tx),
        .got_FCT_rx(got_fct),
        .sending_allowed(sending_allowed),
        .en_in_fifo_rx(wr_en_fifo_rx),
        .free_slots_fifo_rx(free_slots_fifo_rx),
        .send_FCT(send_fct_fc)
    );

    logic got_bit;
    logic rx_Error;
    logic parity_err;
    logic escape_err;
    assign rx_Error = escape_err | parity_err;

    logic en_rx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic en_tx; // TODO analisar depois se os módulos possuem um sinal para ativar
    logic rst_n_rx;
    logic rst_n_tx;
    logic send_null, send_eep, send_eop;
    logic link_disabled;
    logic start_link = 1; // TODO verificar o que seria essa start_link, mas creio
                      // que seja um sinal externo para controle de quandoa ativar o rx

    state_machine #(.CLK_FREQ(CLK_FREQ))dut_sm(
        .clk(system_clk),
        .rst_n(rst_n),

        // RX
        .en_rx(en_rx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_rx(rst_n_rx),
        .got_bit(got_bit),
        .got_FCT(got_fct),
        .got_null(got_null),
        .got_TimeCode(got_timecode),
        .got_N_Char(got_nchar),
        .got_Cred(got_Cred),
        .rx_Error(rx_Error),

        // TX
        .en_tx(en_tx), // TODO analisar depois se os módulos possuem um sinal para ativar
        .rst_n_tx(rst_n_tx),
        .send_FCT(send_fct_sm),
        .send_Null(send_null),
        .send_EOP(send_eop),
        .send_EEP(send_eep),

        // FSM
        .link_disabled(link_disabled),
        .start_link(start_link),
        .run_state(run_state)
    );

    logic [9:0]wr_data_fifo_sync, wr_en_fifo_sync, wr_full_fifo_sync;
    logic [9:0]rd_data_fifo_sync, rd_en_fifo_sync, rd_empty_fifo_sync;

    logic parity_err_ref_tx_clk, escape_err_ref_tx_clk;

    rx dut_rx (
        .ref_rx_clk(ref_tx_clk),
        .rst_n(rst_n_rx),

        // interface com outro codec
        .d_i(D_in),
        .s_i(S_in),

        // interface com a fifo
        .data_o(wr_data_fifo_sync),
        .data_valid_o(wr_en_fifo_sync),

        .parity_err_o(parity_err_ref_tx_clk),
        .escape_err_o(escape_err_ref_tx_clk)
    );

    cdc_sync #(.STAGES(2)) u_parity_err_sync (
        .clk (system_clk),
        .d   (parity_err_ref_tx_clk),
        .q   (parity_err)
    );

    cdc_sync #(.STAGES(2)) u_escape_err_sync (
        .clk (system_clk),
        .d   (escape_err_ref_tx_clk),
        .q   (escape_err)
    );
    

    logic [1:0] wrst_n_sync_ff;
    logic  wrst_n_sync;

    always_ff @(posedge ref_tx_clk or negedge rst_n) begin
        if (!rst_n)
            wrst_n_sync_ff <= 2'b00;
        else
            wrst_n_sync_ff <= {wrst_n_sync_ff[0], 1'b1};
    end

    assign wrst_n_sync = wrst_n_sync_ff[1];

    fifo1 #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut_fifo_sync(  
        .wfull(wr_full_fifo_sync),
        .rempty(rd_empty_fifo_sync),

        .wdata(wr_data_fifo_sync),
        .winc(wr_en_fifo_sync), 
        .wclk(ref_tx_clk),
        .wrst_n(wrst_n_sync),

        .rdata(rd_data_fifo_sync),
        .rinc(rd_en_fifo_sync),
        .rclk(system_clk),
        .rrst_n(rst_n) // posso passar direto, pois se trata do clk do sistema
    );


    // decode
    spw_char_decode dut_spw_char_decode(
        .system_clk(system_clk),
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
    logic char_ack_o; //TODO falta conectar

    tx dut_tx(
        .clk(tx_clk_div),
        .rst_n(rst_n_tx),

        // interface com outro codec
        .d_o(D_out),
        .s_o(S_out),

        // interface com a fifo
        .rd_en_fifo(wr_en_fifo_tx),
        .rd_data_fifo(wr_data_fifo_tx), 
        .empty_fifo(empty_tx_fifo),

        // interface com a maquina de estado
        .run_state(run_state),
        .bit_tick_i(1), // TODO perguntar o que seria isso
        .send_fct_i(send_fct),
        .send_eop_i(send_eop),
        .send_eep_i(send_eep),
        .send_null_i(send_null),
        .char_ack_o(char_ack_o), // TODO perguntar o que seria isso

        // vem direto sem passar pela fifo
        .send_timecode_i(Time_Code_TX_valid),
        .timecode_i(Time_Code_TX)

    );

endmodule
