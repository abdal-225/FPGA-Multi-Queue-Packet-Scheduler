`timescale 1ns / 1ps

module scheduler_mux_tb;

reg [15:0] data_q0;
reg [15:0] data_q1;
reg [15:0] data_q2;
reg [15:0] data_q3;

reg [1:0] selected_queue;
reg select_valid;

wire [15:0] packet_out;
wire packet_valid;

// Instantiate the DUT
scheduler_mux sm (
    .data_q0(data_q0),
    .data_q1(data_q1),
    .data_q2(data_q2),
    .data_q3(data_q3),
    .selected_queue(selected_queue),
    .select_valid(select_valid),
    .packet_out(packet_out),
    .packet_valid(packet_valid)
);

initial begin
    $display("--------------------------------");
    $display("SCHEDULER MUX TESTBENCH");
    $display("--------------------------------");

    // Initialize inputs
    data_q0 = 16'hA001;
    data_q1 = 16'hB002;
    data_q2 = 16'hC003;
    data_q3 = 16'hD004;

    select_valid = 1'b1;

    // Test Queue 0
    selected_queue = 2'b00;
    #10;
    if (packet_out == data_q0 && packet_valid == 1'b1)
        $display("PASS: Queue 0");
    else
        $display("FAIL: Queue 0");

    // Test Queue 1
    selected_queue = 2'b01;
    #10;
    if (packet_out == data_q1 && packet_valid == 1'b1)
        $display("PASS: Queue 1");
    else
        $display("FAIL: Queue 1");

    // Test Queue 2
    selected_queue = 2'b10;
    #10;
    if (packet_out == data_q2 && packet_valid == 1'b1)
        $display("PASS: Queue 2");
    else
        $display("FAIL: Queue 2");

    // Test Queue 3
    selected_queue = 2'b11;
    #10;
    if (packet_out == data_q3 && packet_valid == 1'b1)
        $display("PASS: Queue 3");
    else
        $display("FAIL: Queue 3");

    // Test select_valid = 0
    select_valid = 1'b0;
    #10;
    if (packet_out == 16'h0000 && packet_valid == 1'b0)
        $display("PASS: Invalid selection");
    else
        $display("FAIL: Invalid selection");

    $display("--------------------------------");
    $display("TESTBENCH COMPLETED");
    $display("--------------------------------");

    $finish;
end

endmodule