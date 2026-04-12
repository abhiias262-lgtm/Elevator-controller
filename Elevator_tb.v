`timescale 1ns/1ns

module multi_elevator_tb;

    // ==================== Signals ====================
    reg clk;
    reg rst;

    // Inputs to DUT
    reg [2:0]   floor_req;
    reg         new_floor_button_pressed;
    reg [2:0]   call_floor;
    reg         call_button_pressed;
    reg         upward;
    reg         downward;
    reg         stop;

    // Outputs from DUT
    wire        door_statusE1, moving_upE1, moving_downE1;
    wire [2:0]  current_floorE1;

    wire        door_statusE2, moving_upE2, moving_downE2;
    wire [2:0]  current_floorE2;

    wire        door_statusE3, moving_upE3, moving_downE3;
    wire [2:0]  current_floorE3;

    // ==================== Instantiate DUT ====================
    multi_elevator_top DUT (

        .clk(clk),
        .rst(rst),

        .floor_req(floor_req),
        .new_floor_button_pressed(new_floor_button_pressed),
        .call_floor(call_floor),
        .call_button_pressed(call_button_pressed),
        .upward(upward),
        .downward(downward),
        .stop(stop),


        .door_statusE1(door_statusE1),
        .moving_upE1(moving_upE1),
        .moving_downE1(moving_downE1),
        .current_floorE1(current_floorE1),


        .door_statusE2(door_statusE2),
        .moving_upE2(moving_upE2),
        .moving_downE2(moving_downE2),
        .current_floorE2(current_floorE2),


        .door_statusE3(door_statusE3),
        .moving_upE3(moving_upE3),
        .moving_downE3(moving_downE3),
        .current_floorE3(current_floorE3)
    );

    // ==================== Clock Generation ====================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100 MHz clock (10ns period)
    end

    // ==================== Reset Task ====================
    task reset_system;
        begin
            rst = 1;
            floor_req = 0;
            new_floor_button_pressed = 0;
            call_floor = 0;
            call_button_pressed = 0;
            upward = 0;
            downward = 0;
            stop = 0;
            repeat(10) @(posedge clk);
            rst = 0;
            repeat(5) @(posedge clk);
            $display("[%0t] System Reset Done", $time);
        end
    endtask

    // ==================== Random Hall Call Task ====================
    task random_hall_call;
        integer rand_floor;
        begin
            rand_floor = $urandom_range(0, MAX_FLOOR);           // Random floor 0 to 7
            call_floor = rand_floor;

            // Random direction (70% chance of UP, 30% DOWN for realism)
            if ($random % 10 < 7) begin
                upward = 1; downward = 0;
            end else begin
                upward = 0; downward = 1;
            end

            call_button_pressed = 1;
            @(posedge clk);
            call_button_pressed = 0;     // Pulse for one cycle

            $display("[%0t] Random Hall Call: Floor=%0d, Dir=%s", 
                     $time, rand_floor, upward ? "UP" : "DOWN");
        end
    endtask

    // ==================== Random Cabin Button Press ====================
    task random_cabin_press;
        integer rand_floor;
        begin
            rand_floor = $urandom_range(0, MAX_FLOOR);
            floor_req = rand_floor;
            new_floor_button_pressed = 1;
            @(posedge clk);
            new_floor_button_pressed = 0;

            $display("[%0t] Random Cabin Press: Floor=%0d", $time, rand_floor);
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

    // ==================== Monitor Task (Optional) ====================
    always @(posedge clk) begin
        if (door_statusE1 || door_statusE2 || door_statusE3) begin
            $display("[%0t] Door Open - E1:%0d E2:%0d E3:%0d | Floors: %0d %0d %0d", 
                     $time, door_statusE1, door_statusE2, door_statusE3,
                     current_floorE1, current_floorE2, current_floorE3);
        end
    end

    // ==================== Main Test Sequence ====================
    initial begin
        $dumpfile("multi_elevator_tb.vcd");
        $dumpvars(0, multi_elevator_tb);

        reset_system();

        repeat(5) @(posedge clk);

        $display("=== Starting Random Stimulus Test ===");
        repeat(80) begin          
            // Randomly generate hall calls or cabin presses
            if ($random % 5 == 0)      
                random_emergency();
            else if ($random % 3 == 0) 
                random_hall_call();
            else                       
                random_cabin_press();

            // Small random delay between requests
            repeat($urandom_range(5, 25)) @(posedge clk);
        end

        $display("=== Random Test Completed ===");
        repeat(100) @(posedge clk);
        $finish;
    end

endmodule