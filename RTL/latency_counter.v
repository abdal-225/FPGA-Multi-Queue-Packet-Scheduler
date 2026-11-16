`timescale 1ns / 1ps

module latency_counter (
    input wire clk,
    input wire reset,
    input wire packet_arrival,
    input wire [1:0] arrival_queue,
    input wire packet_departure,
    input wire [1:0] departure_queue,

    output reg [31:0] latency_cycles,
    output reg [31:0] average_latency
);

    reg [31:0] cycle_counter;
    reg [31:0] timestamp_mem [0:3][0:255];

    reg [7:0] wr_ptr [0:3];
    reg [7:0] rd_ptr [0:3];
    reg [8:0] queue_count [0:3];

    reg [63:0] total_latency;
    reg [31:0] packet_count;

    wire [31:0] current_latency =
        cycle_counter - timestamp_mem[departure_queue][rd_ptr[departure_queue]];

    wire [63:0] next_total_latency =
        total_latency + current_latency;

    wire [31:0] next_packet_count =
        packet_count + 32'd1;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            cycle_counter   <= 0;
            latency_cycles  <= 0;
            average_latency <= 0;
            total_latency   <= 0;
            packet_count    <= 0;

            for (i = 0; i < 4; i = i + 1) begin
                wr_ptr[i]     <= 0;
                rd_ptr[i]     <= 0;
                queue_count[i] <= 0;
            end
        end
        else begin
            cycle_counter <= cycle_counter + 1'b1;

            // Record an arrival timestamp in its queue's timestamp FIFO.
            if (packet_arrival &&
                queue_count[arrival_queue] < 9'd256) begin

                timestamp_mem[arrival_queue][wr_ptr[arrival_queue]]
                    <= cycle_counter;

                wr_ptr[arrival_queue] <=
                    wr_ptr[arrival_queue] + 1'b1;
            end

            // Record departure latency using the oldest timestamp
            // belonging to the departing queue.
            if (packet_departure &&
                queue_count[departure_queue] != 0) begin

                latency_cycles <= current_latency;
                total_latency  <= next_total_latency;
                packet_count   <= next_packet_count;

                average_latency <=
                    next_total_latency / next_packet_count;

                rd_ptr[departure_queue] <=
                    rd_ptr[departure_queue] + 1'b1;
            end

            // Maintain each queue's timestamp FIFO occupancy.
            for (i = 0; i < 4; i = i + 1) begin
                case ({
                    packet_arrival &&
                    (arrival_queue == i) &&
                    (queue_count[i] < 9'd256),

                    packet_departure &&
                    (departure_queue == i) &&
                    (queue_count[i] != 0)
                })
                    2'b10:
                        queue_count[i] <= queue_count[i] + 1'b1;

                    2'b01:
                        queue_count[i] <= queue_count[i] - 1'b1;

                    default:
                        queue_count[i] <= queue_count[i];
                endcase
            end
        end
    end

endmodule