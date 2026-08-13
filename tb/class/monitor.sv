//=============================================================
// monitor.sv
//
// Monitor responsibilities (per architecture.md / Phase 3):
//   - PASSIVE observation only - never drives a single DUT pin
//   - watch rx_done/rx_data/parity_error/framing_error
//   - reconstruct an "actual" transaction reflecting what the
//     RX side really produced
//   - forward that actual transaction to the SCOREBOARD and to
//     COVERAGE (two separate mailboxes, since each consumer
//     needs its own copy - never share a single handle between
//     two independent consumers)
//
// NOTE: the monitor only reconstructs what RX observed (rx_data,
// parity_error, framing_error). It does not know, and does not
// need to know, what error injection was originally REQUESTED -
// that comparison is entirely the scoreboard's job, using the
// expected transaction supplied separately by the generator.
//=============================================================

class monitor;

    virtual uart_if vif;
    mailbox #(transaction) mon2sb_mbx;
    mailbox #(transaction) mon2cov_mbx;

    // Tracks whether a frame is currently being received, so we
    // only treat a HIGH->LOW transition on rx_serial as a new
    // start bit when the line was previously idle - a data bit
    // inside an in-progress frame can also go low, and must NOT
    // be mistaken for a new frame start.
    //
    // KNOWN LIMITATION: if a glitch on rx_serial were injected
    // (vplan row 28, marked optional/stretch and NOT implemented
    // in this project's test suite), the RTL would reject it and
    // never pulse rx_done, which would leave frame_in_progress
    // stuck at 1 forever, silently disabling the monitor. Since
    // glitch injection is out of scope here, this is documented
    // rather than solved - a full solution would add a timeout-
    // based recovery (e.g. clear frame_in_progress if rx_done
    // hasn't arrived within some generous multiple of the current
    // baud_div's bit period).
    bit frame_in_progress;

    function new(virtual uart_if vif,
                 mailbox #(transaction) mon2sb_mbx,
                 mailbox #(transaction) mon2cov_mbx);
        this.vif          = vif;
        this.mon2sb_mbx   = mon2sb_mbx;
        this.mon2cov_mbx  = mon2cov_mbx;
        this.frame_in_progress = 1'b0;
    endfunction

    //---------------------------------------------------------
    // run(): reconstructs one transaction per UART frame.
    //
    // TIMING NOTE (found during Phase 7 review): parity_en /
    // parity_type / baud_div must be captured at FRAME START,
    // not at rx_done. If the driver begins the NEXT frame the
    // instant tx_busy drops, and RX (which lags TX by about half
    // a bit period due to the start-bit deglitch delay) hasn't
    // fired rx_done for the PREVIOUS frame yet, reading the live
    // config at rx_done time could pick up the next frame's
    // config instead of the frame actually being reported. This
    // race led to intermittent coverage cross-tagging errors
    // during code review and is fixed by snapshotting config at
    // the start-bit edge instead, when there is no ambiguity
    // about which frame it belongs to.
    //---------------------------------------------------------
    task run();
        transaction obs;
        bit        snap_parity_en;
        bit        snap_parity_type;
        bit [15:0] snap_baud_div;

        forever begin
            @(posedge vif.clk);

            // Detect a genuine new-frame start: line is LOW now,
            // was HIGH one cycle ago is implicitly guaranteed by
            // frame_in_progress being 0 (we only look for starts
            // while idle).
            if (!frame_in_progress && vif.rx_serial === 1'b0) begin
                frame_in_progress = 1'b1;
                snap_parity_en    = vif.parity_en;
                snap_parity_type  = vif.parity_type;
                snap_baud_div     = vif.baud_div;
            end

            if (vif.rx_done === 1'b1) begin
                obs = new();
                obs.rx_data        = vif.rx_data;
                obs.parity_error   = vif.parity_error;
                obs.framing_error  = vif.framing_error;
                obs.rx_done_seen   = 1'b1;
                obs.parity_en      = snap_parity_en;
                obs.parity_type    = snap_parity_type;
                obs.baud_div       = snap_baud_div;

                mon2sb_mbx.put(obs.copy());
                mon2cov_mbx.put(obs.copy());

                frame_in_progress = 1'b0;
            end
        end
    endtask

endclass : monitor
