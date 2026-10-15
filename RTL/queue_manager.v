module queue_manager (
    input clk, reset,

    input [15:0] packet_in,
    input [1:0] queue_select_in,
    input write_request,

    input [1:0] read_select,
    input read_request,

    output [63:0] queue_data,
    output [3:0] empty,
    output [3:0] full,
    output [19:0] occupancy
);

    // Individual FIFO control signals
    wire [3:0] fifo_write_enable;
    wire [3:0] fifo_read_enable;

    // Individual FIFO outputs
    wire [15:0] q0_data;
    wire [15:0] q1_data;
    wire [15:0] q2_data;
    wire [15:0] q3_data;

    wire [4:0] q0_count;
    wire [4:0] q1_count;
    wire [4:0] q2_count;
    wire [4:0] q3_count;

    // Write decode: block writes when selected FIFO is full
    assign fifo_write_enable[0] =
        write_request && (queue_select_in == 2'b00) && !full[0];

    assign fifo_write_enable[1] =
        write_request && (queue_select_in == 2'b01) && !full[1];

    assign fifo_write_enable[2] =
        write_request && (queue_select_in == 2'b10) && !full[2];

    assign fifo_write_enable[3] =
        write_request && (queue_select_in == 2'b11) && !full[3];

    // Read decode: block reads when selected FIFO is empty
    assign fifo_read_enable[0] =
        read_request && (read_select == 2'b00) && !empty[0];

    assign fifo_read_enable[1] =
        read_request && (read_select == 2'b01) && !empty[1];

    assign fifo_read_enable[2] =
        read_request && (read_select == 2'b10) && !empty[2];

    assign fifo_read_enable[3] =
        read_request && (read_select == 2'b11) && !empty[3];

    // Queue data mapping
    assign queue_data = {
        q3_data,
        q2_data,
        q1_data,
        q0_data
    };

    // Occupancy : five bits per FIFO
    assign occupancy = {
        q3_count,
        q2_count,
        q1_count,
        q0_count
    };

    // FIFO Q0
    fifo Q0 (
    .clk(clk),
    .reset(reset),
    .write_en(fifo_write_enable[0]),
    .read_en(fifo_read_enable[0]),
    .data_in(packet_in),
    .data_out(q0_data),
    .full(full[0]),
    .empty(empty[0]),
    .count(q0_count)
);

    // FIFO Q1
    fifo Q1 (
    .clk(clk),
    .reset(reset),
    .write_en(fifo_write_enable[1]),
    .read_en(fifo_read_enable[1]),
    .data_in(packet_in),
    .data_out(q1_data),
    .full(full[1]),
    .empty(empty[1]),
    .count(q1_count)
);

    // FIFO Q2
    fifo Q2 (
    .clk(clk),
    .reset(reset),
    .write_en(fifo_write_enable[2]),
    .read_en(fifo_read_enable[2]),
    .data_in(packet_in),
    .data_out(q2_data),
    .full(full[2]),
    .empty(empty[2]),
    .count(q2_count)
);
    // FIFO Q3
    fifo Q3 (
    .clk(clk),
    .reset(reset),
    .write_en(fifo_write_enable[3]),
    .read_en(fifo_read_enable[3]),
    .data_in(packet_in),
    .data_out(q3_data),
    .full(full[3]),
    .empty(empty[3]),
    .count(q3_count)
);

endmodule