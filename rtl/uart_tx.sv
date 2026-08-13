//=============================================================
// uart_tx.sv
//
// UART Transmitter.
// FSM: IDLE -> START -> DATA -> PARITY(optional) -> STOP -> IDLE
//
// Frame format (per design_specification.md section 5):
//   1 start bit (0) | 8 data bits (LSB first) | [1 parity bit] | 1 stop bit (1)
//
// One bit period = (baud_div + 1) clock cycles.
// tx_start is accepted only while not busy (spec section 11 corner case).
//=============================================================

module uart_tx (
    input  logic        clk,
    input  logic        rst,          // active-high, synchronous

    input  logic [15:0] baud_div,
    input  logic        parity_en,
    input  logic        parity_type,  // 0 = even, 1 = odd

    input  logic [7:0]  tx_data,
    input  logic        tx_start,

    output logic        tx_busy,
    output logic        tx_done,
    output logic        tx_serial
);

    // FSM states --------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_PARITY,
        S_STOP
    } tx_state_e;

    tx_state_e state, state_n;

    // Internal registers -------------------------------------------
    logic [15:0] baud_cnt;        // counts clocks within one bit period
    logic [2:0]  bit_idx;         // which data bit (0..7) is being sent
    logic [7:0]  data_shift;      // latched data for this frame
    logic        parity_en_lat;   // latched parity config for this frame
    logic        parity_type_lat;
    logic        parity_bit;      // computed parity value for this frame

    // A "bit period complete" pulse: true on the last clock cycle
    // of the current bit period.
    logic bit_tick;
    assign bit_tick = (baud_cnt == baud_div);

    //-----------------------------------------------------------
    // Sequential state / counters
    //-----------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            baud_cnt    <= '0;
            bit_idx     <= '0;
            data_shift  <= '0;
            parity_en_lat   <= 1'b0;
            parity_type_lat <= 1'b0;
            tx_done     <= 1'b0;
        end else begin
            state <= state_n;

            // tx_done is a single-cycle pulse: default deassert,
            // asserted explicitly below when STOP bit completes.
            tx_done <= 1'b0;

            // Baud counter: reset to 0 whenever we change state,
            // otherwise increment until bit_tick, then wrap.
            if (state != state_n) begin
                baud_cnt <= '0;
            end else if (bit_tick) begin
                baud_cnt <= '0;
            end else begin
                baud_cnt <= baud_cnt + 16'd1;
            end

            // Latch frame data/config at the moment we leave IDLE
            if (state == S_IDLE && state_n == S_START) begin
                data_shift      <= tx_data;
                parity_en_lat   <= parity_en;
                parity_type_lat <= parity_type;
                bit_idx         <= '0;
            end

            // Advance bit index while shifting out data bits
            if (state == S_DATA && bit_tick) begin
                bit_idx <= bit_idx + 3'd1;
            end

            // Signal tx_done on the tick that completes the STOP bit
            if (state == S_STOP && bit_tick) begin
                tx_done <= 1'b1;
            end
        end
    end

    //-----------------------------------------------------------
    // Parity computation (combinational, from latched data)
    // even parity: parity_bit makes total ones EVEN
    // odd  parity: parity_bit makes total ones ODD
    //-----------------------------------------------------------
    assign parity_bit = parity_type_lat ? ~(^data_shift) : (^data_shift);
    // ^data_shift = XOR reduction = 1 if odd number of 1s in data.
    // even parity bit = ^data_shift (adds a 1 exactly when data has odd # of ones)
    // odd  parity bit = ~^data_shift

    //-----------------------------------------------------------
    // Next-state logic (combinational)
    //-----------------------------------------------------------
    always_comb begin
        state_n = state;
        unique case (state)
            S_IDLE: begin
                if (tx_start && !tx_busy)
                    state_n = S_START;
            end

            S_START: begin
                if (bit_tick)
                    state_n = S_DATA;
            end

            S_DATA: begin
                if (bit_tick && (bit_idx == 3'd7)) begin
                    if (parity_en_lat)
                        state_n = S_PARITY;
                    else
                        state_n = S_STOP;
                end
            end

            S_PARITY: begin
                if (bit_tick)
                    state_n = S_STOP;
            end

            S_STOP: begin
                if (bit_tick)
                    state_n = S_IDLE;
            end

            default: state_n = S_IDLE;
        endcase
    end

    //-----------------------------------------------------------
    // Output logic
    //-----------------------------------------------------------
    assign tx_busy = (state != S_IDLE);

    always_comb begin
        unique case (state)
            S_IDLE   : tx_serial = 1'b1;
            S_START  : tx_serial = 1'b0;
            S_DATA   : tx_serial = data_shift[bit_idx];
            S_PARITY : tx_serial = parity_bit;
            S_STOP   : tx_serial = 1'b1;
            default  : tx_serial = 1'b1;
        endcase
    end

endmodule : uart_tx
