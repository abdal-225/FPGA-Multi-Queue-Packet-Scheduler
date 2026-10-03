`timescale 1ns/1ps

module traffic_generator_tb;

    reg clk;
    reg reset;
    reg start;
    reg [1:0] traffic_mode;

    wire [15:0] packet_out;
    wire [1:0] queue_select;
    wire valid_out;


    // DUT
    traffic_generator tg (
        .clk(clk),
        .reset(reset),
        .start(start),
        .traffic_mode(traffic_mode),
        .packet_out(packet_out),
        .queue_select(queue_select),
        .valid_out(valid_out)
    );


    // Clock
    always #5 clk = ~clk;

    initial begin
        // Initial values
        clk = 0;
        reset = 1;
        start = 0;
        traffic_mode = 2'b00;

        // RESET
        #10;reset = 0;
        
        // SINGLE PACKET
        traffic_mode = 2'b00; #5; 
        start = 1;#10;
        start = 0;#10;

        // BURST
        reset = 1;
        #10;
        reset = 0;
        traffic_mode = 2'b01;#5;
        start = 1;#10;
        start = 0;

        // Observe 8 packets
        repeat(8) begin
            #10;
            $display("BURST: Packet=%h Queue=%b Valid=%b",
                     packet_out, queue_select, valid_out);
        end

        // CONTINUOUS
        reset = 1;#10;
        reset = 0;
        traffic_mode = 2'b10;#5;
        start = 1;#10;
        start = 0;

        repeat(5) begin
            #10;
            $display("CONTINUOUS: Packet=%h Queue=%b Valid=%b",
                     packet_out, queue_select, valid_out);
        end

        // QUEUE SPECIFIC

        reset = 1; #10;
        reset = 0;
        traffic_mode = 2'b11;#5;
        start = 1;#10;
        start = 0;
        repeat(5) begin
            #10;
            $display("QUEUE-SPECIFIC: Packet=%h Queue=%b Valid=%b",
                     packet_out, queue_select, valid_out);
        end

        #20;
        $finish;
    end
endmodule