`timescale 1ns / 1ps

module traffic_generator (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] traffic_mode,

    output reg [15:0] packet_out,
    output reg [1:0] queue_select,
    output reg valid_out
);

    localparam SINGLE     = 2'b00;
    localparam BURST      = 2'b01;
    localparam CONTINUOUS = 2'b10;

    reg [15:0] packet_counter;
    reg [4:0] burst_count;
    reg active;
    reg start_d;

    wire start_rising = start && !start_d;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            packet_out     <= 0;
            queue_select   <= 0;
            valid_out      <= 0;
            packet_counter <= 0;
            burst_count    <= 0;
            active         <= 0;
            start_d        <= 0;
        end
        else begin
            start_d   <= start;
            valid_out <= 0;

            if (!start) begin
                active      <= 0;
                burst_count <= 0;
            end
            else if (start_rising && !active) begin
                active         <= 1;
                packet_counter <= packet_counter + 1'b1;
                burst_count    <= 0;
            end
            else if (active && start) begin
                case (traffic_mode)

                    SINGLE: begin
                        packet_out   <= packet_counter;
                        queue_select <= packet_counter[1:0];
                        valid_out    <= 1;
                        active       <= 0;
                    end

                    BURST: begin
                        if (burst_count < 5'd16) begin
                            packet_out   <= packet_counter;
                            queue_select <= packet_counter[1:0];
                            valid_out    <= 1;

                            packet_counter <= packet_counter + 1'b1;
                            burst_count    <= burst_count + 1'b1;
                        end
                        else begin
                            active <= 0;
                        end
                    end

                    CONTINUOUS: begin
                        packet_out   <= packet_counter;
                        queue_select <= packet_counter[1:0];
                        valid_out    <= 1;

                        packet_counter <= packet_counter + 1'b1;
                    end

                    default: begin
                        active    <= 0;
                        valid_out <= 0;
                    end
                endcase
            end
        end
    end

endmodule