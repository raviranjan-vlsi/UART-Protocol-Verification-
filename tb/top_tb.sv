//=============================================================
// top_tb.sv  (Phase 7+: full class-based OOP testbench)
//
// Top-level: instantiates the interface, the DUT (with bound
// assertions - see uart_assertions.sv), and the class-based
// test environment from uart_pkg.
//
// TEST SELECTION: the scenario to run is chosen via a plusarg,
// e.g.  +TESTNAME=TEST_STRESS
// If no plusarg is given, TEST_RANDOM_DATA is used as a safe
// default. This mirrors real regression flows (Phase 12), where
// a single compiled testbench binary is re-run many times with
// different plusargs rather than being recompiled per test.
//=============================================================
`timescale 1ns/1ps

import uart_pkg::*;

module top_tb;

    //-----------------------------------------------------------
    // Clock generation
    //-----------------------------------------------------------
    logic clk = 0;
    always #5 clk = ~clk;   // 100 MHz system clock

    //-----------------------------------------------------------
    // Interface instance
    //-----------------------------------------------------------
    uart_if vif (.clk(clk));

    //-----------------------------------------------------------
    // DUT instance (assertions are bound in automatically by
    // uart_assertions.sv via `bind uart_top` - no RTL edits).
    //
    // LOOPBACK: tx_serial -> rx_serial, driven as a continuous
    // assignment directly on the interface. (Note: this exact
    // pattern - continuous-assigning an interface `logic` member
    // - is rejected by Icarus Verilog 12.0 as a tool limitation;
    // it is fully legal SystemVerilog and works correctly on
    // Questa/VCS/EDA Playground, which are this project's primary
    // targets. See docs/verification_report.md for the full list
    // of open-source-simulator limitations encountered.)
    //-----------------------------------------------------------
    
    assign vif.rx_serial = vif.inject_enable? vif.inject_value: vif.tx_serial;

    uart_top dut (
        .clk           (clk),
        .rst           (vif.rst),
        .baud_div      (vif.baud_div),
        .parity_en     (vif.parity_en),
        .parity_type   (vif.parity_type),
        .tx_data       (vif.tx_data),
        .tx_start      (vif.tx_start),
        .tx_busy       (vif.tx_busy),
        .tx_done       (vif.tx_done),
        .tx_serial     (vif.tx_serial),
        .rx_serial     (vif.rx_serial),
        .rx_data       (vif.rx_data),
        .rx_done       (vif.rx_done),
        .parity_error  (vif.parity_error),
        .framing_error (vif.framing_error)
    );

    //-----------------------------------------------------------
    // Test selection + run
    //-----------------------------------------------------------
    string test_name;
    test   t;

    initial begin
        if (!$value$plusargs("TESTNAME=%s", test_name))
            test_name = "TEST_RANDOM_DATA";

        $display("========================================");
        $display("UART TESTBENCH - running %s", test_name);
        $display("========================================");

        t = new(vif, test_name);
        t.run();

        $display("========================================");
        $display("UART TESTBENCH - %s COMPLETE", test_name);
        $display("========================================");

        $finish;
    end

endmodule : top_tb
