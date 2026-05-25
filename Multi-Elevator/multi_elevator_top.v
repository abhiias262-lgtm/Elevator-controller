`timescale 1ns/1ns

module multi_elevator_top (
    input clk,
    input rst,

    // Hall call inputs (corridor buttons — tested via multi_elevator_tb)
    input [2:0]   call_floor,
    input         call_button_pressed,
    input         upward,
    input         downward,

    // Elevator enable signals
    input         enable_ele1,
    input         enable_ele2,
    input         enable_ele3,

    // Elevator 1 outputs
    output wire       door_statusE1,
    output wire [2:0] current_floorE1,
    output wire [1:0] direction_E1,

    // Elevator 2 outputs
    output wire       door_statusE2,
    output wire [2:0] current_floorE2,
    output wire [1:0] direction_E2,

    // Elevator 3 outputs
    output wire       door_statusE3,
    output wire [2:0] current_floorE3,
    output wire [1:0] direction_E3
);

    wire [2:0] assigned_floor_E1, assigned_floor_E2, assigned_floor_E3;
    wire       assigned_dir_E1,   assigned_dir_E2,   assigned_dir_E3;
    wire new_call_E1, new_call_E2, new_call_E3;
    // ===================================================================
    // Instantiate 3 Elevators
    //
    // Cabin inputs (cabin_button_pressed, floor_req, stop) are tied to 0
    // because cabin behaviour is tested separately via cabin_tb, which
    // instantiates fsm_controller directly and drives those ports itself.
    // Routing them through the top module is unnecessary.
    // ===================================================================

    fsm_controller ELEV1 (
        .clk                  (clk),
        .rst                  (rst),
        .cabin_button_pressed (1'b0),
        .floor_req            (3'b000),
        .stop                 (1'b0),
        .new_call             (new_call_E1),
        .assign_floor         (assigned_floor_E1),
        .upward               (assigned_dir_E1),
        .downward             (~assigned_dir_E1),
        .door_status          (door_statusE1),
        .current_floor        (current_floorE1),
        .direction            (direction_E1)
    );

    fsm_controller  ELEV2 (
        .clk                  (clk),
        .rst                  (rst),
        .cabin_button_pressed (1'b0),
        .floor_req            (3'b000),
        .stop                 (1'b0),
        .new_call             (new_call_E2),
        .assign_floor         (assigned_floor_E2),
        .upward               (assigned_dir_E2),
        .downward             (~assigned_dir_E2),
        .door_status          (door_statusE2),
        .current_floor        (current_floorE2),
        .direction            (direction_E2)
    );

    fsm_controller  ELEV3 (
        .clk                  (clk),
        .rst                  (rst),
        .cabin_button_pressed (1'b0),
        .floor_req            (3'b000),
        .stop                 (1'b0),
        .new_call             (new_call_E3),
        .assign_floor         (assigned_floor_E3),
        .upward               (assigned_dir_E3),
        .downward             (~assigned_dir_E3),
        .door_status          (door_statusE3),
        .current_floor        (current_floorE3),
        .direction            (direction_E3)
    );

    // ===================================================================
    // Central Dispatcher
    // ===================================================================

    elevator_dispatcher GROUP_CTRL (
        .clk                 (clk),
        .rst                 (rst),
        .call_button_pressed (call_button_pressed),
        .call_floor          (call_floor),
        .upward              (upward),
        .downward            (downward),
        .new_call_E1         (new_call_E1),
        .new_call_E2         (new_call_E2),
        .new_call_E3         (new_call_E3),
        .enable_ele1         (enable_ele1),
        .enable_ele2         (enable_ele2),
        .enable_ele3         (enable_ele3),
        .current_floor_E1    (current_floorE1),
        .current_floor_E2    (current_floorE2),
        .current_floor_E3    (current_floorE3),
        .direction_E1        (direction_E1),
        .direction_E2        (direction_E2),
        .direction_E3        (direction_E3),
        .assigned_floor_E1   (assigned_floor_E1),
        .assigned_dir_E1     (assigned_dir_E1),
        .assigned_floor_E2   (assigned_floor_E2),
        .assigned_dir_E2     (assigned_dir_E2),
        .assigned_floor_E3   (assigned_floor_E3),
        .assigned_dir_E3     (assigned_dir_E3)
    );

endmodule