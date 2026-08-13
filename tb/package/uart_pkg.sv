//=============================================================
// uart_pkg.sv
//
// Bundles all class-based testbench components in the correct
// compilation order (SystemVerilog classes must be declared
// before they are referenced by name in another class/task).
//
// Order: transaction -> generator -> driver -> monitor ->
//        scoreboard -> coverage -> environment -> test
//
// uart_if.sv is NOT included here - interfaces are compiled at
// the same level as modules, outside the package, and referenced
// via `virtual uart_if` inside the classes below (the package
// only needs to know the interface's NAME, which is visible
// project-wide once uart_if.sv is compiled/imported alongside
// this package - see top_tb.sv compile order).
//=============================================================

package uart_pkg;

    `include "transaction.sv"
    `include "generator.sv"
    `include "driver.sv"
    `include "monitor.sv"
    `include "scoreboard.sv"
    `include "coverage.sv"
    `include "environment.sv"
    `include "test.sv"

endpackage : uart_pkg
