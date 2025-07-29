import tkinter as tk
from tkinter import ttk, messagebox, simpledialog, scrolledtext, filedialog
import subprocess
import re
import telnetlib
import hashlib
import pandas as pd
from threading import Thread
import serial
import numpy as np
from collections import deque
import time
from pyftdi.i2c import I2cController

def dump_i2c_eeprom(i2c_url='ftdi:///2', eeprom_addr=0x50, size=65536, output_file='i2c_firmware.bin'):
    ctrl = I2cController()
    ctrl.configure(i2c_url)
    slave = ctrl.get_port(eeprom_addr)

    with open(output_file, 'wb') as f:
        for offset in range(0, size, 16):
            addr = offset.to_bytes(2, 'big')  # some EEPROMs/flash use 16-bit address
            data = slave.exchange(addr, 16)
            f.write(data)
    ctrl.close()
    print(f"I²C dump saved to {output_file}")


def choose_baud_rate():
    root = tk.Tk()
    root.withdraw()

    options = [
        "115200",
        "57600",
        "38400",
        "19200",
        "9600",
        "4800",
        "2400",
        "1200"
    ]

    selected = simpledialog.askstring(
        "Choose Baud Rate",
        f"Enter baud rate (options: {', '.join(options)}):",
        initialvalue="115200"
    )

    if selected is None or selected not in options:
        messagebox.showerror("Invalid", "Invalid or cancelled selection. Using default 115200.")
        return 115200

    return int(selected)

def dump_uart(port="/dev/ttyUSB0", baudrate=115200, output_file="firmware_uart_dump.bin"):
    print(f"Connecting to {port} at {baudrate} baud...")
    try:
        with serial.Serial(port, baudrate, timeout=2) as ser, open(output_file, "wb") as f:
            print(f"Dumping UART data to {output_file}. Press Ctrl+C to stop.")
            while True:
                data = ser.read(1024)
                if data:
                    f.write(data)
    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except KeyboardInterrupt:
        print("\nDump stopped by user.")

class RealTimeZScoreDetector:
    def __init__(self, threshold=2.5, train_size=100):
        self.threshold = threshold
        self.train_size = train_size
        self.values = deque(maxlen=train_size)
        self.prev_value = None
        self.trained = False

    def add_sample(self, value):
        if self.prev_value is not None and abs(value - self.prev_value) > 5.0:
            return "Spike"
        self.prev_value = value

        if not self.trained:
            self.values.append(value)
            if len(self.values) == self.train_size:
                self.trained = True
            return "Training"

        mean = np.mean(self.values)
        std = np.std(self.values)

        if std == 0:
            return "Normal"

        z = (value - mean) / std
        self.values.append(value)

        if abs(z) > self.threshold:
            return "Anomaly"
        else:
            return "Normal"

class FlashExtractorGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("FirmEx: Firmware Extraction & Monitoring Tool")
        self.root.geometry("650x600")

        ttk.Label(root, text="Choose extraction method:", font=("Arial", 12)).pack(pady=10)
        self.methods = ["SPI", "JTAG", "SWD", "UART", "I2C", "Run Anomaly Detection"]
        for method in self.methods:
            ttk.Button(root, text=method, command=lambda m=method: self.handle_method(m)).pack(pady=5)

        self.output_text = scrolledtext.ScrolledText(root, height=17, width=80, font=("Consolas", 10))
        self.output_text.pack(pady=10)

        self.output_text.tag_config('normal', foreground='green')
        self.output_text.tag_config('anomaly', foreground='red')
        self.output_text.tag_config('spike', foreground='orange')
        self.output_text.tag_config('info', foreground='blue')

    def insert_colored_text(self, text):
        if "🟥" in text:
            tag = 'anomaly'
        elif "🟩" in text:
            tag = 'normal'
        elif "⚠️" in text:
            tag = 'spike'
        else:
            tag = 'info'
        self.output_text.insert(tk.END, text + "\n", tag)
        self.output_text.see(tk.END)

    def append_output(self, text):
        self.insert_colored_text(text)

    def handle_method(self, method):
        if method == "SPI":
            self.run_flashrom_spi_initial()
        elif method == "JTAG":
            self.run_jtag_extraction()
        elif method == "SWD":
            self.run_swd_extraction()
        elif method == "UART":
            self.run_uart_extraction()
        elif method == "I2C":
            self.run_i2c_extraction()
        elif method == "Run Anomaly Detection":
            Thread(target=self.run_anomaly_detection).start()
        else:
            messagebox.showinfo("Not Implemented", f"{method} extraction not yet implemented.")

    def run_flashrom_spi_initial(self):
        try:
            result = subprocess.run([
                "sudo", "/usr/local/sbin/flashrom", "-p", "ft2232_spi:type=2232H,port=B,divisor=4", "-r", "router.bin"
            ], capture_output=True, text=True)

            output = result.stdout + result.stderr
            with open("flashrom_log.txt", "w") as f:
                f.write(output)

            if "Multiple flash chip definitions match" in output:
                self.extract_chip_options(output)
            elif "Reading flash... done." in output and "flash chip" in output:
                messagebox.showinfo("Success", "Flash read successful with a single detected chip.")
            else:
                messagebox.showerror("Error", f"SPI read failed.\n\n{output}")
        except Exception as e:
            messagebox.showerror("Exception", str(e))

    def extract_chip_options(self, output):
        match = re.search(r'Multiple flash chip definitions match.*?:\s+(.*)', output)
        if match:
            chips = [chip.strip().strip('"') for chip in match.group(1).split(",")]
            self.show_chip_selection(chips)
        else:
            messagebox.showerror("Error", "Failed to parse chip list from flashrom output.")

    def show_chip_selection(self, chips):
        win = tk.Toplevel(self.root)
        win.title("Select Flash Chip")
        ttk.Label(win, text="Multiple chips detected. Choose one to dump flash:", font=("Arial", 11)).pack(pady=10)

        chip_var = tk.StringVar()
        combo = ttk.Combobox(win, values=chips, textvariable=chip_var, state="readonly", width=40)
        combo.pack(pady=10)
        combo.current(0)

        def select_chip():
            selected_chip = chip_var.get()
            win.destroy()
            self.show_post_extraction_options(selected_chip)

        ttk.Button(win, text="Dump with selected chip", command=select_chip).pack(pady=5)
    
    def run_swd_extraction(self):
        
        try:
            cfg = "swd_dump.cfg"  # your SWD config file
            openocd_proc = subprocess.Popen(
                ["sudo", "openocd", "-f", cfg],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT
            )
            time.sleep(3)

            tn = telnetlib.Telnet("localhost", 4444)
            tn.read_until(b">")
            tn.write(b"reset halt\n")
            tn.read_until(b">")

            tn.write(b"swd dap ap scan\n")  # Optional: confirms SWD AP is present
            tn.read_until(b">")
            tn.write(b"dump_image swd_dump.bin 0x00000000 0x00040000\n")  # Adjust size if needed
            dump_output = tn.read_until(b">", timeout=60)

            tn.write(b"shutdown\n")
            tn.close()
            openocd_proc.wait()

            if b"dumped" in dump_output:
                messagebox.showinfo("SWD Dump Success", "Firmware dumped to 'swd_dump.bin'.")
            else:
                messagebox.showerror("SWD Dump Failed", dump_output.decode(errors="ignore"))
        except Exception as e:
            messagebox.showerror("SWD Exception", str(e))

    def run_uart_extraction(self):
        baudrate = choose_baud_rate()
        try:
            Thread(target=dump_uart, args=("/dev/ttyUSB0", baudrate)).start()
            messagebox.showinfo("UART", f"Started UART dump at {baudrate} baud.\nPress Ctrl+C in console to stop.")
        except Exception as e:
            messagebox.showerror("UART Error", str(e))
    
    def run_i2c_extraction(self):
        try:
            Thread(target=dump_i2c_eeprom).start()
            messagebox.showinfo("I²C", "Started I²C firmware dump in background.")
        except Exception as e:
            messagebox.showerror("I²C Error", str(e))

    def show_post_extraction_options(self, chip_name):
        win = tk.Toplevel(self.root)
        win.title("Post Extraction Options")
        ttk.Label(win, text="Select operation:", font=("Arial", 11)).pack(pady=10)

        ttk.Button(win, text="Extract Firmware",
                   command=lambda: [win.destroy(), self.run_flashrom_with_chip(chip_name, "extract")]).pack(pady=5)

        ttk.Button(win, text="Extract and Verify Firmware",
                   command=lambda: [win.destroy(), self.run_flashrom_with_chip(chip_name, "verify")]).pack(pady=5)

    def run_flashrom_with_chip(self, chip_name, mode):
        try:
            filename = "firmex.bin"
            result = subprocess.run([
                "sudo", "/usr/local/sbin/flashrom", "-p", "ft2232_spi:type=2232H,port=B,divisor=4",
                "-c", chip_name, "-r", filename
            ], capture_output=True, text=True)

            output = result.stdout + result.stderr
            with open("flashrom_log.txt", "a") as f:
                f.write("\n\n--- Rerun with -c ---\n")
                f.write(output)

            if "Reading flash... done." in output and "flash chip" in output:
                messagebox.showinfo("Dump Complete", f"Flash dumped successfully into {filename}")
                if mode == "verify":
                    self.verify_firmware(filename)
            else:
                messagebox.showerror("Dump Failed", output)
        except Exception as e:
            messagebox.showerror("Exception", str(e))

    def compute_sha256(self, filename):
        sha256 = hashlib.sha256()
        with open(filename, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

    def verify_firmware(self, firmware_path):
        self.append_output("🔍 Looking for hash in our database...")
        try:
            sha_value = self.compute_sha256(firmware_path)
            self.append_output(f"🔢 Computed SHA256: {sha_value}")

            df = pd.read_csv("lfwc-masked.csv")
            hashes = df.iloc[:, 15].astype(str).values

            if sha_value in hashes:
                self.append_output("✅ Firmware is secure.")
            else:
                self.append_output("❌ Firmware likely tampered. Upload original firmware for verification.")
                file_path = filedialog.askopenfilename(title="Upload original firmware")
                if file_path:
                    uploaded_hash = self.compute_sha256(file_path)
                    self.append_output(f"📦 Uploaded file SHA256: {uploaded_hash}")
                    if uploaded_hash == sha_value:
                        self.append_output("✅ Original firmware matches! Device hash is verified.")
                    else:
                        self.append_output("❌ Uploaded file does not match. Possible corruption or incorrect file.")
        except Exception as e:
            self.append_output(f"⚠️ Error during verification: {e}")

    def run_jtag_extraction(self):
        try:
            openocd_proc = subprocess.Popen([
                "sudo", "openocd", "-f", "jtag_dump.cfg"
            ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            time.sleep(3)

            tn = telnetlib.Telnet("localhost", 4444)
            tn.read_until(b">")
            tn.write(b"reset halt\n")
            tn.read_until(b">")

            tn.write(b"dump_image jtag_dump.bin 0x00000000 0x00040000\n")
            dump_output = tn.read_until(b">", timeout=30)
            tn.write(b"shutdown\n")
            tn.close()

            openocd_proc.wait()

            if b"dumped" in dump_output:
                messagebox.showinfo("JTAG Dump Success", "Firmware dumped successfully into 'jtag_dump.bin'.")
            else:
                messagebox.showerror("Dump Failed", dump_output.decode())
        except Exception as e:
            messagebox.showerror("JTAG Exception", str(e))

    def run_anomaly_detection(self):
        SERIAL_PORT = "/dev/ttyUSB1"
        BAUD_RATE = 115200
        PACKET_SIZE = 5

        self.append_output("📡 Starting real-time anomaly detection with 100-sample training")
        detector = RealTimeZScoreDetector(threshold=2.5, train_size=100)
        cooldown_counter = 0
        prev_temp = None

        try:
            with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1) as ser:
                while True:
                    packet = ser.read(PACKET_SIZE)
                    if len(packet) == PACKET_SIZE:
                        temp = self.parse_temperature(packet[3], packet[4])
                        result = detector.add_sample(temp)

                        if prev_temp is not None and abs(temp - prev_temp) > 5:
                            cooldown_counter = 5
                            self.append_output(f"⚠️ Spike detected: {prev_temp:.2f}°C → {temp:.2f}°C")
                        elif cooldown_counter > 0:
                            self.append_output(f"Cooling down... Temp: {temp:.2f}°C")
                            cooldown_counter -= 1
                        else:
                            if result == "Anomaly":
                                self.append_output(f"🟥 Anomaly Detected! Temp: {temp:.2f}°C")
                            elif result == "Normal":
                                self.append_output(f"🟩 Normal Temp: {temp:.2f}°C")
                            else:
                                self.append_output(f"🔄 {result} Temp: {temp:.2f}°C")

                        prev_temp = temp
        except Exception as e:
            self.append_output(f"❌ Error: {str(e)}")

    def parse_temperature(self, high_byte, low_byte):
        raw = (high_byte << 8) | low_byte
        shifted = raw >> 5
        return shifted * 0.125


if __name__ == "__main__":
    root = tk.Tk()
    app = FlashExtractorGUI(root)
    root.mainloop()