from machine import Pin, SPI
import config

class FPGALink:
    def __init__(self):
        self.spi = SPI(
            config.SPI_ID,
            baudrate=config.SPI_BAUDRATE,
            polarity=config.SPI_POLARITY,
            phase=config.SPI_PHASE,
            bits=8,
            firstbit=SPI.MSB,
            sck=Pin(config.SPI_SCK_PIN),
            mosi=Pin(config.SPI_MOSI_PIN),
            miso=Pin(config.SPI_MISO_PIN)
        )
        self.cs = Pin(config.SPI_CS_PIN, Pin.OUT, value=1)
        self.tx_buf = bytearray(3)
        self.rx_buf = bytearray(3)

    def transfer(self, target_limit, direction):
        target_limit = max(0, min(target_limit, 0xFFFFF))
        packed = (target_limit << 4) | ((direction & 1) << 3)
        self.tx_buf[0] = (packed >> 16) & 0xFF
        self.tx_buf[1] = (packed >> 8) & 0xFF
        self.tx_buf[2] = packed & 0xFF

        self.cs.value(0)
        self.spi.write_readinto(self.tx_buf, self.rx_buf)
        self.cs.value(1)

        raw = (self.rx_buf[0] << 16) | (self.rx_buf[1] << 8) | self.rx_buf[2]
        current_limit = (raw >> 4) & 0xFFFFF
        kill_status = (raw >> 3) & 1
        return current_limit, kill_status

    def stop_motors(self):
        self.transfer(config.STEP_LIMIT_MAX, 0)

    def emergency_stop(self):
        for _ in range(5):
            self.stop_motors()
