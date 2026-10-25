module fifo (
    input clk,
    input reset,

    input write_en,
    input read_en,

    input [15:0] data_in,
    output reg [15:0] data_out,

    output full,
    output empty,
    output [4:0] count
);

    // FIFO memory: 16 packets, each 16 bits wide
    reg [15:0] mem [0:15];

    // Read and write pointers
    reg [3:0] write_ptr;
    reg [3:0] read_ptr;

    // Occupancy counter
    reg [4:0] fifo_count;

    // FIFO status flags
    assign full  = (fifo_count == 5'd16);
    assign empty = (fifo_count == 5'd0);
    assign count = fifo_count;

    // FIFO operations
    always @(posedge clk) begin
        if (reset) begin
            write_ptr <= 4'd0;
            read_ptr  <= 4'd0;
            fifo_count <= 5'd0;
            data_out  <= 16'd0;
        end
        else begin

            // Write operation
            if (write_en && !full) begin
                mem[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1'b1;
            end

            // Read operation
            if (read_en && !empty) begin
                data_out <= mem[read_ptr];
                read_ptr <= read_ptr + 1'b1;
            end

            // Occupancy update
            case ({
                write_en && !full,
                read_en && !empty
            })
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                2'b11: fifo_count <= fifo_count;
                default: fifo_count <= fifo_count;
            endcase

        end
    end

endmodule