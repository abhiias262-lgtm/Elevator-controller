`timescale 1ns/1ns
module fsm_controller (

    // input from internal testbench or cabin testbench
    input       clk,
    input       rst,
    input       cabin_button_pressed,
    input [2:0] floor_req,
    input       stop,               //emergency stop

    // input from dispatcher through top module 
    input [2:0] assign_floor,
    input       upward,
    input       downward,    
    input [1:0] selected, 
    
    // output to the top module 
    output reg          door_status,
    output   [2:0]      current_floor,     
    output reg  [1:0]   direction,
    output  reg [2:0]          floor_count       

);

//============= TOTAL FLOORS ====================
    parameter   MAX_FLOOR   = 7,
                TIMEOUT_AT  =20;

//============= PARAMETER =======================
    parameter   IDLE        = 2'b00, 
                GO_UP       = 2'b01,
                GO_DOWN     = 2'b10,
                OPEN_DOOR   = 2'b11;

//============= REGISTERS ======================

    reg [MAX_FLOOR:0]   call_request;   //this will store hall request from external testbench
    reg [MAX_FLOOR:0]   cabin_request;  //this will store cabin request from internal testbench

    reg [1:0]           current_state;
    reg [1:0]           next_state;
    reg [2:0]           next_target;
    reg [4:0]           door_timing_counter;
    reg                 has_request_above, has_request_below;
    reg                 moving_up;
    reg                 moving_down;



    integer j;
//combine both the arrays
    wire [MAX_FLOOR:0] request = call_request | cabin_request;

    assign current_floor = floor_count;

// Direction output
    always @(*) begin
        if      (moving_up)     direction = 2'b01;
        else if (moving_down)   direction = 2'b10;
        else                    direction = 2'b00;
    end

//      QUEUE FOR FLOOR REQUESTS

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            call_request  <= 0;
            cabin_request <= 0;
        end 
        else begin
            if (selected !=0 ) begin
                call_request[assign_floor]    <= 1'b1;
            end
            if (cabin_button_pressed) begin
                cabin_request[floor_req]    <= 1'b1;
            end
            if (current_state == OPEN_DOOR && timeout) begin
                cabin_request[floor_count]  <= 1'b0;
                call_request[floor_count]   <= 1'b0;
            end
        end
    end

//    MOVEMENT OF LIFT - UP/DOWN 

    reg [2:0]target;
    reg found;
    integer i;
    always @(*) begin
            target = 0;
            found = 0;
            if (request[floor_count]) begin      // if user entered same floor on which lift is present.
                target = floor_count;
                found = 1;
            end
            else if (moving_up) begin
                for (i = floor_count+1 ; i <= MAX_FLOOR; i = i + 1) begin
                    if (request[i]==1 && !found) begin
                        target = i;
                        found = 1;
                    end
                end
            end 
            else if(moving_down) begin
                for (i = floor_count-1; i >= 0; i = i - 1) begin
                    if (request[i]==1 && !found) begin
                        target = i;
                        found = 1;
                    end
                end
            end
// if there is request then it should move no need of this else 

            // else begin               // if lift is not moving in either of the direction
            //     for(i = 0; i<MAX_FLOOR+1 ; i=i+1)begin      //boundation - good for single request,for multiple request it should look 
            //         if (request[i] && !found) begin    //for the nearest floor wrt current floor.
            //             target=i - floor_count;
            //             found=1;
            //         end
            //     end
            // end
        
    end

    always @(posedge clk or posedge rst) begin
        if(rst)
            next_target <= 0;
        else 
            next_target <= target;
    end

//      STATE DECISION

    always @(*) begin
        next_state = current_state;

        case (current_state)

        IDLE: begin
            if (|request) begin
                if (next_target > floor_count)
                    next_state = GO_UP;
                else if (next_target < floor_count)
                    next_state = GO_DOWN;
                else
                    next_state = IDLE;
            end
        end
           
        GO_UP,GO_DOWN:begin
            if (stop || next_target == floor_count ) begin
                next_state=OPEN_DOOR;
            end
            else  begin
                next_state=current_state;
            end
        end   

        OPEN_DOOR : begin
            if (timeout) begin
                next_state=IDLE;
            end
        end
        default: next_state=IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            moving_up <= 1;
            moving_down <=0;
        end 
        else begin

            has_request_above <= 1'b0;
            has_request_below <= 1'b0;
            // Check ABOVE
            for (j = floor_count + 1; j <= MAX_FLOOR; j = j + 1) begin
                if (request[j]) begin
                    has_request_above <= 1'b1;
                end
            end
            // Check BELOW
            for (j = 0; j < floor_count; j = j + 1) begin
                if (request[j]) begin
                    has_request_below <= 1'b1;
                end
            end
            // Direction decision (NO dependency on previous state)
            if (current_state==GO_DOWN || current_state==GO_UP) begin
                if (has_request_above) begin
                    moving_up <= 1;
                    moving_down <= 0;
                end 
                else if (has_request_below) begin
                    moving_down <= 1;
                    moving_up <= 0;
                end
            end

            // else: no change
        end
    end

//      STATE TRANSITIONS

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

//      FLOOR TRANSITION

    always @(posedge clk or posedge rst) begin
        if (rst)begin 
            floor_count <= 0;
        end
        else if (current_state == GO_UP) begin
            if (floor_count < next_target && floor_count < MAX_FLOOR)   //  protection
                    floor_count <= floor_count + 1;
            end
        else if (current_state == GO_DOWN) begin
            if (floor_count > next_target && floor_count > 0)             //  protection
                floor_count <= floor_count - 1;
            end
    end

//              COUNTER

    always @(posedge clk or posedge rst) begin
        if (rst)begin
            door_timing_counter <= 0;
        end
        else if (current_state == OPEN_DOOR) begin
            if(door_timing_counter <= TIMEOUT_AT)
                door_timing_counter <= door_timing_counter+1;
        end
        else
            door_timing_counter <= 0;
    end

    wire timeout=(door_timing_counter==TIMEOUT_AT);

//       OUTPUT LOGIC

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            door_status <= 1'b0;
        end
        else if(current_state == OPEN_DOOR && !timeout)begin
            door_status <= 1'b1;
        end
        else begin
            door_status <= 1'b0; 
        end
        
    end

endmodule

module cabin_tb;
    reg         rst;
    reg         clk;
    reg         stop;
    reg         upward;
    reg         downward;
    reg         cabin_button_pressed;
    reg [2:0]   floor_req;
    reg [2:0]   assign_floor;
    reg [1:0]   selected;
    wire        door_status;
    wire  [1:0] direction;
    wire [2:0]  floor_count;


    parameter MAX_FLOOR = 7;

    fsm_controller DUT(
        .clk(clk),
        .cabin_button_pressed(cabin_button_pressed),
        .floor_req(floor_req),
        .stop(stop),
        .selected(selected),
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
        forever #5 clk = ~clk;   // 100 MHz clock (10ns period)
    end

// ==================== Random Cabin Button Press ====================
    task random_cabin_press();
        integer rand_floor;
        begin
            rand_floor = $urandom_range(0, MAX_FLOOR);
            floor_req = rand_floor;
            cabin_button_pressed = 1;
            @(posedge clk);
            cabin_button_pressed = 0;
            $display("[%0t],cabin request = %0d",$time,floor_req);

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

    reg [MAX_FLOOR:0] prev_floor = 0;
    reg prev_door = 0;

    always @(posedge clk) begin
        if (floor_count != prev_floor || door_status != prev_door) begin
            $display("[%0t] Door Open - %0d | Floor: %0d",$time, door_status, floor_count);
            prev_floor <= floor_count;
            prev_door  <= door_status;
        end
    end


        initial begin
        // $dumpfile("elevator.vcd");
        // $dumpvars(0,cabin_tb);


        repeat(5) @(posedge clk);

        $display("=== Starting Random Stimulus Test ===");
        repeat(10) begin          
            // Randomly generate hall calls or cabin presses
            if ($random % 15 == 0)      
                random_emergency(); 
            else if ($random % 4 == 0) begin
                random_cabin_press();
                if (selected==2'd1) 
                    $display("request from 1st Elevator");
                else if (selected==2'd2)
                    $display("request from 2nd Elevator");
                else if (selected==2'd3) 
                    $display("request from 3rd Elevator");
            end                    
               
            // Small random delay between requests
            repeat($urandom_range(5, 20)) @(posedge clk);
        end
    end


endmodule

