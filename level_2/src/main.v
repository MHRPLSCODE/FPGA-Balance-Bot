#include <Arduino.h>
#include <EEPROM.h>
#include <SPI.h>
#include <Shrike.h>

ShrikeFlash fpga;

const int SCK_PIN  = 2;
const int MOSI_PIN = 3;
const int MISO_PIN = 0;
const int CS_PIN   = 1;
const int RST_PIN  = 14;

const uint8_t CMD_START = 0xA5;

uint16_t test_targets[] = {5000, 0, 20000, 100};
int      target_idx = 0;

uint8_t spi_byte(uint8_t tx_byte) {
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  digitalWrite(CS_PIN, LOW);
  delayMicroseconds(10);
  uint8_t rx = SPI.transfer(tx_byte);
  delayMicroseconds(10);
  digitalWrite(CS_PIN, HIGH);
  SPI.endTransaction();
  delayMicroseconds(50);
  return rx;
}

uint16_t send_motion_command(uint16_t target, uint8_t direction, uint8_t &status_out) {
  uint8_t r0 = spi_byte(CMD_START);
  uint8_t r1 = spi_byte((target >> 8) & 0xFF);
  uint8_t r2 = spi_byte(target & 0xFF);
  uint8_t r3 = spi_byte(direction & 0x01);

  Serial.print("  replies: 0x");
  if (r0 < 0x10) Serial.print("0"); Serial.print(r0, HEX); Serial.print(" 0x");
  if (r1 < 0x10) Serial.print("0"); Serial.print(r1, HEX); Serial.print(" 0x");
  if (r2 < 0x10) Serial.print("0"); Serial.print(r2, HEX); Serial.print(" 0x");
  if (r3 < 0x10) Serial.print("0"); Serial.print(r3, HEX);
  Serial.println();

  uint16_t ramped = ((uint16_t)r1 << 8) | r2;
  status_out = r3;
  return ramped;
}

void setup() {
  delay(2000);
  Serial.begin(115200);
  while (!Serial) delay(10);

  Serial.println();
  Serial.println("=== Level 2: Motion Coprocessor ===");

  if (!fpga.begin()) {
    Serial.println("FPGA init failed!");
    while (1) delay(1000);
  }
  Serial.print("Flashing FPGA..");
  fpga.flash("/level2.bin");
  Serial.println(" done.");

  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, HIGH); delay(100);
  digitalWrite(RST_PIN, LOW);  delay(500);
  digitalWrite(RST_PIN, HIGH); delay(500);

  pinMode(CS_PIN, OUTPUT);
  digitalWrite(CS_PIN, HIGH);
  SPI.setSCK(SCK_PIN);
  SPI.setTX(MOSI_PIN);
  SPI.setRX(MISO_PIN);
  SPI.begin();

  Serial.println("SPI ready. Starting ramp tests.");
  Serial.println();
}

void loop() {
  uint16_t target = test_targets[target_idx];
  Serial.print(">>> New target: "); Serial.println(target);

  for (int i = 0; i < 30; i++) {
    uint8_t status;
    uint16_t ramped = send_motion_command(target, 0, status);
    Serial.print("  ramped="); Serial.print(ramped);
    Serial.print("  status=0x");
    if (status < 0x10) Serial.print("0");
    Serial.print(status, HEX);
    Serial.print("  at_target=");
    Serial.println(status & 0x01 ? "YES" : "no");
    delay(200);
  }

  target_idx = (target_idx + 1) % 4;
  delay(1000);
}
