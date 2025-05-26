module top (
    input  logic clk,
    input  logic rst_n,

    input  logic [4:0] btn,
    output logic [7:0] led,

    output logic OLED_RST,
    output logic OLED_DC,
    output logic OLED_SCL,
    inout  logic OLED_SDA,

    output logic EEPROM_SCL,
    inout  logic EEPROM_SDA
);


endmodule
