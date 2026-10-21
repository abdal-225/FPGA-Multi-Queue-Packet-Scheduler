
`timescale 1ns / 1ps

module weighted_rr_scheduler_tb;

    reg clk;
    reg reset;
    reg [3:0] empty;
    reg [3:0] weight_q0;
    reg [3:0] weight_q1;
    reg [3:0] weight_q2;
    reg [3:0] weight_q3;
    reg request;

    wire [1:0] selected_queue;
    wire select_valid;

    integer tests;
    integer errors;
    integer i;

    reg [1:0] expected_pattern [0:9];

    weighted_rr_scheduler uut (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .weight_q0(weight_q0),
        .weight_q1(weight_q1),
        .weight_q2(weight_q2),
        .weight_q3(weight_q3),
        .request(request),
        .selected_queue(selected_queue),
        .select_valid(select_valid)
    );

    // 100 MHz clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Check one service and update the WRR state.
    task service_and_check;
        input [3:0] test_empty;
        input [1:0] expected_queue;

        begin
            @(negedge clk);
            empty = test_empty;
            request = 1'b1;
            #1;

            tests = tests + 1;

            if ((select_valid !== 1'b1) ||
                (selected_queue !== expected_queue)) begin
                $display(
                    "FAIL: Expected Q%0d, got Q%0d valid=%b",
                    expected_queue, selected_queue, select_valid
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Selected Q%0d, empty=%b",
                    selected_queue, test_empty
                );
            end

            // Allow the service strobe to reach the next rising edge.
            @(posedge clk);
            #1;

            // Deassert before another rising edge.
            @(negedge clk);
            request = 1'b0;
        end
    endtask

    // Check selection without performing a service.
    task selection_only_check;
        input [3:0] test_empty;
        input test_request;
        input [1:0] expected_queue;
        input expected_valid;

        begin
            @(negedge clk);
            empty = test_empty;
            request = test_request;
            #1;

            tests = tests + 1;

            if ((selected_queue !== expected_queue) ||
                (select_valid !== expected_valid)) begin
                $display(
                    "FAIL: empty=%b request=%b expected=%b/%b got=%b/%b",
                    test_empty, test_request,
                    expected_queue, expected_valid,
                    selected_queue, select_valid
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: empty=%b request=%b selected=%b valid=%b",
                    test_empty, test_request,
                    selected_queue, select_valid
                );
            end

            // Prevent the selection-only test from updating state.
            request = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b1;
        empty = 4'b1111;
        request = 1'b0;

        // Default WRR weights: 4:3:2:1
        weight_q0 = 4'd4;
        weight_q1 = 4'd3;
        weight_q2 = 4'd2;
        weight_q3 = 4'd1;

        tests = 0;
        errors = 0;

        expected_pattern[0] = 2'd0;
        expected_pattern[1] = 2'd0;
        expected_pattern[2] = 2'd0;
        expected_pattern[3] = 2'd0;
        expected_pattern[4] = 2'd1;
        expected_pattern[5] = 2'd1;
        expected_pattern[6] = 2'd1;
        expected_pattern[7] = 2'd2;
        expected_pattern[8] = 2'd2;
        expected_pattern[9] = 2'd3;

        $display("------------------------------------------");
        $display("WEIGHTED ROUND-ROBIN SCHEDULER TESTBENCH");
        $display("------------------------------------------");

        // TEST 1: Reset pointer
        repeat (2) @(negedge clk);
        reset = 1'b0;
        #1;

        tests = tests + 1;

        if (uut.pointer === 2'd0) begin
            $display("PASS: Reset pointer = Q0");
        end
        else begin
            $display("FAIL: Reset pointer is not Q0");
            errors = errors + 1;
        end

        // TEST 2: Verify 10 services for weights 4:3:2:1.
        // All queues are continuously non-empty.
        $display("------------------------------------------");
        $display("TEST: DEFAULT WEIGHT RATIO 4:3:2:1");
        $display("------------------------------------------");

        for (i = 0; i < 10; i = i + 1) begin
            service_and_check(4'b0000, expected_pattern[i]);
        end

        // TEST 3: Only Q0 is non-empty.
        // Reset WRR state to make the expected result deterministic.
        @(negedge clk);
        reset = 1'b1;
        request = 1'b0;
        empty = 4'b1110;
        repeat (2) @(negedge clk);
        reset = 1'b0;

        selection_only_check(4'b1110, 1'b1, 2'd0, 1'b1);

        // TEST 4: Reset pointer to Q0; skip empty Q0 and select Q1.
        @(negedge clk);
        reset = 1'b1;
        request = 1'b0;
        repeat (2) @(negedge clk);
        reset = 1'b0;

        selection_only_check(4'b1101, 1'b1, 2'd1, 1'b1);

        // TEST 5: All queues empty.
        selection_only_check(4'b1111, 1'b1, 2'd0, 1'b0);

        // TEST 6: Request disabled.
        selection_only_check(4'b0000, 1'b0, 2'd0, 1'b0);

        $display("------------------------------------------");
        $display("Checks executed: %0d", tests);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $display("------------------------------------------");
        $finish;
    end

endmodule
