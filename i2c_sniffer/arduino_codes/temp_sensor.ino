#include <Wire.h>

#define LM75_ADDR 0x48  // Default LM75 I2C address (A0/A1/A2 = GND)

void setup() {
  Serial.begin(9600);
  Wire.begin();
  delay(970);  // Optional small delay for stability

  Serial.println("LM75 Initialized\n");
}

void loop() {
  Serial.print("Read #");
  static int read_count = 1;
  Serial.println(read_count++);

  // Set register pointer to Temperature Register (0x00)
  Wire.beginTransmission(LM75_ADDR);
  Wire.write(0x00);  // Temperature register
  Wire.endTransmission(false);  // Repeated start

  Wire.requestFrom(LM75_ADDR, 2);  // Request 2 bytes

  if (Wire.available() >= 2) {
    byte msb = Wire.read();
    byte lsb = Wire.read();

    // Print raw hex values
    Serial.print("Byte 0 (MSB): 0x");
    if (msb < 0x10) Serial.print("0");
    Serial.println(msb, HEX);

    Serial.print("Byte 1 (LSB): 0x");
    if (lsb < 0x10) Serial.print("0");
    Serial.println(lsb, HEX);

    // Combine bytes into 11-bit signed integer (temperature)
    int16_t raw_temp = ((msb << 8) | lsb) >> 5;

    // Handle negative values (11-bit 2's complement)
    if (raw_temp & 0x0400) {  // If bit 10 is 1 (sign bit)
      raw_temp |= 0xF800;     // Sign extend to 16-bit negative number
    }

    float celsius = raw_temp * 0.125;

    // Print calculated temperature
    Serial.print("Temperature: ");
    Serial.print(celsius, 3);  // 3 decimal places for precision
    Serial.println(" °C");
  } else {
    Serial.println("Error: Not enough data received from LM75");
  }
