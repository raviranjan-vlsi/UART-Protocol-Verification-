//=============================================================
// coverage.sv
//
// Functional coverage (Phase 10). Samples every ACTUAL
// (observed) transaction from the monitor - coverage reflects
// what really happened on the bus, not just what was requested,
// per the architecture decision in Phase 3.
//
// Covers (per verification_plan.md section 3):
//   - data value ranges + the four boundary values
//   - baud configuration
//   - parity enable / parity type
//   - error injection outcomes (parity error, framing error)
//   - cross coverage: baud x parity, data pattern x parity,
//     parity x error type
//
// Kept intentionally small (few coverpoints, few bins) per the
// project rule "avoid huge coverage models that make simulation
// slow."
//=============================================================

class coverage;

    mailbox #(transaction) mon2cov_mbx;

    // The covergroup samples from these local fields, which are
    // updated just before each sample() call. Covergroups cannot
    // directly sample class-object members through a queue, so
    // this local-field-then-sample pattern is the standard idiom.
    bit [7:0] cov_data;
    bit       cov_parity_en;
    bit       cov_parity_type;
    bit [15:0] cov_baud_div;
    bit       cov_parity_error;
    bit       cov_framing_error;

    covergroup uart_cg;
        option.per_instance = 1;

        cp_data_value: coverpoint cov_data {
            bins bin_zero  = {8'h00};
            bins bin_ff    = {8'hFF};
            bins bin_aa    = {8'hAA};
            bins bin_55    = {8'h55};
            bins low_range   = {[8'h01 : 8'h3F]};
            bins mid_range   = {[8'h40 : 8'hBF]};
            bins high_range  = {[8'hC0 : 8'hFE]};
        }

        cp_parity_en: coverpoint cov_parity_en {
            bins bin_disabled = {1'b0};
            bins bin_enabled  = {1'b1};
        }

        cp_parity_type: coverpoint cov_parity_type {
            bins bin_even = {1'b0};
            bins bin_odd  = {1'b1};
        }

        cp_baud_config: coverpoint cov_baud_div {
            bins baud_fast   = {16'd9};
            bins baud_medium = {16'd19};
            bins baud_slow   = {16'd49};
        }

        cp_parity_error: coverpoint cov_parity_error {
            bins bin_no_error = {1'b0};
            bins bin_error    = {1'b1};
        }

        cp_framing_error: coverpoint cov_framing_error {
            bins bin_no_error = {1'b0};
            bins bin_error    = {1'b1};
        }

        // Cross coverage --------------------------------------
        cross_baud_x_parity: cross cp_baud_config, cp_parity_en;

        cross_data_x_parity: cross cp_data_value, cp_parity_en {
            // Ignore the wide low/mid/high range bins in the cross
            // to avoid an explosion of low-value bins; keep only
            // the four named boundary values crossed with parity.
            ignore_bins ignore_ranges =
                binsof(cp_data_value.low_range) ||
                binsof(cp_data_value.mid_range) ||
                binsof(cp_data_value.high_range);
        }

        cross_parity_x_errortype: cross cp_parity_en, cp_parity_error, cp_framing_error;

    endgroup

    function new(mailbox #(transaction) mon2cov_mbx);
        this.mon2cov_mbx = mon2cov_mbx;
        uart_cg = new();
    endfunction

    //---------------------------------------------------------
    // run(): forever loop - pull each observed transaction and
    // sample the covergroup. NOTE: coverage samples the ACTUAL/
    // observed data (rx_data etc. reconstructed by the monitor),
    // matching the architecture decision that coverage reflects
    // reality, not stimulus intent.
    //---------------------------------------------------------
    task run();
        transaction txn;
        forever begin
            mon2cov_mbx.get(txn);
            cov_data          = txn.rx_data;
            cov_parity_error  = txn.parity_error;
            cov_framing_error = txn.framing_error;
            // parity_en/parity_type/baud_div here come from the
            // monitor's frame-start snapshot (see monitor.sv's
            // run() task) rather than a live read at rx_done time,
            // which avoids a config-tagging race documented there.
            cov_parity_en     = txn.parity_en;
            cov_parity_type   = txn.parity_type;
            cov_baud_div      = txn.baud_div;
            uart_cg.sample();
        end
    endtask

    //---------------------------------------------------------
    // report(): final coverage percentage, printed once.
    //---------------------------------------------------------
    function void report();
        $display("========================================");
        $display("UART FUNCTIONAL COVERAGE");
        $display("========================================");
        $display("Coverage = %0.2f %%", uart_cg.get_coverage());
        $display("========================================");
    endfunction

endclass : coverage
