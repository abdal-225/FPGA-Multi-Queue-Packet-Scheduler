`timescale 1ns / 1ps

module uart_telemetry #(
    parameter integer CLK_FREQ_HZ = 100000000,
    parameter integer BAUD_RATE = 115200,
    parameter integer REPORT_INTERVAL_CYCLES = 10000000 // 100 ms at 100 MHz
)(
    input wire clk,
    input wire reset,
    
    // Scheduler status
    input wire [1:0] mode,
    input wire [1:0] selected_queue,
    input wire select_valid,
    
    // Queue status
    input wire [3:0] empty,
    input wire [3:0] full,
    input wire [19:0] occupancy,
    
    // Packet generated event
    input wire generated_valid,
    input wire [15:0] generated_packet,
    input wire [1:0] generated_queue,
    
    // Successful queue insertion event
    input wire enqueue_valid,
    input wire [15:0] enqueue_packet,
    input wire [1:0] enqueue_queue,
    
    // Actual transmission event
    input wire transmitted_valid,
    input wire [15:0] transmitted_packet,
    input wire [1:0] transmitted_queue,
    
    // Performance counters
    input wire [31:0] cycle_count,
    input wire [31:0] generated_count,
    input wire [31:0] transmitted_count,
    input wire [31:0] latency_count,
    input wire [31:0] throughput_count,
    
    output reg uart_tx,
    output reg buffer_overflow // Exposes overflow status for LEDs/Debugging
);

    // ==========================================
    // UART Transmitter (115200 baud, 8-N-1)
    // ==========================================
    localparam CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    
    reg [12:0] baud_timer;
    reg [3:0]  tx_bit_idx;
    reg [9:0]  tx_shift_reg;
    reg        tx_busy;
    
    reg [7:0]  tx_byte_data;
    reg        tx_byte_valid;
    wire       tx_ready = ~tx_busy;

    always @(posedge clk) begin
        if (reset) begin
            uart_tx <= 1'b1;
            tx_busy <= 1'b0;
            baud_timer <= 0;
            tx_bit_idx <= 0;
            tx_shift_reg <= 10'b1111111111;
        end else begin
            if (tx_busy) begin
                if (baud_timer == CLKS_PER_BIT - 1) begin
                    baud_timer <= 0;
                    uart_tx <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    
                    if (tx_bit_idx == 9) begin
                        tx_busy <= 1'b0;
                        tx_bit_idx <= 0;
                    end else begin
                        tx_bit_idx <= tx_bit_idx + 1;
                    end
                end else begin
                    baud_timer <= baud_timer + 1;
                end
            end else if (tx_byte_valid) begin
                tx_shift_reg <= {1'b1, tx_byte_data, 1'b0};
                tx_busy <= 1'b1;
                baud_timer <= 0;
                tx_bit_idx <= 0;
            end
        end
    end

    // ==========================================
    // Telemetry Event FIFO (256 depth)
    // ==========================================
    // Stores: {Event Type (8), Queue ID (8), Packet Data (16)} = 32 bits wide
    reg [31:0] event_fifo [0:255];
    reg [7:0]  fifo_head;
    reg [7:0]  fifo_tail;
    reg [8:0]  fifo_count;
    
    wire fifo_full = (fifo_count == 256);
    wire fifo_empty = (fifo_count == 0);

    // Event Capture Logic (Handles simultaneous events)
    reg pending_gen, pending_enq, pending_tx;
    reg [31:0] cap_gen_data, cap_enq_data, cap_tx_data;

    always @(posedge clk) begin
        if (reset) begin
            fifo_head <= 0;
            fifo_tail <= 0;
            fifo_count <= 0;
            buffer_overflow <= 0;
            pending_gen <= 0; pending_enq <= 0; pending_tx <= 0;
        end else begin
            // Latch incoming events
            if (generated_valid) begin
                pending_gen <= 1;
                cap_gen_data <= {8'h01, 6'b0, generated_queue, generated_packet};
            end
            if (enqueue_valid) begin
                pending_enq <= 1;
                cap_enq_data <= {8'h02, 6'b0, enqueue_queue, enqueue_packet};
            end
            if (transmitted_valid) begin
                pending_tx <= 1;
                cap_tx_data <= {8'h03, 6'b0, transmitted_queue, transmitted_packet};
            end

            // Push to FIFO sequentially to avoid multi-port RAM overhead
            if (!fifo_full) begin
                if (pending_gen) begin
                    event_fifo[fifo_head] <= cap_gen_data;
                    fifo_head <= fifo_head + 1;
                    fifo_count <= fifo_count + 1 - (fifo_read_en ? 1 : 0);
                    pending_gen <= 0;
                end else if (pending_enq) begin
                    event_fifo[fifo_head] <= cap_enq_data;
                    fifo_head <= fifo_head + 1;
                    fifo_count <= fifo_count + 1 - (fifo_read_en ? 1 : 0);
                    pending_enq <= 0;
                end else if (pending_tx) begin
                    event_fifo[fifo_head] <= cap_tx_data;
                    fifo_head <= fifo_head + 1;
                    fifo_count <= fifo_count + 1 - (fifo_read_en ? 1 : 0);
                    pending_tx <= 0;
                end else if (fifo_read_en) begin
                    fifo_count <= fifo_count - 1;
                end
            end else if (pending_gen || pending_enq || pending_tx) begin
                buffer_overflow <= 1; // Flag overflow permanently until reset[cite: 8]
                if (fifo_read_en) fifo_count <= fifo_count - 1;
            end else if (fifo_read_en) begin
                fifo_count <= fifo_count - 1;
            end
            
            // Advance tail on read
            if (fifo_read_en) begin
                fifo_tail <= fifo_tail + 1;
            end
        end
    end

    // ==========================================
    // Frame Builder State Machine
    // ==========================================
    reg [31:0] status_timer;
    reg [5:0]  frame_byte_idx;
    reg [7:0]  checksum;
    reg        fifo_read_en;
    
    localparam STATE_IDLE        = 3'd0;
    localparam STATE_SEND_EVENT  = 3'd1;
    localparam STATE_SEND_STATUS = 3'd2;
    reg [2:0] state;

    reg [31:0] active_event_data;

    always @(posedge clk) begin
        if (reset) begin
            status_timer <= 0;
            state <= STATE_IDLE;
            tx_byte_valid <= 1'b0;
            frame_byte_idx <= 0;
            checksum <= 0;
            fifo_read_en <= 0;
        end else begin
            tx_byte_valid <= 1'b0;
            fifo_read_en <= 0;
            
            if (status_timer == REPORT_INTERVAL_CYCLES - 1) begin
                status_timer <= 0;
            end else begin
                status_timer <= status_timer + 1;
            end

            case (state)
                STATE_IDLE: begin
                    frame_byte_idx <= 0;
                    checksum <= 0;
                    
                    if (status_timer == 0) begin
                        state <= STATE_SEND_STATUS;
                    end else if (!fifo_empty) begin
                        active_event_data <= event_fifo[fifo_tail];
                        fifo_read_en <= 1'b1;
                        state <= STATE_SEND_EVENT;
                    end
                end

                STATE_SEND_EVENT: begin
                    if (tx_ready && !tx_byte_valid) begin
                        tx_byte_valid <= 1'b1;
                        case (frame_byte_idx)
                            0: tx_byte_data <= 8'hAA; // Sync 1[cite: 6]
                            1: tx_byte_data <= 8'h55; // Sync 2[cite: 6]
                            2: tx_byte_data <= active_event_data[31:24]; // Event type
                            3: tx_byte_data <= active_event_data[23:16]; // Queue ID
                            4: tx_byte_data <= active_event_data[7:0];   // Packet low byte[cite: 7]
                            5: tx_byte_data <= active_event_data[15:8];  // Packet high byte[cite: 7]
                            6: tx_byte_data <= checksum;
                            default: tx_byte_valid <= 1'b0;
                        endcase

                        if (frame_byte_idx < 6) begin
                            checksum <= checksum + tx_byte_data;
                            frame_byte_idx <= frame_byte_idx + 1;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_SEND_STATUS: begin
                    if (tx_ready && !tx_byte_valid) begin
                        tx_byte_valid <= 1'b1;
                        case (frame_byte_idx)
                            0: tx_byte_data <= 8'hAA;
                            1: tx_byte_data <= 8'h55;
                            2: tx_byte_data <= 8'h01; // Protocol version
                            3: tx_byte_data <= {6'b0, mode};
                            4: tx_byte_data <= select_valid ? {6'b0, selected_queue} : 8'hFF;
                            5: tx_byte_data <= {7'b0, select_valid};
                            6: tx_byte_data <= {4'b0, empty};
                            7: tx_byte_data <= {4'b0, full};
                            8: tx_byte_data <= {3'b0, occupancy[4:0]};
                            9: tx_byte_data <= {3'b0, occupancy[9:5]};
                            10: tx_byte_data <= {3'b0, occupancy[14:10]};
                            11: tx_byte_data <= {3'b0, occupancy[19:15]};
                            12: tx_byte_data <= generated_count[7:0];
                            13: tx_byte_data <= generated_count[15:8];
                            14: tx_byte_data <= generated_count[23:16];
                            15: tx_byte_data <= generated_count[31:24];
                            16: tx_byte_data <= transmitted_count[7:0];
                            17: tx_byte_data <= transmitted_count[15:8];
                            18: tx_byte_data <= transmitted_count[23:16];
                            19: tx_byte_data <= transmitted_count[31:24];
                            20: tx_byte_data <= cycle_count[7:0];
                            21: tx_byte_data <= cycle_count[15:8];
                            22: tx_byte_data <= cycle_count[23:16];
                            23: tx_byte_data <= cycle_count[31:24];
                            24: tx_byte_data <= latency_count[7:0];
                            25: tx_byte_data <= latency_count[15:8];
                            26: tx_byte_data <= latency_count[23:16];
                            27: tx_byte_data <= latency_count[31:24];
                            28: tx_byte_data <= throughput_count[7:0];
                            29: tx_byte_data <= throughput_count[15:8];
                            30: tx_byte_data <= throughput_count[23:16];
                            31: tx_byte_data <= throughput_count[31:24];
                            32: tx_byte_data <= checksum;
                            default: tx_byte_valid <= 1'b0; 
                        endcase
                        
                        if (frame_byte_idx < 32) begin
                            checksum <= checksum + tx_byte_data;
                            frame_byte_idx <= frame_byte_idx + 1;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end
                end
            endcase
        end
    end
endmodule