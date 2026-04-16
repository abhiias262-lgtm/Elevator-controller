Testbench 
   ↓ (drives inputs)
multi_elevator_top
   ├──→ call_button_pressed, call_floor, upward, downward → GROUP_CTRL (dispatcher)
   │
   ├──→ ELEV1 (controller)
   │       ├──→ door_statusE1, moving_upE1, moving_downE1 → to Testbench
   │       ├──→ current_floorE1, direction_E1 ────────────┐
   │                                                      │
   ├──→ ELEV2 (controller)                                │
   │       └──→ current_floorE2, direction_E2 ────────────┼──→ to GROUP_CTRL
   │                                                      │
   └──→ ELEV3 (controller)                                │
           └──→ current_floorE3, direction_E3 ────────────┘
   
   GROUP_CTRL (dispatcher)
        ├──→ Calculates best elevator using cost
        └──→ Sends assigned_floor_E1 / assigned_dir_E1 → only to ELEV1 (or E2/E3)