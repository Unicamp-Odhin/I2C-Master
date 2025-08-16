`timescale 1ns/1ps

module i2c_slave_tb;

    // Clock de sistema
    logic sys_clk;
    logic scl;            // Clock do I²C
    logic sda;            // Dados do I²C (linha bidirecional)
    
    // Sinais do master (I2C Master)
    logic rst_n;          // Reset ativo baixo
    logic start_i;        // Início de comunicação
    logic we_i;           // Operação de escrita (1) ou leitura (0)
    logic reg_operation_i;// Operação de registro (1) ou memória (0)
    logic [6:0] addr_i;   // Endereço do escravo
    logic [7:0] reg_addr_i;// Endereço do registro
    logic [7:0] data_in_o;// Dados a serem enviados
    logic stop_o;         // Fim da comunicação
    logic data_out_valid_o; // Dados válidos
    logic busy_o;         // Master ocupado
    logic error_o;        // Erro
    logic [7:0] data_out_o;// Dados recebidos

    // Sinais do slave (I2C Slave)
    logic ack_slave;      // Acknowledgment do slave
    logic [7:0] data_in_slave; // Dados recebidos pelo slave
    logic sda_out_slave; // Controle da saída de dados do slave (SDA)
    
    // Instanciando o módulo I²C Master
    i2c_master #(
        .SYSTEM_CLOCK_FREQ(100_000_000),
        .I2C_CLOCK_FREQ(5_000_000)
    ) uut (
        .sys_clk(sys_clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .start_i(start_i),
        .we_i(we_i),
        .reg_operation_i(reg_operation_i),
        .stop_o(stop_o),
        .data_out_valid_o(data_out_valid_o),
        .busy_o(busy_o),
        .error_o(error_o),
        .addr_i(addr_i),
        .reg_addr_i(reg_addr_i),
        .data_in_o(data_in_o),
        .data_out_o(data_out_o)
    );

    logic sda_valid_slave, sda_tmp_slave;
    assign sda_out_slave = sda_valid_slave ? sda_tmp_slave : 1'bz;

    // Simulando o comportamento de um slave no endereço 0x50
    always_ff @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            ack_slave <= 0;
            sda_valid_slave <= 0;
        end else begin
            // Simula o reconhecimento do endereço do slave
            if (addr_i == 7'h50 && start_i) begin
                ack_slave <= 1; // Acknowledgment do slave
            end else begin
                ack_slave <= 0;
            end

            // Simula operações de leitura e escrita
            if (ack_slave) begin
                if (we_i) begin
                    // Escrita no slave
                    data_in_slave <= data_in_o;
                end else begin
                    // Leitura do slave
                    sda_tmp_slave <= data_in_slave[7]; // Envia o bit mais significativo
                    data_in_slave <= {data_in_slave[6:0], 1'b0}; // Shift para o próximo bit
                end
            end else begin
                sda_valid_slave <= 0;
            end
        end
    end

    // Gerador de clock de 50 MHz (para o sistema)
    always begin
        #10 sys_clk = ~sys_clk;
    end

    // Processo de estímulos para testar a comunicação
    initial begin
        // Inicializa os sinais

        // Configuração do dump de waveform
        $dumpfile("tb/i2c_slave_tb.vcd");
        $dumpvars(0, i2c_slave_tb);

        sys_clk = 0;
        rst_n = 0;
        start_i = 0;
        we_i = 0;
        reg_operation_i = 0;
        addr_i = 7'h00;
        reg_addr_i = 8'h00;
        data_in_o = 8'h00;

        // Reset do sistema
        #20 rst_n = 1;

        // Teste 1: Escrita no slave (registro)
        #20 addr_i = 7'h50;       // Endereço do escravo
        reg_addr_i = 8'h10;       // Endereço do registro
        data_in_o = 8'hA5;        // Dados a serem escritos
        we_i = 1;                 // Operação de escrita
        reg_operation_i = 1;      // Operação de registro
        start_i = 1;              // Inicia a comunicação
        #20 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 2: Leitura do slave (registro)
        #20 addr_i = 7'h50;       // Endereço do escravo
        reg_addr_i = 8'h10;       // Endereço do registro
        we_i = 0;                 // Operação de leitura
        reg_operation_i = 1;      // Operação de registro
        start_i = 1;              // Inicia a comunicação
        #20 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 3: Escrita no slave (memória)
        #20 addr_i = 7'h50;       // Endereço do escravo
        data_in_o = 8'h3C;        // Dados a serem escritos
        we_i = 1;                 // Operação de escrita
        reg_operation_i = 0;      // Operação de memória
        start_i = 1;              // Inicia a comunicação
        #20 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 4: Leitura do slave (memória)
        #20 addr_i = 7'h50;       // Endereço do escravo
        we_i = 0;                 // Operação de leitura
        reg_operation_i = 0;      // Operação de memória
        start_i = 1;              // Inicia a comunicação
        #20 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Finalizar simulação após algum tempo
        #200 $finish;
    end

    // Monitoramento de sinais
    initial begin
        $monitor("At time %t, addr_i = %h, reg_addr_i = %h, data_in_o = %h, data_out_o = %h, busy_o = %b, error_o = %b", 
                 $time, addr_i, reg_addr_i, data_in_o, data_out_o, busy_o, error_o);
    end

endmodule
