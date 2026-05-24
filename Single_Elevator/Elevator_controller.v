`timescale 1ns/1ns
module controller (
    input [TARGET_BIT:0] floor_req,
    input [TARGET_BIT:0] call_floor,
    input new_floor_button_pressed,
    input stop,
    input clk,
    input rst,
    input  upward,
    input  downward,
    output reg door_status,
    output reg moving_up,
    output reg moving_down
);

//============= TOTAL FLOORS ====================
    parameter   MAX = 7,
                COUNTER_BIT=4,
                TARGET_BIT=2;

//============= PARAMETER =======================
    parameter   IDLE = 2'b00, 
                GO_UP = 2'b01,
                GO_DOWN = 2'b10,
                OPEN_DOOR = 2'b11;

//============= REGISTERS ======================

    reg [MAX:0] call_request;   // outside
    reg [MAX:0] cabin_request;  // inside  // one bit per floor  -request[2]=1 means'someone requested 2nd floor'
    reg [1:0] current_state;    
    reg [1:0] next_state;       
    reg [TARGET_BIT:0] floor_count;      //[2,0]
    reg [TARGET_BIT:0] next_target;      //[2,0]
    reg [COUNTER_BIT:0] door_timing_counter;      // [4,0]
    reg has_request_above, has_request_below;       
    integer j;
    wire [MAX:0] request = call_request | cabin_request;

//      QUEUE FOR FLOOR REQUESTS

always @(posedge clk or posedge rst) begin
    if (rst) begin
        call_request  <= 8'd0;
        cabin_request <= 8'd0;
    end 
    else begin
        if (upward || downward) begin
            call_request[call_floor] <= 1'b1;
        end
        if (new_floor_button_pressed) begin
            cabin_request[floor_req] <= 1'b1;
        end
        if (current_state == OPEN_DOOR && timeout) begin
            cabin_request[floor_count] <= 1'b0;
            call_request[floor_count]  <= 1'b0;
        end
    end
end

//    MOVEMENT OF LIFT - UP/DOWN 

reg [TARGET_BIT:0]target;
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
            for (i = floor_count+1 ; i <= MAX; i = i + 1) begin
                if (request[i] && !found) begin
                    target = i;
                    found = 1;
                end
            end
        end 
        else if(moving_down) begin
            for (i = floor_count-1; i >= 0; i = i - 1) begin
                if (request[i] && !found) begin
                    target = i;
                    found = 1;
                end
            end
        end
        else begin               // if lift is not moving in either of the direction
            for(i = 0; i<MAX+1 ; i=i+1)begin                    //boundation - good for single request,for multiple request it should look 
                if (request[i] && !found) begin             //for the nearest floor wrt current floor.
                    target=i;
                    found=1;
                end
            end
        end
    
end

always @(posedge clk or posedge rst) begin
    if(rst)
        next_target <= 0;
    else 
        next_target<=target;
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
            if (stop || next_target==floor_count ) begin
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

        has_request_above = 1'b0;
        has_request_below = 1'b0;
        // Check ABOVE
        for (j = floor_count + 1; j <= MAX; j = j + 1) begin
            if (request[j]) begin
                has_request_above = 1'b1;
            end
        end
        // Check BELOW
        for (j = 0; j < floor_count; j = j + 1) begin
            if (request[j]) begin
                has_request_below = 1'b1;
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
        if (floor_count < next_target && floor_count < MAX)   //  protection
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
        if(door_timing_counter < 25)
            door_timing_counter <= door_timing_counter+1;
    end
    else
        door_timing_counter <= 0;
end

    wire timeout=(door_timing_counter==20);

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

// TESTBENCH

module controller_tb;

    // ------------------ Signals ------------------
    reg [2:0] floor_req;
    reg [2:0] call_floor;
    reg new_floor_button_pressed;
    reg stop;
    reg clk;
    reg rst;
    reg upward;
    reg downward;
    reg [2:0]t;

    wire door_status;
    wire moving_up;
    wire moving_down;

    parameter   MAX = 7,                
                COUNTER_BIT=4,
                TARGET_BIT=2;
             

    // Instantiate DUT 
    controller dut (
        .floor_req(floor_req),
        .call_floor(call_floor),
        .new_floor_button_pressed(new_floor_button_pressed),
        .stop(stop),
        .clk(clk),
        .rst(rst),
        .upward(upward),
        .downward(downward),
        .door_status(door_status),
        .moving_up(moving_up),
        .moving_down(moving_down)
    );

    // ------------------ Clock Generation ------------------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz clock (10ns period)

    // ------------------ Reset Task ------------------
    task reset_dut;
        begin
            rst = 1;
            floor_req = 0;
            call_floor = 0;
            upward = 0;
            downward = 0;
            new_floor_button_pressed = 0;
            stop = 0;

            repeat(5) @(posedge clk);
            rst = 0;
            repeat(5) @(posedge clk);
        end
    endtask

    // ------------------ External Call (Hall Button) ------------------
    task call_elvtr(input [TARGET_BIT:0] call, input is_up);
        begin
            @(posedge clk);
            call_floor = call;
            $display("CALLED FROM FLOOR = %d",call);
            if (is_up) begin
                upward   = 1;
                $display("Moving up");
            end
            else begin    
                downward = 1;
                $display("Moving down");
            end
            repeat(2) @(posedge clk);   // Hold the signal for a couple of cycles

            upward   = 0;
            downward = 0;
            // call_floor = 0;
        end
    endtask

    // ------------------ Inside Cabin Button ------------------
    task press_button_inside(input [TARGET_BIT:0] floor);
        begin
            if (floor > dut.MAX) begin
                $display("ERROR: Invalid floor %0d", floor);
                disable press_button_inside;
            end

            @(posedge clk);
            floor_req = floor;
            new_floor_button_pressed = 1;
            $display("BUTTON PRESSED FOR FLOOR = %d",floor);

            @(posedge clk);
            new_floor_button_pressed = 0;
            floor_req = 0;
        end
    endtask

    // ------------------ Emergency Stop ------------------
    task emergency_stop;
        begin
            @(posedge clk);
            stop = 1;
            @(posedge clk);
            stop = 0;
            $display("[%0t] Emergency STOP asserted and released", $time);
        end
    endtask


// === SINGLE LINE PRINT MONITOR (Add this) ===
reg [MAX:0] prev_floor = 0;
reg prev_door = 0;

always @(posedge clk) begin
    if (dut.floor_count != prev_floor || door_status != prev_door) begin
        $display("[%0t] Door Open - %0d | Floor: %0d", 
                 $time, door_status, dut.floor_count);
        prev_floor <= dut.floor_count;
        prev_door  <= door_status;
    end
end



 // ------------------ Main Test Sequence ------------------
integer floor;
integer call;

initial begin
    $dumpfile("controller.vcd");
    $dumpvars(0, controller_tb);

    repeat(40) begin          
            // Randomly generate hall calls or cabin presses
            if ($random % 5 == 0) begin
                emergency_stop();
            end 
            else if ($random % 3 == 0) begin
                call = $urandom_range(0,MAX);
                call_elvtr(call, $random % 2);
            end
                
            else begin
                floor = $urandom_range(0,MAX);
                press_button_inside(floor);
            end


            // Small random delay between requests
            repeat($urandom_range(5, 25)) @(posedge clk);
        end


    repeat(100) @(posedge clk);   // extra safety time
    $finish;
end

endmodule