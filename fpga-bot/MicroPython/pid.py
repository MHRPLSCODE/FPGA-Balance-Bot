import time
import config


class PIDController:
    def __init__(self, kp=None, ki=None, kd=None, setpoint=None):
        self.kp = kp if kp is not None else config.PID_KP
        self.ki = ki if ki is not None else config.PID_KI
        self.kd = kd if kd is not None else config.PID_KD
        self.setpoint = setpoint if setpoint is not None else config.PID_SETPOINT

        self.integral = 0.0
        self.prev_error = 0.0
        self.last_time = time.ticks_us()

        self.output_min = config.PID_OUTPUT_MIN
        self.output_max = config.PID_OUTPUT_MAX
        self.integral_limit = config.PID_INTEGRAL_LIMIT

    def reset(self):
        self.integral = 0.0
        self.prev_error = 0.0
        self.last_time = time.ticks_us()

    def compute(self, measured_value):
        now = time.ticks_us()
        dt = time.ticks_diff(now, self.last_time) / 1_000_000.0
        self.last_time = now

        if dt <= 0.0 or dt > 0.1:
            dt = 0.01

        error = self.setpoint - measured_value

        p_term = self.kp * error

        self.integral += error * dt
        if self.integral > self.integral_limit:
            self.integral = self.integral_limit
        elif self.integral < -self.integral_limit:
            self.integral = -self.integral_limit

        i_term = self.ki * self.integral

        if dt > 0:
            derivative = (error - self.prev_error) / dt
        else:
            derivative = 0.0

        d_term = self.kd * derivative

        self.prev_error = error

        output = p_term + i_term + d_term

        if output > self.output_max:
            output = self.output_max
        elif output < self.output_min:
            output = self.output_min

        return output

    def set_gains(self, kp=None, ki=None, kd=None):
        if kp is not None:
            self.kp = kp
        if ki is not None:
            self.ki = ki
        if kd is not None:
            self.kd = kd

    def get_debug(self):
        return {
            'error': self.prev_error,
            'integral': self.integral,
            'kp': self.kp,
            'ki': self.ki,
            'kd': self.kd
        }
