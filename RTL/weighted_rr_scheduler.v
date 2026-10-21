
module weighted_rr_scheduler (
    input clk,
    input reset,
    input [3:0] empty,
    input [3:0] weight_q0,
    input [3:0] weight_q1,
    input [3:0] weight_q2,
    input [3:0] weight_q3,
    input request,
    output reg [1:0] selected_queue,
    output reg select_valid
);

    reg [1:0] pointer;
    reg [3:0] served_count;
    reg [3:0] selected_weight;

    // Find the next non-empty queue, starting from pointer.
    
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

    // Select the configured weight of the chosen queue.
    always @(*) begin
        case (selected_queue)
            2'd0: selected_weight = weight_q0;
            2'd1: selected_weight = weight_q1;
            2'd2: selected_weight = weight_q2;
            2'd3: selected_weight = weight_q3;
            default: selected_weight = 4'd1;
        endcase
    end

    // WRR state update.
    // request is treated as a one-cycle successful-service strobe.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pointer     <= 2'd0;
            served_count <= 4'd0;
        end
        else if (request && select_valid) begin

            // If the search skipped the current pointer, begin a
            // new quota for the queue that was actually selected.
            if (selected_queue != pointer) begin
                if (selected_weight <= 4'd1) begin
                    pointer      <= selected_queue + 2'd1;
                    served_count <= 4'd0;
                end
                else begin
                    pointer      <= selected_queue;
                    served_count <= 4'd1;
                end
            end

            // Current queue was selected.
            else begin
                if ((selected_weight <= 4'd1) ||
                    (served_count >= selected_weight - 4'd1)) begin
                    pointer      <= selected_queue + 2'd1;
                    served_count <= 4'd0;
                end
                else begin
                    pointer      <= selected_queue;
                    served_count <= served_count + 4'd1;
                end
            end
        end
    end

endmodule
