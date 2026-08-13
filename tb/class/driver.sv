//=============================================================
// driver.sv
//
// Driver responsibilities (per architecture.md / Phase 3):
//   - receive transactions from the generator (mailbox)
//   - configure the DUT (parity_en/type, baud_div)
//   - drive tx_data and pulse tx_start, honoring tx_busy
//     (LESSON FROM PHASE 5/6: never issue tx_start while busy -
//     the DUT correctly ignores it, so the driver must not rely
//     on that; it must wait for tx_busy==0 itself)
//   - apply error injection at the WIRE level (never by
//     modifying the golden uart_top/uart_tx/uart_rx RTL)
//   - never check correctness (that's the scoreboard's job)
//
// ERROR INJECTION TECHNIQUE (see also Phase 11 notes): the
// driver computes WHEN the parity/stop bit windows occur using
// ONLY spec-visible quantities (baud_div, and the fixed frame
// layout from design_specification.md section 5) - it does NOT
// read any DUT-internal FSM state. This keeps the driver a
// legitimate black-box verification component and avoids the
// fragile hand-counted-cycle bugs found during Phase 5/6
// debugging (those used internal state as a shortcut, which is
// fine for throwaway bring-up checks but not for the permanent
// OOP driver).
//=============================================================

class driver;

    virtual uart_if vif;
    mailbox #(transaction) gen2drv_mbx;

    function new(virtual uart_if vif, mailbox #(transaction) gen2drv_mbx);
        this.vif          = vif;
        this.gen2drv_mbx  = gen2drv_mbx;
    endfunction

    //---------------------------------------------------------
    // reset_dut(): drive rst for a few cycles at the start of
    // every test. Also sets safe default values on all DUT
    // inputs so nothing is ever driven with X.
    //---------------------------------------------------------
    task reset_dut();
        vif.rst         = 1'b1;
        vif.tx_start    = 1'b0;
        vif.tx_data     = 8'h00;
        vif.parity_en   = 1'b0;
        vif.parity_type = 1'b0;
        vif.baud_div    = 16'd9;
        vif.inject_enable = 1'b0;
        vif.inject_value  = 1'b1;
        repeat (5) @(posedge vif.clk);
        vif.rst = 1'b0;
        repeat (5) @(posedge vif.clk);
    endtask

    //---------------------------------------------------------
    // run(): main driving loop. Pulls transactions from the
    // mailbox one at a time and drives each one to completion
    // before pulling the next (this naturally enforces the
    // tx_busy-gated back-to-back behavior from the test plan).
    //---------------------------------------------------------
    task run();
        transaction txn;
        forever begin
            gen2drv_mbx.get(txn);
            drive_transaction(txn);
        end
    endtask

    //---------------------------------------------------------
    // drive_transaction(): drive one full UART frame onto the
    // interface, applying error injection if requested by the
    // transaction's err_inject_* fields.
    //---------------------------------------------------------
    task drive_transaction(transaction txn);
        int bit_period_clocks;
        int frame_bits_before_parity; // start + 8 data bits
        int parity_window_start_clk;
        int stop_window_start_clk;

        bit_period_clocks = txn.baud_div + 1;

        // Wait for any prior frame to finish (per Phase 5/6 lesson).
        wait (vif.tx_busy == 1'b0);

        @(negedge vif.clk);
        vif.tx_data     = txn.data;
        vif.parity_en   = txn.parity_en;
        vif.parity_type = txn.parity_type;
        vif.baud_div    = txn.baud_div;
        vif.tx_start    = 1'b1;
        @(negedge vif.clk);
        vif.tx_start = 1'b0;

        // If no error injection requested, nothing more to do -
        // just let the frame transmit naturally.
        if (!txn.err_inject_parity && !txn.err_inject_framing) begin
            return;
        end

        // Compute the clock-count windows for the parity and stop
        // bits using ONLY spec-visible timing (frame layout is
        // fixed: 1 start + 8 data + [1 parity] + 1 stop, each bit
        // = bit_period_clocks clocks). These counts are relative
        // to the posedge immediately following the tx_start pulse
        // (i.e. the posedge where TX first enters the START state -
        // this reference point was verified by hand-tracing the
        // RTL's cycle-by-cycle state timing, since the class-based
        // testbench cannot be locally simulated with the open-
        // source tools available in this environment - see
        // docs/verification_report.md).
        frame_bits_before_parity = 1 + 8; // start + data
        parity_window_start_clk  = frame_bits_before_parity * bit_period_clocks;
        stop_window_start_clk    = parity_window_start_clk  + (txn.parity_en ? bit_period_clocks : 0);

        // IMPORTANT: error injection is done SEQUENTIALLY in this
        // one process, not via parallel fork branches. An earlier
        // version used fork/join with two independent branches
        // both touching vif.rx_serial - when both errors are
        // injected together, the parity branch's release and the
        // framing branch's force land on the EXACT SAME clock edge
        // (parity window ends exactly where the stop window
        // begins), creating an inter-process race with undefined
        // relative ordering. Doing this sequentially in one process
        // removes that race entirely.
        if (txn.err_inject_parity && txn.parity_en) begin
    repeat (parity_window_start_clk) @(posedge vif.clk);

    // Override RX with the opposite of the real TX parity bit
    vif.inject_value  = ~vif.tx_serial;
    vif.inject_enable = 1'b1;

    repeat (bit_period_clocks) @(posedge vif.clk);

    // Return to normal TX -> RX loopback
    vif.inject_enable = 1'b0;
end

        if (txn.err_inject_framing) begin
            int posedges_already_consumed;
            int remaining;

            posedges_already_consumed = (txn.err_inject_parity && txn.parity_en)
                                         ? (parity_window_start_clk + bit_period_clocks)
                                         : 0;
            remaining = stop_window_start_clk - posedges_already_consumed;

           vif.inject_value  = 1'b0;
vif.inject_enable = 1'b1;

repeat (bit_period_clocks) @(posedge vif.clk);

vif.inject_enable = 1'b0;
        end
    endtask

endclass : driver
