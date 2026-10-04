module performance_counter (
    input  wire        clk, reset, enable,
    input  wire        packet_generated,
    input  wire        packet_transmitted,
    input  wire [1:0]  selected_queue,

    output reg  [31:0] cycle_count,
    output reg  [31:0] generated_count,
    output reg  [31:0] transmitted_count
);

    always @(posedge clk) begin

        if (reset) begin
            cycle_count        <= 32'd0;
            generated_count    <= 32'd0;
            transmitted_count  <= 32'd0;
        end

        else if (enable) begin

            // Count active measurement cycles
            cycle_count <= cycle_count + 32'd1;

            // Count generated packets
            if (packet_generated)
                generated_count <= generated_count + 32'd1;

            // Count transmitted packets
            if (packet_transmitted)
                transmitted_count <= transmitted_count + 32'd1;

        end

    end

endmodule