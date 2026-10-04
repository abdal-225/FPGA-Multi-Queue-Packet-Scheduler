`timescale 1ns/1ps

module performance_counter_tb;

    reg         clk, reset, enable;
    reg         packet_generated;
    reg         packet_transmitted;
    reg  [1:0]  selected_queue;

    wire [31:0] cycle_count;
    wire [31:0] generated_count;
    wire [31:0] transmitted_count;

    performance_counter pc (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .packet_generated(packet_generated),
        .packet_transmitted(packet_transmitted),
        .selected_queue(selected_queue),
        .cycle_count(cycle_count),
        .generated_count(generated_count),
        .transmitted_count(transmitted_count)
    );

    always #5 clk = ~clk;

    initial begin
    
        clk = 0; reset = 1; enable = 0;
        packet_generated = 0;
        packet_transmitted = 0;
        selected_queue = 2'b00;
        #10;
        if (cycle_count == 32'd0 &&
            generated_count == 32'd0 &&
            transmitted_count == 32'd0)
            $display("PASS: Reset");
        else
            $display("FAIL: Reset");

        reset = 0;

        // TEST 2: DISABLED
        enable = 0;
        packet_generated = 1;
        packet_transmitted = 1;
        #20;

        if (cycle_count == 32'd0 &&
            generated_count == 32'd0 &&
            transmitted_count == 32'd0)
            $display("PASS: Disabled measurement");
        else
            $display("FAIL: Disabled measurement");

        packet_generated = 0;
        packet_transmitted = 0;

        // TEST 3: CYCLE COUNTING
        enable = 1;
        #30;

        if (cycle_count == 32'd3)
            $display("PASS: Cycle counting");
        else
            $display("FAIL: Cycle count = %0d", cycle_count);

        // TEST 4: GENERATED PACKETS
        packet_generated = 1;#10;
        packet_generated = 0;#10;
        packet_generated = 1;#10;
        packet_generated = 0;

        if (generated_count == 32'd2)
            $display("PASS: Generated packet counting");
        else
            $display("FAIL: Generated count = %0d", generated_count);

        // TEST 5: TRANSMITTED PACKETS
        packet_transmitted = 1; #10;
        packet_transmitted = 0; #10;
        packet_transmitted = 1; #10;
        packet_transmitted = 0;

        if (transmitted_count == 32'd2)
            $display("PASS: Transmitted packet counting");
        else
            $display("FAIL: Transmitted count = %0d",
                     transmitted_count);
                     
                     
        $display("TESTBENCH COMPLETE");

        $finish;

    end

endmodule