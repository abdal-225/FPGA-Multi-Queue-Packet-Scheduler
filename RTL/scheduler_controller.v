
module scheduler_controller(
    input clk,
    input reset,
    input [1:0] mode,
    input [3:0] empty,
    input [15:0] weights,
    input request,
    output reg [1:0] selected_queue,
    output reg select_valid
);

    // Individual scheduler outputs
    wire [1:0] priority_queue;
    wire priority_valid;

    wire [1:0] rr_queue;
    wire rr_valid;

    wire [1:0] wrr_queue;
    wire wrr_valid;

    // Enable only the active scheduler
    wire priority_request;
    wire rr_request;
    wire wrr_request;

    assign priority_request = request && (mode == 2'b00);
    assign rr_request       = request && (mode == 2'b01);
    assign wrr_request      = request && (mode == 2'b10);

    // Priority Scheduler
    priority_scheduler U_PRIORITY (
        .empty(empty),
        .request(priority_request),
        .selected_queue(priority_queue),
        .select_valid(priority_valid)
    );

    // Round-Robin Scheduler
    round_robin_scheduler U_RR (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .request(rr_request),
        .selected_queue(rr_queue),
        .select_valid(rr_valid)
    );

    // Weighted Round-Robin Scheduler
    weighted_rr_scheduler U_WRR (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .weight_q0(weights[3:0]),
        .weight_q1(weights[7:4]),
        .weight_q2(weights[11:8]),
        .weight_q3(weights[15:12]),
        .request(wrr_request),
        .selected_queue(wrr_queue),
        .select_valid(wrr_valid)
    );

    
    // Select the active scheduler's output.
    always @(*) begin
        selected_queue = 2'b00;
        select_valid   = 1'b0;

        case (mode)
            2'b00: begin
                if (priority_valid) begin
                    selected_queue = priority_queue;
                    select_valid   = 1'b1;
                end
            end

            2'b01: begin
                if (rr_valid) begin
                    selected_queue = rr_queue;
                    select_valid   = 1'b1;
                end
            end

            2'b10: begin
                if (wrr_valid) begin
                    selected_queue = wrr_queue;
                    select_valid   = 1'b1;
                end
            end

            2'b11: begin
                selected_queue = 2'b00;
                select_valid   = 1'b0;
            end

            default: begin
                selected_queue = 2'b00;
                select_valid   = 1'b0;
            end
        endcase
    end


endmodule
