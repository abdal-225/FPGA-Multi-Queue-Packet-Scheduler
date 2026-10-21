`timescale 1ns / 1ps

module round_robin_scheduler_tb;

    reg clk;
    reg reset;
    reg [3:0] empty;
    reg request;

    wire [1:0] selected_queue;
    wire select_valid;

    integer tests;
    integer errors;

    // DUT
    round_robin_scheduler uut (
        .clk(clk),
        .reset(reset),
        .empty(empty),
        .request(request),
        .selected_queue(selected_queue),
        .select_valid(select_valid)
    );

    // 10 ns clock period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Check a successful service and pointer advancement
    task service_queue;
        input [3:0] test_empty;
        input [1:0] expected_queue;
        input [1:0] expected_pointer;

        begin
            @(negedge clk);
            empty = test_empty;
            request = 1'b1;
            #1;

            if ((select_valid !== 1'b1) ||
                (selected_queue !== expected_queue)) begin
                $display(
                    "FAIL: Expected Q%0d, got Q%0d valid=%b",
                    expected_queue, selected_queue, select_valid
                );
                errors = errors + 1;
            end
            else begin
                @(posedge clk);
                #1;

                tests = tests + 1;

                if (uut.pointer !== expected_pointer) begin
                    $display(
                        "FAIL: After Q%0d service expected pointer Q%0d, got Q%0d",
                        expected_queue, expected_pointer, uut.pointer
                    );
                    errors = errors + 1;
                end
                else begin
                    $display(
                        "PASS: Serviced Q%0d; pointer advanced to Q%0d",
                        expected_queue, uut.pointer
                    );
                end
            end

            @(negedge clk);
            request = 1'b0;
        end
    endtask

    // Check selection without allowing pointer advancement
    task check_selection;
        input [3:0] test_empty;
        input test_request;
        input [1:0] expected_queue;
        input expected_valid;

        reg [1:0] saved_pointer;

        begin
            @(negedge clk);
            empty = test_empty;
            request = test_request;
            saved_pointer = uut.pointer;

            #1;

            tests = tests + 1;

            if ((selected_queue !== expected_queue) ||
                (select_valid !== expected_valid)) begin
                $display(
                    "FAIL: ptr=%b empty=%b req=%b expected=%b/%b got=%b/%b",
                    saved_pointer, test_empty, test_request,
                    expected_queue, expected_valid,
                    selected_queue, select_valid
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: ptr=%b empty=%b req=%b selected=%b valid=%b",
                    saved_pointer, test_empty, test_request,
                    selected_queue, select_valid
                );
            end

            // Deassert before the next rising edge
            request = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b1;
        empty = 4'b1111;
        request = 1'b0;
        tests = 0;
        errors = 0;

        $display("------------------------------------------");
        $display("ROUND-ROBIN SCHEDULER TESTBENCH");
        $display("------------------------------------------");

        // TEST 1: Reset pointer
        repeat (2) @(negedge clk);
        reset = 1'b0;
        #1;

        if (uut.pointer === 2'd0) begin
            $display("PASS: Reset pointer = Q0");
            tests = tests + 1;
        end
        else begin
            $display("FAIL: Reset pointer is not Q0");
            errors = errors + 1;
        end

        // TESTS 2-5: Complete circular service sequence
        service_queue(4'b0000, 2'd0, 2'd1);
        service_queue(4'b0000, 2'd1, 2'd2);
        service_queue(4'b0000, 2'd2, 2'd3);
        service_queue(4'b0000, 2'd3, 2'd0);

        // TEST 6: Pointer at Q0; Q0 empty, select Q1
        check_selection(4'b0001, 1'b1, 2'd1, 1'b1);

        // Move pointer from Q0 to Q1 and then Q2
        service_queue(4'b0000, 2'd0, 2'd1);
        service_queue(4'b0000, 2'd1, 2'd2);

        // TEST 9: Pointer at Q2; skip Q2 and select Q3
        check_selection(4'b0111, 1'b1, 2'd3, 1'b1);

        // TEST 10: Pointer at Q2; Q2/Q3 empty, wrap to Q0
        check_selection(4'b1100, 1'b1, 2'd0, 1'b1);

        // TEST 11: Pointer at Q2; Q2/Q3/Q0 empty, select Q1
        check_selection(4'b1101, 1'b1, 2'd1, 1'b1);

        // TEST 12: All queues empty
        check_selection(4'b1111, 1'b1, 2'd2, 1'b0);

        // TEST 13: Request disabled
        check_selection(4'b0000, 1'b0, 2'd2, 1'b0);

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
