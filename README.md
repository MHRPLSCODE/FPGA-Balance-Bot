# FPGA-Based Self-Balancing Robot — Motor Control & Sensor Interface

FPGA motor controller and sensor interface for a two-wheeled self-balancing robot, built on the **Vicharak Shrike Lite** (Renesas SLG47910 ForgeFPGA, 1120 LUTs + RP2040).


## Architecture

```
MPU-6050 IMU ──I²C──▶ RP2040 (PID) ──SPI──▶ ForgeFPGA ──step/dir──▶ A4988 ──▶ NEMA 17
                          ▲                      │                              │
                          └──── count/dir ◀──────┘◀──── encoder A/B ◀───────────┘
```

FPGA handles all deterministic motor I/O. RP2040 handles PID + IMU. Hardware/software co-design mirroring industrial motor drive architectures.

## Build Status

| Rung | Module | Status |
|------|--------|--------|
| 0 | Blink — toolchain proof | ✅ Hardware verified |
| 1 | Button → LED with debouncer | ⏭ Skipped |
| 2 | Stepper driver (step pulse gen + direction) | ✅ Simulated |
| 2.5 | Acceleration ramp engine | ✅ Simulated |
| 3a | Quadrature decoder | ✅ Written |
| 3b | Stall detector | ✅ Written |
| 3c | Hardware watchdog | ✅ Written |
| 4a | SPI slave interface | ✅ Written |
| 4b | Debug UART TX | ✅ Written |
| 5 | Top module | 🔲 Next |
| 6 | System integration | 🔲 Hardware arriving July 8-9 |

**All 8 Verilog modules written. MicroPython (SPI master, IMU driver, PID controller) generated.**

## FPGA Module Map (1120 LUT Budget)

| Module | Function | Est. LUTs | Status |
|--------|----------|-----------|--------|
| Step pulse generator (2 ch) | Variable-frequency pulse for A4988 step/dir | ~100 | ✅ |
| Acceleration ramp (2 ch) | Timed increment/decrement to prevent stalling | ~150 | ✅ |
| Quadrature decoder (2 ch) | Encoder A/B edge counting + direction | ~120 | ✅ |
| Stall detector | Expected vs actual encoder count comparison | ~60 | ✅ |
| Hardware watchdog | Timeout safety shutdown if comms fail | ~30 | ✅ |
| SPI slave | 24-bit bidirectional RP2040 ↔ FPGA transfer | ~150 | ✅ |
| Debug UART TX | 115200 baud serial debug output | ~80 | ✅ |
| **Total** | | **~690 / 1120 (~62%)** | **8/8 done** |

## Design Decisions

- **No division operator** — step frequency via programmable-limit counter, not clock division. Conserves LUTs on a chip with no DSP blocks.
- **Inverse speed encoding** — large `step_limit` = slow motor, small = fast. Ramp module walks value toward target ±1 per tick.
- **Reset to max step_limit (0xFFFFF)** — motors start stopped, ramp up. Prevents stall on startup.
- **1x quadrature decoding** — rising edges of channel A only. Simpler than 4x, sufficient for 400PPR encoders.
- **Edge detection pattern** — `(~prev & current)` used in quad_decoder, stall_detector, and watchdog. One pattern, three applications.
- **SPI slave (not master)** — RP2040 generates SCLK and initiates. FPGA responds. 24-bit transfers for MicroPython byte alignment.
- **Microstepping deprioritized** — A4988 MS1/MS2/MS3 hardwired or controlled by RP2040 GPIO directly.

## SPI Data Format

| Direction | Bits | Content |
|-----------|------|---------|
| MOSI (RP2040 → FPGA) | [23:4] | target_limit (20 bits) |
| | [3] | direction (1 bit) |
| | [2:0] | reserved |
| MISO (FPGA → RP2040) | [23:8] | encoder_count (16 bits) |
| | [7] | encoder_dir (1 bit) |
| | [6] | stall_flag (1 bit) |
| | [5:0] | reserved |

## Key Patterns

| Pattern | Modules | Description |
|---------|---------|-------------|
| Programmable-limit counter | blink, stepper_driver, accel_ramp, watchdog | Count to N, pulse, reset |
| Rising edge detector | quad_decoder, stall_detector, watchdog | `(~prev & current)` — 1 cycle pulse on 0→1 |
| Synchronous reset | All | `if (reset)` inside `always @(posedge clk)` |
| Shift register | spi_slave | `{reg[22:0], mosi}` — serial to parallel |
| FSM | uart_tx | IDLE → START → DATA → STOP with baud counter |
| Output enable | Top-level only | ForgeFPGA `_oe = 1'b1` for every output pin |

## Platform

| Component | Spec |
|-----------|------|
| FPGA | Renesas SLG47910 ForgeFPGA — 1120 LUTs, 50 MHz |
| MCU | RP2040 (on same board) |
| Board | Vicharak Shrike Lite |
| Motors | NEMA 17 JK42HS34-0406 (1.5 kg-cm, 0.31A, 6-wire) × 3 |
| Drivers | A4988 Good Quality × 3 |
| Encoders | 400PPR 2-phase optical rotary × 2 |
| IMU | MPU-6050 GY-521 × 2 |
| Battery | Orange 11.1V 600mAh 25C 3S LiPo |
| Synthesis | Go Configure Software Hub (GCSH) |
| Simulation | Icarus Verilog + GTKWave |
| Flash | mpremote → shrike.flash() |

## Repo Structure

```
forge_balance_hdl/
├── rtl/
│   ├── blink.v
│   ├── stepper_driver.v
│   ├── accel_ramp.v
│   ├── quad_decoder.v
│   ├── stall_detector.v
│   ├── watchdog.v
│   ├── spi_slave.v
│   └── uart_tx.v
├── tb/
│   ├── blink_tb.v
│   ├── stepper_driver_tb.v
│   ├── accel_ramp_tb.v
│   ├── quad_decoder_tb.v
│   ├── stall_detector_tb.v
│   ├── watchdog_tb.v
│   ├── spi_slave_tb.v
│   └── uart_tx_tb.v
├── micropython/
│   ├── config.py
│   ├── main.py
│   ├── spi_master.py
│   ├── imu.py
│   └── pid.py
├── docs/
├── .gitignore
└── README.md
```

## Simulation

```bash
iverilog -o tb/stepper_driver_tb rtl/stepper_driver.v tb/stepper_driver_tb.v && vvp tb/stepper_driver_tb && gtkwave tb/stepper_driver_tb.vcd
iverilog -o tb/accel_ramp_tb rtl/accel_ramp.v tb/accel_ramp_tb.v && vvp tb/accel_ramp_tb && gtkwave tb/accel_ramp_tb.vcd
iverilog -o tb/quad_decoder_tb rtl/quad_decoder.v tb/quad_decoder_tb.v && vvp tb/quad_decoder_tb && gtkwave tb/quad_decoder_tb.vcd
iverilog -o tb/stall_detector_tb rtl/stall_detector.v tb/stall_detector_tb.v && vvp tb/stall_detector_tb && gtkwave tb/stall_detector_tb.vcd
iverilog -o tb/watchdog_tb rtl/watchdog.v tb/watchdog_tb.v && vvp tb/watchdog_tb && gtkwave tb/watchdog_tb.vcd
iverilog -o tb/spi_slave_tb rtl/spi_slave.v tb/spi_slave_tb.v && vvp tb/spi_slave_tb && gtkwave tb/spi_slave_tb.vcd
iverilog -o tb/uart_tx_tb rtl/uart_tx.v tb/uart_tx_tb.v && vvp tb/uart_tx_tb && gtkwave tb/uart_tx_tb.vcd
```

## Flash

```bash
mpremote cp FPGA_bitstream_FLASH_MEM.bin :
mpremote exec "import shrike; shrike.flash('FPGA_bitstream_FLASH_MEM.bin')"
```

## Timeline

| Date | Milestone |
|------|-----------|
| July 1 | ✅ Blink hardware verified |
| July 1 | ✅ Stepper driver simulated |
| July 2 | ✅ Acceleration ramp simulated |
| July 3 | ✅ Quad decoder, stall detector, watchdog written |
| July 3 | ✅ SPI slave and UART TX written |
| July 4 | ✅ MicroPython package generated |
| July 5-7 | Top module, sim verification, presentation prep |
| July 8-9 | Hardware arrives — flash, wire, test |
| July 10-12 | Integration, PID tuning, demo polish |
| July 13-17 | Presentation window |

## Author
MHR ECE'27
