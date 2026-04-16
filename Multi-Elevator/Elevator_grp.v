`timescale 1ns/1ns

module multi_elevator_top (
    input clk,
    input rst,

    input [2:0]   floor_req,                   
    input         new_floor_button_pressed,     
    input [2:0]   call_floor,                   
    input         call_button_pressed,          
    input         upward,                       
    input         downward,                     
    input         stop, 


    // Elevator 1
    output wire       door_statusE1,        // generated from the elevator to DUT.(all output written over here)
    output wire       moving_upE1,          
    output wire       moving_downE1,
    output wire [2:0] current_floorE1,

    // Elevator 2
    output wire       door_statusE2,
    output wire       moving_upE2,
    output wire       moving_downE2,
    output wire [2:0] current_floorE2,

    // Elevator 3
    output wire       door_statusE3,
    output wire       moving_upE3,
    output wire       moving_downE3,
    output wire [2:0] current_floorE3
);


    wire [1:0] direction_E1, direction_E2, direction_E3;        // why it is required here ??

    // Assigned calls from Dispatcher to each Elevator
    wire [2:0] assigned_floor_E1, assigned_floor_E2, assigned_floor_E3;
    wire       assigned_dir_E1,   assigned_dir_E2,   assigned_dir_E3;  // 1=UP, 0=DOWN
    wire       assign_valid_E1,   assign_valid_E2,   assign_valid_E3;


    // Instantiate 3 Independent Elevators

    fsm_controller ELEV1 (
        .clk(clk),
        .rst(rst),
        .floor_req(floor_req),
        .new_floor_button_pressed(new_floor_button_pressed),
        .call_floor(assigned_floor_E1),      
        .upward(assigned_dir_E1 & assign_valid_E1),
        .downward(~assigned_dir_E1 & assign_valid_E1),
        .stop(stop),
        .door_status(door_statusE1),        //Output of this Elevator
        .moving_up(moving_upE1),            //Output of this Elevator
        .moving_down(moving_downE1),        //Output of this Elevator
        .current_floor(current_floorE1),    //Output of this Elevator
        .direction(direction_E1)            //Output of this Elevator
    );      

    fsm_controller ELEV2 (
        .clk(clk),
        .rst(rst),
        .floor_req(floor_req),
        .new_floor_button_pressed(new_floor_button_pressed),
        .call_floor(assigned_floor_E2),
        .upward(assigned_dir_E2 & assign_valid_E2),
        .downward(~assigned_dir_E2 & assign_valid_E2),
        .stop(stop),
        .door_status(door_statusE2),
        .moving_up(moving_upE2),
        .moving_down(moving_downE2),
        .current_floor(current_floorE2),
        .direction(direction_E2)
    );

    fsm_controller ELEV3 (
        .clk(clk),
        .rst(rst),
        .floor_req(floor_req),
        .new_floor_button_pressed(new_floor_button_pressed),
        .call_floor(assigned_floor_E3),                     
        .upward(assigned_dir_E3 & assign_valid_E3),                     
        .downward(~assigned_dir_E3 & assign_valid_E3),                      
        .stop(stop),
        .door_status(door_statusE3),
        .moving_up(moving_upE3),
        .moving_down(moving_downE3),
        .current_floor(current_floorE3),
        .direction(direction_E3)
    );

    // ===================================================================
    // Instantiate Central Dispatcher
    // ===================================================================

    elevator_dispatcher GROUP_CTRL (
        .clk(clk),
        .rst(rst),

        // Hall Call Inputs
        .call_button_pressed (call_button_pressed),     // siganl from test bench
        .call_floor(call_floor),                        
        .upward(upward),                                
        .downward(downward),                           

        // Status from all Elevators
        .current_floor_E1(current_floorE1),         // from controller(elevator)
        .current_floor_E2(current_floorE2),         
        .current_floor_E3(current_floorE3),         

        .direction_E1(direction_E1),                
        .direction_E2(direction_E2),                
        .direction_E3(direction_E3),                

        // Assigned Calls to Elevators
        .assigned_floor_E1(assigned_floor_E1),          //signal to elevator 1.
        .assigned_dir_E1(assigned_dir_E1),
        .assign_valid_E1(assign_valid_E1),

        .assigned_floor_E2(assigned_floor_E2),          //signal to elevator 2.
        .assigned_dir_E2(assigned_dir_E2),
        .assign_valid_E2(assign_valid_E2),

        .assigned_floor_E3(assigned_floor_E3),          //signal to elevator 3.
        .assigned_dir_E3(assigned_dir_E3),
        .assign_valid_E3(assign_valid_E3)
    );

endmodule