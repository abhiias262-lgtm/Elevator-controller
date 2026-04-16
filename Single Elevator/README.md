# Elevator Controller - Single Elevator FSM Design

A complete **Finite State Machine (FSM)** based Elevator Controller designed in Verilog, capable of handling both external hall calls and internal cabin requests for a single elevator.

Designed and verified using **AMD Vivado** and simulated with ModelSim / Vivado Simulator.

---

##  Features

- **8 Floors** (0 to 7)
- Supports **external calls** (Hall buttons - Up/Down)
- Supports **internal cabin requests** (Floor buttons inside elevator)
- Realistic **door open/close** with timeout (20 clock cycles)
- Automatic direction decision (Up/Down)
- Handles multiple pending requests efficiently
- Emergency Stop functionality
- Priority-based floor servicing
- Fully synthesizable RTL design

---

##  Modules & Architecture

### Main Module: `controller`

**Inputs:**
- `floor_req` – Floor requested from inside cabin
- `call_floor` – External call from hall button
- `new_floor_button_pressed` – Pulse for internal button press
- `upward`, `downward` – Direction of external call
- `stop` – Emergency stop signal
- `clk`, `rst`

**Outputs:**
- `door_status` – 1 = Door Open, 0 = Door Closed
- `moving_up` – Elevator is moving upwards
- `moving_down` – Elevator is moving downwards

### States
- `IDLE`
- `GO_UP`
- `GO_DOWN`
- `OPEN_DOOR`

---

##  Testbench Features

- Random stimulus generation (mix of internal + external requests)
- Emergency stop testing
- Self-contained tasks for:
  - `reset_dut()`
  - `call_elvtr()` – External hall call
  - `press_button_inside()` – Cabin button press
  - `emergency_stop()`
- Real-time monitoring of door status and current floor
- Clean single-line output using edge detection

---

##  Simulation Results

- Successfully handles multiple floor requests
- Correct door timing (opens for ~20 clock cycles)
- Proper direction control and movement
- Emergency stop works as expected
- No latch inference (fully synchronous design)

---

##  How to Run
### Simulation

```bash
# Using Icarus verilog
iverilog -o controller.out Elevator_controller.v
vvp controller.out

