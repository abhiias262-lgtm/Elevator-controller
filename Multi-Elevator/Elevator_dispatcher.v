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

    // output to elevator directly not to grp that's why these are assigned as wire 
    output reg [1:0] assign_selected,

    output reg [2:0] assigned_floor_E1,
    output reg       assigned_dir_E1,
 
    output reg [2:0] assigned_floor_E2,
    output reg       assigned_dir_E2,
  
    output reg [2:0] assigned_floor_E3,
    output reg       assigned_dir_E3

);
    // Max floor count 
    parameter MAX_FLOOR = 7;

    // signal to check if any request served or not if served than that floor count assigned to it .
    reg [1:0] served;


    // the incoming hall requests are stored here 
    reg [1:0] hall_request [0:MAX_FLOOR];   


    reg [3:0] cost_E1, cost_E2, cost_E3;
    integer j;


    // ====================== Store New Hall Calls ======================
    always @(posedge clk or posedge rst) begin

        // sets zero to all places in array
        if (rst) begin
            for ( j=0; j<=MAX_FLOOR; j=j+1) begin
                hall_request[j][0]<= 0;
                hall_request[j][1]<= 0;
            end
        end
                // update the array with incoming hall requests
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

        
         // clears the request from the array when the elevator is assigned 
        if (served != 0) begin
            hall_request[served][0]<=0;
            hall_request[served][1]<=0;
        end



    end

    // ====================== Cost + Assignment Logic ======================

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            assigned_floor_E1 <= 0; 
            assigned_floor_E2 <= 0; 
            assigned_floor_E3 <= 0; 
            assign_selected <=0;
            served<=0;
        end
        else begin
            // Default: no assignment this cycle
            assign_selected <= 0;
            served<=0;

            // Scan all floors from bottom to top every clock pulse 
            for (i = 0; i <= MAX_FLOOR; i = i + 1) begin
                if (hall_request[i][0]) begin   // if there is a pending request at floor i


                    // if only one elevator is enabled 
                    if (enable_ele1==1 && enable_ele2==0 && enable_ele3==0) begin
                            assigned_floor_E1 <= i;
                            assigned_dir_E1   <= hall_request[i][1];
                            served <= i;
                            assign_selected <= 2'd1;
                    end
                    else if (enable_ele1==0 && enable_ele2==1 && enable_ele3==0)begin
                            assigned_floor_E2 <= i;
                            assigned_dir_E2   <= hall_request[i][1];
                            served <= i;
                            assign_selected<=2'd2;
                    end
                    else if (enable_ele1==0 && enable_ele2==0 && enable_ele3==1) begin
                            assigned_floor_E3 <= i;
                            assigned_dir_E3   <= hall_request[i][1];
                            served <= i;
                            assign_selected<=2'd3;
                    end


                    // if any of the two elevators are enabled
                    else if (enable_ele1==1 && enable_ele2==1 && enable_ele3==0) begin
                        cost_E1 = get_cost(current_floor_E1, direction_E1, i, hall_request[i][1]);
                        cost_E2 = get_cost(current_floor_E2, direction_E2, i, hall_request[i][1]);
                        cost_E3 = 20;
                    end
                    else if (enable_ele1==1 && enable_ele2==0 && enable_ele3==1) begin
                        cost_E1 = get_cost(current_floor_E1, direction_E1, i, hall_request[i][1]);
                        cost_E3 = get_cost(current_floor_E3, direction_E3, i, hall_request[i][1]);
                        cost_E2 = 20;

                    end
                    else if (enable_ele1==0 && enable_ele2==1 && enable_ele3==1) begin
                         cost_E3 = get_cost(current_floor_E3, direction_E3, i, hall_request[i][1]);
                         cost_E2 = get_cost(current_floor_E2, direction_E2, i, hall_request[i][1]);
                         cost_E1 = 20;
                    end


                    // if all three elevators are enabled 
                    else begin
                        cost_E1 = get_cost(current_floor_E1, direction_E1, i, hall_request[i][1]);
                        cost_E2 = get_cost(current_floor_E2, direction_E2, i, hall_request[i][1]);
                        cost_E3 = get_cost(current_floor_E3, direction_E3, i, hall_request[i][1]);
                    end


                    // Assign to the elevator with lowest cost
                        if ((cost_E1 <= cost_E2 && cost_E1 <= cost_E3) && (cost_E1 < 2)) begin:costly
                            assigned_floor_E1 <= i;
                            assigned_dir_E1   <= hall_request[i][1];
                            served          <= 1;
                            assign_selected<=2'd1;
                        end
                        else if ((cost_E2 <= cost_E3)&& (cost_E2 < 2)) begin
                            assigned_floor_E2 <= i;
                            assigned_dir_E2   <= hall_request[i][1];
                            served              <= 1;
                            assign_selected<=2'd2;
                        end
                        else if(cost_E3 < 2) begin
                            assigned_floor_E3 <= i;
                            assigned_dir_E3   <= hall_request[i][1];
                            served              <= 1;
                            assign_selected<=2'd3;
                        end
                
                end
            end
        end
    end


    // ====================== Cost Function ======================
    function [3:0] get_cost;
        input [2:0] curr_floor;     //current floor of the elevator
        input [1:0] dir;            //current direction of the elevator
        input [2:0] req_floor;      //where to go (floor)
        input       req_dir;        //in which direction to go

        begin
             // Both going UP
            if (dir == 2'b01 && req_dir == 1)     
                get_cost = (curr_floor > req_floor) ? 12 : (req_floor - curr_floor);
            // Both going DOWN
            else if (dir == 2'b10 && req_dir == 0)
                get_cost = (curr_floor < req_floor) ? 12 : (curr_floor - req_floor);
            // if elevator is not moving 
            else if (dir == 2'b00)
                get_cost = (req_floor > curr_floor) ? (req_floor - curr_floor) : (curr_floor - req_floor);
            else
                get_cost = 5 + (req_floor > curr_floor ? (req_floor - curr_floor) : (curr_floor - req_floor));
        end
    endfunction

endmodule