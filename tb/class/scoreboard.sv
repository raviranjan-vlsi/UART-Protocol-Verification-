//=============================================================
// scoreboard.sv
//
// Scoreboard responsibilities (per architecture.md / Phase 3):
//   - receive EXPECTED transactions from the generator
//   - receive ACTUAL transactions from the monitor
//   - compare them (transaction::compare(), see transaction.sv)
//   - tally total/pass/fail, including separate tallies for
//     parity-error and framing-error MATCHES (per project rule:
//     "track parity-error matches, framing-error matches")
//   - print a concise PASS/FAIL per mismatch, and a summary
//     report at the end - NOT thousands of lines for random tests
//
// SYNCHRONIZATION MODEL: expected and actual transactions arrive
// on two independent mailboxes, but they must be paired up IN
// ORDER (the Nth expected transaction corresponds to the Nth
// actual transaction) because the UART is a single in-order
// channel with no reordering possible. This is the simplest
// correct synchronization scheme for this design - no tagging/
// sequence-ID matching is needed.
//=============================================================

class scoreboard;

    mailbox #(transaction) gen2sb_mbx;
    mailbox #(transaction) mon2sb_mbx;

    // Tallies
    int total_count        = 0;
    int pass_count         = 0;
    int fail_count         = 0;
    int parity_err_match   = 0;   // expected parity error AND observed parity error
    int framing_err_match  = 0;   // expected framing error AND observed framing error

    function new(mailbox #(transaction) gen2sb_mbx, mailbox #(transaction) mon2sb_mbx);
        this.gen2sb_mbx = gen2sb_mbx;
        this.mon2sb_mbx = mon2sb_mbx;
    endfunction

    //---------------------------------------------------------
    // run(): forever loop - pull one expected + one actual
    // transaction (blocking gets, so this naturally paces itself
    // to the slower of the two producers) and compare them.
    //---------------------------------------------------------
    task run();
        transaction exp_txn, act_txn;
        forever begin
            gen2sb_mbx.get(exp_txn);
            mon2sb_mbx.get(act_txn);
            check(exp_txn, act_txn);
        end
    endtask

    //---------------------------------------------------------
    // check(): compare one expected/actual pair, tally, and
    // print only on FAILURE (or a light PASS trace) to keep
    // logs readable during large random/stress runs.
    //---------------------------------------------------------
    task check(transaction exp_txn, transaction act_txn);
        bit match;
        total_count++;

        match = exp_txn.compare(act_txn);

        if (match) begin
            pass_count++;
        end else begin
            fail_count++;
            $display("[SCOREBOARD] *** MISMATCH on transaction #%0d ***", total_count);
            exp_txn.display("EXP");
            act_txn.display("ACT");
        end

        if (exp_txn.err_inject_parity && act_txn.parity_error)
            parity_err_match++;
        if (exp_txn.err_inject_framing && act_txn.framing_error)
            framing_err_match++;
    endtask

    //---------------------------------------------------------
    // report(): final summary, printed once at the end of a test
    // (per project rule: concise PASS/FAIL block, not per-packet
    // spam).
    //---------------------------------------------------------
    function void report();
        real pass_pct;
        pass_pct = (total_count > 0) ? (100.0 * pass_count / total_count) : 0.0;

        $display("========================================");
        $display("UART SCOREBOARD REPORT");
        $display("========================================");
        $display("Total             : %0d", total_count);
        $display("PASS              : %0d", pass_count);
        $display("FAIL              : %0d", fail_count);
        $display("Pass Percentage   : %0.2f%%", pass_pct);
        $display("Parity Err Matches: %0d", parity_err_match);
        $display("Framing Err Matches: %0d", framing_err_match);
        $display("========================================");
    endfunction

endclass : scoreboard
