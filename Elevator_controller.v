
module controller (
    input [2:0] floor_req,
    input stop,
    input clk,
    input rst,
    output reg door_status

);
//total floor
    parameter MAX = 4;      //0,1,2,3
// states 
    parameter  IDLE = 2'b00, go_up = 2'b01, go_down = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [2:0] floor_count;
    reg door;



// state update at every clk pulse
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end


// state transitions
    always @(*) begin
        next_state = current_state;
        case (current_state)
        IDLE : begin                                    //In this state lift is not running 
            if ( floor_count < floor_req )begin
                next_state = go_up;
            end
            else if ( floor_count > floor_req ) begin
                next_state = go_down;
            end
        end  

        go_up:begin
            if (stop || floor_count >= floor_req)
                next_state = IDLE;
        
        end   

        go_down : begin
            if (stop || floor_count <= floor_req)
                next_state = IDLE;
        end

        endcase
    end


// floor updation


always @(posedge clk or posedge rst) begin
    if (rst)begin 
        floor_count <= 0;
    end
   
    else if (current_state == go_up) begin
        if (floor_count < floor_req && floor_count < MAX-1)   // ← protection
            floor_count <= floor_count + 1;
    end
    else if (current_state == go_down) begin
        if (floor_count > floor_req && floor_count > 0)             // ← protection
            floor_count <= floor_count - 1;
    end
    // else: hold current floor (implicit)
end
    
    

//output logic
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            door_status <= 0;
        end
        else if(current_state == IDLE && floor_count == floor_req)begin
            door_status <= 1;
        end
        else begin
            door_status <= 0;   
        end
        
    end




endmodule

module controller_tb;
    reg [2:0] floor_req;
    reg stop;
    reg clk;
    reg rst;
    wire door_status;

    controller dut(.floor_req(floor_req), .stop(stop), .clk(clk), .rst(rst), .door_status(door_status));

    initial clk=0;
    always #5 clk = ~clk;

    task floor_input( input [2:0] f);
        begin
            floor_req=f;
            @(posedge clk);
        end 
    endtask

    task stop_input;
    begin
        stop=1;
        @(posedge clk);
        stop=0;
        @(posedge clk);
    end 
    endtask
//----------------------test inputs----------------------

     initial begin
        rst=1;
        stop=0;
        floor_req=0;

        repeat(2)@(posedge clk);
        rst=0;


        // Example test sequence
        floor_input(3'd2);
        repeat(30) @(posedge clk);
        floor_input(3'd0);
        repeat(40) @(posedge clk);
        floor_input(3'd3);
        repeat(50) @(posedge clk);
        $finish;



     end

    initial begin
    $dumpfile("controller.vcd");   // waveform file
    $dumpvars(0, controller_tb);   // dump all signals
    end

    initial begin
        $monitor("T=%0t  | door status=%b ",$time,door_status);
    end
    

    
endmodule