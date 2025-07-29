module top (
    input        clk,          // System clock (100MHz)
    input        rst,          // Active-high reset
    inout        i2c_sda,      // I2C data line
    inout        i2c_scl,      // I2C clock line
    output  debug_led,
    output       tx            // UART TX output
);

    // I2C Sniffer signals
    wire [7:0] address;
    wire [7:0] reg_address;
    wire [7:0] reg_data;
    wire       address_ready;
    wire       reg_address_ready;
    wire       reg_data_ready;
    wire sda_clean_dbg, scl_clean_dbg;
    // UART Control signals
    wire [7:0] uart_tx_data;
    wire       tx_start;
    wire       tx_done;
    wire       tx_busy;



    // Instantiate I2C Sniffer
    i2c_sniffer i2c_sniffer_inst (
        .clk(clk),
        .rst(rst),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .address(address),
        .reg_address(reg_address),
        .reg_data(reg_data),
        .address_ready(address_ready),
        .reg_address_ready(reg_address_ready),
        .reg_data_ready(reg_data_ready),
        .debug_led(debug_led)
  
    );

    // Instantiate UART Send Sequencer
    uart_send_sequencer sequencer (
        .clk(clk),
        .rst(rst),
        .address_ready(address_ready),
        .reg_address_ready(reg_address_ready),
        .reg_data_ready(reg_data_ready),
        .address(address),
        .reg_address(reg_address),
        .reg_data(reg_data),
        .uart_tx_data(uart_tx_data),
        .uart_tx_en(tx_start),
        .uart_tx_done(tx_done),
        .debug_led(debug_led)
    );

    // Instantiate UART TX
    uart_tx #(
        .BAUD_RATE(115200),
        .CLK_FREQ(100_000_000)
    ) uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_data(uart_tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .tx_serial(tx),
        .debug_led(debug_led),
        .tx_done(tx_done)
    );

endmodule
