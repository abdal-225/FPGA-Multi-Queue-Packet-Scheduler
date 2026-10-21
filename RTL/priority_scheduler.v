
module priority_scheduler (
    input  [3:0] empty,
    input        request,
    output reg [1:0] selected_queue,
    output reg       select_valid
);

always @(*) begin
    // Default: no queue selected
    selected_queue = 2'b00;
    select_valid   = 1'b0;

    if (request) begin
        // Highest priority: Q0 > Q1 > Q2 > Q3
        if (!empty[0]) begin
            selected_queue = 2'b00;  // Q0
            select_valid   = 1'b1;
        end
        else if (!empty[1]) begin
            selected_queue = 2'b01;  // Q1
            select_valid   = 1'b1;
        end
        else if (!empty[2]) begin
            selected_queue = 2'b10;  // Q2
            select_valid   = 1'b1;
        end
        else if (!empty[3]) begin
            selected_queue = 2'b11;  // Q3
            select_valid   = 1'b1;
        end
    end
end

endmodule
