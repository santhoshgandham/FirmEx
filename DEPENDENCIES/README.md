1. **Toolchain dependencies (libraries/packages)**
2. **Important functions used from those libraries**
3. **External files expected (like configs and CSVs)**
4. **Hardcoded/manual port names and addresses**

---

### ✅ **1. Toolchain Dependencies (Packages & Libraries)**

| **Library/Package**                                               | **Purpose**                                   |
| ----------------------------------------------------------------- | --------------------------------------------- |
| `tkinter`                                                         | GUI elements (buttons, windows, input boxes)  |
| `ttk`, `messagebox`, `simpledialog`, `scrolledtext`, `filedialog` | Tkinter submodules for GUI features           |
| `subprocess`                                                      | Running external commands (flashrom, openocd) |
| `telnetlib`                                                       | Communicating with OpenOCD via Telnet         |
| `hashlib`                                                         | SHA-256 hash calculation                      |
| `pandas`                                                          | CSV file parsing and hash matching            |
| `threading.Thread`                                                | Non-blocking background tasks (like dumps)    |
| `serial` (pyserial)                                               | UART communication                            |
| `numpy`                                                           | Mean and std deviation in anomaly detection   |
| `collections.deque`                                               | Fixed-size buffer for samples                 |
| `time`                                                            | Delay during OpenOCD startup                  |
| `pyftdi.i2c.I2cController`                                        | I²C firmware dumping via FTDI                 |

---

### ✅ **2. Important Functions Used from Libraries**

| **Function / Method**         | **From**      | **Purpose**                             |
| ----------------------------- | ------------- | --------------------------------------- |
| `I2cController().configure()` | `pyftdi`      | Configure FTDI device for I²C           |
| `slave.exchange()`            | `pyftdi`      | Send/receive I²C data                   |
| `serial.Serial()`             | `pyserial`    | Establish UART communication            |
| `subprocess.run()`            | `subprocess`  | Execute shell commands (e.g., flashrom) |
| `subprocess.Popen()`          | `subprocess`  | Spawn background OpenOCD process        |
| `telnetlib.Telnet()`          | `telnetlib`   | Connect to OpenOCD Telnet server        |
| `sha256.update()`             | `hashlib`     | Add bytes to hash computation           |
| `pandas.read_csv()`           | `pandas`      | Load firmware hashes from CSV           |
| `np.mean()` / `np.std()`      | `numpy`       | Z-score based anomaly detection         |
| `deque(maxlen=n)`             | `collections` | Rolling buffer for training samples     |
| `simpledialog.askstring()`    | `tkinter`     | Baud rate selection dialog              |

---

### ✅ **3. Files the Program Expects or Creates**

| **File**                        | **Purpose**                                                                        |
| ------------------------------- | ---------------------------------------------------------------------------------- |
| `i2c_firmware.bin`              | Output of I²C EEPROM dump                                                          |
| `firmware_uart_dump.bin`        | Output of UART data dump                                                           |
| `router.bin`, `firmex.bin`      | Output of SPI flashrom dump                                                        |
| `jtag_dump.bin`                 | Output from JTAG dump                                                              |
| `swd_dump.bin`                  | Output from SWD dump                                                               |
| `lfwc-masked.csv`               | **Required** – Contains firmware SHA256 hashes for verification (used with Pandas) |
| `flashrom_log.txt`              | Stores flashrom output logs                                                        |
| `swd_dump.cfg`, `jtag_dump.cfg` | **Required** – OpenOCD config files for SWD/JTAG                                   |

---

### ✅ **4. Hardcoded Device Paths and Addresses**

| **Device/File**            | **Usage Context**                      |
| -------------------------- | -------------------------------------- |
| `/dev/ttyUSB0`             | Default UART port for dumping firmware |
| `/dev/ttyUSB1`             | Used for real-time anomaly detection   |
| `ftdi:///2`                | FTDI I²C interface                     |
| `0x50`                     | EEPROM I²C address                     |
| `0x00000000`, `0x00040000` | Memory addresses for SWD/JTAG dumps    |
| `port=B`                   | Flashrom SPI port using FTDI FT2232H   |
| `divisor=4`                | SPI clock divider in flashrom          |

---

### ✅ **5. Extraction Methods & How They Work**

| **Method**            | **Details**                                                      |
| --------------------- | ---------------------------------------------------------------- |
| **SPI**               | Uses `flashrom` via subprocess, detects multiple chips if needed |
| **JTAG**              | Uses `openocd` and `telnet` for command execution                |
| **SWD**               | Similar to JTAG, but using `swd_dump.cfg`                        |
| **UART**              | Uses `pyserial`, baudrate selected interactively                 |
| **I²C**               | Uses `pyftdi` to read EEPROM contents                            |
| **Anomaly Detection** | Real-time temp monitor from UART packets (with Z-score logic)    |

---
