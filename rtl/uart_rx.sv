//=============================================================
// uart_rx.sv
//
// UART Receiver.
// FSM: IDLE -> START -> DATA -> PARITY(optional) -> STOP -> IDLE
//
// Key behavior (design_specification.md section 7):
//  - Detect HIGH->LOW edge on rx_serial while idle (candidate start).
//  - Wait HALF a bit period, re-check rx_serial is still LOW
//    (basic deglitch). If not low anymore -> false start, return
//    to IDLE silently (no framing_error, since no valid start
//    was ever confirmed).
//  - Once confirmed, sample every subsequent bit at the CENTER
//    of its bit period (one full bit period after the previous
//    sample point), not at arbitrary edges.
//  - rx_done pulses once per completed frame (start seen through
//    stop bit sampled), REGARDLESS of parity/framing error -
//    the byte is still delivered, flagged as suspect.
//=============================================================

module uart_rx (
    input  logic        clk,
    input  logic        rst,          // active-high, synchronous

    input  logic [15:0] baud_div,
    input  logic        parity_en,
    input  logic        parity_type,  // 0 = even, 1 = odd

    input  logic        rx_serial,

    output logic [7:0]  rx_data,
    output logic        rx_done,
    output logic        parity_error,
    output logic        framing_error
);

    // FSM states --------------------------------------------------
    typedef enum logic [2:0] {
        R_IDLE,
        R_START,     // waiting half a bit period to confirm start
        R_DATA,
        R_PARITY,
        R_STOP
    } rx_state_e;

    rx_state_e state, state_n;

    // Internal registers -------------------------------------------
    logic [15:0] baud_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  data_shift;      // shifting in received data bits
    logic        parity_en_lat;
    logic        parity_type_lat;
    logic        parity_bit_rx;   // sampled parity bit from the line
    logic        expected_parity; // recomputed from received data
    logic        rx_serial_prev;  // for edge detection

    // half-bit and full-bit tick targets.
    // half period = (baud_div+1)/2 clocks (rounded down - adequate
    // for a beginner-friendly, non-oversampled design).
    logic [15:0] half_bit;
    assign half_bit = baud_div >> 1;

    logic half_tick;   // pulses when baud_cnt reaches half_bit (used only in R_START)
    logic full_tick;   // pulses when baud_cnt reaches baud_div (bit period complete)
    assign half_tick = (baud_cnt == half_bit);
    assign full_tick = (baud_cnt == baud_div);

    logic start_edge;  // HIGH->LOW transition detected while idle
    assign start_edge = rx_serial_prev && !rx_serial;

    //-----------------------------------------------------------
    // Sequential state / counters
    //-----------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= R_IDLE;
            baud_cnt        <= '0;
            bit_idx         <= '0;
            data_shift      <= '0;
            parity_en_lat   <= 1'b0;
            parity_type_lat <= 1'b0;
            rx_serial_prev  <= 1'b1;
            rx_done         <= 1'b0;
            parity_error    <= 1'b0;
            framing_error   <= 1'b0;
            rx_data         <= '0;
        end else begin
            state          <= state_n;
            rx_serial_prev <= rx_serial;

            // Pulses default low each cycle, asserted explicitly below.
            rx_done       <= 1'b0;
            parity_error  <= 1'b0;
            framing_error <= 1'b0;

            // Baud counter: reset to 0 whenever we change state
            // (this naturally handles R_START->R_IDLE on false start,
            // and R_START->R_DATA on confirmed start, and every other
            // state transition), otherwise count up to full_tick/
            // half_tick and wrap within the same state.
            if (state != state_n) begin
                baud_cnt <= '0;
            end else if (state == R_START) begin
                baud_cnt <= baud_cnt + 16'd1;  // counts toward half_tick
            end else if (full_tick) begin
                baud_cnt <= '0;
            end else begin
                baud_cnt <= baud_cnt + 16'd1;
            end

            // Latch config the moment we confirm a valid start bit
            if (state == R_START && state_n == R_DATA) begin
                parity_en_lat   <= parity_en;
                parity_type_lat <= parity_type;
                bit_idx         <= '0;
            end

            // Shift in data bits at bit-center (full_tick while in R_DATA)
            if (state == R_DATA && full_tick) begin
                data_shift[bit_idx] <= rx_serial;
                bit_idx <= bit_idx + 3'd1;
            end

            // Sample parity bit at its bit-center
            if (state == R_PARITY && full_tick) begin
                parity_bit_rx <= rx_serial;
            end

            // Sample stop bit at its bit-center -> check framing,
            // and this is also where rx_done / parity_error fire.
            if (state == R_STOP && full_tick) begin
                rx_data <= data_shift;
                rx_done <= 1'b1;

                if (rx_serial != 1'b1)
                    framing_error <= 1'b1;

                if (parity_en_lat && (parity_bit_rx != expected_parity))
                    parity_error <= 1'b1;
            end
        end
    end

    //-----------------------------------------------------------
    // Expected parity, recomputed from the data actually received
    //-----------------------------------------------------------
    assign expected_parity = parity_type_lat ? ~(^data_shift) : (^data_shift);

    //-----------------------------------------------------------
    // Next-state logic (combinational)
    //-----------------------------------------------------------
    always_comb begin
        state_n = state;
        unique case (state)
            R_IDLE: begin
                if (start_edge)
                    state_n = R_START;
            end

            R_START: begin
                // At half_tick, re-check the line is still LOW.
                // If still low -> confirmed valid start, move to DATA.
                // If not low anymore -> false start / glitch, back to IDLE.
                if (half_tick) begin
                    if (rx_serial)
                        state_n = R_IDLE;
                    else
                        state_n = R_DATA;
                end
            end

            R_DATA: begin
                if (full_tick && (bit_idx == 3'd7)) begin
                    // Use the LATCHED parity_en (captured when this frame's
                    // start bit was confirmed), not the live input - the
                    // live input may already reflect the *next* frame's
                    // config if the testbench/system changes it early.
                    if (parity_en_lat)
                        state_n = R_PARITY;
                    else
                        state_n = R_STOP;
                end
            end

            R_PARITY: begin
                if (full_tick)
                    state_n = R_STOP;
            end

            R_STOP: begin
                if (full_tick)
                    state_n = R_IDLE;
            end

            default: state_n = R_IDLE;
        endcase
    end

endmodule : uart_rx
