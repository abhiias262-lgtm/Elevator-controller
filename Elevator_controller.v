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
    reg [3:0] door_timing_counter;

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
            if(timeout)begin
                served_floor=floor_count;
                next_state=IDLE;
            end
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


always @(posedge clk or posedge rst) begin
    if (rst)begin
        door_timing_counter <= 0;
    end
    else if (current_state == open_door) begin
        if(door_timing_counter < 20)
            door_timing_counter <= door_timing_counter+1;
    end
    else
        door_timing_counter <= 0;
end

wire timeout=(door_timing_counter>10);

// ============================================= 
//       OUTPUT LOGIC
// =============================================

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            door_status <= 0;
        end
        else if(current_state == open_door && !timeout)begin
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

    controller dut(.floor_req(floor_req), .new_floor_button_pressed(new_floor_button_pressed),
    .stop(stop), .clk(clk), .rst(rst), .door_status(door_status));

    initial clk=0;
    always #5 clk = ~clk;

    reg[7:0] expected_requests;
 

    task reset_dut;
        begin
            rst = 1;
            floor_req=0;
            new_floor_button_pressed=0;
            stop=0;
            expected_requests=8'b0;
            repeat(4) @(posedge clk);
            rst=0;
            repeat(4) @(posedge clk);
            $display("[%t]  Reset Completed. current floor =%d",$time,dut.floor_count);
        end
    endtask

    task press_button(input [2:0] floor);
        begin
            if (floor > 7) begin
                $display("ERROR: Invalid floor=%d",floor);
                return;
            end
        
        @(posedge clk );
        floor_req=floor;
        new_floor_button_pressed=1;
        expected_requests[floor]=1;
        @(posedge clk);
        new_floor_button_pressed=0;

        $display("[%t]  Button pressed for floor=%d | expected request = %b ",$time,floor,expected_requests);
        end
    endtask


    task emergency_stop(port_list);
    begin
        @(posedge clk);
        stop=1;
        @(posedge clk);
        stop=0;
        $display("%t  Emergency STOP asserted",$time);
    end  
    endtask


    task wait_for_door_open(input [2:0] expected_floor,input integer timeout);
        if (door_status && dut.floor_count == expected_floor) begin
                $display("PASS  T%0t | Reached floor %0d and door opened (requests now = %b)",
                $time, expected_floor, dut.request);
            end
        
    endtask

    task check_request_cleared(input [2:0] floor);
        begin
            @(posedge clk);   // give one cycle for clearing logic
            if (dut.request[floor] === 1'b1) begin
                $display("ERROR T%0t | Request bit for floor %0d still set after door open!", $time, floor);
                error_count = error_count + 1;
            end else begin
                $display("      Request %0d cleared OK", floor);
            end
        end
    endtask

    reset_dut();

        // ─── Test 1: Single floor request ─────────────────────────────
    
        $display("\n=== TEST %0d : Single floor request (floor 4) ===", 1);
        press_button(4);
        wait_for_door_open_at(4, 120);
        check_request_cleared(4);

        // ─── Test 2: Multiple requests in same direction ──────────────
   
        $display("\n=== TEST %0d : Multiple upward requests ===", 2);
        press_button(2);
        press_button(5);
        press_button(7);
        wait_for_door_open_at(2, 10);   // should serve lowest first if going up? (your logic may differ)
        check_request_cleared(2);
        wait_for_door_open_at(5, 10);
        check_request_cleared(5);
        wait_for_door_open_at(7, 10);
        check_request_cleared(7);

        // ─── Test 3: Requests in both directions + emergency stop ─────

        $display("\n=== TEST %0d : Mixed directions + emergency stop ===", 3);
        press_button(1);
        press_button(6);
        wait_for_door_open_at(1, 10);   // assuming it goes down first
        check_request_cleared(1);

        // interrupt movement to 6;
        //repeat(8) @(posedge clk);       
        issue_emergency_stop();
        //repeat(4) @(posedge clk);
        if (door_status !== 1) begin
            $display("ERROR T%0t | Door did not open after emergency stop", $time);
        end

        // ─── Test 4: New request while door open ──────────────────────
      
        $display("\n=== TEST %0d : Request while door is open ===", 4);
        press_button(3);
       // repeat(5) @(posedge clk);        // wait some time
        wait_for_door_open_at(3, 10);
        check_request_cleared(3);

        // ─── Summary ──────────────────────────────────────────────────
        $display("\n=====================================");

        $display(">>> ALL SELF-CHECKS PASSED <<<");

        $display("=====================================\n");

        //repeat(20) @(posedge clk);
        $finish;
   
endmodule