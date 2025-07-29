    module uart_send_sequencer (
        input        clk,
        input        rst,
        input        address_ready,
        input        reg_address_ready,
        input        reg_data_ready,
        input  [7:0] address,
        input  [7:0] reg_address,
        input  [7:0] reg_data,
         output reg        uart_tx_en,
        input  wire      uart_tx_done,
        output reg [7:0] uart_tx_data,
        input tx_busy,
        output reg      sniff_success,
         output reg debug_led
    
    );
    reg [4:0] wait_counter;  // 4-bit counter, adjust the size if needed
    reg [25:0] led_counter;  // for LED hold time
    
        // FSM States
        localparam UART_IDLE       = 4'd0;
        localparam UART_SEND_ADDR  = 4'd1;
        localparam UART_WAIT_ADDR  = 4'd2;
        localparam UART_IDLE_ADDR  = 4'd3;
        localparam UART_SEND_REG   = 4'd4;
        localparam UART_WAIT_REG   = 4'd5;
        localparam UART_IDLE_REG   = 4'd6;
        localparam UART_SEND_DATA  = 4'd7;
        localparam UART_WAIT_DATA  = 4'd8;
        reg [3:0] uart_state = UART_IDLE;
        
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                uart_state       <= UART_IDLE;
         sniff_success <= 0;
                uart_tx_en  <= 0;
                uart_tx_data     <= 0;
               
            end else begin
           uart_tx_en  <= 0;
           
            case (uart_state)
              UART_IDLE: begin
            
           //  $display("UART_IDLE: ld_tx_data=%b", uart_ld_tx_data);
                 //$display("UART_IDLE: uart_tx_data = %h", uart_tx_data);
                 if (address_ready) begin
                        
                         uart_state <= UART_SEND_ADDR;
                    end else if (reg_address_ready) begin
                    
                         uart_state <= UART_SEND_REG;
                    end else if (reg_data_ready) begin
                         uart_state <= UART_SEND_DATA;
                    end
            end
           UART_SEND_ADDR: begin
            uart_tx_data <= address;          
            uart_state <= UART_WAIT_ADDR;    // Go to wait state
           //  $display("UART_SEND_ADDR: ld_tx_data = %b, tx_data = %h", uart_ld_tx_data, uart_tx_data);
            end
    
        UART_WAIT_ADDR: begin
            uart_tx_en  <= 1;
          // $display("Time %0t: Entered UART_WAIT_ADDR, uart_tx_done = %b", $time, uart_tx_done);
            if (uart_tx_done)begin
            uart_tx_en  <= 0;
                uart_state <= UART_IDLE_ADDR; // Wait for TX complete
        end 
        end
        
          UART_IDLE_ADDR: begin       
        //  $display("UART_IDLE_ADDR: ");
                     if (address_ready) begin
                    
                         uart_state <= UART_SEND_ADDR;
                    end else if (reg_address_ready) begin
                    
                         uart_state <= UART_SEND_REG;
                    end else if (reg_data_ready) begin
                 
                         uart_state <= UART_SEND_DATA;
                    end
                end
        UART_SEND_REG: begin    
                    uart_tx_data <= reg_address;             // Load reg_address
                    uart_state <= UART_WAIT_REG;             // Go to wait state
                   //  $display("UART_SEND_REG: ld_tx_data = %b, tx_data = %h", uart_ld_tx_data, uart_tx_data);
                end
    
           UART_WAIT_REG: begin
                  uart_tx_en  <= 1;
                  //  $display("UART_WAIT_REG: ld_tx_data = %b", uart_ld_tx_data);
                    if (uart_tx_done)begin    
                        uart_tx_en  <= 0;            
                        uart_state <= UART_IDLE_REG;         // Wait for TX to complete
                end
                end
    
                UART_IDLE_REG: begin
                 
               // $display("UART_IDLE_REG: ld_tx_data = %b", uart_ld_tx_data);
                    if (address_ready) begin
                         uart_state <= UART_SEND_ADDR;                      
                    end else if (reg_address_ready) begin
                         uart_state <= UART_SEND_REG;
                    end else if (reg_data_ready) begin
                         uart_state <= UART_SEND_DATA;
                    end
                 end
    
                UART_SEND_DATA: begin
                
                    uart_tx_data <= reg_data;
                    uart_state <= UART_WAIT_DATA;
                    //$display("UART_SEND_DATA: ld_tx_data = %b, tx_data = %h", uart_ld_tx_data, uart_tx_data);
                end
    
                UART_WAIT_DATA: begin
               
                   uart_tx_en  <= 1;
                   // $display("UART_WAIT_DATA: ld_tx_data = %b", uart_ld_tx_data);
                   // $display("UART_WAIT_DATA: ld_tx_data = %b", uart_ld_tx_data);
                    if (uart_tx_done) begin
                     //sniff_success <= 1;
                        uart_tx_en  <= 0;
                        uart_state <= UART_IDLE;
                end
                end
    
            endcase
                 
    /*// LED trigger logic
    if (sniff_success) begin
        led_counter <= 26'd50_000_000; // 0.5 sec at 100 MHz
        debug_led <= 1;
    end else if (led_counter != 0) begin
        led_counter <= led_counter - 1;
        if (led_counter == 1)
            debug_led <= 0;
    end*/
        end
    end
    
    endmodule
