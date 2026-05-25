`timescale 1ns/1ns

module fsm_controller (

    // input from testbench / top module
    input       clk,
    input       rst,
    input       cabin_button_pressed,
    input [2:0] floor_req,
    input       stop,        // emergency stop

    // input from dispatcher through top module
    input [2:0] assign_floor,
    input       upward,
    input       downward,
    input       new_call,

    // output to top module
    output reg          door_status,
    output   [2:0]      current_floor,
    output reg  [1:0]   direction,
    output  reg [2:0]   floor_count

);

//============= TOTAL FLOORS ====================
    parameter   MAX_FLOOR   = 7,
                TIMEOUT_AT  = 20;

//============= STATES =======================
    parameter   IDLE        = 2'b00,
                GO_UP       = 2'b01,
                GO_DOWN     = 2'b10,
                OPEN_DOOR   = 2'b11;

//============= REGISTERS ======================

    reg [MAX_FLOOR:0]   call_request;   // hall requests assigned by dispatcher
    reg [MAX_FLOOR:0]   cabin_request;  // requests pressed inside the cabin

    reg [1:0]           current_state;
    reg [1:0]           next_state;
    reg [2:0]           next_target;
    reg [4:0]           door_timing_counter;
    reg                 has_request_above, has_request_below;
    reg                 moving_up;
    reg                 moving_down;

    integer j;

    // Combined request bitmap
    wire [MAX_FLOOR:0] request = call_request | cabin_request;

    assign current_floor = floor_count;

// --------- Direction output (combinational) ---------
    always @(*) begin
        if      (moving_up)   direction = 2'b01;
        else if (moving_down) direction = 2'b10;
        else                  direction = 2'b00;
    end

//      QUEUE FOR FLOOR REQUESTS

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            call_request  <= 0;
            cabin_request <= 0;
        end else begin
            if (new_call)
                call_request[assign_floor] <= 1'b1;

            if (cabin_button_pressed)
                cabin_request[floor_req] <= 1'b1;

            // Clear the served floor once the door has been open long enough
            if (current_state == OPEN_DOOR && timeout) begin
                cabin_request[floor_count] <= 1'b0;
                call_request[floor_count]  <= 1'b0;
            end
        end
    end

//      TARGET FINDING (combinational)

    reg [2:0] target;
    reg       found;
    integer   i;

    always @(*) begin
        target = floor_count;
        found  = 0;

        // Request at current floor — open door immediately
        if (request[floor_count]) begin
            target = floor_count;
            found  = 1;
        end
        else if (moving_up) begin
            // Scan above first (SCAN algorithm)
            for (i = floor_count + 1; i <= MAX_FLOOR; i = i + 1)
                if (request[i] && !found) begin target = i; found = 1; end
            // If nothing above, reverse and look below
            if (!found) begin
                for (i = floor_count - 1; i >= 0; i = i - 1)
                    if (request[i] && !found) begin target = i; found = 1; end
            end
        end
        else if (moving_down) begin
            // Guard against unsigned underflow when at floor 0
            if (floor_count > 0) begin
                for (i = floor_count - 1; i >= 0; i = i - 1)
                    if (request[i] && !found) begin target = i; found = 1; end
            end
            // If nothing below, reverse and look above
            if (!found) begin
                for (i = floor_count + 1; i <= MAX_FLOOR; i = i + 1)
                    if (request[i] && !found) begin target = i; found = 1; end
            end
        end
        else begin
            // IDLE: find nearest floor (lowest index first, same as SCAN start)
            for (i = 0; i <= MAX_FLOOR; i = i + 1)
                if (request[i] && !found) begin target = i; found = 1; end
        end
    end

    // Register the target (1-cycle latency before FSM reacts)
    always @(posedge clk or posedge rst) begin
        if (rst) next_target <= 0;
        else      next_target <= target;
    end

//      STATE DECISION (combinational)

    always @(*) begin
        next_state = current_state;

        case (current_state)

        IDLE: begin
            if (|request) begin
                if      (next_target > floor_count) next_state = GO_UP;
                else if (next_target < floor_count) next_state = GO_DOWN;                
                else    next_state = OPEN_DOOR;     // keeping next_state = IDLE, freezes the elevator.
            end
        end

        GO_UP, GO_DOWN: begin
            if (stop || next_target == floor_count)
                next_state = OPEN_DOOR;
            else
                next_state = current_state;
        end

        OPEN_DOOR: begin
            if (timeout)
                next_state = IDLE;
        end

        default: next_state = IDLE;
        endcase
    end

//      DIRECTION CONTROL

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            moving_up   <= 0;
            moving_down <= 0;
        end else begin
            // Pre-compute whether requests exist above / below current floor
            has_request_above <= 1'b0;
            has_request_below <= 1'b0;
            for (j = floor_count + 1; j <= MAX_FLOOR; j = j + 1)
                if (request[j]) has_request_above <= 1'b1;
            for (j = 0; j < floor_count; j = j + 1)
                if (request[j]) has_request_below <= 1'b1;

            // Set direction when leaving IDLE.
            // updating only moving_up/down during GO_UP/GO_DOWN,
            // so the first cycle after IDLE the direction signal was wrong.
            if (current_state == IDLE && |request) begin
                if      (next_target > floor_count) begin moving_up <= 1; moving_down <= 0; end
                else if (next_target < floor_count) begin moving_down <= 1; moving_up <= 0; end
            end
            else if (current_state == GO_UP || current_state == GO_DOWN) begin
                if (has_request_above) begin
                    moving_up <= 1; moving_down <= 0;
                end else if (has_request_below) begin
                    moving_down <= 1; moving_up <= 0;
                end
            end
            else if (current_state == OPEN_DOOR && timeout) begin
                // Prepare direction for the next journey after door closes
                if      (has_request_above) begin moving_up <= 1; moving_down <= 0; end
                else if (has_request_below) begin moving_down <= 1; moving_up <= 0; end
                else                        begin moving_up <= 0; moving_down <= 0; end
            end
        end
    end

//      STATE TRANSITIONS

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

//      FLOOR MOVEMENT

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            floor_count <= 0;
        end
        else if (current_state == GO_UP) begin
            if (floor_count < next_target && floor_count < MAX_FLOOR)
                floor_count <= floor_count + 1;
        end
        else if (current_state == GO_DOWN) begin
            if (floor_count > next_target && floor_count > 0)
                floor_count <= floor_count - 1;
        end
    end

//      DOOR OPEN TIMER

    always @(posedge clk or posedge rst) begin
        if (rst)
            door_timing_counter <= 0;
        else if (current_state == OPEN_DOOR) begin
            if (door_timing_counter <= TIMEOUT_AT)
                door_timing_counter <= door_timing_counter + 1;
        end
        else
            door_timing_counter <= 0;
    end

    wire timeout = (door_timing_counter == TIMEOUT_AT);

//      DOOR STATUS OUTPUT

    always @(posedge clk or posedge rst) begin
        if (rst)
            door_status <= 1'b0;
        else if (current_state == OPEN_DOOR && !timeout)
            door_status <= 1'b1;
        else
            door_status <= 1'b0;
    end

endmodule


// ======================================================================
//  cabin_tb — stand-alone single-elevator testbench (unchanged logic,
//             MY_ELE_ID defaults to 2'd1 so it works without changes)
// ======================================================================
module cabin_tb;
    reg         rst;
    reg         clk;
    reg         stop;
    reg         upward;
    reg         downward;
    reg         cabin_button_pressed;
    reg [2:0]   floor_req;
    reg [2:0]   assign_floor;
    reg         new_call;
    wire        door_status;
    wire [1:0]  direction;
    wire [2:0]  floor_count;

    parameter MAX_FLOOR = 7;

    fsm_controller DUT (
        .clk(clk),
        .cabin_button_pressed(cabin_button_pressed),
        .floor_req(floor_req),
        .stop(stop),
        .new_call(new_call),
        .assign_floor(assign_floor),
        .rst(rst),
        .upward(upward),
        .downward(downward),
        .door_status(door_status),
        .direction(direction),
        .floor_count(floor_count)
    );

// ==================== Clock Generation ====================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

// ==================== Random Cabin Button Press ====================
    task random_cabin_press;
        integer rand_floor;
        begin
            rand_floor = $urandom_range(0, MAX_FLOOR);
            floor_req  = rand_floor;
            cabin_button_pressed = 1;
            @(posedge clk);
            cabin_button_pressed = 0;
            $display("[%0t] Cabin request = %0d", $time, floor_req);
        end
    endtask

// ==================== Random Emergency Stop ====================
    task random_emergency;
        begin
            stop = 1;
            @(posedge clk);
            stop = 0;
            $display("[%0t] *** EMERGENCY STOP Triggered ***", $time);
        end
    endtask

    // reg [MAX_FLOOR:0] prev_floor = 0;
    // reg prev_door = 0;

    // always @(posedge clk) begin
    //     if (floor_count != prev_floor || door_status != prev_door) begin
    //         $display("[%0t] Door Open - %0d | Floor: %0d",
    //                  $time, door_status, floor_count);
    //         prev_floor <= floor_count;
    //         prev_door  <= door_status;
    //     end
    // end

    initial begin
        repeat(5) @(posedge clk);

        $display("=== Starting Random Stimulus Test ===");
        repeat(10) begin
            if ($random % 15 == 0)
                random_emergency();
            else if ($random % 2 == 0) begin
                random_cabin_press();
                if      (new_call== 2'd1) $display("Request from 1st Elevator");
                else if (new_call== 2'd2) $display("Request from 2nd Elevator");
                else if (new_call == 2'd3) $display("Request from 3rd Elevator");
            end
            repeat($urandom_range(5, 20)) @(posedge clk);
        end
    end

endmodule