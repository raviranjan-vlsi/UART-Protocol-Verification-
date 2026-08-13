//=============================================================
// uart_top.sv
//
// Top-level UART wrapper: instantiates uart_tx and uart_rx.
//
// NOTE: tx_serial and rx_serial are exposed as SEPARATE ports.
// This module does NOT hardwire loopback internally - that
// connection (tx_serial -> rx_serial) is made at the testbench
// level (top_tb.sv / uart_if instance) so this same DUT can be
// used for loopback testing now, or independent TX/RX testing
// later, without changing the RTL.
//=============================================================

module uart_top (
    input  logic        clk,
    input  logic        rst,          // active-high, synchronous

    input  logic [15:0] baud_div,
    input  logic        parity_en,
    input  logic        parity_type,  // 0 = even, 1 = odd

    // TX side
    input  logic [7:0]  tx_data,
    input  logic        tx_start,
    output logic        tx_busy,
    output logic        tx_done,
    output logic        tx_serial,

    // RX side
    input  logic        rx_serial,
    output logic [7:0]  rx_data,
    output logic        rx_done,
    output logic        parity_error,
    output logic        framing_error
);

    uart_tx u_uart_tx (
        .clk          (clk),
        .rst          (rst),
        .baud_div     (baud_div),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .tx_data      (tx_data),
        .tx_start     (tx_start),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .tx_serial    (tx_serial)
    );

    uart_rx u_uart_rx (
        .clk           (clk),
        .rst           (rst),
        .baud_div      (baud_div),
        .parity_en     (parity_en),
        .parity_type   (parity_type),
        .rx_serial     (rx_serial),
        .rx_data       (rx_data),
        .rx_done       (rx_done),
        .parity_error  (parity_error),
        .framing_error (framing_error)
    );

endmodule : uart_top
