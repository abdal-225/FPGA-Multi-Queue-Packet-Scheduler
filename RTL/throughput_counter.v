`timescale 1ns / 1ps

module throughput_counter #(
    parameter integer SCHEDULER_CLOCK_HZ = 2,
    parameter integer WINDOW_SECONDS = 1
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire packet_transmitted,
    input wire [31:0] measurement_cycles,

    output reg [31:0] throughput_count
);

    localparam integer WINDOW_CYCLES =
        SCHEDULER_CLOCK_HZ * WINDOW_SECONDS;

    reg [31:0] window_cycles;
    reg [31:0] window_packets;

    wire [31:0] next_window_packets =
        window_packets + (packet_transmitted ? 32'd1 : 32'd0);

    always @(posedge clk) begin
        if (reset) begin
            window_cycles    <= 0;
            window_packets   <= 0;
            throughput_count <= 0;
        end
        else if (!enable) begin
            window_cycles  <= 0;
            window_packets <= 0;
        end
        else begin
            if (packet_transmitted)
                window_packets <= next_window_packets;

            if (window_cycles == WINDOW_CYCLES - 1) begin
                throughput_count <= next_window_packets;
                window_cycles    <= 0;
                window_packets   <= 0;
            end
            else begin
                window_cycles <= window_cycles + 1'b1;
            end
        end
    end

endmodule