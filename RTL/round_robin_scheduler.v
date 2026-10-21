
module round_robin_scheduler (
    input clk, reset,
    input [3:0] empty,
    input request,
    output reg [1:0] selected_queue,
    output reg select_valid
);

    reg [1:0] pointer;

    // Combinational round-robin queue selection
    always @(*) begin
        selected_queue = pointer;
        select_valid = 1'b0;

        if (request) begin
            case (pointer)

                2'd0: begin
                    if      (!empty[0]) begin
                        selected_queue = 2'd0;
                        select_valid = 1'b1;
                    end
                    else if (!empty[1]) begin
                        selected_queue = 2'd1;
                        select_valid = 1'b1;
                    end
                    else if (!empty[2]) begin
                        selected_queue = 2'd2;
                        select_valid = 1'b1;
                    end
                    else if (!empty[3]) begin
                        selected_queue = 2'd3;
                        select_valid = 1'b1;
                    end
                end

                2'd1: begin
                    if      (!empty[1]) begin
                        selected_queue = 2'd1;
                        select_valid = 1'b1;
                    end
                    else if (!empty[2]) begin
                        selected_queue = 2'd2;
                        select_valid = 1'b1;
                    end
                    else if (!empty[3]) begin
                        selected_queue = 2'd3;
                        select_valid = 1'b1;
                    end
                    else if (!empty[0]) begin
                        selected_queue = 2'd0;
                        select_valid = 1'b1;
                    end
                end

                2'd2: begin
                    if      (!empty[2]) begin
                        selected_queue = 2'd2;
                        select_valid = 1'b1;
                    end
                    else if (!empty[3]) begin
                        selected_queue = 2'd3;
                        select_valid = 1'b1;
                    end
                    else if (!empty[0]) begin
                        selected_queue = 2'd0;
                        select_valid = 1'b1;
                    end
                    else if (!empty[1]) begin
                        selected_queue = 2'd1;
                        select_valid = 1'b1;
                    end
                end

                2'd3: begin
                    if      (!empty[3]) begin
                        selected_queue = 2'd3;
                        select_valid = 1'b1;
                    end
                    else if (!empty[0]) begin
                        selected_queue = 2'd0;
                        select_valid = 1'b1;
                    end
                    else if (!empty[1]) begin
                        selected_queue = 2'd1;
                        select_valid = 1'b1;
                    end
                    else if (!empty[2]) begin
                        selected_queue = 2'd2;
                        select_valid = 1'b1;
                    end
                end

                default: begin
                    selected_queue = 2'd0;
                    select_valid = 1'b0;
                end

            endcase
        end
    end

    // Pointer advances after a successful service.
    // request must be a one-cycle service strobe.
    always @(posedge clk or posedge reset) begin
        if (reset)
            pointer <= 2'd0;
        else if (request && select_valid)
            pointer <= selected_queue + 2'd1;
    end

endmodule
