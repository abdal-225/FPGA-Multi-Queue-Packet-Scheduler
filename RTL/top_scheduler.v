`timescale 1ns / 1ps

module top_scheduler (
    input wire CLK100MHZ,
    input wire [7:0] SW,
    input wire [4:0] BTN,
    output wire [7:0] LED,
    output reg [6:0] SEG,
    output wire [7:0] AN,
    output wire UART_TX
);

    wire clk = CLK100MHZ;
    wire reset = BTN[0];
    wire start = SW[4];

    wire [1:0] mode = SW[1:0];
    wire [1:0] traffic_mode = SW[3:2];

    localparam [15:0] WEIGHTS = 16'h1234;

    // 100 MHz -> 2 Hz scheduler clock
    reg [25:0] clk_div;
    reg slow_clk;

    localparam [25:0] DIVIDER_MAX = 26'd24999999;

    always @(posedge clk) begin
        if (reset) begin
            clk_div  <= 0;
            slow_clk <= 0;
        end
        else if (clk_div == DIVIDER_MAX) begin
            clk_div  <= 0;
            slow_clk <= ~slow_clk;
        end
        else begin
            clk_div <= clk_div + 1'b1;
        end
    end

    // Traffic generator
    wire [15:0] generated_packet;
    wire [1:0] generated_queue;
    wire generated_valid;

    traffic_generator u_traffic_generator (
        .clk(slow_clk),
        .reset(reset),
        .start(start),
        .traffic_mode(traffic_mode),
        .packet_out(generated_packet),
        .queue_select(generated_queue),
        .valid_out(generated_valid)
    );

    // Queue manager
    wire [63:0] queue_data;
    wire [3:0] queue_empty;
    wire [3:0] queue_full;
    wire [19:0] queue_occupancy;

    wire write_request;
    wire read_request;

    wire [1:0] selected_queue;
    wire select_valid;

    wire [15:0] packet_out;
    wire packet_valid;

    wire sink_ready;
    wire [31:0] sink_packet_count;

    assign write_request =
        generated_valid && !queue_full[generated_queue];

    assign read_request =
        select_valid &&
        !queue_empty[selected_queue] &&
        sink_ready;

    queue_manager u_queue_manager (
        .clk(slow_clk),
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

    // Scheduler controller.
    // request enables selection; read_request confirms actual service.
    scheduler_controller u_scheduler_controller (
        .clk(slow_clk),
        .reset(reset),
        .mode(mode),
        .empty(queue_empty),
        .weights(WEIGHTS),
        .request(1'b1),
        .service(read_request),
        .selected_queue(selected_queue),
        .select_valid(select_valid)
    );

    // Align registered FIFO output with the selected queue.
    reg [1:0] selected_queue_d;
    reg select_valid_d;

    always @(posedge slow_clk) begin
        if (reset) begin
            selected_queue_d <= 0;
            select_valid_d   <= 0;
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
        .clk(slow_clk),
        .reset(reset),
        .packet_in(packet_out),
        .valid_in(packet_valid),
        .ready(sink_ready),
        .packet_count(sink_packet_count)
    );

    // Packet event signals
    wire packet_generated_event = generated_valid;
    wire packet_enqueued_event = write_request;
    wire packet_transmitted_event = packet_valid && sink_ready;

    // Performance counters
    wire [31:0] cycle_count;
    wire [31:0] generated_count;
    wire [31:0] transmitted_count;

    performance_counter u_performance_counter (
        .clk(slow_clk),
        .reset(reset),
        .enable(start),
        .packet_generated(packet_generated_event),
        .packet_transmitted(packet_transmitted_event),
        .selected_queue(selected_queue_d),
        .cycle_count(cycle_count),
        .generated_count(generated_count),
        .transmitted_count(transmitted_count)
    );

    // Latency measurement
    wire [31:0] latency_cycles;
    wire [31:0] average_latency;

    latency_counter u_latency_counter (
        .clk(slow_clk),
        .reset(reset),
        .packet_arrival(packet_enqueued_event),
        .arrival_queue(generated_queue),
        .packet_departure(packet_transmitted_event),
        .departure_queue(selected_queue_d),
        .latency_cycles(latency_cycles),
        .average_latency(average_latency)
    );

    // Throughput measurement
    wire [31:0] throughput_count;

    throughput_counter u_throughput_counter (
        .clk(slow_clk),
        .reset(reset),
        .enable(start),
        .packet_transmitted(packet_transmitted_event),
        .measurement_cycles(cycle_count),
        .throughput_count(throughput_count)
    );

    // Board outputs
    assign LED[1:0] = mode;
    assign LED[3:2] = selected_queue;
    assign LED[7:4] = queue_full;

    assign AN = 8'b11111110;

    always @(*) begin
        case (selected_queue)
            2'b00: SEG = 7'b1000000;
            2'b01: SEG = 7'b1111001;
            2'b10: SEG = 7'b0100100;
            2'b11: SEG = 7'b0110000;
            default: SEG = 7'b1111111;
        endcase
    end

    // ============================================================
    // Event transfer: slow clock -> 100 MHz UART clock
    // ============================================================

    reg gen_toggle_s;
    reg enq_toggle_s;
    reg tx_toggle_s;

    reg [17:0] gen_payload_s;
    reg [17:0] enq_payload_s;
    reg [17:0] tx_payload_s;

    always @(posedge slow_clk) begin
        if (reset) begin
            gen_toggle_s <= 0;
            enq_toggle_s <= 0;
            tx_toggle_s  <= 0;

            gen_payload_s <= 0;
            enq_payload_s <= 0;
            tx_payload_s  <= 0;
        end
        else begin
            if (generated_valid) begin
                gen_payload_s <= {generated_queue, generated_packet};
                gen_toggle_s  <= ~gen_toggle_s;
            end

            if (write_request) begin
                enq_payload_s <= {generated_queue, generated_packet};
                enq_toggle_s  <= ~enq_toggle_s;
            end

            if (packet_transmitted_event) begin
                tx_payload_s <= {selected_queue_d, packet_out};
                tx_toggle_s  <= ~tx_toggle_s;
            end
        end
    end

    // Toggle synchronizers
    reg [1:0] gen_sync;
    reg [1:0] enq_sync;
    reg [1:0] tx_sync;

    reg gen_seen;
    reg enq_seen;
    reg tx_seen;

    reg gen_valid_pulse;
    reg enq_valid_pulse;
    reg tx_valid_pulse;

    reg [15:0] gen_packet_fast;
    reg [1:0] gen_queue_fast;

    reg [15:0] enq_packet_fast;
    reg [1:0] enq_queue_fast;

    reg [15:0] tx_packet_fast;
    reg [1:0] tx_queue_fast;

    always @(posedge clk) begin
        if (reset) begin
            gen_sync <= 0;
            enq_sync <= 0;
            tx_sync  <= 0;

            gen_seen <= 0;
            enq_seen <= 0;
            tx_seen  <= 0;

            gen_valid_pulse <= 0;
            enq_valid_pulse <= 0;
            tx_valid_pulse  <= 0;

            gen_packet_fast <= 0;
            gen_queue_fast  <= 0;

            enq_packet_fast <= 0;
            enq_queue_fast  <= 0;

            tx_packet_fast <= 0;
            tx_queue_fast  <= 0;
        end
        else begin
            gen_sync <= {gen_sync[0], gen_toggle_s};
            enq_sync <= {enq_sync[0], enq_toggle_s};
            tx_sync  <= {tx_sync[0], tx_toggle_s};

            gen_valid_pulse <= 0;
            enq_valid_pulse <= 0;
            tx_valid_pulse  <= 0;

            if (gen_sync[1] != gen_seen) begin
                gen_seen        <= gen_sync[1];
                gen_packet_fast <= gen_payload_s[15:0];
                gen_queue_fast  <= gen_payload_s[17:16];
                gen_valid_pulse <= 1;
            end

            if (enq_sync[1] != enq_seen) begin
                enq_seen        <= enq_sync[1];
                enq_packet_fast <= enq_payload_s[15:0];
                enq_queue_fast  <= enq_payload_s[17:16];
                enq_valid_pulse <= 1;
            end

            if (tx_sync[1] != tx_seen) begin
                tx_seen        <= tx_sync[1];
                tx_packet_fast <= tx_payload_s[15:0];
                tx_queue_fast  <= tx_payload_s[17:16];
                tx_valid_pulse <= 1;
            end
        end
    end

    // UART telemetry
    wire telemetry_overflow;

    uart_telemetry u_uart_telemetry (
        .clk(clk),
        .reset(reset),

        .mode(mode),
        .selected_queue(selected_queue_d),
        .select_valid(select_valid_d),

        .empty(queue_empty),
        .full(queue_full),
        .occupancy(queue_occupancy),

        .generated_valid(gen_valid_pulse),
        .generated_packet(gen_packet_fast),
        .generated_queue(gen_queue_fast),

        .enqueue_valid(enq_valid_pulse),
        .enqueue_packet(enq_packet_fast),
        .enqueue_queue(enq_queue_fast),

        .transmitted_valid(tx_valid_pulse),
        .transmitted_packet(tx_packet_fast),
        .transmitted_queue(tx_queue_fast),

        .cycle_count(cycle_count),
        .generated_count(generated_count),
        .transmitted_count(transmitted_count),
        .latency_count(average_latency),
        .throughput_count(throughput_count),

        .uart_tx(UART_TX),
        .buffer_overflow(telemetry_overflow)
    );

endmodule