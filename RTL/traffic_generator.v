module traffic_generator(
    input wire clk,reset,start,
    input wire [1:0] traffic_mode,
    output reg [15:0] packet_out,
    output reg [1:0] queue_select,
    output reg valid_out
    );
    
    // Traffic modes
    localparam SINGLE       = 2'b00;
    localparam BURST        = 2'b01;
    localparam CONTINUOUS   = 2'b10;
    localparam QUEUE_SPEC   = 2'b11;
    
    // Internal Registers
    reg[1:0] mode_reg;
    reg[3:0] burst_count;
    reg active;
    
    localparam BURST_LENGTH = 4'd8;
    
    always @(posedge clk or posedge reset) begin
    
        if(reset) begin
            packet_out  <= 16'b0;
            queue_select <= 2'b0;
            valid_out   <= 1'b0;
            mode_reg    <= 2'b0;
            burst_count <= 4'b0;
            active      <= 1'b0;
        end
        
        else begin
            
            if(start & !active) begin
                mode_reg    <= traffic_mode ;
                burst_count <= 4'b0 ;
                active      <= 1'b1 ;
                valid_out   <= 1'b0 ;
            end
            
            else if (active) begin
            
                case (mode_reg)
                    
                    SINGLE : begin
                        packet_out   <= 16'hA001;
                        queue_select <= 2'b00;
                        valid_out    <= 1'b1;
                        active       <= 1'b0;
                    end
                    
                    BURST : begin
                        packet_out   <= 16'hB000 + burst_count;
                        queue_select <= burst_count[1:0];
                        valid_out    <= 1'b1;

                        if (burst_count == BURST_LENGTH - 1) begin
                            burst_count <= 4'b0;
                            active      <= 1'b0;
                        end

                        else begin
                            burst_count <= burst_count + 1'b1;
                        end
                    end
                    
                    CONTINUOUS : begin
                        packet_out   <= 16'hC000 + burst_count;
                        queue_select <= burst_count[1:0];
                        valid_out    <= 1'b1;
                        burst_count <= burst_count + 1'b1;
                        active <= 1'b1;
                    end
                    
                    QUEUE_SPEC : begin
                        packet_out   <= 16'hD000 + burst_count;
                        queue_select <= 2'b10; // Generate packets for Q2
                        valid_out    <= 1'b1;
                        burst_count <= burst_count + 1'b1;
                        active <= 1'b1;
                    end
                    
                     default: begin
                        packet_out   <= 16'b0;
                        queue_select <= 2'b0;
                        valid_out    <= 1'b0;
                        active <= 1'b0;
                    end
                    
                endcase
            
            end
            
            else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule