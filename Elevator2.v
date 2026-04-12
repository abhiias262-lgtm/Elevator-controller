`timescale 1ns/1ns
module controller (
    input new_floor_button_pressed,
    input [2:0] floor_req,
    input call_button_pressed,
    input [2:0] call_floor,
    input stop,
    input clk,
    input rst,
    input  upward,
    input  downward,
    output reg door_status,
    output reg moving_up,
    output reg [2:0] floor_count,
    output [2:0] current_floor,     
    output reg [1:0] direction,          
    output reg moving_down
);

//============= TOTAL FLOORS ====================
    parameter   MAX_FLOOR = 7,
                TIMEOUT_AT=20;

//============= PARAMETER =======================
    parameter   IDLE = 2'b00, 
                GO_UP = 2'b01,
                GO_DOWN = 2'b10,
                OPEN_DOOR = 2'b11;

//============= REGISTERS ======================

    reg [MAX_FLOOR:0] call_request;   // outside
    reg [MAX_FLOOR:0] cabin_request;  // inside  // one bit per floor  -request[2]=1 means'someone requested 2nd floor'
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [2:0] next_target;
    reg [4:0] door_timing_counter;
    reg has_request_above, has_request_below;
    integer j;
    wire [MAX_FLOOR:0] request = call_request | cabin_request;

    assign current_floor = floor_count;

// Direction output
    always @(*) begin
        if (moving_up)    direction = 2'b01;
        else if (moving_down) direction = 2'b10;
        else              direction = 2'b00;
    end

//      QUEUE FOR FLOOR REQUESTS

always @(posedge clk or posedge rst) begin
    if (rst) begin
        call_request  <= 0;
        cabin_request <= 0;
    end 
    else begin
        if (call_button_pressed) begin
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
            for(i = 0; i<MAX_FLOOR+1 ; i=i+1)begin                    //boundation - good for single request,for multiple request it should look 
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
        moving_up<= 1;
        moving_down <=0;
    end 
    else begin

        has_request_above = 1'b0;
        has_request_below = 1'b0;
        // Check ABOVE
        for (j = floor_count + 1; j <= MAX_FLOOR; j = j + 1) begin
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
        if (current_state==IDLE || current_state==GO_DOWN || current_state==GO_UP) begin
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

