
`timescale 1ns / 1ps

module priority_scheduler_tb;

reg [3:0] empty;
reg request;

wire [1:0] selected_queue;
wire select_valid;

integer errors;
integer i;

// DUT instantiation
priority_scheduler ps (
    .empty(empty),
    .request(request),
    .selected_queue(selected_queue),
    .select_valid(select_valid)
);

// Self-checking task
task check_result;
    input [3:0] test_empty;
    input test_request;
    input [1:0] expected_queue;
    input expected_valid;

    begin
        empty = test_empty;
        request = test_request;
        #10;

        if ((selected_queue !== expected_queue) ||
            (select_valid !== expected_valid)) begin
            $display("FAIL: empty=%b request=%b expected_queue=%b expected_valid=%b got_queue=%b got_valid=%b",
                empty, request, expected_queue, expected_valid,
                selected_queue, select_valid);
            errors = errors + 1;
        end
        else begin
            $display("PASS: empty=%b request=%b selected_queue=%b select_valid=%b",
                empty, request, selected_queue, select_valid);
        end
    end
endtask

initial begin
    errors = 0;

    $display("----------------------------------------");
    $display("PRIORITY SCHEDULER TESTBENCH");
    $display("Priority: Q0 > Q1 > Q2 > Q3");
    $display("----------------------------------------");

    // TEST 1: All queues contain data
    check_result(4'b0000, 1'b1, 2'b00, 1'b1);

    // TEST 2: Q0 is empty; Q1 has highest priority
    check_result(4'b1110, 1'b1, 2'b00, 1'b1);

    // TEST 3: Q0 is empty, Q1-Q3 available
    check_result(4'b0001, 1'b1, 2'b01, 1'b1);

    // TEST 4: Only Q1 available
    check_result(4'b1101, 1'b1, 2'b01, 1'b1);

    // TEST 5: Q0 and Q1 empty; Q2 selected
    check_result(4'b1011, 1'b1, 2'b10, 1'b1);

    // TEST 6: Only Q3 available
    check_result(4'b0111, 1'b1, 2'b11, 1'b1);

    // TEST 7: All queues empty
    check_result(4'b1111, 1'b1, 2'b00, 1'b0);

    // TEST 8: Request disabled
    check_result(4'b0000, 1'b0, 2'b00, 1'b0);

    // TEST 9: Required specification patterns
    check_result(4'b1000, 1'b1, 2'b00, 1'b1);
    check_result(4'b1100, 1'b1, 2'b00, 1'b1);

    // TEST 10: Exhaustively verify all 16 empty combinations
    $display("\nEXHAUSTIVE TEST");

    for (i = 0; i < 16; i = i + 1) begin
        if (i[0] == 1'b0)
            check_result(i, 1'b1, 2'b00, 1'b1);
        else if (i[1] == 1'b0)
            check_result(i, 1'b1, 2'b01, 1'b1);
        else if (i[2] == 1'b0)
            check_result(i, 1'b1, 2'b10, 1'b1);
        else if (i[3] == 1'b0)
            check_result(i, 1'b1, 2'b11, 1'b1);
        else
            check_result(i, 1'b1, 2'b00, 1'b0);
    end

    $display("\n----------------------------------------");

    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("TESTS FAILED: %0d errors", errors);

    $display("----------------------------------------");

    $finish;
end

endmodule
