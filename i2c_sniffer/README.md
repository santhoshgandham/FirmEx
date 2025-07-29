I²C Sniffer using FPGA (Basys 3 + Verilog)
This project implements an I²C Sniffer on the Basys 3 FPGA development board using Verilog. It passively monitors I²C communication between a master (e.g., Arduino) and a slave (e.g., MPU-6050), and transmits the captured data over UART to a PC.

Features
Sniffs I²C transactions non-intrusively.
Decodes and transmits:
Start condition
Slave address + R/W bit
Register address
Data bytes
Displays data via UART in hex format.
Modular Verilog design:
Separate I²C sniffer, FIFO buffer, UART transmitter, and controller FSMs.
Hardware Used
Basys 3 FPGA board (Artix-7)
MPU-6050 (or MPU-6500) IMU sensor (I²C slave)
Arduino UNO (I²C master)
Breadboard + jumper wires
Hardware Used
Main Components
Basys 3 Development Board (Xilinx Artix-7 FPGA)
MPU-6050 / MPU-6500 (I²C Sensor, slave)
Arduino Uno (I²C Master)
Supporting Components
Breadboard
Jumper wires
Setup Instructions
Hardware Connections
SDA, SCL from Arduino → FPGA
FPGA UART TX pin (e.g., JA4) → USB-UART converter → PC
Common ground between FPGA and Arduino
Vivado Setup
Open Vivado, create a new project
Add Verilog files and XDC constraints
Set the top module
Generate bitstream and program the FPGA
Serial Monitor
Use RealTerm / HTerm / PuTTY
Baud Rate: 115200
Display Format: Hexadecimal
How to Use
Upload the Arduino code from the /arduino folder
Open a UART terminal on the PC
Power the Basys 3 board
Start observing sniffed I²C traffic live
Note: Add delay(900); after Serial.begin() in the Arduino sketch to avoid startup glitches.

Sample Output
D0 6B 00 D0 3B D1 08 50 06 F4 3D F8
Example breakdown:

D0: Write to 0x68
6B: Power management register
00: Data (wake-up)
D1: Read from 0x68
Remaining: Sensor data bytes
Known Issues / Limitations
Currently supports only 100 kHz I²C
Clock stretching not supported
UART baud must match terminal exactly (e.g., 115200)
Initial false transactions may appear without startup delay on Arduino
Credits
Reference:
MPU-6500 Datasheet

Basys 3 Reference Manual (Digilent)
