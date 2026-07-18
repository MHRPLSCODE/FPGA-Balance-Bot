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

uint8_t spi_exchange(uint8_t byte_to_send) {
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  digitalWrite(CS_PIN, LOW);
  delayMicroseconds(10);
  uint8_t received = SPI.transfer(byte_to_send);
  delayMicroseconds(10);
  digitalWrite(CS_PIN, HIGH);
  SPI.endTransaction();
  return received;
}

void setup() {
  delay(2000);
  Serial.begin(115200);
  while (!Serial) delay(10);

  Serial.println("SPI Loopback Example");

  if (!fpga.begin()) {
    Serial.println("FPGA init failed!");
    while (1) delay(1000);
  }
  Serial.print("Flashing FPGA..");
  fpga.flash("/FPGA_bitstream_MCU.bin");
  Serial.println(" Done.");

  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, HIGH);
  delay(100);
  digitalWrite(RST_PIN, LOW);
  delay(1000);
  digitalWrite(RST_PIN, HIGH);
  delay(1000);

  pinMode(CS_PIN, OUTPUT);
  digitalWrite(CS_PIN, HIGH);

  SPI.setSCK(SCK_PIN);
  SPI.setTX(MOSI_PIN);
  SPI.setRX(MISO_PIN);
  SPI.begin();

  Serial.println("SPI initialized. Starting loop...");
}

void loop() {
  uint8_t values[] = {0xAB, 0xFF};
  for (int i = 0; i < 2; i++) {
    uint8_t resp = spi_exchange(values[i]);
    Serial.print("Sent 0x");
    if (values[i] < 0x10) Serial.print("0");
    Serial.print(values[i], HEX);
    Serial.print(", Received 0x");
    if (resp < 0x10) Serial.print("0");
    Serial.println(resp, HEX);
    delay(1000);
  }
}
