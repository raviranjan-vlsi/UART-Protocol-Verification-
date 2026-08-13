//=============================================================
// uart_assertions.sv  (Phase 9)
//
// SystemVerilog Assertions - protocol-level, ALWAYS-ON checkers,
// independent of any specific transaction's data content (per
// verification_plan.md section 3: assertions check protocol
// SHAPE/timing, not data correctness - data correctness is the
// scoreboard's job).
//
// Bound into uart_top via a `bind` statement (see end of file)
// so the assertions attach to the DUT without modifying the
// golden RTL files at all.
//=============================================================

module uart_assertions (
    input logic        clk,
    input logic        rst,

    input logic        tx_busy,
    input logic        tx_done,
    input logic        tx_serial,
    input logic        tx_start,

    input logic        rx_done,
    input logic [7:0]  rx_data,
    input logic        parity_error,
    input logic        framing_error
);

    //-----------------------------------------------------------
    // a_reset_forces_tx_idle
    // While rst is high, tx_serial must be 1 and tx_busy must be 0.
    // Checked ONE CYCLE AFTER rst asserts (rst takes effect
    // synchronously, so the same-cycle value may still reflect
    // pre-reset state - LRM/simulator dependent for combinational
    // outputs, so we check the cycle after to be unambiguous).
    //-----------------------------------------------------------
    property p_reset_forces_tx_idle;
        @(posedge clk) rst |=> (tx_serial == 1'b1 && tx_busy == 1'b0);
    endproperty
    a_reset_forces_tx_idle: assert property (p_reset_forces_tx_idle)
        else $error("[ASSERT FAIL] a_reset_forces_tx_idle: tx not idle one cycle after reset");

    //-----------------------------------------------------------
    // a_reset_forces_rx_idle
    // While rst is high, rx_done/parity_error/framing_error must
    // not be pulsing (no stale/spurious pulses out of reset).
    //-----------------------------------------------------------
    property p_reset_forces_rx_idle;
        @(posedge clk) rst |=> (rx_done == 1'b0 && parity_error == 1'b0 && framing_error == 1'b0);
    endproperty
    a_reset_forces_rx_idle: assert property (p_reset_forces_rx_idle)
        else $error("[ASSERT FAIL] a_reset_forces_rx_idle: spurious rx pulse one cycle after reset");

    //-----------------------------------------------------------
    // a_tx_idle_high
    // Whenever tx_busy is low (no frame in progress) and we are
    // not in reset, tx_serial must be high (idle line level per
    // design_specification.md section 6.1).
    //-----------------------------------------------------------
    property p_tx_idle_high;
        @(posedge clk) disable iff (rst) (!tx_busy) |-> (tx_serial == 1'b1);
    endproperty
    a_tx_idle_high: assert property (p_tx_idle_high)
        else $error("[ASSERT FAIL] a_tx_idle_high: tx_serial not high while tx_busy=0");

    //-----------------------------------------------------------
    // a_tx_done_after_busy
    // tx_done must never pulse unless tx_busy was high at some
    // point in the preceding cycle window (i.e. tx_done cannot
    // fire "out of nowhere" with no frame having been in progress).
    // Implemented as: tx_done implies tx_busy was high the
    // previous cycle (STOP bit is still part of the busy window).
    //-----------------------------------------------------------
    property p_tx_done_after_busy;
        @(posedge clk) disable iff (rst) tx_done |-> $past(tx_busy, 1);
    endproperty
    a_tx_done_after_busy: assert property (p_tx_done_after_busy)
        else $error("[ASSERT FAIL] a_tx_done_after_busy: tx_done pulsed without a preceding busy frame");

    //-----------------------------------------------------------
    // a_tx_done_pulse_width
    // tx_done must be exactly one cycle wide (not held high).
    //-----------------------------------------------------------
    property p_tx_done_pulse_width;
        @(posedge clk) disable iff (rst) tx_done |=> !tx_done;
    endproperty
    a_tx_done_pulse_width: assert property (p_tx_done_pulse_width)
        else $error("[ASSERT FAIL] a_tx_done_pulse_width: tx_done held for more than one cycle");

    //-----------------------------------------------------------
    // a_rx_done_pulse_width
    // rx_done must be exactly one cycle wide.
    //-----------------------------------------------------------
    property p_rx_done_pulse_width;
        @(posedge clk) disable iff (rst) rx_done |=> !rx_done;
    endproperty
    a_rx_done_pulse_width: assert property (p_rx_done_pulse_width)
        else $error("[ASSERT FAIL] a_rx_done_pulse_width: rx_done held for more than one cycle");

    //-----------------------------------------------------------
    // a_parity_error_pulse_width
    //-----------------------------------------------------------
    property p_parity_error_pulse_width;
        @(posedge clk) disable iff (rst) parity_error |=> !parity_error;
    endproperty
    a_parity_error_pulse_width: assert property (p_parity_error_pulse_width)
        else $error("[ASSERT FAIL] a_parity_error_pulse_width: parity_error held for more than one cycle");

    //-----------------------------------------------------------
    // a_framing_error_pulse_width
    //-----------------------------------------------------------
    property p_framing_error_pulse_width;
        @(posedge clk) disable iff (rst) framing_error |=> !framing_error;
    endproperty
    a_framing_error_pulse_width: assert property (p_framing_error_pulse_width)
        else $error("[ASSERT FAIL] a_framing_error_pulse_width: framing_error held for more than one cycle");

    //-----------------------------------------------------------
    // a_no_x_on_rx_data_at_done
    // rx_data must be a known value (no X/Z) whenever rx_done
    // pulses - an X here would indicate an uninitialized/timing
    // bug feeding into system logic downstream.
    //-----------------------------------------------------------
    property p_no_x_on_rx_data_at_done;
        @(posedge clk) disable iff (rst) rx_done |-> !$isunknown(rx_data);
    endproperty
    a_no_x_on_rx_data_at_done: assert property (p_no_x_on_rx_data_at_done)
        else $error("[ASSERT FAIL] a_no_x_on_rx_data_at_done: rx_data contains X/Z when rx_done pulsed");

endmodule : uart_assertions

// Bind the assertion module into every uart_top instance so the
// checks run automatically without editing the golden RTL files.
bind uart_top uart_assertions u_uart_assertions (
    .clk           (clk),
    .rst           (rst),
    .tx_busy       (tx_busy),
    .tx_done       (tx_done),
    .tx_serial     (tx_serial),
    .tx_start      (tx_start),
    .rx_done       (rx_done),
    .rx_data       (rx_data),
    .parity_error  (parity_error),
    .framing_error (framing_error)
);
