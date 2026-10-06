module FiFo(
    input        clk,
    input        rst,

    input        wr_en,
    input        rd_en,

    input  [7:0] data_in,
    output reg [7:0] data_out,

    output        full,
    output        empty
);

    // FIFO memory
    reg [7:0] mem [0:7];

    // Read and write pointers
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;

    // Number of stored elements
    reg [3:0] count;

    // Full and empty conditions
    assign empty = (count == 0);
    assign full  = (count == 8);

    always @(posedge clk) begin

        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_out <= 0;
        end

        else begin

            // WRITE operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end

            // READ operation
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end

            // COUNT update
            case ({wr_en && !full, rd_en && !empty})

                2'b10: count <= count + 1; // Write only

                2'b01: count <= count - 1; // Read only

                2'b11: count <= count;     // Read and write

                default: count <= count;   // Nothing

            endcase

        end
    end

endmodule    
