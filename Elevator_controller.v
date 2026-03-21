// total 8 floors (0-7)
// number of lifts 3

`timescale 1ns/1ns
module controller (
    input [2:0] floor_req,
    input new_floor_button_pressed,
    input stop,
    input clk,
    input rst,
    output reg door_status

);
//============= TOTAL FLOORS ====================
    parameter MAX = 7;

//============= PARAMETER =======================
    parameter   IDLE = 2'b00, 
                go_up = 2'b01, 
                go_down = 2'b10,
                open_door = 2'b11;

//============= REGISTERS ======================
    reg [7:0] request;  // one bit per floor  -request[2]=1 means'someone requested 2nd floor'
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [2:0] floor_count;
    reg        door;
    reg [2:0]  served_floor;
    reg moving_up;           // 1 = currently serving upward requests, 0 = downward
    reg [2:0] next_target;

// =============================================
//      QUEUE FOR FLOOR REQUESTS
// =============================================
always @(posedge clk or posedge rst)begin
    if(rst)
        request <= 8'd0;
    else begin
        // New requests arrive (from outside or inside the cabin)
        if (new_floor_button_pressed)          // pulse or level signal
            request[floor_req] <= 1'b1;

        // Clear request when we actually serve the floor
        if (door_status)
            request[served_floor] <= 1'b0;
    end
end

// =============================================
//    MOVEMENT OF LIFT - UP/DOWN 
// =============================================

integer i;
reg found;

always @(*) begin
    next_target = floor_count;
    found = 0;

    if (moving_up) begin
        for (i = floor_count+1; i <= MAX; i = i + 1) begin
            if (request[i] && !found) begin
                next_target = i;
                found = 1;
            end
        end
    end else begin
        for (i = floor_count-1; i >= 0; i = i - 1) begin
            if (request[i] && !found) begin
                next_target = i;
                found = 1;
            end
        end
    end
end

// =============================================
//      STATE DECISION
// =============================================
    always @(*) begin
        next_state = current_state;
        case (current_state)
        IDLE : begin                                    //In this state lift is not running
            if (floor_req<floor_count) begin
                next_state=go_down;
            end
            else if (floor_req>floor_count) begin
                next_state=go_up;
            end
        end

        go_up:begin
            if (stop) begin
                next_state=open_door;
            end
            else if (next_target==floor_count) begin
                next_state=open_door;
            end
        end   

        go_down : begin
            if (stop) begin
                next_state=open_door;
            end
            else if (next_target==floor_count) begin
                next_state=open_door;
            end
        end

        open_door : begin
            served_floor=floor_count;
            next_state=IDLE;
        end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            moving_up <= 1;
        else if (current_state == IDLE) begin
            if (floor_req > floor_count)
                moving_up <= 1;
            else if (floor_req < floor_count)
                moving_up <= 0;
        end
    end

// =============================================
//      STATE TRANSITIONS
// =============================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end


// =============================================
//      FLOOR TRANSITION
// =============================================
always @(posedge clk or posedge rst) begin
    if (rst)begin 
        floor_count <= 0;
    end
   
    else if (current_state == go_up) begin
        if (floor_count < next_target && floor_count < MAX)   //  protection
            floor_count <= floor_count + 1;
    end
    else if (current_state == go_down) begin
        if (floor_count > next_target && floor_count >= 0)             //  protection
            floor_count <= floor_count - 1;
    end
    // else: hold current floor (implicit)
end



// ============================================= 
//       OUTPUT LOGIC
// =============================================

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            door_status <= 0;
        end
        else if(current_state == open_door)begin
            door_status <= 1;
        end
        else begin
            door_status <= 0;   
        end
        
    end

endmodule

// =============================================
//      TESTBENCH
// =============================================

module controller_tb;
    reg [2:0] floor_req;
    reg new_floor_button_pressed;
    reg stop=0;
    reg clk;
    reg rst;
    wire door_status;

    controller dut(.floor_req(floor_req), .new_floor_button_pressed(new_floor_button_pressed),.stop(stop), .clk(clk), .rst(rst), .door_status(door_status));

    initial clk=0;
    always #5 clk = ~clk;

    task floor_input(input [2:0] f);
        begin
            new_floor_button_pressed=1;
            floor_req=f;
            repeat(2)@(posedge clk);
            new_floor_button_pressed=0;
            @(posedge clk);
        end
    endtask

    task stop_input(input signal);
    begin
        stop=signal;
        repeat(2)@(posedge clk);
        stop=0;
        @(posedge clk);
    end 
    endtask


//============================= RANDOM TEST INPUTS ==================================

    initial begin
        rst=1;
        stop=0;
        floor_req=0;

        repeat(2)@(posedge clk);
        rst=0;

        // Random tests

        repeat (20)begin
            repeat(20)@(posedge clk);
            floor_req={$random}%8;
            $display("Expected floor=%d",floor_req);
            floor_input(floor_req);
            stop_input({$random}%2);
        end

        repeat(50) @(posedge clk);
        $finish;
    end

    initial begin
    $dumpfile("controller.vcd");   // waveform file
    $dumpvars(0, controller_tb);   // dump all signals
    end

    always @(posedge clk) begin
        if(stop && door_status==1)begin
            $display("Emergency Stop | Floor Reached=%d | Door Opened ",dut.floor_count);
        end
        else if (dut.floor_count == floor_req && door_status == 1) begin
            $display("T=%0t | Reached floor=%0d | Door Opened",$time,dut.floor_count);
        end

    end
endmodule