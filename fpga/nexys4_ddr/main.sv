module top (
    input  logic clk,
    input  logic CPU_RESETN,

    input  logic rx,
    output logic tx,

    output logic [15:0]LED,

    input  logic [15:0] SW,

    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic VGA_HS,
    output logic VGA_VS,

    output logic M_CLK,      // Clock do microfone
    output logic M_LRSEL,    // Left/Right Select (Escolha do canal)

    input  logic M_DATA      // Dados do microfone
);


endmodule
