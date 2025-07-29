#include "Wire.h"
#include "I2Cdev.h"
#include "MPU6050.h"

MPU6050 mpu;

int16_t ax, ay, az;
int16_t gx, gy, gz;
int16_t tempRaw;



void setup() {
  Serial.begin(115200);
  delay(1000);
  Wire.begin();
  mpu.initialize();
}

void loop() {
  
    // Read sensor values
    mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
    tempRaw = mpu.getTemperature();

    delay(500);

    // Print all in hex
    Serial.print("Accel X = 0x"); Serial.print(ax, HEX); Serial.print("  ");
    Serial.print("Accel Y = 0x"); Serial.print(ay, HEX); Serial.print("  ");
    Serial.print("Accel Z = 0x"); Serial.println(az, HEX);

    Serial.print("Temp Raw = 0x"); Serial.println(tempRaw, HEX);

    Serial.print("Gyro X = 0x"); Serial.print(gx, HEX); Serial.print("  ");
    Serial.print("Gyro Y = 0x"); Serial.print(gy, HEX); Serial.print("  ");
    Serial.print("Gyro Z = 0x"); Serial.println(gz, HEX);

    Serial.println("--------------------------------------------------");



   
  
}
