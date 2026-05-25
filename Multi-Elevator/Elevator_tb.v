`timescale 1ns/1ns

module multi_elevator_tb;

    // ==================== Signals ====================
    reg clk, rst;
    reg [2:0]   call_floor;
    reg         call_button_pressed;
    reg         upward, downward;
    reg         enable_ele1, enable_ele2, enable_ele3;

    wire        door_statusE1;
    wire [1:0]  direction_E1;
    wire [2:0]  current_floorE1;

    wire        door_statusE2;
    wire [1:0]  direction_E2;
    wire [2:0]  current_floorE2;

    wire        door_statusE3;
    wire [1:0]  direction_E3;
    wire [2:0]  current_floorE3;

    parameter MAX_FLOOR = 7;

    // ==================== Instantiate DUT ====================
    multi_elevator_top DUT (
        .clk                 (clk),
        .rst                 (rst),
        .call_floor          (call_floor),
        .call_button_pressed (call_button_pressed),
        .upward              (upward),
        .downward            (downward),
        // .new_call_E1         (new_call_E1),
        // .new_call_E2         (new_call_E2),
        // .new_call_E3         (new_call_E3),
        .enable_ele1         (enable_ele1),
        .enable_ele2         (enable_ele2),
        .enable_ele3         (enable_ele3),
        .door_statusE1       (door_statusE1),
        .current_floorE1     (current_floorE1),
        .direction_E1        (direction_E1),
        .door_statusE2       (door_statusE2),
        .current_floorE2     (current_floorE2),
        .direction_E2        (direction_E2),
        .door_statusE3       (door_statusE3),
        .current_floorE3     (current_floorE3),
        .direction_E3        (direction_E3)
    );

    // ==================== Clock ====================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ==================== Reset ====================
    task reset_system;
        begin
            rst = 1;
            call_floor = 0; call_button_pressed = 0;
            upward = 0;     downward = 0;
            enable_ele1 = 0; enable_ele2 = 0; enable_ele3 = 0;
            repeat(10) @(posedge clk);
            rst = 0;
            repeat(5)  @(posedge clk);
            $display("[%0t] System Reset Done", $time);
        end
    endtask

    // ==================== Hall Call Task ====================
    task random_hall_call;
        integer rand_floor;
        begin
            rand_floor = $urandom_range(0, MAX_FLOOR);
            call_floor = rand_floor;
            if ($urandom_range(0,10) < 5) begin upward=1; downward=0; end
            else                          begin upward=0; downward=1; end
            call_button_pressed = 1;
            @(posedge clk);
            call_button_pressed = 0;
            $display("[%0t] Hall Call: Floor=%0d  Dir=%s",
                     $time, rand_floor, upward ? "UP" : "DOWN");
        end
    endtask

// ==================== Monitor ====================
reg prev_doorE1, prev_doorE2, prev_doorE3;

always @(posedge clk) begin
    // Detect rising edge: door was 0 last cycle, now it's 1
    if ((!prev_doorE1 && door_statusE1) ||
        (!prev_doorE2 && door_statusE2) ||
        (!prev_doorE3 && door_statusE3))
    begin
        $display("[%0t] Doors E1:%b E2:%b E3:%b | Floors E1:%0d E2:%0d E3:%0d",
                 $time,
                 door_statusE1, door_statusE2, door_statusE3,
                 current_floorE1, current_floorE2, current_floorE3);
    end

    // Update previous state each cycle
    prev_doorE1 <= door_statusE1;
    prev_doorE2 <= door_statusE2;
    prev_doorE3 <= door_statusE3;
end

    // ==================== Main Test Sequence ====================
    initial begin
        // $dumpfile("multi_elevator.vcd");
        // $dumpvars(0, multi_elevator_tb);

        reset_system();

        // --- Test 1: Single elevator ---
        // $display("\n=== TEST 1: Single Elevator (E1 only) ===");
        // enable_ele1=1; enable_ele2=0; enable_ele3=0;
        // repeat(30) begin
        //     if ($random % 5 == 0) random_hall_call();
        //     repeat($urandom_range(5, 50)) @(posedge clk);
        // end
        // repeat(7000) @(posedge clk);

        // --- Test 2: Two elevators ---
        // $display("\n=== TEST 2: Two Elevators (E1 + E2) ===");
        // enable_ele1=1; enable_ele2=1; enable_ele3=0;
        // repeat(30) begin
        //     if ($random % 5 == 0) random_hall_call();
        //     repeat($urandom_range(5, 50)) @(posedge clk);
        // end
        // repeat(7000) @(posedge clk);

        // --- Test 3: All three elevators ---
        $display("\n=== TEST 3: All Three Elevators ===");
        enable_ele1=1; enable_ele2=1; enable_ele3=1;
        repeat(40) begin
            if ($random % 3 == 0) random_hall_call();
            repeat($urandom_range(5, 50)) @(posedge clk);
        end
        repeat(7000) @(posedge clk);

        $display("\n=== Simulation Complete ===");
        $finish;
    end

endmodule