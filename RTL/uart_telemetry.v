`timescale 1ns / 1ps

module uart_telemetry #(
    parameter integer CLK_FREQ_HZ = 100000000,
    parameter integer BAUD_RATE = 115200,
    parameter integer REPORT_INTERVAL_CYCLES = 10000000
)(
    input wire clk,
    input wire reset,

    input wire [1:0] mode,
    input wire [1:0] selected_queue,
    input wire select_valid,

    input wire [3:0] empty,
    input wire [3:0] full,
    input wire [19:0] occupancy,

    input wire generated_valid,
    input wire [15:0] generated_packet,
    input wire [1:0] generated_queue,

    input wire enqueue_valid,
    input wire [15:0] enqueue_packet,
    input wire [1:0] enqueue_queue,

    input wire transmitted_valid,
    input wire [15:0] transmitted_packet,
    input wire [1:0] transmitted_queue,

    input wire [31:0] cycle_count,
    input wire [31:0] generated_count,
    input wire [31:0] transmitted_count,
    input wire [31:0] latency_count,
    input wire [31:0] throughput_count,

    output reg uart_tx,
    output reg buffer_overflow
);

    // 1. UART TRANSMITTER

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    reg [12:0] baud_timer;
    reg [3:0] tx_bit_idx;
    reg [9:0] tx_shift_reg;
    reg tx_busy;

    reg [7:0] tx_byte_data;
    reg tx_byte_valid;

    wire tx_ready = !tx_busy;

    always @(posedge clk) begin
        if (reset) begin
            uart_tx      <= 1'b1;
            tx_busy      <= 1'b0;
            baud_timer   <= 0;
            tx_bit_idx   <= 0;
            tx_shift_reg <= 10'b1111111111;
        end
        else begin
            if (tx_busy) begin
                if (baud_timer == CLKS_PER_BIT - 1) begin
                    baud_timer <= 0;

                    uart_tx      <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};

                    if (tx_bit_idx == 4'd9) begin
                        tx_busy    <= 0;
                        tx_bit_idx <= 0;
                    end
                    else begin
                        tx_bit_idx <= tx_bit_idx + 1'b1;
                    end
                end
                else begin
                    baud_timer <= baud_timer + 1'b1;
                end
            end
            else if (tx_byte_valid) begin
                tx_shift_reg <= {1'b1, tx_byte_data, 1'b0};
                tx_busy      <= 1'b1;
                baud_timer   <= 0;
                tx_bit_idx   <= 0;
            end
        end
    end

    // 2. EVENT FIFO

    reg [31:0] event_fifo [0:255];

    reg [7:0] fifo_head;
    reg [7:0] fifo_tail;
    reg [8:0] fifo_count;

    wire fifo_full  = (fifo_count == 9'd256);
    wire fifo_empty = (fifo_count == 0);

    // One pending slot per event type
    reg pending_gen;
    reg pending_enq;
    reg pending_tx;

    reg [31:0] cap_gen_data;
    reg [31:0] cap_enq_data;
    reg [31:0] cap_tx_data;

    // ============================================================
    // 3. FRAME BUILDER CONTROL
    // ============================================================

    localparam STATE_IDLE        = 2'd0;
    localparam STATE_SEND_EVENT  = 2'd1;
    localparam STATE_SEND_STATUS = 2'd2;

    reg [1:0] state;

    reg [31:0] status_timer;
    reg [5:0] frame_byte_idx;
    reg [7:0] checksum;

    reg [31:0] active_event_data;

    wire fifo_pop =
        (state == STATE_IDLE) &&
        !fifo_empty &&
        (status_timer != 0);

    wire pending_any =
        pending_gen || pending_enq || pending_tx;

    wire fifo_can_push = !fifo_full || fifo_pop;
    wire fifo_push = pending_any && fifo_can_push;

    wire push_gen = fifo_push && pending_gen;

    wire push_enq =
        fifo_push && !pending_gen && pending_enq;

    wire push_tx =
        fifo_push && !pending_gen &&
        !pending_enq && pending_tx;

    wire [31:0] fifo_push_data =
        push_gen ? cap_gen_data :
        push_enq ? cap_enq_data :
                   cap_tx_data;

    // 4. EVENT CAPTURE AND FIFO MANAGEMENT

    always @(posedge clk) begin
        if (reset) begin
            fifo_head <= 0;
            fifo_tail <= 0;
            fifo_count <= 0;

            pending_gen <= 0;
            pending_enq <= 0;
            pending_tx  <= 0;

            cap_gen_data <= 0;
            cap_enq_data <= 0;
            cap_tx_data  <= 0;

            buffer_overflow <= 0;
        end
        else begin

            // Generated event
            if (generated_valid) begin
                if (pending_gen && !push_gen)
                    buffer_overflow <= 1'b1;

                pending_gen <= 1'b1;

                cap_gen_data <= {
                    8'h01,
                    6'b000000,
                    generated_queue,
                    generated_packet
                };
            end
            else if (push_gen) begin
                pending_gen <= 1'b0;
            end

            // Successful enqueue event
            if (enqueue_valid) begin
                if (pending_enq && !push_enq)
                    buffer_overflow <= 1'b1;

                pending_enq <= 1'b1;

                cap_enq_data <= {
                    8'h02,
                    6'b000000,
                    enqueue_queue,
                    enqueue_packet
                };
            end
            else if (push_enq) begin
                pending_enq <= 1'b0;
            end

            // Transmission event
            if (transmitted_valid) begin
                if (pending_tx && !push_tx)
                    buffer_overflow <= 1'b1;

                pending_tx <= 1'b1;

                cap_tx_data <= {
                    8'h03,
                    6'b000000,
                    transmitted_queue,
                    transmitted_packet
                };
            end
            else if (push_tx) begin
                pending_tx <= 1'b0;
            end

            // FIFO write
            if (fifo_push) begin
                event_fifo[fifo_head] <= fifo_push_data;
                fifo_head <= fifo_head + 1'b1;
            end

            // FIFO read
            if (fifo_pop)
                fifo_tail <= fifo_tail + 1'b1;

            // FIFO occupancy
            case ({fifo_push, fifo_pop})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase

            if (pending_any && fifo_full && !fifo_pop)
                buffer_overflow <= 1'b1;
        end
    end

    // 5. FRAME BYTE GENERATOR

    reg [7:0] frame_byte;

    always @(*) begin
        frame_byte = 8'h00;

        case (state)

            STATE_SEND_EVENT: begin
                case (frame_byte_idx)
                    0: frame_byte = 8'hAA;
                    1: frame_byte = 8'h55;
                    2: frame_byte = active_event_data[31:24];
                    3: frame_byte = active_event_data[23:16];
                    4: frame_byte = active_event_data[7:0];
                    5: frame_byte = active_event_data[15:8];
                    6: frame_byte = checksum;
                    default: frame_byte = 8'h00;
                endcase
            end

            STATE_SEND_STATUS: begin
                case (frame_byte_idx)
                    0: frame_byte = 8'hAA;
                    1: frame_byte = 8'h55;
                    2: frame_byte = 8'h01;
                    3: frame_byte = {6'b0, mode};

                    4: frame_byte = select_valid ?
                                    {6'b0, selected_queue} : 8'hFF;

                    5: frame_byte = {7'b0, select_valid};
                    6: frame_byte = {4'b0, empty};
                    7: frame_byte = {4'b0, full};

                    8:  frame_byte = {3'b0, occupancy[4:0]};
                    9:  frame_byte = {3'b0, occupancy[9:5]};
                    10: frame_byte = {3'b0, occupancy[14:10]};
                    11: frame_byte = {3'b0, occupancy[19:15]};

                    12: frame_byte = generated_count[7:0];
                    13: frame_byte = generated_count[15:8];
                    14: frame_byte = generated_count[23:16];
                    15: frame_byte = generated_count[31:24];

                    16: frame_byte = transmitted_count[7:0];
                    17: frame_byte = transmitted_count[15:8];
                    18: frame_byte = transmitted_count[23:16];
                    19: frame_byte = transmitted_count[31:24];

                    20: frame_byte = cycle_count[7:0];
                    21: frame_byte = cycle_count[15:8];
                    22: frame_byte = cycle_count[23:16];
                    23: frame_byte = cycle_count[31:24];

                    24: frame_byte = latency_count[7:0];
                    25: frame_byte = latency_count[15:8];
                    26: frame_byte = latency_count[23:16];
                    27: frame_byte = latency_count[31:24];

                    28: frame_byte = throughput_count[7:0];
                    29: frame_byte = throughput_count[15:8];
                    30: frame_byte = throughput_count[23:16];
                    31: frame_byte = throughput_count[31:24];

                    32: frame_byte = checksum;

                    default: frame_byte = 8'h00;
                endcase
            end

            default: frame_byte = 8'h00;

        endcase
    end

    // 6. FRAME BUILDER FSM

    always @(posedge clk) begin
        if (reset) begin
            status_timer <= 0;
            state <= STATE_IDLE;
            frame_byte_idx <= 0;
            checksum <= 0;

            tx_byte_valid <= 0;
            tx_byte_data <= 0;

            active_event_data <= 0;
        end
        else begin
            tx_byte_valid <= 0;

            // 100 ms status reporting interval
            if (status_timer == REPORT_INTERVAL_CYCLES - 1)
                status_timer <= 0;
            else
                status_timer <= status_timer + 1'b1;

            case (state)

                STATE_IDLE: begin
                    frame_byte_idx <= 0;
                    checksum <= 0;

                    if (status_timer == 0) begin
                        state <= STATE_SEND_STATUS;
                    end
                    else if (fifo_pop) begin
                        active_event_data <= event_fifo[fifo_tail];
                        state <= STATE_SEND_EVENT;
                    end
                end

                STATE_SEND_EVENT: begin
                    if (tx_ready && !tx_byte_valid) begin
                        tx_byte_data  <= frame_byte;
                        tx_byte_valid <= 1'b1;

                        // Event payload bytes are indices 2 through 5.
                        if ((frame_byte_idx >= 2) &&
                            (frame_byte_idx <= 5))
                            checksum <= checksum + frame_byte;

                        if (frame_byte_idx < 6)
                            frame_byte_idx <= frame_byte_idx + 1'b1;
                        else begin
                            frame_byte_idx <= 0;
                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_SEND_STATUS: begin
                    if (tx_ready && !tx_byte_valid) begin
                        tx_byte_data  <= frame_byte;
                        tx_byte_valid <= 1'b1;

                        // Status payload bytes are indices 2 through 31.
                        if ((frame_byte_idx >= 2) &&
                            (frame_byte_idx <= 31))
                            checksum <= checksum + frame_byte;

                        if (frame_byte_idx < 32)
                            frame_byte_idx <= frame_byte_idx + 1'b1;
                        else begin
                            frame_byte_idx <= 0;
                            state <= STATE_IDLE;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    frame_byte_idx <= 0;
                    checksum <= 0;
                end

            endcase
        end
    end

endmodule