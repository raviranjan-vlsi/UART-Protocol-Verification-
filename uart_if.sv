//=============================================================
// uart_if.sv
//
// Interface bundling all UART TX/RX signals.
// Used both to hook up uart_top in the testbench (as the DUT
// connection) and as the handle the class-based testbench
// (driver/monitor) uses via a virtual interface.
//
// NOTE: In this project, tx_serial and rx_serial are two
// SEPARATE signals in the port list. Loopback (tx_serial ->
// rx_serial) is done at the TESTBENCH level (top_tb.sv), not
// hardwired inside the interface or DUT. This keeps uart_top
// reusable for both loopback testing and (future) independent
// TX-only / RX-only testing.
//=============================================================

interface uart_if (input logic clk);

    // Reset -----------------------------------------------------
    logic        rst;            // active-high, synchronous

    // Shared configuration ---------------------------------------
    logic [15:0] baud_div;       // bit period = (baud_div+1) clocks
    logic        parity_en;      // 1 = parity bit present
    logic        parity_type;    // 0 = even, 1 = odd

    // TX side -----------------------------------------------------
    logic [7:0]  tx_data;
    logic        tx_start;       // 1-cycle pulse to begin a frame
    logic        tx_busy;
    logic        tx_done;        // 1-cycle pulse
    logic        tx_serial;

    // RX side -----------------------------------------------------
    logic        rx_serial;
    logic [7:0]  rx_data;
    logic        rx_done;        // 1-cycle pulse
    logic        parity_error;   // 1-cycle pulse
    logic        framing_error;  // 1-cycle pulse

    logic        inject_enable;
    logic        inject_value;

endinterface : uart_if
