//=============================================================
// test.sv
//
// Single base test class, configured differently per scenario
// (per project rule: "use a simple base test plus configuration/
// test selection" rather than 16 duplicated classes).
//
// The scenario is selected by a string (set via +TESTNAME=...
// plusarg in top_tb.sv, or directly by name when instantiated).
// Each scenario configures the generator (num_transactions,
// directed_txn) differently, matching docs/test_plan.md.
//=============================================================

class test;

    environment env;
    string       test_name;

    function new(virtual uart_if vif, string test_name);
        this.test_name = test_name;
        env = new(vif);
    endfunction

    //---------------------------------------------------------
    // configure(): set up the generator for the selected
    // scenario. Directed scenarios build one or more explicit
    // transactions; random scenarios just set num_transactions
    // and let transaction's own constraints do the rest.
    //---------------------------------------------------------
    function void configure();
        transaction t;

        case (test_name)

            "TEST_SINGLE_TX_RX": begin
                t = new();
                t.data = 8'h3C; t.parity_en = 0; t.parity_type = 0;
                t.baud_div = 16'd9; t.err_inject_parity = 0; t.err_inject_framing = 0;
                env.gen.directed_txn = t;
            end

            "TEST_NO_PARITY": begin
                env.gen.num_transactions   = 20;
                env.gen.force_parity_en    = 0;  // force parity OFF on every txn
            end

            "TEST_EVEN_PARITY": begin
                env.gen.num_transactions   = 20;
                env.gen.force_parity_en    = 1;  // force parity ON
                env.gen.force_parity_type  = 0;  // force EVEN
            end

            "TEST_ODD_PARITY": begin
                env.gen.num_transactions   = 20;
                env.gen.force_parity_en    = 1;  // force parity ON
                env.gen.force_parity_type  = 1;  // force ODD
            end

            "TEST_BOUNDARY_DATA": begin
                // Handled as four explicit directed sends inside
                // run() below (needs multiple distinct transactions,
                // not a single directed_txn).
            end

            "TEST_BACK_TO_BACK": begin
                env.gen.num_transactions = 8;
            end

            "TEST_TX_BUSY_IGNORE": begin
                // Handled directly in run() - needs precise manual
                // pin wiggling (second tx_start while busy) that
                // doesn't fit the generator/driver's one-frame-per-
                // transaction model.
            end

            "TEST_PARITY_ERROR": begin
                t = new();
                t.data = 8'hF0; t.parity_en = 1; t.parity_type = 0;
                t.baud_div = 16'd9; t.err_inject_parity = 1; t.err_inject_framing = 0;
                env.gen.directed_txn = t;
            end

            "TEST_FRAMING_ERROR": begin
                t = new();
                t.data = 8'h3A; t.parity_en = 0; t.parity_type = 0;
                t.baud_div = 16'd9; t.err_inject_parity = 0; t.err_inject_framing = 1;
                env.gen.directed_txn = t;
            end

            "TEST_BOTH_ERRORS": begin
                t = new();
                t.data = 8'h11; t.parity_en = 1; t.parity_type = 0;
                t.baud_div = 16'd9; t.err_inject_parity = 1; t.err_inject_framing = 1;
                env.gen.directed_txn = t;
            end

            "TEST_RESET": begin
               // Reset scenario is handled by run_reset_scenario()
            end

            "TEST_BAUD_RATE": begin
                env.gen.num_transactions = 15; // constraint sweeps all 3 legal bauds
            end

            "TEST_RANDOM_DATA": begin
                env.gen.num_transactions = 100;
            end

            "TEST_STRESS": begin
                env.gen.num_transactions = 300;
            end

            default: begin
                $display("[TEST] WARNING: unknown test_name '%s', defaulting to TEST_RANDOM_DATA behavior", test_name);
                env.gen.num_transactions = 20;
            end
        endcase
    endfunction

    //---------------------------------------------------------
    // run(): configure, then run the scenario. A few scenarios
    // need extra manual steps beyond generator configuration
    // (TEST_RESET, TEST_BOUNDARY_DATA, TEST_TX_BUSY_IGNORE) -
    // those are handled with small dedicated sequences here,
    // still reusing env.drv directly for pin-level control where
    // the generic generator/driver flow doesn't fit.
    //---------------------------------------------------------
    task run();
        configure();

        case (test_name)

            "TEST_RESET": run_reset_scenario();

            "TEST_BOUNDARY_DATA": run_boundary_scenario();

            "TEST_TX_BUSY_IGNORE": run_tx_busy_ignore_scenario();

            default: begin
                env.run();
            end
        endcase

        env.sb.report();
        env.cov.report();
    endtask

    //---------------------------------------------------------
    // TEST_RESET : exercise reset while idle AND mid-frame.
    // Uses env.drv directly for low-level pin control since this
    // scenario is about the reset pin itself, not normal frames.
    //---------------------------------------------------------
    task run_reset_scenario();
        env.drv.reset_dut();

        fork
            env.mon.run();
            env.sb.run();
            env.cov.run();
        join_none

        // Reset while idle - no-op case.
        env.drv.reset_dut();
        if (env.vif.tx_serial === 1'b1 && env.vif.tx_busy === 1'b0)
            $display("[TEST_RESET] idle-reset OK: tx_serial=1 tx_busy=0");
        else
            $display("[TEST_RESET] idle-reset FAIL: tx_serial=%0b tx_busy=%0b", env.vif.tx_serial, env.vif.tx_busy);

        // Reset mid-frame.
        env.vif.tx_data = 8'h5A; env.vif.parity_en = 0; env.vif.baud_div = 16'd9;
        @(negedge env.vif.clk);
        env.vif.tx_start = 1'b1;
        @(negedge env.vif.clk);
        env.vif.tx_start = 1'b0;
        repeat (15) @(posedge env.vif.clk);
        env.vif.rst = 1'b1;
        @(posedge env.vif.clk);
        if (env.vif.tx_busy === 1'b0 && env.vif.tx_serial === 1'b1)
            $display("[TEST_RESET] mid-frame-reset OK: tx forced back to idle");
        else
            $display("[TEST_RESET] mid-frame-reset FAIL: tx_busy=%0b tx_serial=%0b", env.vif.tx_busy, env.vif.tx_serial);
        @(posedge env.vif.clk);
        env.vif.rst = 1'b0;
        repeat (5) @(posedge env.vif.clk);
    endtask

    //---------------------------------------------------------
    // TEST_BOUNDARY_DATA : four explicit directed sends, since
    // the generator's directed_txn mode only supports one
    // transaction at a time.
    //---------------------------------------------------------
    task run_boundary_scenario();
        transaction t;
        bit [7:0] values[4]  = '{8'h00, 8'hFF, 8'hAA, 8'h55};
        bit       pe[4]      = '{1'b1, 1'b1, 1'b0, 1'b0};
        bit       ptype[4]   = '{1'b0, 1'b1, 1'b0, 1'b0};

        fork
            env.drv.run();
            env.mon.run();
            env.sb.run();
            env.cov.run();
        join_none

        env.drv.reset_dut();

        foreach (values[i]) begin
            t = new();
            t.data = values[i]; t.parity_en = pe[i]; t.parity_type = ptype[i];
            t.baud_div = 16'd9; t.err_inject_parity = 0; t.err_inject_framing = 0;
            env.gen2drv_mbx.put(t.copy());
            env.gen2sb_mbx.put(t.copy());
        end

        repeat (500) @(posedge env.vif.clk);
        // Fixed drain window is safe here (unlike environment.sv's
        // generic run(), which needed a completion-tracking fix -
        // see Phase 7 review notes there): this scenario always
        // uses baud_div=9 (10 clocks/bit) and exactly 4 frames, so
        // worst case is 4 * 11 bit periods * 10 clocks = 440 clocks,
        // comfortably under the 500-cycle window.
    endtask

    //---------------------------------------------------------
    // TEST_TX_BUSY_IGNORE : fire a second tx_start immediately
    // while the first frame is still busy; the second must be
    // ignored. Needs raw pin control, so bypasses generator/driver.
    //---------------------------------------------------------
    task run_tx_busy_ignore_scenario();
        fork
            env.mon.run();
            env.sb.run();
            env.cov.run();
        join_none

        env.drv.reset_dut();

        // Expected transaction the scoreboard should compare against
        // is the FIRST frame's data (0x44) - the second tx_start
        // (0x99) is expected to be ignored by the DUT.
        begin
            transaction exp;
            exp = new();
            exp.data = 8'h44; exp.parity_en = 0; exp.parity_type = 0;
            exp.baud_div = 16'd9; exp.err_inject_parity = 0; exp.err_inject_framing = 0;
            env.gen2sb_mbx.put(exp);
        end

        wait (env.vif.tx_busy == 1'b0);
        @(negedge env.vif.clk);
        env.vif.tx_data   = 8'h44;
        env.vif.parity_en = 1'b0;
        env.vif.tx_start  = 1'b1;
        @(negedge env.vif.clk);
        env.vif.tx_start = 1'b0;

        @(negedge env.vif.clk);
        env.vif.tx_data  = 8'h99;  // should be ignored - DUT still busy
        env.vif.tx_start = 1'b1;
        @(negedge env.vif.clk);
        env.vif.tx_start = 1'b0;

        repeat (300) @(posedge env.vif.clk);
        // Fixed drain window is safe here: fixed baud_div=9 and
        // exactly one real frame (the second tx_start is ignored
        // by the DUT), worst case ~110 clocks, well under 300.
    endtask

endclass : test
