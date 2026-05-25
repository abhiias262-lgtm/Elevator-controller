`timescale 1ns/1ns

module elevator_dispatcher (
    input clk,
    input rst,
    
    // Hall Call Inputs from buttons
    input           call_button_pressed,
    input [2:0]     call_floor,
    input           upward,      // 1 = UP call
    input           downward,

    // Enable buttons
    input           enable_ele1,
    input           enable_ele2,
    input           enable_ele3,
    
    // Status from 3 Elevators
    input [2:0]     current_floor_E1,
    input [2:0]     current_floor_E2,
    input [2:0]     current_floor_E3,
    
    input [1:0]     direction_E1,   // 00=IDLE, 01=UP, 10=DOWN
    input [1:0]     direction_E2,
    input [1:0]     direction_E3,

    // output reg [1:0] assign_selected,
    output reg new_call_E1,
    output reg new_call_E2,
    output reg new_call_E3,

    output reg [2:0] assigned_floor_E1,
    output reg       assigned_dir_E1,
 
    output reg [2:0] assigned_floor_E2,
    output reg       assigned_dir_E2,
  
    output reg [2:0] assigned_floor_E3,
    output reg       assigned_dir_E3
);

    parameter MAX_FLOOR = 7;

    // hall_request[floor][0] = pending flag, [1] = direction (1=UP)
    reg [1:0] hall_request [0:MAX_FLOOR];

    //  Separate valid flag and floor index
    // 'served' was dual-use (sometimes floor index, sometimes constant 1).
    // Also the old 'if (served != 0)' check prevented clearing floor 0.

    reg         served_valid;
    reg [2:0]   served_floor;

    reg [3:0] cost_E1, cost_E2, cost_E3;
    integer j;

    // ====================== Store / Clear Hall Calls ======================
    //  Clearing logic moved inside else branch so it doesn't
    //              execute during reset when 'served_valid' may hold stale data.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j <= MAX_FLOOR; j = j + 1)
                hall_request[j] <= 2'b00;
        end else begin
            // Register new hall call
            if (call_button_pressed)
                // [1]=direction(upward), [0]=pending flag
                hall_request[call_floor] <= {upward, 1'b1};

            //Clear the served floor using the separated flag+index.
            // served_valid is set by the cost block one cycle earlier.
            if (served_valid)
                hall_request[served_floor] <= 2'b00;
        end
    end

    // ====================== Cost + Assignment Logic ======================

    integer i;

    // Temp variables — use blocking (=) so the for-loop can see the flag immediately
    reg [2:0]  t_floor;
    reg [1:0]  t_selected;
    reg        t_valid;
    reg        t_dir;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            assigned_floor_E1 <= 0; assigned_dir_E1 <= 0;
            assigned_floor_E2 <= 0; assigned_dir_E2 <= 0;
            assigned_floor_E3 <= 0; assigned_dir_E3 <= 0;
            // assign_selected   <= 0;
            served_valid      <= 0;
            served_floor      <= 0;
            new_call_E1 <= 0; new_call_E2 <= 0; new_call_E3 <= 0;
        end else begin
            // Default: nothing dispatched this cycle
            // assign_selected <= 0;
            served_valid    <= 0;
            new_call_E1 <= 0; new_call_E2 <= 0; new_call_E3 <= 0;

            // Initialise temp working registers with blocking assignment
            t_valid    = 0;
            t_floor    = 0;
            t_dir      = 0;
            t_selected = 0;

            //  Use blocking t_valid flag so only the FIRST (lowest)
            //              pending floor is picked.  Previously, non-blocking '<=
            //              caused the LAST matching floor to overwrite earlier ones.
            for (i = 0; i <= MAX_FLOOR; i = i + 1) begin
                if (hall_request[i][0] && !t_valid && |{enable_ele1, enable_ele2, enable_ele3}) begin
                    t_floor = i;
                    t_dir   = hall_request[i][1];
                    t_valid = 1;  // blocking — stops further iterations from matching

                    // ---- Determine which elevator to dispatch ----

                    // Single elevator enabled
                    if (enable_ele1 && !enable_ele2 && !enable_ele3) begin
                        t_selected = 2'd1;
                    end
                    else if (!enable_ele1 && enable_ele2 && !enable_ele3) begin
                        t_selected = 2'd2;
                    end
                    else if (!enable_ele1 && !enable_ele2 && enable_ele3) begin
                        t_selected = 2'd3;
                    end
                    else begin
                        // Two or three elevators enabled: compute cost for each.
                        // Disabled elevators get worst-case cost (15) so they are
                        // never selected.
                        cost_E1 = enable_ele1 ?
                            get_cost(current_floor_E1, direction_E1, i, hall_request[i][1]) : 4'd15;
                        cost_E2 = enable_ele2 ?
                            get_cost(current_floor_E2, direction_E2, i, hall_request[i][1]) : 4'd15;
                        cost_E3 = enable_ele3 ?
                            get_cost(current_floor_E3, direction_E3, i, hall_request[i][1]) : 4'd15;


                        if (cost_E1 <= cost_E2 && cost_E1 <= cost_E3)
                            t_selected = 2'd1;
                        else if (cost_E2 <= cost_E3)
                            t_selected = 2'd2;
                        else
                            t_selected = 2'd3;
                    end
                end
            end // for

            // Apply the assignment made during the scan
            if (t_valid) begin
                served_valid    <= 1;       // tell Block A to clear this floor next cycle
                served_floor    <= t_floor; // always the actual floor index
                // assign_selected <= t_selected;

                // Only update the floor/direction registers of the selected elevator
                case (t_selected)
                    2'd1: begin assigned_floor_E1<=t_floor; assigned_dir_E1<=t_dir; new_call_E1<=1; end
                    2'd2: begin assigned_floor_E2<=t_floor; assigned_dir_E2<=t_dir; new_call_E2<=1; end
                    2'd3: begin assigned_floor_E3<=t_floor; assigned_dir_E3<=t_dir; new_call_E3<=1; end
                endcase
            end
        end
    end


    // ====================== Cost Function ======================
    function [3:0] get_cost;
        input [2:0] curr_floor;     // current floor of the elevator
        input [1:0] dir;            // current direction of the elevator (00=IDLE,01=UP,10=DN)
        input [2:0] req_floor;      // requested floor
        input       req_dir;        // requested direction (1=UP, 0=DOWN)

        begin
            // Elevator going UP, call is also UP
            if (dir == 2'b01 && req_dir == 1)
                get_cost = (curr_floor > req_floor) ? 12 : (req_floor - curr_floor);
            // Elevator going DOWN, call is also DOWN
            else if (dir == 2'b10 && req_dir == 0)
                get_cost = (curr_floor < req_floor) ? 12 : (curr_floor - req_floor);
            // Elevator is idle
            else if (dir == 2'b00)
                get_cost = (req_floor > curr_floor) ? (req_floor - curr_floor) : (curr_floor - req_floor);
            // Direction mismatch — penalise
            else
                get_cost = 5 + (req_floor > curr_floor ? (req_floor - curr_floor) : (curr_floor - req_floor));
        end
    endfunction

endmodule