module uart_tx #(
    parameter BAUD_RATE  = 115200,
    parameter CLK_FREQ   =100_000_000
)(
    input        clk,
    input        rst,
    input  [7:0] tx_data,
    input        tx_start,
    output reg      tx_busy,
    output reg   tx_serial,
    output reg   tx_done,
     output reg      sniff_success,
     output reg debug_led
);

    localparam CLOCK_DIV = 868;//CLK_FREQ / BAUD_RATE;

    // FSM States
    localparam STATE_IDLE   = 3'b000;
    localparam STATE_START  = 3'b001;
    localparam STATE_DATA   = 3'b010;
    localparam STATE_STOP   = 3'b011;
    localparam STATE_DONE   = 3'b100;

    reg [2:0]  state        = STATE_IDLE;
   // reg [7:0]  tx_buffer    = 8'd0;
    reg [15:0]  baud_counter = 16'd0;    // You can adjust to [31:0] if CLOCK_DIV is very large
    reg [2:0]  bit_index    = 3'd0;
   // reg        busy         = 1'b0;
 //   reg        done         = 1'b0;

    reg [4:0] wait_counter;  // 4-bit counter, adjust the size if needed
reg [25:0] led_counter;  // for LED hold time

    always @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                baud_counter <= 0;
                bit_index    <= 0;
                tx_serial    <= 1'b1;  // Idle line is HIGH
                tx_done      <= 1'b0;
               
                if (tx_start) begin
                 //sniff_success <= 1;
                    tx_busy      <= 1'b1;
                    state     <= STATE_START;
                     
                end
            end

            STATE_START: begin
          
                tx_serial <= 1'b0;  // Start bit
            // $display("Time=%0t | tx_serial_out = %b ", $time, tx_serial);
                if (baud_counter < CLOCK_DIV - 1) begin
                    baud_counter <= baud_counter + 1;
                    
               end else begin
                    baud_counter <= 0;
                     
                    state        <= STATE_DATA;
                end
            end

            STATE_DATA: begin
              
             // $display("Time %0t: Entered STATE_DATA, baud_counter = %0d", $time, baud_counter);
                tx_serial <= tx_data[bit_index];
                $display("Time=%0t | tx_serial_out = %b  bit_index = %0d", $time, tx_serial, bit_index);
                if (baud_counter < CLOCK_DIV - 1)
                    baud_counter <= baud_counter + 1;
                else begin
                    baud_counter <= 0;
                    if (bit_index == 7)begin
                    //sniff_success <= 1;
                        state <= STATE_STOP;
                  end  else
                        bit_index <= bit_index + 1;
                end
                
            end

            STATE_STOP: begin
          
                tx_serial <= 1'b1;
            // $display("Time=%0t | tx_serial_out = %b  ", $time, tx_serial);
                if (baud_counter < CLOCK_DIV - 1)
                    baud_counter <= baud_counter + 1;
                else begin
                    baud_counter <= 0;
                   tx_busy         <= 0;
                    tx_done         <= 1;
                    state        <= STATE_DONE;
                end
            end

            STATE_DONE: begin
             
                tx_done <= 1;
                //sniff_success <= 1;
                state   <= STATE_IDLE;
            end

            default: state <= STATE_IDLE;

        endcase
 /*       // LED trigger logic
if (sniff_success) begin
    led_counter <= 26'd50_000_000; // 0.5 sec at 100 MHz
    debug_led <= 1;
end else if (led_counter != 0) begin
    led_counter <= led_counter - 1;
    if (led_counter == 1)
        debug_led <= 0;
end*/
    end

endmodule
