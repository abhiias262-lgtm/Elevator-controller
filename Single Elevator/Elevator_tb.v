`timescale 1ns/1ns

module new_multi_elevator_tb;

    // ==================== Signals ====================
    reg clk;
    reg rst;

    reg [2:0]   call_floor;
    reg         call_button_pressed;

    // ye kahan se ayega ? nahi ye yahan se jayega call ke
    reg         upward;
    reg         downward;


    // Outputs from DUT (grp file)
    wire        door_statusE1;
    wire [1:0]  direction_E1;
    wire [2:0]  current_floorE1;
    wire [2:0] floor_countE1;

    wire        door_statusE2; 
    wire [1:0]  direction_E2;
    wire [2:0]  current_floorE2;
    wire [2:0] floor_countE2;

    wire        door_statusE3;
    wire [1:0]  direction_E3 ;
    wire [2:0]  current_floorE3;
    wire [2:0] floor_countE3;

    parameter MAX_FLOOR = 7 ;

    // ==================== Instantiate DUT ====================
    multi_elevator_top DUT (

        .clk(clk),
        .rst(rst),
        .call_floor(call_floor),
        .call_button_pressed(call_button_pressed),
        .upward(upward),
        .downward(downward),



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
            call_button_pressed=1;
            @(posedge clk);
            call_button_pressed=0;

            $display("[%0t] Random Hall Call: Floor=%0d, Dir=%s", 
                     $time, rand_floor, upward ? "UP" : "DOWN");
        end
    endtask


    // === SINGLE LINE PRINT MONITOR (Add this) ===
reg [MAX_FLOOR:0] prev_floorE1 = 0;
reg [MAX_FLOOR:0] prev_floorE2 = 0;
reg [MAX_FLOOR:0] prev_floorE3 = 0;
reg prev_doorE1 = 0;
reg prev_doorE2 = 0;
reg prev_doorE3 = 0;

always @(*) begin
    
    if ((floor_countE1 != prev_floorE1 || door_statusE1 != prev_doorE1)&&(floor_countE2 != prev_floorE2 || door_statusE2 != prev_doorE2)&&
        (floor_countE3 != prev_floorE3 || door_statusE3 != prev_doorE3)) begin
        $display("[%0t] Open status- E1:%0d,E2:%0d,E3:%0d  | Current Floors: %0d ",$time, door_statusE1, current_floorE1, );
        prev_floorE1 <= floor_countE1;
        prev_doorE1  <= door_statusE1;
        prev_floorE2 <= floor_countE2;
        prev_doorE2  <= door_statusE2;
        prev_floorE3 <= floor_countE3;
        prev_doorE3  <= door_statusE3;
    end
    if  begin
        $display("[%0t] Door Open - E2:%0d  | Floors: %0d ",$time, door_statusE2, current_floorE2, );

    end
    if  begin
        $display("[%0t] Door Open - E3:%0d  | Floors: %0d ",$time, door_statusE3, current_floorE3, );

    end
end




    // ==================== Main Test Sequence ====================
    initial begin
        $dumpfile("new_multi_elevator_tb.vcd");
        $dumpvars(0,new_multi_elevator_tb);

        reset_system();

        repeat(5) @(posedge clk);

        $display("=== Starting Random Stimulus Test ===");
        repeat(80) begin          
            // Randomly generate hall calls or cabin presses
            if ($random % 5 == 0)      
                random_hall_call();

            // Small random delay between requests
            repeat($urandom_range(5, 25)) @(posedge clk);
        end
        repeat(100) @(posedge clk);
        $finish;
    end

endmodule