
`timescale 1ns / 1ps

module scheduler_controller_tb;

    reg clk;
    reg reset;
    reg [1:0] mode;
    reg [3:0] empty;
    reg [15:0] weights;
    reg request;

    wire [1:0] selected_queue;
    wire select_valid;

    integer pass_count;
    integer fail_count;

    scheduler_controller DUT (
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .empty(empty),
        .weights(weights),
        .request(request),
        .selected_queue(selected_queue),
        .select_valid(select_valid)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_result;
        input [1:0] expected_queue;
        input expected_valid;
        input [255:0] test_name;
        begin
            #1;

            if ((selected_queue === expected_queue) &&
                (select_valid === expected_valid)) begin
                $display("PASS: %0s | mode=%b empty=%b queue=%b valid=%b",
                         test_name, mode, empty,
                         selected_queue, select_valid);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %0s | mode=%b empty=%b expected=%b/%b actual=%b/%b",
                         test_name, mode, empty,
                         expected_queue, expected_valid,
                         selected_queue, select_valid);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $display("==============================================");
        $display(" SCHEDULER CONTROLLER TESTBENCH");
        $display("==============================================");

        pass_count = 0;
        fail_count = 0;

        clk     = 1'b0;
        reset   = 1'b1;
        mode    = 2'b00;
        empty   = 4'b1111;
        weights = 16'h4321;
        request = 1'b0;

        // Reset stateful schedulers
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // ==========================================
        // TEST 1: PRIORITY SCHEDULER
        // ==========================================
        $display("\nTEST 1: PRIORITY MODE");

        mode = 2'b00;
        request = 1'b1;

        empty = 4'b0000;
        check_result(2'b00, 1'b1, "Priority selects Q0");

        empty = 4'b0001;
        check_result(2'b01, 1'b1, "Priority selects Q1");

        empty = 4'b0011;
        check_result(2'b10, 1'b1, "Priority selects Q2");

        empty = 4'b0111;
        check_result(2'b11, 1'b1, "Priority selects Q3");

        empty = 4'b1111;
        check_result(2'b00, 1'b0, "Priority all queues empty");

        // ==========================================
        // TEST 2: ROUND-ROBIN SCHEDULER
        // ==========================================
        $display("\nTEST 2: ROUND-ROBIN MODE");

        @(negedge clk);
        reset = 1'b1;
        mode = 2'b01;
        empty = 4'b0000;
        request = 1'b0;

        @(negedge clk);
        reset = 1'b0;
        request = 1'b1;

        check_result(2'b00, 1'b1, "RR initial selection Q0");

        // Complete one service and advance the RR pointer.
        @(posedge clk);
        #1;
        request = 1'b0;

        @(negedge clk);
        request = 1'b1;
        check_result(2'b01, 1'b1, "RR next selection Q1");

        @(posedge clk);
        #1;
        request = 1'b0;

        // ==========================================
        // TEST 3: WEIGHTED ROUND-ROBIN SCHEDULER
        // ==========================================
        $display("\nTEST 3: WEIGHTED ROUND-ROBIN MODE");

        @(negedge clk);
        reset = 1'b1;
        mode = 2'b10;
        empty = 4'b0000;
        weights = 16'h4321;
        request = 1'b0;

        @(negedge clk);
        reset = 1'b0;
        request = 1'b1;

        check_result(2'b00, 1'b1, "WRR initial selection Q0");

        // Complete one service before testing the next request.
        @(posedge clk);
        #1;
        request = 1'b0;

        // ==========================================
        // TEST 4: RESERVED MODE
        // ==========================================
        $display("\nTEST 4: RESERVED MODE");

        @(negedge clk);
        mode = 2'b11;
        request = 1'b1;
        empty = 4'b0000;

        check_result(2'b00, 1'b0, "Reserved mode invalid");

        // ==========================================
        // TEST 5: REQUEST DISABLED
        // ==========================================
        $display("\nTEST 5: REQUEST DISABLED");

        mode = 2'b00;
        request = 1'b0;
        empty = 4'b0000;

        check_result(2'b00, 1'b0, "No request");

        // ==========================================
        // TEST 6: ALL QUEUES EMPTY
        // ==========================================
        $display("\nTEST 6: ALL QUEUES EMPTY");

        request = 1'b1;
        empty = 4'b1111;

        mode = 2'b00;
        check_result(2'b00, 1'b0, "Priority queues empty");

        mode = 2'b01;
        check_result(2'b00, 1'b0, "RR queues empty");

        mode = 2'b10;
        check_result(2'b00, 1'b0, "WRR queues empty");

        // ==========================================
        // TEST 7: MODE SWITCHING
        // ==========================================
        $display("\nTEST 7: MODE SWITCHING");

        empty = 4'b1110; // Only Q0 is available

        mode = 2'b00;
        check_result(2'b00, 1'b1, "Switch to Priority");

        mode = 2'b01;
        check_result(2'b00, 1'b1, "Switch to RR");

        mode = 2'b10;
        check_result(2'b00, 1'b1, "Switch to WRR");

        mode = 2'b11;
        check_result(2'b00, 1'b0, "Switch to Reserved");

        // ==========================================
        // TEST 8: WEIGHT INPUT MAPPING
        // ==========================================
        $display("\nTEST 8: WEIGHT CONFIGURATION");

        mode = 2'b10;
        empty = 4'b1110;
        weights = 16'h1234;

        check_result(2'b00, 1'b1, "WRR with configured weights");

        // ==========================================
        // FINAL SUMMARY
        // ==========================================
        $display("\n==============================================");
        $display(" SIMULATION SUMMARY");
        $display("==============================================");
        $display("PASSED: %0d", pass_count);
        $display("FAILED: %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TESTS FAILED");

        $display("==============================================");

        $finish;
    end

endmodule
