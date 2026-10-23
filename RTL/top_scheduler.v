`timescale 1ns / 1ps

module top_scheduler (
    input wire CLK100MHZ,
    input wire [7:0] SW,
    input wire [4:0] BTN,
    output wire [7:0] LED,
    output reg [6:0] SEG,
    output wire [7:0] AN
);

    // 1. CONTROL SIGNALS
    
    wire clk;
    wire reset;
    wire start;

    wire [1:0] mode;
    wire [1:0] traffic_mode;

    assign clk         = CLK100MHZ;
    assign reset       = BTN[0];
    assign mode        = SW[1:0];
    assign traffic_mode = SW[3:2];
    assign start       = SW[4];

    // Weighted Round-Robin weights:
    // Q0 = 4, Q1 = 3, Q2 = 2, Q3 = 1.
    // Assumes Q0 uses the least-significant nibble.
    localparam [15:0] WEIGHTS = 16'h1234;

    // 2. TRAFFIC GENERATOR
    
    wire [15:0] generated_packet;
    wire [1:0] generated_queue;
    wire generated_valid;

    // 3. QUEUE MANAGER
    
    wire [63:0] queue_data;
    wire [3:0] queue_empty;
    wire [3:0] queue_full;
    wire [19:0] queue_occupancy;

    wire write_request;
    wire read_request;

    // 4. SCHEDULER CONTROLLER
    
    wire [1:0] selected_queue;
    wire select_valid;

    // 5. REGISTERED FIFO READ ALIGNMENT
    
    // Queue-manager FIFO outputs are registered.
    // Delay the selected queue and valid signal so they
    // align with the packet returned by the FIFO.

    reg [1:0] selected_queue_d;
    reg select_valid_d;

    // 6. SCHEDULER MULTIPLEXER
    
    wire [15:0] packet_out;
    wire packet_valid;

    // 7. PACKET SINK
    
    wire sink_ready;
    wire [31:0] sink_packet_count;

    // 8. PERFORMANCE COUNTERS
    
    wire [31:0] cycle_count;
    wire [31:0] generated_count;
    wire [31:0] transmitted_count;

    wire [31:0] latency_cycles;
    wire [31:0] average_latency;

    wire [31:0] throughput_count;

    // 9. EVENT SIGNALS
    
    wire packet_generated_event;
    wire packet_transmitted_event;

    // Do not write into a full queue.
    assign write_request =
        generated_valid && !queue_full[generated_queue];

    // Read one packet when a valid, nonempty queue is
    // selected and the sink is ready.
    assign read_request =
        select_valid &&
        !queue_empty[selected_queue] &&
        sink_ready;

    assign packet_generated_event = write_request;

    assign packet_transmitted_event =
        packet_valid && sink_ready;

    // 10. MODULE INSTANTIATIONS
    
    traffic_generator u_traffic_generator (
        .clk(clk),
        .reset(reset),
        .start(start),
        .traffic_mode(traffic_mode),
        .packet_out(generated_packet),
        .queue_select(generated_queue),
        .valid_out(generated_valid)
    );

    queue_manager u_queue_manager (
        .clk(clk),
        .reset(reset),

        .packet_in(generated_packet),
        .queue_select_in(generated_queue),
        .write_request(write_request),

        .read_select(selected_queue),
        .read_request(read_request),

        .queue_data(queue_data),
        .empty(queue_empty),
        .full(queue_full),
        .occupancy(queue_occupancy)
    );

    scheduler_controller u_scheduler_controller (
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .empty(queue_empty),
        .weights(WEIGHTS),
        .request(1'b1),
        .selected_queue(selected_queue),
        .select_valid(select_valid)
    );

    // Align the queue selection with the registered FIFO
    // data output. A reset clears the pending read.
    always @(posedge clk) begin
        if (reset) begin
            selected_queue_d <= 2'b00;
            select_valid_d   <= 1'b0;
        end
        else begin
            selected_queue_d <= selected_queue;
            select_valid_d   <= read_request;
        end
    end

    scheduler_mux u_scheduler_mux (
        .data_q0(queue_data[15:0]),
        .data_q1(queue_data[31:16]),
        .data_q2(queue_data[47:32]),
        .data_q3(queue_data[63:48]),

        .selected_queue(selected_queue_d),
        .select_valid(select_valid_d),

        .packet_out(packet_out),
        .packet_valid(packet_valid)
    );

    packet_sink u_packet_sink (
        .clk(clk),
        .reset(reset),
        .packet_in(packet_out),
        .valid_in(packet_valid),
        .ready(sink_ready),
        .packet_count(sink_packet_count)
    );

    performance_counter u_performance_counter (
        .clk(clk),
        .reset(reset),
        .enable(start),
        .packet_generated(packet_generated_event),
        .packet_transmitted(packet_transmitted_event),
        .selected_queue(selected_queue_d),
        .cycle_count(cycle_count),
        .generated_count(generated_count),
        .transmitted_count(transmitted_count)
    );

    latency_counter u_latency_counter (
        .clk(clk),
        .reset(reset),
        .packet_arrival(packet_generated_event),
        .packet_departure(packet_transmitted_event),
        .latency_cycles(latency_cycles),
        .average_latency(average_latency)
    );

    throughput_counter u_throughput_counter (
        .clk(clk),
        .reset(reset),
        .enable(start),
        .packet_transmitted(packet_transmitted_event),
        .measurement_cycles(cycle_count),
        .throughput_count(throughput_count)
    );

    // 11. BOARD STATUS OUTPUTS
    
    // LED[1:0] : scheduling mode
    // LED[3:2] : selected queue
    // LED[7:4] : queue-full status, Q3 to Q0

    assign LED[1:0] = mode;
    assign LED[3:2] = selected_queue;
    assign LED[7:4] = queue_full;

    // Nexys 4 DDR seven-segment display:
    // Display the selected queue number on digit 0.
    // SEG and AN are active-low on this board.

    assign AN = 8'b11111110;

    always @(*) begin
        case (selected_queue)
            2'b00: SEG = 7'b1000000; // 0
            2'b01: SEG = 7'b1111001; // 1
            2'b10: SEG = 7'b0100100; // 2
            2'b11: SEG = 7'b0110000; // 3
            default: SEG = 7'b1111111;
        endcase
    end

endmodule
