import time
import shrike
import config
from spi_master import FPGALink
from imu import MPU6050
from pid import PIDController


def pid_to_motor(pid_output):
    magnitude = abs(pid_output)

    if magnitude < config.MOTOR_DEAD_ZONE:
        return config.STEP_LIMIT_MAX, 0

    direction = 1 if pid_output > 0 else 0

    magnitude = min(magnitude, config.PID_OUTPUT_MAX)

    range_in = config.PID_OUTPUT_MAX - config.MOTOR_DEAD_ZONE
    range_out = config.STEP_LIMIT_MAX - config.STEP_LIMIT_MIN

    if range_in > 0:
        step_limit = config.STEP_LIMIT_MAX - int(
            (magnitude - config.MOTOR_DEAD_ZONE) * range_out / range_in
        )
    else:
        step_limit = config.STEP_LIMIT_MAX

    step_limit = max(config.STEP_LIMIT_MIN, min(step_limit, config.STEP_LIMIT_MAX))

    return step_limit, direction


def main():
    print("=" * 50)
    print("FPGA Balance Bot — Starting Up")
    print("=" * 50)

    print("\n[1/4] Flashing FPGA bitstream...")
    try:
        shrike.reset()
        shrike.flash(config.BITSTREAM_FILE)
        print("      FPGA programmed successfully.")
    except Exception as e:
        print(f"      ERROR: FPGA flash failed: {e}")
        print("      Make sure bitstream file is uploaded to RP2040 filesystem.")
        return

    time.sleep_ms(200)

    print("\n[2/4] Initializing peripherals...")

    try:
        fpga = FPGALink()
        print("      SPI link to FPGA: OK")
    except Exception as e:
        print(f"      ERROR: SPI init failed: {e}")
        return

    try:
        imu = MPU6050()
        print("      MPU-6050 IMU: OK")
    except Exception as e:
        print(f"      ERROR: IMU init failed: {e}")
        return

    pid = PIDController()
    print("      PID controller: OK")
    print(f"      Gains: Kp={pid.kp}, Ki={pid.ki}, Kd={pid.kd}")

    print("\n[3/4] Calibrating IMU...")
    print("      Hold robot upright and still!")
    time.sleep(2)
    imu.calibrate()

    print("\n[4/4] Starting balance control loop...")
    print(f"      Target frequency: {config.LOOP_FREQ_HZ} Hz")
    print(f"      Loop period: {config.LOOP_PERIOD_MS} ms")
    print("      Press Ctrl+C to stop.\n")

    fpga.stop_motors()

    loop_count = 0
    loop_start = time.ticks_ms()

    try:
        while True:
            iter_start = time.ticks_us()

            tilt_angle = imu.get_tilt_angle()

            pid_output = pid.compute(tilt_angle)

            step_limit, direction = pid_to_motor(pid_output)

            encoder_count, encoder_dir, stall_flag = fpga.transfer(
                step_limit, direction
            )

            if stall_flag:
                if config.DEBUG_PRINT:
                    print("WARNING: Motor stall detected!")

            loop_count += 1
            if config.DEBUG_PRINT and (loop_count % config.DEBUG_INTERVAL == 0):
                elapsed = time.ticks_diff(time.ticks_ms(), loop_start)
                actual_freq = (loop_count * 1000) / elapsed if elapsed > 0 else 0

                print(
                    f"angle={tilt_angle:+6.1f}° "
                    f"pid={pid_output:+7.0f} "
                    f"step={step_limit:6d} "
                    f"dir={direction} "
                    f"enc={encoder_count:5d} "
                    f"stall={stall_flag} "
                    f"freq={actual_freq:.0f}Hz"
                )

            iter_time_us = time.ticks_diff(time.ticks_us(), iter_start)
            sleep_us = (config.LOOP_PERIOD_MS * 1000) - iter_time_us
            if sleep_us > 0:
                time.sleep_us(sleep_us)

    except KeyboardInterrupt:
        print("\n\nStopping motors...")
        fpga.emergency_stop()
        print("Done. Motors safe.")


def test_spi():
    print("SPI test mode — sending fixed commands to FPGA")
    shrike.reset()
    shrike.flash(config.BITSTREAM_FILE)
    time.sleep_ms(200)

    fpga = FPGALink()

    print("Sending step_limit=10000, direction=1...")
    for i in range(100):
        enc, enc_dir, stall = fpga.transfer(10000, 1)
        if i % 10 == 0:
            print(f"  enc={enc}, dir={enc_dir}, stall={stall}")
        time.sleep_ms(50)

    print("Stopping...")
    fpga.stop_motors()
    print("SPI test done.")


def test_imu():
    print("IMU test mode — reading tilt angle")
    imu = MPU6050()
    imu.calibrate()

    print("Reading angles (Ctrl+C to stop)...")
    try:
        while True:
            angle = imu.get_tilt_angle()
            raw = imu.get_raw_debug()
            print(
                f"angle={angle:+6.1f}° "
                f"ax={raw['ax']:+5.2f} ay={raw['ay']:+5.2f} az={raw['az']:+5.2f} "
                f"gx={raw['gx']:+6.1f} gy={raw['gy']:+6.1f}"
            )
            time.sleep_ms(50)
    except KeyboardInterrupt:
        print("IMU test done.")


def test_motor_sweep():
    print("Motor sweep test — ramping speed up and down")
    shrike.reset()
    shrike.flash(config.BITSTREAM_FILE)
    time.sleep_ms(200)

    fpga = FPGALink()

    print("Speeding up...")
    for step in range(50000, 1000, -500):
        fpga.transfer(step, 1)
        time.sleep_ms(50)

    time.sleep(1)

    print("Slowing down...")
    for step in range(1000, 50000, 500):
        fpga.transfer(step, 1)
        time.sleep_ms(50)

    print("Reversing direction...")
    for step in range(50000, 1000, -500):
        fpga.transfer(step, 0)
        time.sleep_ms(50)

    fpga.stop_motors()
    print("Motor sweep done.")


if __name__ == "__main__":
    main()
