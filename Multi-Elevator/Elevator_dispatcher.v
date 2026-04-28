`timescale 1ns/1ns

module elevator_dispatcher (
    input clk,
    input rst,
    
    // Hall Call Inputs
    input           call_button_pressed,
    input [2:0]     call_floor,
    input           upward,      // 1 = UP call
    input           downward,    // 1 = DOWN call
    
    // Status from Elevators
    input [2:0]     current_floor_E1,
    input [2:0]     current_floor_E2,
    input [2:0]     current_floor_E3,
    
    input [1:0]     direction_E1,
    input [1:0]     direction_E2,
    input [1:0]     direction_E3,
    
    // Assigned Calls to Elevators
    output reg [2:0] assigned_floor_E1,
    output reg       assigned_dir_E1,
    output reg       assign_valid_E1,
    
    output reg [2:0] assigned_floor_E2,
    output reg       assigned_dir_E2,
    output reg       assign_valid_E2,
    
    output reg [2:0] assigned_floor_E3,
    output reg       assigned_dir_E3,
    output reg       assign_valid_E3
);

    parameter MAX_FLOOR = 7 ;
    reg [3:0] cost_E1, cost_E2, cost_E3;
    reg [1:0] selected_elev;
    reg [MAX_FLOOR:0][1:0] hall_request;
    
    // NEW: Remember the hall call until it is assigned
    reg       call_pending;
    reg [2:0] pending_floor;
    reg       pending_dir;   // 1=UP, 0=DOWN

    // ================= queue of incoming request ===============call_button_pressed
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hall_request<= 0;
        end
        else begin
            if (call_button_pressed) begin
                hall_request[call_floor][0]<=1;
                if (upward) begin
                    hall_request[call_floor][1]<=1;
                end
                else begin
                    hall_request[call_floor][1]<=0;
                end
            end
        end
    end

    // =============== checking for hall request ================call_button_pressed

    

    // ====================== Latch Hall Call ======================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            call_pending  <= 0;
            pending_floor <= 0;
            pending_dir   <= 0;
        end
        else if (call_button_pressed && !call_pending) begin
            call_pending  <= 1;
            pending_floor <= call_floor;
            pending_dir   <= upward;          // problem here 
        end
        else if (assign_valid_E1 || assign_valid_E2 || assign_valid_E3) begin
            call_pending <= 0;   // Clear only after successful assignment
        end
    end

    // ====================== Cost Calculation ======================
    always @(*) begin
        cost_E1 = 8'hF; cost_E2 = 8'hF; cost_E3 = 8'hF;

        // Elevator 1
        if (direction_E1 == 2'b01 && pending_dir == 1)      //upward
            cost_E1 = (current_floor_E1 > pending_floor) ? 12 : (pending_floor - current_floor_E1);
        else if (direction_E1 == 2'b10 && pending_dir == 0)     //downward
            cost_E1 = (current_floor_E1 < pending_floor) ? 12 : (current_floor_E1 - pending_floor);
        else                            // Elevator 1 not moving
            cost_E1 = 5 + (pending_floor > current_floor_E1 ? 
                      (pending_floor - current_floor_E1) : (current_floor_E1 - pending_floor));

        // Elevator 2
        if (direction_E2 == 2'b01 && pending_dir == 1)
            cost_E2 = (current_floor_E2 > pending_floor) ? 12 : (pending_floor - current_floor_E2);
        else if (direction_E2 == 2'b10 && pending_dir == 0)
            cost_E2 = (current_floor_E2 < pending_floor) ? 12 : (current_floor_E2 - pending_floor);
        else
            cost_E2 = 5 + (pending_floor > current_floor_E2 ?
                      (pending_floor - current_floor_E2) : (current_floor_E2 - pending_floor));

        // Elevator 3
        if (direction_E3 == 2'b01 && pending_dir == 1)
            cost_E3 = (current_floor_E3 > pending_floor) ? 12 : (pending_floor - current_floor_E3);
        else if (direction_E3 == 2'b10 && pending_dir == 0)
            cost_E3 = (current_floor_E3 < pending_floor) ? 12 : (current_floor_E3 - pending_floor);
        else
            cost_E3 = 5 + (pending_floor > current_floor_E3 ? 
                      (pending_floor - current_floor_E3) : (current_floor_E3 - pending_floor));
    end

    // ====================== Assignment Logic ======================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            assigned_floor_E1 <= 0; assign_valid_E1 <= 0;
            assigned_floor_E2 <= 0; assign_valid_E2 <= 0;
            assigned_floor_E3 <= 0; assign_valid_E3 <= 0;
            selected_elev <= 0;
        end
        else if (call_pending && !assign_valid_E1 && !assign_valid_E2 && !assign_valid_E3) begin
            // Choose best elevator
            if (cost_E1 <= cost_E2 && cost_E1 <= cost_E3)
                selected_elev <= 2'b01;
            else if (cost_E2 <= cost_E3)
                selected_elev <= 2'b10;
            else
                selected_elev <= 2'b11;

            case (selected_elev)
                2'b01: begin
                    assigned_floor_E1 <= pending_floor;
                    assigned_dir_E1   <= pending_dir;
                    assign_valid_E1   <= 1;
                end
                2'b10: begin
                    assigned_floor_E2 <= pending_floor;
                    assigned_dir_E2   <= pending_dir;
                    assign_valid_E2   <= 1;
                end
                2'b11: begin
                    assigned_floor_E3 <= pending_floor;
                    assigned_dir_E3   <= pending_dir;
                    assign_valid_E3   <= 1;
                end
            endcase
        end
        else begin
            // Clear valid signals (short pulse is fine now because of call_pending)
            assign_valid_E1 <= 0;
            assign_valid_E2 <= 0;
            assign_valid_E3 <= 0;
        end
    end

endmodule