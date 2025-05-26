module I2C_Master #(
    parameter SYSTEM_CLOCK_FREQ = 100_000_000,
    parameter I2C_CLOCK_FREQ    = 5_000_000
)(
    input  logic sys_clk,
    input  logic rst_n,

    output logic scl,
    inout  logic sda,
    
    input  logic start_i,
    input  logic we_i,               // 1 = write, 0 = read
    input  logic reg_operation_i,    // 1 = register operation, 0 = memory operation
    output logic stop_o,

    output logic data_out_valid_o,
    output logic busy_o,
    output logic error_o,

    input  logic [6:0] addr_i,
    input  logic [7:0] reg_addr_i,
    input  logic [7:0] data_in_o,
    output logic [7:0] data_out_o
);

    localparam integer BIT_PERIOD = SYSTEM_CLOCK_FREQ / I2C_CLOCK_FREQ;

    typedef enum logic [4:0] {
        IDLE, START, SEND_ADDR, ADDR_ACK,
        SEND_REG, REG_ACK,
        SEND_DATA, DATA_ACK,
        READ_DATA, READ_ACK,
        STOP, DONE
    } state_t;

    state_t state;

    logic [7:0] shift_reg;
    logic [3:0] bit_cnt;
    logic scl_int, scl_en;
    logic sda_out, sda_oe;
    logic [$clog2(BIT_PERIOD)-1:0] clk_cnt;

    logic [2:0] edge_reg; // For edge detection
    logic posedge_scl, negedge_scl;
    logic read_after_reg_write;

    assign posedge_scl = (!edge_reg[2] && edge_reg[1]);
    assign negedge_scl = (edge_reg[2] && !edge_reg[1]);

    assign scl = scl_en ? scl_int : 1'b1;
    assign sda = sda_oe ? sda_out : 1'bz;

    // Clock divider
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            scl_int <= 1;
        end else begin 
            if (scl_en) begin
                if (clk_cnt == BIT_PERIOD/2 - 1) begin
                    scl_int <= ~scl_int;
                    clk_cnt <= 0;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            edge_reg <= {edge_reg[1:0], scl_int};
        end
    end

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            busy_o           <= 0;
            scl_en           <= 0;
            sda_oe           <= 1;
            sda_out          <= 1;
            stop_o           <= 0;
            data_out_valid_o <= 0;
            error_o          <= 0;
            read_after_reg_write <= 0;
        end else begin
            case (state)
                IDLE: begin
                    busy_o           <= 0;
                    stop_o           <= 0;
                    data_out_valid_o <= 0;
                    sda_out          <= 1;
                    scl_en           <= 0;
                    read_after_reg_write <= 0;
                    error_o          <= 0;

                    if (start_i) begin
                        busy_o <= 1;
                        if (~we_i && reg_operation_i)
                            read_after_reg_write <= 1;

                        state  <= START;
                    end
                end

                START: begin
                    sda_out <= 0;
                    scl_en  <= 1;
                    
                    if (read_after_reg_write) begin
                        shift_reg <= {addr_i, 1'b1}; // Read
                        read_after_reg_write <= 0;
                    end else begin
                        shift_reg <= {addr_i, ~we_i}; // Write
                    end

                    bit_cnt <= 7;
                    state   <= SEND_ADDR;
                end

                SEND_ADDR: begin
                    if (scl_int == 0) begin
                        sda_oe  <= 1;
                        sda_out <= shift_reg[bit_cnt];
                        if (bit_cnt == 0)
                            state <= ADDR_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                ADDR_ACK: begin
                    sda_oe <= 0;
                    if (scl_int == 1) begin
                        if (sda == 0) begin
                            if (~we_i && ~reg_operation_i) begin // direct read
                                bit_cnt <= 7;
                                state   <= READ_DATA;
                            end else begin
                                shift_reg <= (reg_operation_i) ? reg_addr_i : data_in_o;
                                bit_cnt   <= 7;
                                state     <= (reg_operation_i) ? SEND_REG : SEND_DATA;
                            end
                        end else begin
                            error_o <= 1;
                            state   <= STOP;
                        end
                    end
                end

                SEND_REG: begin
                    if (scl_int == 0) begin
                        sda_oe  <= 1;
                        sda_out <= shift_reg[bit_cnt];
                        if (bit_cnt == 0)
                            state <= REG_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                REG_ACK: begin
                    sda_oe <= 0;
                    if (scl_int == 1) begin
                        if (sda == 0) begin
                            if (~we_i) begin // read after reg write
                                sda_oe  <= 1;
                                sda_out <= 1;
                                state   <= START;
                            end else begin
                                shift_reg <= data_in_o;
                                bit_cnt   <= 7;
                                state     <= SEND_DATA;
                            end
                        end else begin
                            error_o <= 1;
                            state   <= STOP;
                        end
                    end
                end

                SEND_DATA: begin
                    if (scl_int == 0) begin
                        sda_oe  <= 1;
                        sda_out <= shift_reg[bit_cnt];
                        if (bit_cnt == 0)
                            state <= DATA_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                DATA_ACK: begin
                    sda_oe <= 0;
                    if (scl_int == 1) begin
                        state <= STOP;
                    end
                end

                READ_DATA: begin
                    if (scl_int == 1) begin
                        data_out_o[bit_cnt] <= sda;
                        if (bit_cnt == 0)
                            state <= READ_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                READ_ACK: begin
                    sda_oe  <= 1;
                    sda_out <= 1; // NACK
                    data_out_valid_o <= 1;
                    state <= STOP;
                end

                STOP: begin
                    sda_out <= 0;
                    scl_en  <= 0;
                    state   <= DONE;
                end

                DONE: begin
                    sda_out <= 1;
                    stop_o  <= 1;
                    busy_o  <= 0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
