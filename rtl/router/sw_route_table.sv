module sw_route_table #(
    parameter int N_PORTS = 4                    // portas físicas(2--31)
)(
    input  logic clk,
    input  logic rst_n,                          // reset(ativo em 0)

    // write
    input  logic                       tbl_wr_en_i,   // enable (1)
    input  logic [7:0]                 tbl_addr_i,    // endereço lógico (32--254)
    input  logic [$clog2(N_PORTS+1)-1:0] tbl_port_i,  // output
    input  logic                       tbl_valid_i,   // 1 = rota válida/ 0 = apaga

    // lookup
    input  logic [N_PORTS:1][7:0]                   lookup_addr_i,  // endereço a consultar
    output logic [N_PORTS:1]                        lookup_hit_o,   // rota existe(1)
    output logic [N_PORTS:1][$clog2(N_PORTS+1)-1:0] lookup_port_o   // output/0 se não houver rota
);
 
    localparam int PW = $clog2(N_PORTS + 1); // bits para n de porta 

    // Faixa dos endereços lógicos
    localparam logic [7:0]    ADDR_MIN = 8'd32;
    localparam logic [7:0]    ADDR_MAX = 8'd254;
    localparam logic [PW-1:0] PORT_MIN = PW'(1);
    localparam logic [PW-1:0] PORT_MAX = PW'(N_PORTS);

    // Memória
    logic [PW-1:0] port_mem  [32:254];
    logic          valid_mem [32:254];

    // write
    for (genvar g = 32; g <= 254; g++) begin : g_entry
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                valid_mem[g] <= 1'b0;   // Sem rota = reset
                port_mem[g]  <= '0;     // zera porta
            end else if (tbl_wr_en_i && (tbl_addr_i == 8'(g))) begin
                valid_mem[g] <= tbl_valid_i;
                port_mem[g]  <= tbl_port_i;
            end
        end
    end

    // lookup
    for (genvar i = 1; i <= N_PORTS; i++) begin : g_lookup
        logic [7:0]    addr;      // Consultar endereço
        logic          in_range;  // é endereço lógico (32--254) = 1
        logic [7:0]    idx;       // índice seguro para ler a memória
        logic [PW-1:0] port;      // porta gravada nesse endereço
        logic          port_ok;   // porta gravada existe (1--N) = 1

        assign addr     = lookup_addr_i[i];
        assign in_range = (addr >= ADDR_MIN) && (addr <= ADDR_MAX);


        // lê mesmo se estiver fora da faixa pra não indexar fora da memória
        assign idx      = in_range ? addr : ADDR_MIN;

        assign port     = port_mem[idx];
        assign port_ok  = (port >= PORT_MIN) && (port <= PORT_MAX);

        // Hit = endereço lógico + rota válida + porta existente.
        // Sem rota se Porta gravada 0 ou > N conta como
        assign lookup_hit_o[i]  = in_range && valid_mem[idx] && port_ok;

        // Sem hit = devolve 0
        assign lookup_port_o[i] = lookup_hit_o[i] ? port : '0;
    end

endmodule
