`timescale 1ns/1ps

module throughput_counter_tb;

    reg clk, reset, enable;
    reg packet_transmitted;
    reg [31:0] measurement_cycles;

    wire [31:0] throughput_count;

    // DUT
    throughput_counter tc (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .packet_transmitted(packet_transmitted),
        .measurement_cycles(measurement_cycles),
        .throughput_count(throughput_count)
    );
    
    always #5 clk = ~clk;

    initial begin

        clk = 0; reset = 1; enable = 0;
        packet_transmitted = 0;
        measurement_cycles = 10;

        // RESET
        #10;

        if (throughput_count == 0)
            $display("PASS: Reset");
        else
            $display("FAIL: Reset");

        reset = 0;
        // DISABLED
        #20;

        if (throughput_count == 0)
            $display("PASS: Disabled operation");
        else
            $display("FAIL: Disabled operation");

        // COUNT TRANSMITTED PACKETS
        enable = 1;

        packet_transmitted = 1; #10;
        packet_transmitted = 1; #10;
        packet_transmitted = 1; #10;
        packet_transmitted = 0;

        if (throughput_count == 3)
            $display("PASS: Counted 3 transmitted packets");
        else
            $display("FAIL: Expected 3 packets, got %0d", throughput_count);

        // NON-TRANSMISSION CYCLE
        #10;

        if (throughput_count == 3)
            $display("PASS: No false packet count");
        else
            $display("FAIL: False packet count");

        // DISABLE
        enable = 0;
        packet_transmitted = 1; #20;

        if (throughput_count == 3)
            $display("PASS: Disabled counting");
        else
            $display("FAIL: Counter changed while disabled");

        $display("Throughput Count = %0d", throughput_count);
        
        $finish;

    end

endmodule