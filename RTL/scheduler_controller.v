`timescale 1ns / 1ps

module scheduler_controller (
    input wire clk,
    input wire reset,
    input wire [1:0] mode,
    input wire [3:0] empty,
    input wire [15:0] weights,
    input wire request,
    input wire service,

    output reg [1:0] selected_queue,
    output reg select_valid
);

    wire [1:0] priority_queue;
    wire priority_valid;

    wire [1:0] rr_queue;
    wire rr_valid;

    wire [1:0] wrr_queue;
    wire wrr_valid;

    wire priority_request = request && (mode == 2'b00);
    wire rr_request       = request && (mode == 2'b01);
    wire wrr_request      = request && (mode == 2'b10);

    priority_scheduler U_PRIORITY (
        .empty(empty),
        .request(priority_request),
        .selected_queue(priority_queue),
        .select_valid(priority_valid)
    );

    round_robin_scheduler U_RR (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .request(rr_request),
        .service(service),
        .selected_queue(rr_queue),
        .select_valid(rr_valid)
    );

    weighted_rr_scheduler U_WRR (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .weight_q0(weights[3:0]),
        .weight_q1(weights[7:4]),
        .weight_q2(weights[11:8]),
        .weight_q3(weights[15:12]),
        .request(wrr_request),
        .service(service),
        .selected_queue(wrr_queue),
        .select_valid(wrr_valid)
    );

    always @(*) begin
        selected_queue = 2'b00;
        select_valid   = 1'b0;

        case (mode)
            2'b00: begin
                selected_queue = priority_queue;
                select_valid   = priority_valid;
            end

            2'b01: begin
                selected_queue = rr_queue;
                select_valid   = rr_valid;
            end

            2'b10: begin
                selected_queue = wrr_queue;
                select_valid   = wrr_valid;
            end

            default: begin
                selected_queue = 2'b00;
                select_valid   = 1'b0;
            end
        endcase
    end

endmodule