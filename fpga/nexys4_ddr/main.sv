module top (
    input  logic clk,
    input  logic CPU_RESETN,

    // i2c
    output logic scl,
    output logic sda,
    output logic sdo,

    output logic [15:0]LED,
    output logic M_CLK      // Clock do microfone
);

    // Sinais para o i2c_master
    logic start_i;
    logic we_i;
    logic reg_operation_i;
    logic stop_o;
    logic data_out_valid_o;
    logic busy_o;
    logic error_o;
    logic [6:0] addr_i;
    logic [7:0] reg_addr_i;
    logic [7:0] data_in_o;
    logic [7:0] data_out_o;

    // Instância do módulo i2c_master
    i2c_master #(
        .SYSTEM_CLOCK_FREQ(100_000_000),
        .I2C_CLOCK_FREQ(50_000_000)
    ) i2c_master_inst (
        .sys_clk(clk),
        .rst_n(CPU_RESETN),
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


    typedef enum logic [2:0] {
        MODE     = 3'd0,
        UMIDADE  = 3'd1,
        MSB      = 3'd2,
        LSB      = 3'd3,
        XLSB     = 3'd4
    } state_t;

    state_t state;

    logic [6:0] ADDR = 7'h76;
    logic [7:0] msb_value, lsb_value, xlsb_value; // Armazenando os valores lidos

    always_ff @(posedge clk or negedge CPU_RESETN) begin
        if (!CPU_RESETN) begin
            start_i         <= 1'b0;
            we_i            <= 1'b0;
            reg_operation_i <= 1'b0;
            addr_i          <= 7'd0;
            reg_addr_i      <= 8'd0;
            msb_value       <= 8'd0; // Resetando os valores
            lsb_value       <= 8'd0;
            xlsb_value      <= 8'd0;
        end else begin
            unique case (state)
                MODE: begin
                    start_i         <= 1'b1;
                    we_i            <= 1'b1;
                    reg_operation_i <= 1'b1;
                    addr_i          <= ADDR;
                    data_in_o      <= 8'h27;
                    state           <= UMIDADE;
                end
                UMIDADE: begin
                    start_i         <= 1'b1;
                    we_i            <= 1'b1;
                    reg_operation_i <= 1'b1;
                    addr_i          <= ADDR;
                    data_in_o      <= 8'h01;
                    state           <= MSB;
                end
                MSB: begin
                    start_i         <= 1'b1;
                    we_i            <= 1'b0;
                    reg_operation_i <= 1'b1;
                    addr_i          <= ADDR;
                    if (data_out_valid_o) begin
                        msb_value <= data_out_o;
                    end
                    state           <= LSB;
                end
                LSB: begin
                    start_i         <= 1'b1;
                    we_i            <= 1'b0;
                    reg_operation_i <= 1'b1;
                    addr_i          <= ADDR;
                    if (data_out_valid_o) begin
                        lsb_value <= data_out_o;
                    end
                    state           <= XLSB;
                end
                XLSB: begin
                    start_i         <= 1'b1;
                    we_i            <= 1'b0;
                    reg_operation_i <= 1'b1;
                    addr_i          <= ADDR;
                    if (data_out_valid_o) begin
                        xlsb_value <= data_out_o;
                    end
                    state           <= MODE;
                end
                default: state <= MODE;
            endcase
        end
    end

    assign LED = {msb_value, lsb_value};

endmodule
