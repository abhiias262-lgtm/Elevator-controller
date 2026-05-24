`timescale 1ns/1ns

module multi_elevator_top (
    input clk,
    input rst,
    //input from hall testbench 
    input [2:0]   call_floor,   
    input         call_button_pressed,                        
    input         upward,                       
    input         downward,

    //input from the hall testbench
    input         enable_ele1,
    input         enable_ele2,
    input         enable_ele3,   

           
    // Elevator 1
    output wire       door_statusE1,        // generated from the elevator to DUT.(all output written over here)
    output wire [2:0] current_floorE1,
    output wire [1:0] direction_E1,


    // Elevator 2
    output wire       door_statusE2,
    output wire [2:0] current_floorE2,
    output wire [1:0] direction_E2,


    // Elevator 3
    output wire       door_statusE3,
    output wire [2:0] current_floorE3,
    output wire [1:0] direction_E3

);


    // Assigned calls from Dispatcher to each Elevator
    wire [2:0] assigned_floor_E1, assigned_floor_E2, assigned_floor_E3;
    wire       assigned_dir_E1,   assigned_dir_E2,   assigned_dir_E3;  
    wire [1:0] assign_selected;


    // Instantiate 3 Independent Elevators
    fsm_controller ELEV1 (
        .clk(clk),
        .rst(rst),
        .selected(assign_selected),                            
        .assign_floor(assigned_floor_E1),                                                      
        .upward(assigned_dir_E1 ),                                      
        .downward(assigned_dir_E1 ),                                                           
        .door_status(door_statusE1),        
        .current_floor(current_floorE1),   
        .direction(direction_E1)          
      
    );      

    fsm_controller ELEV2 (
        .clk(clk),
        .rst(rst),   
        .selected(assign_selected),
        .assign_floor(assigned_floor_E2),
        .upward(assigned_dir_E2 ),
        .downward(assigned_dir_E2 ),
        .door_status(door_statusE2),
        .current_floor(current_floorE2),
        .direction(direction_E2)

    );

    fsm_controller ELEV3 (
        .clk(clk),
        .rst(rst),
        .selected(assign_selected),
        .assign_floor(assigned_floor_E3),                     
        .upward(assigned_dir_E3 ),                     
        .downward(assigned_dir_E3 ),                      
        .door_status(door_statusE3),
        .current_floor(current_floorE3),
        .direction(direction_E3)
    );

    // ===================================================================
    // Instantiate Central Dispatcher
    // ===================================================================

    elevator_dispatcher GROUP_CTRL (
        .clk(clk),
        .rst(rst),

        .call_button_pressed (call_button_pressed),        
        .call_floor(call_floor),                         
        .upward(upward),                                   
        .downward(downward),                                

        .assign_selected(assign_selected),                 

        .enable_ele1(enable_ele1),                       
        .enable_ele2(enable_ele2),                     
        .enable_ele3(enable_ele3),                          

        // Status from all Elevators
        .current_floor_E1(current_floorE1),        
        .current_floor_E2(current_floorE2),         
        .current_floor_E3(current_floorE3),         

        .direction_E1(direction_E1),                
        .direction_E2(direction_E2),                
        .direction_E3(direction_E3),                

        // Assigned Calls to Elevators
        .assigned_floor_E1(assigned_floor_E1),          //signal to elevator 1.
        .assigned_dir_E1(assigned_dir_E1),


        .assigned_floor_E2(assigned_floor_E2),          //signal to elevator 2.
        .assigned_dir_E2(assigned_dir_E2),
  

        .assigned_floor_E3(assigned_floor_E3),          //signal to elevator 3.
        .assigned_dir_E3(assigned_dir_E3)

    );

endmodule