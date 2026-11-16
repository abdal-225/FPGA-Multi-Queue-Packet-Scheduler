`timescale 1ns / 1ps

module performance_counter (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire packet_generated,
    input wire packet_transmitted,
    input wire [1:0] selected_queue,

    output reg [31:0] cycle_count,
    output reg [31:0] generated_count,
    output reg [31:0] transmitted_count
);

    always @(posedge clk) begin
        if (reset) begin
            cycle_count       <= 0;
            generated_count   <= 0;
            transmitted_count <= 0;
        end
        else if (enable) begin
            cycle_count <= cycle_count + 1'b1;

            if (packet_generated)
                generated_count <= generated_count + 1'b1;

            if (packet_transmitted)
                transmitted_count <= transmitted_count + 1'b1;
        end
    end

endmodule