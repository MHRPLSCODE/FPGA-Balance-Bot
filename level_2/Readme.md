# Level 2 — Motion Coprocessor (WIP)

**Status:** RTL written, not yet synthesized / hardware-tested (July 19, 2026)

Offloads acceleration-ramp motion profiling from the RP2040 to the FPGA.
RP2040 sends target step-rate + direction over SPI once per PID cycle;
FPGA's `accel_ramp` runs continuously at 50 MHz and returns the current
ramped rate back on the same transaction. RP2040 still drives STEP/DIR
pins in software — FPGA is a coprocessor, not a motor controller.

## Architecture

```
RP2040                        FPGA (SLG47910V)
------                        ------------------
PID / MPU6050  --spi_mosi-->  spi_target.v  ---> FSM ---> accel_ramp.v
step-rate gen  <--spi_miso--  (unchanged)    (main.v)     (ramp logic)
```

## SPI protocol

4-byte transaction, SPI mode 0, 1 MHz clock, MSB first.

**MOSI (RP2040 → FPGA):**
| Byte | Name | Contents |
|---|---|---|
| 0 | CMD | 0xA5 = update (currently unused, always commits) |
| 1 | TARGET_HI | Upper 8 bits of 16-bit target step-rate |
| 2 | TARGET_LO | Lower 8 bits of target step-rate |
| 3 | DIR_FLAGS | Bit 0 = direction (0=fwd, 1=rev) |

**MISO (FPGA → RP2040), sampled at start of transaction for coherent snapshot:**
| Byte | Name | Contents |
|---|---|---|
| 0 | ACK | 0xA5 |
| 1 | RAMPED_HI | Upper 8 bits of current ramp output |
| 2 | RAMPED_LO | Lower 8 bits of current ramp output |
| 3 | STATUS | Bit 0 = at_target |

## FSM

5 states: IDLE, BYTE0, BYTE1, BYTE2, BYTE3. Advances on `o_rx_data_valid` pulse
from spi_target. Commits target rate + direction on BYTE3 valid.
Aborts back to IDLE if SS rises before BYTE3 completes.

Sketch: `fsm_sketch.jpg` (paper, to be cleaned up in a follow-up commit)

## Pin assignments

Same as Level 1 physical pins, port names updated to industry style (`_i` / `_o` / `_ni`).

| Port | FPGA pin | RP2040 pin |
|---|---|---|
| clk_i | OSC_CLK | — |
| clk_en_o | OSC_EN | — |
| rst_ni | GPIO18 (Pin 9) | GPIO14 |
| spi_sck_i | GPIO3 (Pin 16) | GPIO2 |
| spi_ss_ni | GPIO4 (Pin 17) | GPIO1 |
| spi_mosi_i | GPIO5 (Pin 18) | GPIO3 |
| spi_miso_o | GPIO6 (Pin 19) OUT | GPIO0 |
| spi_miso_en_o | GPIO6 (Pin 19) OE | — |
| led_o | GPIO16 (Pin 7) OUT | — |
| led_en_o | GPIO16 (Pin 7) OE | — |

## Design notes

1. **Coherent MISO snapshot.** Ramp state is sampled once at SS falling edge and
   held for all 4 MISO bytes. Prevents torn reads across a continuously updating
   20-bit ramp counter.
2. **CMD byte currently unchecked.** BYTE3 always commits. Extend later with
   opcode gating for read-only polls (Level 3 scope).
3. **`spi_target.v` reused from Vicharak's spi_loopback_led example, unchanged.**
   Proven working on Level 1 hardware. Do not modify.
4. **`accel_ramp.v` reset value changed from 20'hFFFFF to 20'd0** so ramps start
   from zero rather than max on power-up.

## What is NOT yet proven

- Synthesis clean pass (tomorrow)
- Hardware bring-up on Shrike Lite (tomorrow)
- End-to-end SPI transaction success with real ramp readback (tomorrow)
- C++ firmware side (`src/main.cpp`) (tomorrow)
