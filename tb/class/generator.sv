//=============================================================
// generator.sv
//
// Generator responsibilities (per architecture.md / Phase 3):
//   - create transaction objects
//   - randomize them (respecting transaction constraints)
//   - support directed mode (specific field overrides) as well
//     as pure constrained-random mode
//   - send each transaction to the DRIVER (stimulus) via mailbox
//   - send a COPY of each transaction to the SCOREBOARD
//     (expected reference) via mailbox
//   - produce a BOUNDED number of transactions, then stop -
//     every test must terminate cleanly (no infinite loops).
//=============================================================

class generator;

    // Mailboxes connecting this generator to the driver and
    // scoreboard (set by the environment during build).
    mailbox #(transaction) gen2drv_mbx;
    mailbox #(transaction) gen2sb_mbx;

    // Event used to tell the environment/test that generation is
    // complete, so the test knows when it is safe to wind down
    // (see environment.sv run()).
    event gen_done;

    // Number of transactions to generate - configured by the
    // test before run() is called. Every test sets this to a
    // finite, bounded value (see test_plan.md for per-test counts).
    int num_transactions = 10;

    // Optional directed-override transaction. When non-null, the
    // generator sends exactly ONE copy of this transaction
    // (num_transactions is ignored) instead of randomizing - used
    // by directed test scenarios (TEST_RESET, TEST_PARITY_ERROR,
    // etc.) that need very specific field values.
    transaction directed_txn = null;

    // Optional field overrides for FOCUSED random tests (e.g.
    // TEST_NO_PARITY must force parity_en=0 on every transaction,
    // not just leave it to a 50/50 random draw - otherwise a test
    // named "no parity" would not reliably exercise that path at
    // all). Values: 2 = don't care (normal random constraints),
    // 0/1 = force the field to that fixed value. (Encoded as int
    // rather than a real tri-state type to keep this simple, per
    // the "avoid over-engineering" project rule.)
    int force_parity_en   = 2; // 2 = don't care
    int force_parity_type = 2; // 2 = don't care

    function new(mailbox #(transaction) gen2drv_mbx, mailbox #(transaction) gen2sb_mbx);
        this.gen2drv_mbx = gen2drv_mbx;
        this.gen2sb_mbx  = gen2sb_mbx;
    endfunction

    //---------------------------------------------------------
    // randomize_one(): randomizes a single transaction, applying
    // any active force_* overrides via an inline `with` constraint.
    // Kept separate from run() purely for readability.
    //---------------------------------------------------------
    function bit randomize_one(transaction txn);
        bit ok;
        if (force_parity_en != 2 && force_parity_type != 2) begin
            ok = txn.randomize() with {
                parity_en   == local::force_parity_en;
                parity_type == local::force_parity_type;
            };
        end else if (force_parity_en != 2) begin
            ok = txn.randomize() with {
                parity_en == local::force_parity_en;
            };
        end else if (force_parity_type != 2) begin
            ok = txn.randomize() with {
                parity_type == local::force_parity_type;
            };
        end else begin
            ok = txn.randomize();
        end
        return ok;
    endfunction

    //---------------------------------------------------------
    // run(): main generation loop. Bounded by num_transactions
    // (or a single directed transaction). Sends the SAME logical
    // transaction's data to both driver and scoreboard, but as
    // two SEPARATE copies (copy()), so the driver and scoreboard
    // never accidentally alias the same object handle.
    //---------------------------------------------------------
    task run();
        transaction txn;

        if (directed_txn != null) begin
            // Directed mode: exactly one transaction, no randomization.
            txn = directed_txn;
            gen2drv_mbx.put(txn.copy());
            gen2sb_mbx.put(txn.copy());
        end else begin
            // Constrained-random mode: bounded loop.
            for (int i = 0; i < num_transactions; i++) begin
                txn = new();
                if (!randomize_one(txn)) begin
                    $display("[GENERATOR] ERROR: randomize() failed on transaction %0d", i);
                end
                gen2drv_mbx.put(txn.copy());
                gen2sb_mbx.put(txn.copy());
            end
        end

        -> gen_done;
    endtask

endclass : generator
