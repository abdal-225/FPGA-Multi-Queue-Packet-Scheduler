module packet_sink (
    input wire clk, reset,
    input wire [15:0] packet_in,
    input wire valid_in,
    output wire ready,
    output reg [31:0] packet_count
);

    assign ready = 1'b1;
    
    always @(posedge clk) begin
    
        if (reset) begin
            packet_count <= 32'd0;
        end
        else if (valid_in && ready) begin
            packet_count <= packet_count + 32'd1;
        end
    
    end

endmodule