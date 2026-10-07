`timescale 1ns/1ps

module latency_counter_tb;

    reg clk, reset;
    reg packet_arrival, packet_departure;

    wire [31:0] latency_cycles;
    wire [31:0] average_latency;

    latency_counter uut (
        .clk(clk),
        .reset(reset),
        .packet_arrival(packet_arrival),
        .packet_departure(packet_departure),
        .latency_cycles(latency_cycles),
        .average_latency(average_latency)
    );
 
    always #5 clk = ~clk;

    // arrival
    task arrival;
        begin
            @(negedge clk);
            packet_arrival = 1'b1;

            @(negedge clk);
            packet_arrival = 1'b0;
        end
    endtask

    // departure 
    task departure;
        begin
            @(negedge clk);
            packet_departure = 1'b1;

            @(negedge clk);
            packet_departure = 1'b0;
        end
    endtask

    initial begin

        clk = 1'b0;
        reset = 1'b1;
        packet_arrival = 1'b0;
        packet_departure = 1'b0;
        // RESET
        $display("TEST 1: RESET");

        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);
        if (latency_cycles == 0 &&
            average_latency == 0) begin
            $display("PASS: Reset");
        end
        else begin
            $display("FAIL: Reset");
        end

        // SINGLE PACKET

        $display("TEST 2: SINGLE PACKET LATENCY");

        // Arrival is sampled at next posedge
        arrival;

        // We want departure exactly 5 sampled
        // clock edges after arrival.

        repeat (4) @(posedge clk);
        departure;

        #1;

        $display("Measured latency = %0d cycles", latency_cycles);

        if (latency_cycles == 5) begin
            $display("PASS: Single packet latency");
        end
        else begin
            $display("FAIL: Expected 5 cycles, got %0d",
                     latency_cycles);
        end
        // MULTIPLE PACKETS

        $display("TEST 3: MULTIPLE PACKETS");

        // Packet 2

        arrival;

        // Four additional edges -> 3-cycle latency
        repeat (2) @(posedge clk);
        departure;
        #1;

        if (latency_cycles == 3) begin
            $display("PASS: Packet 2 latency = %0d cycles",latency_cycles);
        end
        else begin
            $display("FAIL: Packet 2 expected 3 cycles, got %0d",latency_cycles);
        end

        // Packet 3

        arrival;
        // Six additional edges -> 7-cycle latency
        repeat (6) @(posedge clk);
        departure;
        #1;

        if (latency_cycles == 7) begin
            $display("PASS: Packet 3 latency = %0d cycles",latency_cycles);
        end
        else begin
            $display("FAIL: Packet 3 expected 7 cycles, got %0d",latency_cycles);
        end
        
        // AVERAGE LATENCY
        $display("TEST 4: AVERAGE LATENCY");

        $display("Average latency = %0d cycles", average_latency);
        // (5 + 3 + 7) / 3 = 5
        if (average_latency == 5) begin
            $display("PASS: Average latency = 5 cycles");
        end
        else begin
            $display("FAIL: Expected average 5, got %0d",average_latency);
        end

        #20;
        $finish;
    end
endmodule