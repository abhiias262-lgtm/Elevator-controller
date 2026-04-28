`timescale 1ns/1ns

module elevator_dispatcher (
    input clk,
    input rst,
    
    // Hall Call Inputs (from outside buttons)
    input call_button_pressed,
    input [2:0] call_floor,
    input upward,          // 1 = UP call, 0 = DOWN call
    input downward,
    
    // Status from all 3 Elevators
    input [2:0] current_floor_E1,
    input [2:0] current_floor_E2,
    input [2:0] current_floor_E3,
    
    input [1:0] direction_E1,   // 00=IDLE, 01=UP, 10=DOWN
    input [1:0] direction_E2,
    input [1:0] direction_E3,
    
    // Assigned Calls to Each Elevator 
    output reg [2:0] assigned_floor_E1,
    output reg       assigned_dir_E1,   // 1=UP, 0=DOWN
    output reg       assign_valid_E1,
    
    output reg [2:0] assigned_floor_E2,
    output reg       assigned_dir_E2,
    output reg       assign_valid_E2,
    
    output reg [2:0] assigned_floor_E3,
    output reg       assigned_dir_E3,
    output reg       assign_valid_E3
);

    reg [3:0] cost_E1, cost_E2, cost_E3;
    reg [1:0] selected_elev;

    // ====================== COST CALCULATION ======================
    always @(*) begin
        // Default high cost
        cost_E1 = 8;
        cost_E2 = 8;
        cost_E3 = 8;

        // Cost for Elevator 1
        if (direction_E1 == 2'b01 && upward)      // Same direction UP
            cost_E1 = (current_floor_E1 > call_floor) ? 15 : (call_floor - current_floor_E1);
        else if (direction_E1 == 2'b10 && downward) // Same direction DOWN
            cost_E1 = (current_floor_E1 < call_floor) ? 15 : (current_floor_E1 - call_floor);
        else
            cost_E1 = 4 + (call_floor > current_floor_E1 ? 
                      (call_floor - current_floor_E1) : (current_floor_E1 - call_floor));

        // Cost for Elevator 2
        if (direction_E2 == 2'b01 && upward)
            cost_E2 = (current_floor_E2 > call_floor) ? 15 : (call_floor - current_floor_E2);
        else if (direction_E2 == 2'b10 && downward)
            cost_E2 = (current_floor_E2 < call_floor) ? 15 : (current_floor_E2 - call_floor);
        else
            cost_E2 = 4 + (call_floor > current_floor_E2 ? 
                      (call_floor - current_floor_E2) : (current_floor_E2 - call_floor));

        // Cost for Elevator 3
        if (direction_E3 == 2'b01 && upward)
            cost_E3 = (current_floor_E3 > call_floor) ? 15 : (call_floor - current_floor_E3);
        else if (direction_E3 == 2'b10 && downward)
            cost_E3 = (current_floor_E3 < call_floor) ? 15 : (current_floor_E3 - call_floor);
        else
            cost_E3 = 4 + (call_floor > current_floor_E3 ? 
                      (call_floor - current_floor_E3) : (current_floor_E3 - call_floor));
    end

    // ====================== ASSIGNMENT LOGIC ======================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            assigned_floor_E1 <= 0; assign_valid_E1 <= 0;
            assigned_floor_E2 <= 0; assign_valid_E2 <= 0;
            assigned_floor_E3 <= 0; assign_valid_E3 <= 0;
            selected_elev <= 0;
        end
        else if (call_button_pressed) begin
            // Find elevator with minimum cost
            if (cost_E1 <= cost_E2 && cost_E1 <= cost_E3)
                selected_elev <= 2'b01;   // Elevator 1
            else if (cost_E2 <= cost_E3)
                selected_elev <= 2'b10;   // Elevator 2
            else
                selected_elev <= 2'b11;   // Elevator 3

            case (selected_elev)
                2'b01: begin
                    assigned_floor_E1 <= call_floor;
                    assigned_dir_E1   <= (current_floor_E1 <= call_floor) ? 1'b1 : 1'b0;
                    assign_valid_E1   <= 1;
                end
                2'b10: begin
                    assigned_floor_E2 <= call_floor;
                    assigned_dir_E2   <= (current_floor_E2 <= call_floor) ? 1'b1 : 1'b0;
                    assign_valid_E2   <= 1;
                end
                2'b11: begin
                    assigned_floor_E3 <= call_floor;
                    assigned_dir_E3   <= (current_floor_E3 <= call_floor) ? 1'b1 : 1'b0;
                    assign_valid_E3   <= 1;
                end
            endcase
        end
        else begin
            // Clear valid after one cycle 
            assign_valid_E1 <= 0;
            assign_valid_E2 <= 0;
            assign_valid_E3 <= 0;
        end
    end

endmodule