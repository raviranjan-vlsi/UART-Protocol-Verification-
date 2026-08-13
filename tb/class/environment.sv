//=============================================================
// environment.sv
//
// Environment responsibilities (per architecture.md / Phase 3):
//   - instantiate generator, driver, monitor, scoreboard, coverage
//   - create the mailboxes that connect them
//   - hold the virtual interface handle, pass it to driver/monitor
//   - run() : kick off driver/monitor/scoreboard/coverage as
//     concurrent processes, run the generator to completion, then
//     let the DUT drain (last frame finish) before returning
//   - NOT contain test-specific scenario logic (that's test.sv)
//=============================================================

class environment;

    virtual uart_if vif;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sb;
    coverage   cov;

    mailbox #(transaction) gen2drv_mbx;
    mailbox #(transaction) gen2sb_mbx;
    mailbox #(transaction) mon2sb_mbx;
    mailbox #(transaction) mon2cov_mbx;

    function new(virtual uart_if vif);
        this.vif = vif;

        gen2drv_mbx  = new();
        gen2sb_mbx   = new();
        mon2sb_mbx   = new();
        mon2cov_mbx  = new();

        gen = new(gen2drv_mbx, gen2sb_mbx);
        drv = new(vif, gen2drv_mbx);
        mon = new(vif, mon2sb_mbx, mon2cov_mbx);
        sb  = new(gen2sb_mbx, mon2sb_mbx);
        cov = new(mon2cov_mbx);
    endfunction

    //---------------------------------------------------------
    // run(): drives one full test scenario to completion.
    //
    // driver/monitor/scoreboard/coverage run FOREVER (they are
    // reactive, event-driven consumers) - so the way this task
    // terminates is by waiting for the GENERATOR to finish (a
    // bounded, known quantity, per generator.sv), then waiting a
    // fixed drain window long enough for the last transaction to
    // fully complete on the DUT, then simply returning (letting
    // the forever loops die naturally with the simulation process
    // when $finish is called in test.sv).
    //---------------------------------------------------------
    task run();
        drv.reset_dut();

        fork
            drv.run();
            mon.run();
            sb.run();
            cov.run();
        join_none

        gen.run();
        // gen.run() is called directly (not forked), so by the time
        // it returns, every transaction has already been PUT into
        // both mailboxes. HOWEVER: mailbox.put() on an unbounded
        // mailbox (created via new() with no size limit, as used
        // throughout this environment) never blocks - so gen.run()
        // returns almost instantly in simulation time, regardless
        // of how many transactions were generated. The DRIVER is
        // still slowly processing them one at a time on the DUT
        // (each frame takes on the order of 100+ clock cycles).
        //
        // A fixed-size drain window here would either waste huge
        // amounts of simulation time for small tests, or (as found
        // during Phase 7 review) badly UNDER-wait for large tests
        // like TEST_STRESS (300 transactions can need 100,000+
        // clocks) - silently truncating the final report. Instead,
        // wait until the SCOREBOARD has actually processed the
        // same number of transactions that were generated, with a
        // generous per-transaction timeout so simulation can never
        // hang indefinitely even if something is stuck (per the
        // project's debugging rules).
        begin
            int expected_count;
            int timeout_limit_per_txn;
            int elapsed;

            expected_count = (gen.directed_txn != null) ? 1 : gen.num_transactions;

            // Generous upper bound per frame: worst case is the
            // slowest legal baud (50 clocks/bit) times the longest
            // possible frame (11 bit periods: start+8data+parity+
            // stop), plus a healthy margin for scheduling slack.
            timeout_limit_per_txn = 3000;

            elapsed = 0;
            while (sb.total_count < expected_count &&
                   elapsed < expected_count * timeout_limit_per_txn) begin
                @(posedge vif.clk);
                elapsed++;
            end

            if (sb.total_count < expected_count) begin
                $display("[ENVIRONMENT] WARNING: timed out waiting for all transactions - got %0d of %0d",
                          sb.total_count, expected_count);
            end
        end

        // Small additional safety margin: coverage.run() consumes
        // from a separate mailbox fed by the monitor at the same
        // time as the scoreboard's feed, so by the time the
        // scoreboard has seen the last transaction, coverage should
        // already have it too - this just guards against any
        // last-delta-cycle ordering slack.
        repeat (20) @(posedge vif.clk);
    endtask

endclass : environment
