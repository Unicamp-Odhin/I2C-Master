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
        .SYSTEM_CLOCK_FREQ(200_000_000),
        .I2C_CLOCK_FREQ(50_000_000)
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


    typedef enum logic [2:0] {
        START, RECEIVE_ADDR, ACK, RECEIVE_REG, ACK_2, RECEIVE_DATA, ACK_3
    } state_slave_t;

    state_slave_t state_slave;
    logic [7:0] reg_slave;  // Registro de dados do slave
    logic [7:0] addr_slave;  // Endereço do slave
    logic [7:0] counter_slave; // Contador para a recepção de dados

    // Simulando o comportamento do slave no endereço 0x50
    always_ff @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            ack_slave <= 0;
            sda_valid_slave <= 0;
            state_slave <= START;
            counter_slave <= 0;
            addr_slave <= 8'h00;  // Endereço do slave inicial
            reg_slave <= 8'h00;  // Registro de dados do slave
        end else begin
            case (state_slave)
                START: begin
                    // Espera a condição de START (SDA vai para baixo enquanto SCL está alto)
                    if (sda == 0) begin
                        state_slave <= RECEIVE_ADDR;
                        counter_slave <= 6;  // Reseta o contador do endereço
                            $display("DEBUG: Indo para RECEIVE_ADDR");
                    end
                end

                RECEIVE_ADDR: begin
                    if (scl == 0) begin
                        // Recebe o byte de endereço no SDA
                        addr_slave[counter_slave] <= sda;
                        counter_slave <= counter_slave - 1;
                        if (counter_slave == 0) begin
                            // Se o endereço completo foi recebido
                            if (addr_slave == 8'h50) begin
                                $display("DEBUG: Endereço reconhecido: %h, indo para ACK", addr_slave);
                                state_slave <= ACK;  // Se for o endereço 0x50, vai para ACK
                                counter_slave <= 7;
                                reg_slave <= 8'h0;
                            end else begin
                                $display("DEBUG: Endereço não reconhecido: %h, reiniciando para START", addr_slave);
                                state_slave <= START;  // Caso contrário, reinicia
                            end
                        end
                    end
                end

                ACK: begin
                    if (scl == 0) begin
                        // Envia o ACK para indicar que o endereço foi reconhecido
                        ack_slave <= 1;
                        sda = 0;  // Envia ACK (SDA = 0)
                        state_slave <= RECEIVE_REG;  // Depois vai para RECEBER DADOS
                    end
                end

                RECEIVE_REG: begin
                    if (scl == 0) begin
                        // Recebe dados do mestre
                        reg_slave[counter_slave] <= sda;
                        counter_slave <= counter_slave - 1;
                        if (counter_slave == 0) begin
                            counter_slave <= 7;
                            reg_slave <= 8'h0;
                            state_slave <= ACK_2;  // Depois de receber os 8 bits de dados, envia ACK
                        end
                    end
                end

                ACK_2: begin
                    if (scl == 0) begin
                        ack_slave <= 1;
                        sda = 0;  // Envia ACK (SDA = 0)
                        state_slave <= RECEIVE_DATA;  // Depois vai para RECEBER DADOS
                    end
                end

                RECEIVE_DATA: begin
                    if (scl == 0) begin
                        // Recebe dados do mestre
                        reg_slave[counter_slave] <= sda;
                        counter_slave <= counter_slave - 1;
                        if (counter_slave == 0) begin
                            state_slave <= ACK_2;  // Depois de receber os 8 bits de dados, envia ACK
                        end
                    end
                end

            endcase
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
        #200 rst_n = 1;

        // Teste 1: Escrita no slave (registro)
        #400 addr_i = 7'h50;       // Endereço do escravo 0x50 = 0b11010
        reg_addr_i = 8'h10;       // Endereço do registro
        data_in_o = 8'hA5;        // Dados a serem escritos
        we_i = 1;                 // Operação de escrita
        reg_operation_i = 1;      // Operação de registro
        start_i = 1;              // Inicia a comunicação
        #200 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 2: Leitura do slave (registro)
        #200 addr_i = 7'h50;       // Endereço do escravo
        reg_addr_i = 8'h10;       // Endereço do registro
        we_i = 0;                 // Operação de leitura
        reg_operation_i = 1;      // Operação de registro
        start_i = 1;              // Inicia a comunicação
        #200 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 3: Escrita no slave (memória)
        #200 addr_i = 7'h50;       // Endereço do escravo
        data_in_o = 8'h3C;        // Dados a serem escritos
        we_i = 1;                 // Operação de escrita
        reg_operation_i = 0;      // Operação de memória
        start_i = 1;              // Inicia a comunicação
        #200 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);

        // Teste 4: Leitura do slave (memória)
        #200 addr_i = 7'h50;       // Endereço do escravo
        we_i = 0;                 // Operação de leitura
        reg_operation_i = 0;      // Operação de memória
        start_i = 1;              // Inicia a comunicação
        #200 start_i = 0;

        // Aguarda o término da operação
        wait (!busy_o);
        // Finaliza a simulação
        #1000 $finish;
    end

    // Monitoramento de sinais
    initial begin
        $monitor("At time %t, addr_i = %h, reg_addr_i = %h, data_in_o = %h, data_out_o = %h, busy_o = %b, error_o = %b", 
                 $time, addr_i, reg_addr_i, data_in_o, data_out_o, busy_o, error_o);
    end

endmodule
