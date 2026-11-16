`timescale 1ns / 1ps

module round_robin_scheduler (
    input wire clk,
    input wire reset,
    input wire [3:0] empty,
    input wire request,
    input wire service,

    output reg [1:0] selected_queue,
    output reg select_valid
);

    reg [1:0] pointer;

    always @(*) begin
        selected_queue = pointer;
        select_valid   = 1'b0;

        if (request) begin
            case (pointer)
                2'd0: begin
                    if      (!empty[0]) begin selected_queue = 0; select_valid = 1; end
                    else if (!empty[1]) begin selected_queue = 1; select_valid = 1; end
                    else if (!empty[2]) begin selected_queue = 2; select_valid = 1; end
                    else if (!empty[3]) begin selected_queue = 3; select_valid = 1; end
                end

                2'd1: begin
                    if      (!empty[1]) begin selected_queue = 1; select_valid = 1; end
                    else if (!empty[2]) begin selected_queue = 2; select_valid = 1; end
                    else if (!empty[3]) begin selected_queue = 3; select_valid = 1; end
                    else if (!empty[0]) begin selected_queue = 0; select_valid = 1; end
                end

                2'd2: begin
                    if      (!empty[2]) begin selected_queue = 2; select_valid = 1; end
                    else if (!empty[3]) begin selected_queue = 3; select_valid = 1; end
                    else if (!empty[0]) begin selected_queue = 0; select_valid = 1; end
                    else if (!empty[1]) begin selected_queue = 1; select_valid = 1; end
                end

                2'd3: begin
                    if      (!empty[3]) begin selected_queue = 3; select_valid = 1; end
                    else if (!empty[0]) begin selected_queue = 0; select_valid = 1; end
                    else if (!empty[1]) begin selected_queue = 1; select_valid = 1; end
                    else if (!empty[2]) begin selected_queue = 2; select_valid = 1; end
                end
            endcase
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            pointer <= 2'd0;
        else if (service && select_valid)
            pointer <= selected_queue + 2'd1;
    end

endmodule