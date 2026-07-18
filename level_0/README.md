# Level 0 — Own Blink

**Status:** Working end-to-end (July 18, 2026)

Proves the full custom-project toolchain from Verilog source to blinking LED:
own `main.v` → GCSH synthesis → `FPGA_bitstream_MCU.bin` → PlatformIO firmware → LittleFS → RP2040 → SPI to FPGA → LED blinks.

## Pin assignments (GCSH I/O Planner)
- `clk` → OSC_CLK (internal 50 MHz oscillator)
- `LED` → GPIO16_OUT (Pin 7)
- `LED_en` → GPIO16_OE (Pin 7)
- `clk_en` → OSC_EN

## Flash procedure
1. Open project in VS Code with PlatformIO.
2. Place `FPGA_bitstream_MCU.bin` (from GCSH build folder) in `data/`.
3. Put board in BOOTSEL mode (hold BOOT, plug USB, release BOOT). Board mounts as `E:` drive.
4. PlatformIO → Project Tasks → pico → Platform → **Build unified FW+FS UF2 image**.
5. Copy the resulting `firmware_with_fs.uf2` from `.pio/build/pico/` into the `E:` drive.
6. Board reboots and runs the firmware; RP2040 flashes the FPGA over SPI; LED blinks.

## Lessons learned this session
1. **PlatformIO `Upload Filesystem Image` fails on Windows without Zadig WinUSB driver.** Bypass by using **Build unified FW+FS UF2 image** and dragging the `.uf2` into the `E:` drive manually.
2. **COM port number changes** between BOOTSEL mode (no COM) and running-firmware mode. Check Device Manager each time.
3. **`upload_port = E:/`** must be set explicitly in `platformio.ini` if the auto-detect fails.
4. **Every top-level Verilog port needs `(* iopad_external_pin *)`** or it never bonds to a physical pin.
5. **All four ports must be assigned in I/O Planner** — including `LED_en` and `clk_en`, not just `LED` and `clk`.

## What is NOT proven yet
- Two-way SPI communication between RP2040 and FPGA (Level 1).
- Any FPGA logic beyond a counter + LED toggle.
