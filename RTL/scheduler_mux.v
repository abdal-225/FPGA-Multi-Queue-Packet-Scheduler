module scheduler_mux(
    input [15:0] data_q0,
    input [15:0] data_q1,
    input [15:0] data_q2,
    input [15:0] data_q3,

    input [1:0] selected_queue,
    input select_valid,

    output reg [15:0] packet_out,
    output reg packet_valid
);

always @(*) begin
    packet_out   = 16'b0;
    packet_valid = 1'b0;

    if (select_valid) begin
        case (selected_queue)
            2'b00: begin
                packet_out   = data_q0;
                packet_valid = 1'b1;
            end

            2'b01: begin
                packet_out   = data_q1;
                packet_valid = 1'b1;
            end

            2'b10: begin
                packet_out   = data_q2;
                packet_valid = 1'b1;
            end

            2'b11: begin
                packet_out   = data_q3;
                packet_valid = 1'b1;
            end

            default: begin
                packet_out   = 16'b0;
                packet_valid = 1'b0;
            end
        endcase
    end
end

endmodule