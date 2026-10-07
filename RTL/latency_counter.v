module latency_counter (
    input        clk, reset,
    input        packet_arrival,
    input        packet_departure,

    output reg [31:0] latency_cycles,
    output reg [31:0] average_latency
);
    reg [31:0] cycle_counter;
    reg [31:0] arrival_timestamp;
    reg [31:0] total_latency;
    reg [31:0] packet_count;

    always @(posedge clk) begin

        if (reset) begin
            cycle_counter     <= 32'd0;
            arrival_timestamp <= 32'd0;
            latency_cycles    <= 32'd0;
            average_latency   <= 32'd0;
            total_latency     <= 32'd0;
            packet_count      <= 32'd0;
        end

        else begin

            // Global timestamp counter
            cycle_counter <= cycle_counter + 32'd1;

            // Record arrival timestamp
            if (packet_arrival) begin
                arrival_timestamp <= cycle_counter;
            end

            // Calculate latency when packet departs
            if (packet_departure) begin

                latency_cycles <= cycle_counter - arrival_timestamp;

                total_latency <= total_latency +
                                 (cycle_counter - arrival_timestamp);

                packet_count <= packet_count + 32'd1;

                // Average latency in clock cycles
                average_latency <=
                    (total_latency +
                     (cycle_counter - arrival_timestamp))
                    / (packet_count + 32'd1);
            end
        end
    end

endmodule
