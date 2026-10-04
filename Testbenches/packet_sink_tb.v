`timescale 1ns/1ps

module packet_sink_tb;
    reg         clk, reset;
    reg  [15:0] packet_in;
    reg         valid_in;
    wire        ready;
    wire [31:0] packet_count;

    packet_sink ps (
        .clk(clk),
        .reset(reset),
        .packet_in(packet_in),
        .valid_in(valid_in),
        .ready(ready),
        .packet_count(packet_count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1;
        packet_in = 16'h0000; valid_in  = 0;
        #10;
        
        if (packet_count == 32'd0)
            $display("PASS: Reset");
        else
            $display("FAIL: Reset");

        reset = 0;
        #10;

        if (packet_count == 32'd0)
            $display("PASS: No packet accepted");
        else
            $display("FAIL: Count changed without valid");
            
        // Test 2: Single packet
        packet_in = 16'hA001;
        valid_in  = 1;
        #10;

        if (packet_count == 32'd1)
            $display("PASS: Single packet accepted");
        else
            $display("FAIL: Single packet count");

        // Stop valid
        valid_in = 0;
        #10;

        // Test 3: Multiple packets
        packet_in = 16'hB001;
        valid_in  = 1;
        #10;
        packet_in = 16'hB002;
        #10;
        packet_in = 16'hB003;
        #10;

        if (packet_count == 32'd4)
            $display("PASS: Multiple packets accepted");
        else
            $display("FAIL: Multiple packet count");

        // Test 4: Check ready
        if (ready == 1'b1)
            $display("PASS: Sink ready");
        else
            $display("FAIL: Sink not ready");
        valid_in = 0;
        #10;

        $display("TESTBENCH COMPLETE");

        $finish;
    end

endmodule