module throughput_counter (
    input        clk, reset, enable,
    input        packet_transmitted,
    input [31:0] measurement_cycles,
    
    output reg [31:0] throughput_count
);

    reg [31:0] cycle_count;

    always @(posedge clk) begin

        if (reset) begin
            cycle_count     <= 32'd0;
            throughput_count <= 32'd0;
        end

        else if (enable) begin

            // Count transmitted packets
            if (packet_transmitted)
                throughput_count <= throughput_count + 32'd1;

            // Count measurement cycles
            if (cycle_count < measurement_cycles)
                cycle_count <= cycle_count + 32'd1;

        end

        else begin
            cycle_count <= 32'd0;
        end

    end

endmodule