module test_bench;

    reg        clk;
    reg        rst;
    reg        wr_en;
    reg        rd_en;
    reg  [7:0] data_in;

    wire [7:0] data_out;
    wire       full;
    wire       empty;

    // Instantiate FIFO
    FiFo dut (
        .clk      (clk),
        .rst      (rst),
        .wr_en    (wr_en),
        .rd_en    (rd_en),
        .data_in  (data_in),
        .data_out (data_out),
        .full     (full),
        .empty    (empty)
    );

    // ------------------------------------------------
    // Clock generation
    // 10 ns clock period
    // ------------------------------------------------
    always #5 clk = ~clk;


    // ------------------------------------------------
    // Write task
    // ------------------------------------------------
    task write_fifo(input [7:0] data);
    begin
        @(negedge clk);

        if (full) begin
            $display("WRITE BLOCKED: FIFO is FULL");
        end
        else begin
            wr_en  = 1;
            data_in = data;

            @(negedge clk);

            wr_en = 0;

            $display("WRITE: data = %0d", data);
        end
    end
    endtask


    // ------------------------------------------------
    // Read task
    // ------------------------------------------------
    task read_fifo(input [7:0] expected_data);
    begin
        @(negedge clk);

        if (empty) begin
            $display("READ BLOCKED: FIFO is EMPTY");
        end
        else begin
            rd_en = 1;

            @(posedge clk);
            #1;

            if (data_out == expected_data)
                $display("READ PASS: expected = %0d, received = %0d",
                         expected_data, data_out);
            else
                $display("READ FAIL: expected = %0d, received = %0d",
                         expected_data, data_out);

            @(negedge clk);

            rd_en = 0;
        end
    end
    endtask


    // ------------------------------------------------
    // Main test
    // ------------------------------------------------
    initial begin

        // Initialize signals
        clk    = 0;
        rst    = 0;
        wr_en  = 0;
        rd_en  = 0;
        data_in = 0;

        // --------------------------------------------
        // TEST 1: RESET
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 1: RESET");
        $display("==============================");

        rst = 1;

        #20;

        rst = 0;

        #10;

        if (empty)
            $display("RESET PASS: FIFO is EMPTY");
        else
            $display("RESET FAIL: FIFO is not EMPTY");


        // --------------------------------------------
        // TEST 2: NORMAL WRITES
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 2: NORMAL WRITES");
        $display("==============================");

        write_fifo(10);
        write_fifo(20);
        write_fifo(30);
        write_fifo(40);


        // --------------------------------------------
        // TEST 3: NORMAL READS
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 3: NORMAL READS");
        $display("==============================");

        read_fifo(10);
        read_fifo(20);
        read_fifo(30);
        read_fifo(40);


        // --------------------------------------------
        // TEST 4: EMPTY CONDITION
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 4: EMPTY CONDITION");
        $display("==============================");

        if (empty)
            $display("EMPTY PASS: FIFO is EMPTY");
        else
            $display("EMPTY FAIL: FIFO is not EMPTY");


        // --------------------------------------------
        // TEST 5: UNDERFLOW PREVENTION
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 5: UNDERFLOW PREVENTION");
        $display("==============================");

        // Attempt to read from empty FIFO
        @(negedge clk);

        rd_en = 1;

        @(posedge clk);
        #1;

        if (empty)
            $display("UNDERFLOW PREVENTION PASS");
        else
            $display("UNDERFLOW PREVENTION FAIL");

        rd_en = 0;


        // --------------------------------------------
        // TEST 6: FILL FIFO
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 6: FILL FIFO");
        $display("==============================");

        write_fifo(1);
        write_fifo(2);
        write_fifo(3);
        write_fifo(4);
        write_fifo(5);
        write_fifo(6);
        write_fifo(7);
        write_fifo(8);


        // --------------------------------------------
        // TEST 7: FULL CONDITION
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 7: FULL CONDITION");
        $display("==============================");

        if (full)
            $display("FULL PASS: FIFO is FULL");
        else
            $display("FULL FAIL: FIFO is not FULL");


        // --------------------------------------------
        // TEST 8: OVERFLOW PREVENTION
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 8: OVERFLOW PREVENTION");
        $display("==============================");

        // Try to write when FIFO is full
        @(negedge clk);

        data_in = 99;
        wr_en = 1;

        @(posedge clk);
        #1;

        wr_en = 0;

        if (full)
            $display("OVERFLOW PREVENTION PASS");
        else
            $display("OVERFLOW PREVENTION FAIL");


        // --------------------------------------------
        // TEST 9: READ ALL DATA
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 9: READ ALL FIFO DATA");
        $display("==============================");

        read_fifo(1);
        read_fifo(2);
        read_fifo(3);
        read_fifo(4);
        read_fifo(5);
        read_fifo(6);
        read_fifo(7);
        read_fifo(8);


        // --------------------------------------------
        // TEST 10: EMPTY AGAIN
        // --------------------------------------------
        $display("\n==============================");
        $display("TEST 10: EMPTY AGAIN");
        $display("==============================");

        if (empty)
            $display("FINAL EMPTY CHECK PASS");
        else
            $display("FINAL EMPTY CHECK FAIL");


        // End simulation
        #20;

        $display("\n==============================");
        $display("FIFO TESTBENCH COMPLETE");
        $display("==============================");

        $finish;

    end

endmodule