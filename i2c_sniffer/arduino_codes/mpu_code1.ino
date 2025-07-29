#include <Wire.h>

#define MPU_ADDR 0x68  // MPU-6500 I2C address

int read_count = 0;  // Counter to limit to 10 reads

void setup() {
  Serial.begin(115200);
  delay(970);
  Wire.begin();

  // Wake up MPU-6500
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1 register
  Wire.write(0x00);  // 0x00 to wake up
  Wire.endTransmission();

  Serial.println("MPU6500 Initialized\n");
}

void loop() {
  if (read_count <10) {
    Serial.print("Read #");
    Serial.println(read_count + 1);

    // Set register pointer to ACCEL_XOUT_H (0x3B)
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(0x43);  // Starting register
    Wire.endTransmission(false);  // Repeated start

    Wire.requestFrom(MPU_ADDR, 6, true);  // Request 6 bytes

    for (int i = 0; i < 6; i++) {
      if (Wire.available()) {
        byte data = Wire.read();
        Serial.print("Byte ");
        Serial.print(i);
        Serial.print(": ");
        Serial.println(data, HEX);
      }
    }

    Serial.println();  // Blank line between reads
    read_count++;      // Increment the counter
    delay(300);        // Small delay between each read
  }
  else {
    // Do nothing after 10 reads — or use while(1); to halt
    while (1);  // Stops the loop permanently
  }
}
