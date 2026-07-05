from machine import Pin, I2C
import math
import time
import config

_PWR_MGMT_1 = 0x6B
_ACCEL_XOUT_H = 0x3B
_GYRO_XOUT_H = 0x43
_WHO_AM_I = 0x75


class MPU6050:
    def __init__(self):
        self.i2c = I2C(
            config.I2C_ID,
            sda=Pin(config.I2C_SDA_PIN),
            scl=Pin(config.I2C_SCL_PIN),
            freq=config.I2C_FREQ
        )

        who = self.i2c.readfrom_mem(config.MPU6050_ADDR, _WHO_AM_I, 1)[0]
        if who != 0x68:
            raise RuntimeError(f"MPU6050 not found! WHO_AM_I = 0x{who:02X}")

        self.i2c.writeto_mem(config.MPU6050_ADDR, _PWR_MGMT_1, bytes([0x00]))
        time.sleep_ms(100)

        self.angle = 0.0
        self.last_time = time.ticks_us()

        self.gyro_offset_x = 0.0
        self.gyro_offset_y = 0.0
        self.accel_offset_x = 0.0
        self.accel_offset_y = 0.0

    def _read_raw(self, reg, count=6):
        data = self.i2c.readfrom_mem(config.MPU6050_ADDR, reg, count)
        values = []
        for i in range(0, count, 2):
            val = (data[i] << 8) | data[i + 1]
            if val > 32767:
                val -= 65536
            values.append(val)
        return values

    def read_accel(self):
        raw = self._read_raw(_ACCEL_XOUT_H, 6)
        ax = raw[0] / config.ACCEL_SCALE - self.accel_offset_x
        ay = raw[1] / config.ACCEL_SCALE - self.accel_offset_y
        az = raw[2] / config.ACCEL_SCALE
        return ax, ay, az

    def read_gyro(self):
        raw = self._read_raw(_GYRO_XOUT_H, 6)
        gx = raw[0] / config.GYRO_SCALE - self.gyro_offset_x
        gy = raw[1] / config.GYRO_SCALE - self.gyro_offset_y
        gz = raw[2] / config.GYRO_SCALE
        return gx, gy, gz

    def calibrate(self, samples=200):
        print("Calibrating IMU — keep robot still and upright...")
        gx_sum = 0.0
        gy_sum = 0.0
        ax_sum = 0.0
        ay_sum = 0.0

        for _ in range(samples):
            raw_a = self._read_raw(_ACCEL_XOUT_H, 6)
            raw_g = self._read_raw(_GYRO_XOUT_H, 6)

            ax_sum += raw_a[0] / config.ACCEL_SCALE
            ay_sum += raw_a[1] / config.ACCEL_SCALE
            gx_sum += raw_g[0] / config.GYRO_SCALE
            gy_sum += raw_g[1] / config.GYRO_SCALE

            time.sleep_ms(5)

        self.gyro_offset_x = gx_sum / samples
        self.gyro_offset_y = gy_sum / samples
        self.accel_offset_x = ax_sum / samples
        self.accel_offset_y = ay_sum / samples

        print(f"Calibration done. Gyro offsets: X={self.gyro_offset_x:.2f}, Y={self.gyro_offset_y:.2f}")
        print(f"Accel offsets: X={self.accel_offset_x:.4f}, Y={self.accel_offset_y:.4f}")

    def get_tilt_angle(self):
        ax, ay, az = self.read_accel()
        gx, gy, gz = self.read_gyro()

        now = time.ticks_us()
        dt = time.ticks_diff(now, self.last_time) / 1_000_000.0
        self.last_time = now

        if dt > 0.1:
            dt = 0.01

        accel_angle = math.atan2(ax, az) * (180.0 / math.pi)

        gyro_rate = gy

        alpha = config.COMP_FILTER_ALPHA
        self.angle = alpha * (self.angle + gyro_rate * dt) + (1.0 - alpha) * accel_angle

        return self.angle

    def get_raw_debug(self):
        ax, ay, az = self.read_accel()
        gx, gy, gz = self.read_gyro()
        return {
            'ax': ax,
            'ay': ay,
            'az': az,
            'gx': gx,
            'gy': gy,
            'gz': gz,
            'angle': self.angle
        }
