`timescale 1ns/1ns

module multi_elevator_tb;

    // ==================== Signals ====================
    reg clk;
    reg rst;

    reg [2:0]   call_floor;
    reg         call_button_pressed;
    reg         upward;
    reg         downward;


    reg        enable_ele1;
    reg        enable_ele2;
    reg        enable_ele3;


    // Outputs from DUT (grp file)
    wire        door_statusE1;
    wire [1:0]  direction_E1;
    wire [2:0]  current_floorE1;


    wire        door_statusE2; 
    wire [1:0]  direction_E2;
    wire [2:0]  current_floorE2;


    wire        door_statusE3;
    wire [1:0]  direction_E3 ;
    wire [2:0]  current_floorE3;


    parameter MAX_FLOOR = 7 ;

    // ==================== Instantiate DUT ====================
    multi_elevator_top DUT (

        .clk(clk),
        .rst(rst),
        .call_floor(call_floor),
        .call_button_pressed(call_button_pressed),
        .upward(upward),
        .downward(downward),

        .enable_ele1(enable_ele1),
        .enable_ele2(enable_ele2),
        .enable_ele3(enable_ele3),

        .door_statusE1(door_statusE1),
        .current_floorE1(current_floorE1),
        .direction_E1(direction_E1),


        .door_statusE2(door_statusE2),
        .current_floorE2(current_floorE2),
        .direction_E2(direction_E2),


        .door_statusE3(door_statusE3),
        .current_floorE3(current_floorE3),
        .direction_E3(direction_E3)
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
            call_floor = 0;
            upward = 0;
            downward = 0;
            call_button_pressed=0;
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

            // Random direction (50% chance of UP, 50% DOWN for realism)
            if ($urandom_range(0,10) < 5) begin
                upward = 1; downward = 0;
            end else begin
                upward = 0; downward = 1;
            end
            call_button_pressed=1;
            @(posedge clk);
            call_button_pressed=0;

            $display("[%0t] Random Hall Call: Floor=%0d, Dir=%s", 
                     $time, rand_floor, upward ? "UP" : "DOWN");
        end
    endtask


    // === SINGLE LINE PRINT MONITOR (Add this) ===

always @(posedge clk) begin
    if (door_statusE1 || door_statusE2 || door_statusE3) begin
        $display("[%0t] Door Status : E1:%b E2:%b E3:%b | Floors: %0d %0d %0d", 
                 $time, door_statusE1, door_statusE2, door_statusE3,
                 current_floorE1, current_floorE2, current_floorE3);
    end
end




    // ==================== Main Test Sequence ====================
    initial begin
        // $dumpfile("multi_elevator.vcd");
        // $dumpvars(0,multi_elevator_tb);

        reset_system();

        repeat(5) @(posedge clk);
        enable_ele1=1;
        enable_ele2=0;
        enable_ele3=0;

        $display("=== Starting Random Stimulus Test ===");
        repeat(10) begin          
            // Randomly generate hall calls or cabin presses
            if ($random % 5 == 0)      
                random_hall_call();

            // Small random delay between requests
            repeat($urandom_range(5, 50)) @(posedge clk);
        end
        repeat(10000) @(posedge clk);
        $finish;
    end

endmodule