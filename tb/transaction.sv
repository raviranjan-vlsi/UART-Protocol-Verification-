//=============================================================
// transaction.sv
//
// UART transaction: the data object that flows between every
// component in the environment (generator -> driver, generator
// -> scoreboard, monitor -> scoreboard, monitor -> coverage).
//
// Contains:
//   - rand STIMULUS fields  : what the generator randomizes and
//                              the driver applies to the DUT.
//   - OBSERVED fields       : filled in by the monitor after
//                              watching the DUT, never randomized.
//
// Per project rule: avoid randomizing fields that shouldn't be
// random (baud_div/parity_type are randomized only from a legal
// SET of values via constraints, not from the full bit range).
//=============================================================

class transaction;

    //---------------------------------------------------------
    // Legal baud divider values used for constrained-random
    // baud selection (TEST_BAUD_RATE / TEST_STRESS). Kept small
    // so simulation stays fast while still exercising a real
    // spread of timings (fast / medium / slow bit periods).
    //---------------------------------------------------------
    static bit [15:0] LEGAL_BAUD_DIVS[3] = '{16'd9, 16'd19, 16'd49};
    // 10, 20, 50 clocks/bit respectively.

    //---------------------------------------------------------
    // STIMULUS fields (randomized by generator, driven by driver)
    //---------------------------------------------------------
    rand bit [7:0]  data;            // byte to transmit
    rand bit        parity_en;       // 1 = frame includes a parity bit
    rand bit        parity_type;     // 0 = even, 1 = odd (ignored if !parity_en)
    rand bit [15:0] baud_div;        // bit period = (baud_div+1) clocks

    // Error injection controls - intent, not the corrupted bit
    // itself. The DRIVER's fault injector reads these and
    // corrupts the wire; the transaction just carries INTENT so
    // the scoreboard knows what to expect.
    rand bit        err_inject_parity;    // corrupt the parity bit on the wire
    rand bit        err_inject_framing;   // corrupt the stop bit on the wire

    //---------------------------------------------------------
    // OBSERVED fields (filled in by monitor, never randomized)
    //---------------------------------------------------------
    bit [7:0] rx_data;
    bit       parity_error;
    bit       framing_error;
    bit       rx_done_seen;     // did rx_done ever pulse for this txn

    //---------------------------------------------------------
    // Constraints
    //---------------------------------------------------------

    // baud_div must come from the legal set, not an arbitrary
    // 16-bit value (an arbitrary value could produce a bit
    // period of 1 clock, which is unrealistic and not part of
    // the verified feature set per the test plan).
    constraint c_baud_div {
        baud_div inside {LEGAL_BAUD_DIVS[0], LEGAL_BAUD_DIVS[1], LEGAL_BAUD_DIVS[2]};
    }

    // Error injection should be RARE by default (stress test
    // wants mostly-clean traffic with occasional errors - see
    // test_plan.md TEST_STRESS). Directed error tests override
    // this by setting the fields directly instead of randomizing.
    constraint c_error_injection_rare {
        err_inject_parity   dist { 1'b0 := 90, 1'b1 := 10 };
        err_inject_framing  dist { 1'b0 := 90, 1'b1 := 10 };
    }

    // Framing-error injection only makes sense as a distinct,
    // isolatable event; don't let both errors always co-occur
    // unless we specifically want that (dual-error scenario is
    // still reachable since both constraints are independent -
    // ~1% of random transactions will naturally get both, which
    // is enough to hit the vplan's "both errors" cross bin over
    // a large stress run without dominating every frame).

    // A parity bit only EXISTS in the frame when parity_en=1, so
    // it makes no sense to "inject a parity error" on a frame
    // that has no parity bit at all. Force the field to 0 when
    // parity is disabled (implication constraint).
    constraint c_parity_err_requires_parity_en {
        if (!parity_en) err_inject_parity == 1'b0;
    }

    //---------------------------------------------------------
    // Constructor
    //---------------------------------------------------------
    function new(string name = "transaction");
        // 'name' accepted for readability/debug only, not stored
        // (kept minimal per "avoid over-engineering" instruction).
    endfunction

    //---------------------------------------------------------
    // copy(): deep-copy all fields into a new transaction handle.
    // Used by generator/scoreboard when the same logical
    // transaction needs to be safely held by more than one
    // component without aliasing.
    //---------------------------------------------------------
    function transaction copy();
        transaction t = new();
        t.data               = this.data;
        t.parity_en           = this.parity_en;
        t.parity_type          = this.parity_type;
        t.baud_div             = this.baud_div;
        t.err_inject_parity    = this.err_inject_parity;
        t.err_inject_framing   = this.err_inject_framing;
        t.rx_data              = this.rx_data;
        t.parity_error         = this.parity_error;
        t.framing_error        = this.framing_error;
        t.rx_done_seen          = this.rx_done_seen;
        return t;
    endfunction

    //---------------------------------------------------------
    // compare(): used by the scoreboard to check EXPECTED (this)
    // against ACTUAL (the argument). Returns 1 if they match per
    // the rules in design_specification.md section 9:
    //   - data must always match
    //   - parity_error must be asserted iff err_inject_parity was set
    //   - framing_error must be asserted iff err_inject_framing was set
    //---------------------------------------------------------
    function bit compare(transaction actual);
        bit data_ok, perr_ok, ferr_ok, done_ok;

        data_ok = (this.data === actual.rx_data);
        perr_ok = (this.err_inject_parity === actual.parity_error);
        ferr_ok = (this.err_inject_framing === actual.framing_error);
        done_ok = (actual.rx_done_seen === 1'b1);

        return (data_ok && perr_ok && ferr_ok && done_ok);
    endfunction

    //---------------------------------------------------------
    // display(): concise single-line print for debug logging.
    // Per project rule: scoreboard must not print thousands of
    // lines, so this is deliberately compact.
    //---------------------------------------------------------
    function void display(string tag = "TXN");
        $display("[%-4s] data=0x%02h pe=%0b ptype=%0b baud_div=%0d err_p=%0b err_f=%0b | rx_data=0x%02h perr=%0b ferr=%0b done=%0b",
                  tag, data, parity_en, parity_type, baud_div, err_inject_parity, err_inject_framing,
                  rx_data, parity_error, framing_error, rx_done_seen);
    endfunction

endclass : transaction
