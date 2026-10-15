`timescale 1ns / 1ps

module queue_manager_tb;

    reg clk;
    reg reset;

    reg [15:0] packet_in;
    reg [1:0] queue_select_in;
    reg write_request;

    reg [1:0] read_select;
    reg read_request;

    wire [63:0] queue_data;
    wire [3:0] empty;
    wire [3:0] full;
    wire [19:0] occupancy;

    integer i;
    integer errors;

    queue_manager qm (
        .clk(clk),
        .reset(reset),
        .packet_in(packet_in),
        .queue_select_in(queue_select_in),
        .write_request(write_request),
        .read_select(read_select),
        .read_request(read_request),
        .queue_data(queue_data),
        .empty(empty),
        .full(full),
        .occupancy(occupancy)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Write one packet to the selected queue
    task write_packet;
        input [1:0] q;
        input [15:0] packet;
        begin
            @(negedge clk);
            queue_select_in = q;
            packet_in = packet;
            write_request = 1'b1;

            @(posedge clk);
            #1;
            write_request = 1'b0;
        end
    endtask

    // Read one packet from the selected queue
    task read_packet;
        input [1:0] q;
        begin
            @(negedge clk);
            read_select = q;
            read_request = 1'b1;

            @(posedge clk);
            #1;
            read_request = 1'b0;
        end
    endtask

    // Check occupancy of an individual queue
    task check_count;
        input [1:0] q;
        input [4:0] expected;
        reg [4:0] actual;
        begin
            case (q)
                2'd0: actual = occupancy[4:0];
                2'd1: actual = occupancy[9:5];
                2'd2: actual = occupancy[14:10];
                2'd3: actual = occupancy[19:15];
            endcase

            if (actual !== expected) begin
                $display(
                    "FAIL: Q%0d count expected %0d, got %0d",
                    q, expected, actual
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Q%0d occupancy = %0d",
                    q, actual
                );
            end
        end
    endtask

    initial begin
        reset = 1'b1;
        packet_in = 16'd0;
        queue_select_in = 2'd0;
        write_request = 1'b0;
        read_select = 2'd0;
        read_request = 1'b0;
        errors = 0;

        $display("----------------------------------------");
        $display("QUEUE MANAGER TESTBENCH");
        $display("----------------------------------------");

        // TEST 1: RESET
        repeat (2) @(posedge clk);
        #1;
        reset = 1'b0;

        if (empty !== 4'b1111 || occupancy !== 20'd0) begin
            $display("FAIL: Reset state incorrect");
            errors = errors + 1;
        end
        else
            $display("PASS: All queues empty after reset");

        // TEST 2: WRITE TO DIFFERENT QUEUES
        $display("----------------------------------------");
        $display("TEST 2: WRITE DECODING");

        write_packet(2'd0, 16'hA001);
        write_packet(2'd1, 16'hB002);
        write_packet(2'd2, 16'hC003);
        write_packet(2'd3, 16'hD004);

        check_count(2'd0, 5'd1);
        check_count(2'd1, 5'd1);
        check_count(2'd2, 5'd1);
        check_count(2'd3, 5'd1);

        if (empty !== 4'b0000) begin
            $display("FAIL: Empty flags incorrect after writes");
            errors = errors + 1;
        end
        else
            $display("PASS: All empty flags cleared");

        // TEST 3: READ ONLY SELECTED QUEUE
        $display("----------------------------------------");
        $display("TEST 3: READ ISOLATION");

        read_packet(2'd1);

        if (queue_data[31:16] !== 16'hB002) begin
            $display("FAIL: Q1 returned incorrect packet");
            errors = errors + 1;
        end
        else
            $display("PASS: Q1 returned B002");

        check_count(2'd0, 5'd1);
        check_count(2'd1, 5'd0);
        check_count(2'd2, 5'd1);
        check_count(2'd3, 5'd1);

        if (empty[1] !== 1'b1 ||
            empty[0] !== 1'b0 ||
            empty[2] !== 1'b0 ||
            empty[3] !== 1'b0) begin
            $display("FAIL: Queue empty flags are not independent");
            errors = errors + 1;
        end
        else
            $display("PASS: Only Q1 became empty");

        // TEST 4: FIFO ORDER
        $display("----------------------------------------");
        $display("TEST 4: FIFO ORDER");

        write_packet(2'd0, 16'h1111);
        write_packet(2'd0, 16'h2222);

        read_packet(2'd0);
        if (queue_data[15:0] !== 16'hA001) begin
            $display("FAIL: First packet was not A001");
            errors = errors + 1;
        end
        else
            $display("PASS: First packet A001");

        read_packet(2'd0);
        if (queue_data[15:0] !== 16'h1111) begin
            $display("FAIL: Second packet was not 1111");
            errors = errors + 1;
        end
        else
            $display("PASS: Second packet 1111");

        read_packet(2'd0);
        if (queue_data[15:0] !== 16'h2222) begin
            $display("FAIL: Third packet was not 2222");
            errors = errors + 1;
        end
        else
            $display("PASS: Third packet 2222");

        check_count(2'd0, 5'd0);

        // TEST 5: READ FROM EMPTY QUEUE
        $display("----------------------------------------");
        $display("TEST 5: EMPTY QUEUE PROTECTION");

        read_packet(2'd0);
        check_count(2'd0, 5'd0);

        if (empty[0] !== 1'b1) begin
            $display("FAIL: Q0 should remain empty");
            errors = errors + 1;
        end
        else
            $display("PASS: Read from empty Q0 was blocked");

        // TEST 6: FILL Q1 TO CAPACITY
        $display("----------------------------------------");
        $display("TEST 6: FULL QUEUE PROTECTION");

        for (i = 0; i < 16; i = i + 1)
            write_packet(2'd1, 16'h5000 + i);

        check_count(2'd1, 5'd16);

        if (full[1] !== 1'b1) begin
            $display("FAIL: Q1 full flag not asserted");
            errors = errors + 1;
        end
        else
            $display("PASS: Q1 full flag asserted");

        // Attempt an extra write to full Q1
        write_packet(2'd1, 16'hFFFF);
        check_count(2'd1, 5'd16);

        if (full[1] !== 1'b1) begin
            $display("FAIL: Q1 full flag changed unexpectedly");
            errors = errors + 1;
        end
        else
            $display("PASS: Extra write to full Q1 was blocked");

        // Check other queues were not affected
        check_count(2'd0, 5'd0);
        check_count(2'd2, 5'd1);
        check_count(2'd3, 5'd1);

        // TEST 7: FULL FLAGS ARE INDEPENDENT
        $display("----------------------------------------");
        $display("TEST 7: INDEPENDENT FULL FLAGS");

        if (full !== 4'b0010) begin
            $display("FAIL: Expected only Q1 to be full");
            errors = errors + 1;
        end
        else
            $display("PASS: Only Q1 is full");

        // FINAL RESULT
        $display("----------------------------------------");
        if (errors == 0)
            $display("ALL QUEUE MANAGER TESTS PASSED");
        else
            $display("TESTBENCH FAILED: %0d errors", errors);

        $display("----------------------------------------");
        $finish;
    end

endmodule