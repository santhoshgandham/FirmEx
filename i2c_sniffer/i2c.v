 `timescale 1ns / 1ps
module i2c_sniffer (
    input wire clk,
    input wire rst,
    inout wire i2c_sda,
    inout wire i2c_scl,
    output reg debug_led,
    output reg [7:0] address,
    output reg [7:0] reg_address,
    output reg [7:0] reg_data,
    output reg       address_ready,
    output reg       reg_address_ready,
    output reg       reg_data_ready,   
    output reg       sniff_success

);
   
    // High-Z mode (passive sniffer)
    assign i2c_sda = 1'bz;
    assign i2c_scl = 1'bz;
    // Sync inputs to system clock
    reg [1:0] scl_sync, sda_sync;
    reg scl_clean, sda_clean;
    reg scl_prev_clean, sda_prev_clean;   
    reg [4:0] wait_counter;  // 4-bit counter, adjust the size if needed
    reg [25:0] led_counter;  // for LED hold time
    wire i2c_scl_in = i2c_scl;
    wire i2c_sda_in = i2c_sda;
    reg stop_flag;
    
    always @(posedge clk) begin
        scl_sync <= {scl_sync[0], i2c_scl_in};
        sda_sync <= {sda_sync[0], i2c_sda_in};
    
        scl_prev_clean <= scl_clean;
        sda_prev_clean <= sda_clean;
    
        scl_clean <= scl_sync[1];
        sda_clean <= sda_sync[1];
    
    end

        // Edge detection with stability
        wire start_cond = scl_clean && scl_prev_clean && sda_prev_clean && !sda_clean;
        wire stop_cond  = scl_clean && scl_prev_clean && !sda_prev_clean && sda_clean;
        // State machine
        localparam IDLE         = 0;
        localparam RECV_ADDR    = 1;
        localparam RECV_REG     = 2;
        localparam WAIT_NEXT    = 3;
        localparam RECV_WRITE   = 4;
        localparam RECV_READ    = 5;
        localparam ACK_ADDR     = 6;
        localparam ACK_REG      = 7;
        localparam WAIT_RESTART = 8;
        localparam REPEATED_START=9;
        localparam ACK_DATA     = 10;
        localparam ACK_RDATA    =11;
        localparam STATE_STOP =12;
       
        
        reg [3:0] state;
        reg [7:0] captured_data;
        reg [2:0] bit_counter;
        wire sda_posedge = sda_clean & !sda_prev_clean;
        wire sda_negedge = !sda_clean & sda_prev_clean;
        wire scl_posedge = scl_clean & !scl_prev_clean;
        wire scl_negedge = !scl_clean & scl_prev_clean;
         
        
        
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                state <= IDLE;
                bit_counter <= 0;
                captured_data <= 0;
                address <= 0;
                reg_address <= 0;
                reg_data <= 0;
                address_ready <= 0;
                reg_address_ready <= 0;
                reg_data_ready <= 0;
                wait_counter <= 0;        // Initialize wait counter to 0
                sniff_success <= 0;
                stop_flag <= 1;  // Bus idle by default
               
            end else begin
                address_ready <= 0;
                reg_address_ready <= 0;
                reg_data_ready <= 0;
                 // Global repeated START detection
                    if (start_cond && !stop_flag && state != IDLE) begin    
                      bit_counter <=0;                
                        state <= RECV_ADDR;  // Repeated start → go capture new address
                    end
                    // Stop/start tracking for repeated START logic
                    if (stop_cond)
                        stop_flag <= 1;       // STOP happened → set flag
                    else if (start_cond)
                        stop_flag <= 0;       // START happened → clear flag
                        
                case (state)
                    IDLE: begin
                       //sniff_success <= 1;
                       // $display("In IDLE, SDA: %b, SCL: %b, state: %b, bit_counter: %d", i2c_sda, i2c_scl, state, bit_counter);
                        if (start_cond && stop_flag) begin
                           // $display("Transitioning from IDLE to RECV_ADDR (Start condition detected).");
                            state <= RECV_ADDR;
                            bit_counter <= 0;
                        end
                    end

                    RECV_ADDR: begin
                    
                 // $display("In RECV_ADDR, SDA: %b, SCL: %b, state: %b, bit_counter: %d, captured_data: %h", i2c_sda, i2c_scl, state, bit_counter, captured_data);
                        if (scl_posedge) begin
                            if (bit_counter == 0)
                                captured_data <= 8'b0;
                            captured_data[7 - bit_counter] <= sda_clean;
                            if (bit_counter == 7) begin
                                bit_counter <= 0;
                                address <= {captured_data[7:1], sda_clean};
                                address_ready <= 1;
                                  
                                 //$display("Transitioning from RECV_ADDR to ACK_ADDR (Address captured: %h)", address);
                                state <= ACK_ADDR;
                            end else begin
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end

                       ACK_ADDR: begin
                      
                         
                //$display("In ACK_ADDR, SDA: %b, SCL: %b, state: %b", i2c_sda, i2c_scl, state);
                         address_ready <= 0;    // default
             
                        if (scl_posedge) begin  // Detect SCL rising edge
                            if (address[0] == 0) begin
                                //$display("Transitioning from ACK_ADDR to RECV_REG (ACK received, address[0] == 0).");
                                state <= RECV_REG;
                            end else begin
                                //$display("Transitioning from ACK_ADDR to RECV_READ (ACK received, address[0] != 0).");
                                state <= RECV_READ;
                            end
                        end
                    end
            
           
                   RECV_REG: begin               
                       
                      
                        //$display("In RECV_REG, SDA: %b, SCL: %b, state: %b, bit_counter: %d, captured_data: %h", i2c_sda, i2c_scl, state, bit_counter, captured_data);
                        if (scl_posedge) begin
                            if (bit_counter == 0)
                                captured_data <= 8'b0;
                            captured_data[7 - bit_counter] <= sda_clean;
                            if (bit_counter == 7) begin
                                reg_address <= {captured_data[7:1], sda_clean};
                                reg_address_ready <= 1;  
                              //  sniff_success <= 1;  // NEW LINE
                              //  $display("Transitioning from RECV_REG to ACK_REG (Register address captured: %h).", reg_address);
                                bit_counter <= 0;
                                state <= ACK_REG;
                            end else begin
                                bit_counter <= bit_counter + 1;
                            end
                        end
                     
                        
                     
                    end
                   ACK_REG: begin
                   
               // $display("In ACK_REG, SDA: %b, SCL: %b, state: %b", i2c_sda, i2c_scl, state);
                  reg_address_ready <= 0;
            
                // Step 1: Check for ACK bit on 9th SCL rising edge
                if (scl_posedge) begin
                    if (sda_clean == 1'b0) begin
                        //$display("ACK received.");
                         state <= RECV_WRITE;
                    end
                  end
                end
                        

             /* WAIT_RESTART: begin           
                   // $display("[%0t] In WAIT_RESTART, SDA: %b, SCL: %b, wait_counter: %d", $time, sda_clean, scl_clean, wait_counter);    
                   if (sda_posedge && scl_clean) begin        // STOP
                        state <= STATE_STOP;
                    end else if (scl_posedge)begin
                        
                        $display("[%0t] New byte transmission. Transitioning to RECV_WRITE/READ.", $time);
                        state <= (address[0] == 0) ? RECV_WRITE : RECV_READ;
                   end 
               end
    
*/
            RECV_WRITE: begin    
                  
                //$display("In RECV_WRITE, SDA: %b, SCL: %b, state: %b, bit_counter: %d, captured_data: %h", i2c_sda, i2c_scl, state, bit_counter, captured_data);
                if (scl_clean && !scl_prev_clean) begin
                    if (bit_counter == 0)
                        captured_data <= 8'b0;
                        captured_data[7 - bit_counter] <= sda_clean;
                            if (bit_counter == 7) begin
                                reg_data <=  {captured_data[7:1], sda_clean};    
                                reg_data_ready <= 1;
                                bit_counter <= 0;
                                // $display("Transitioning from RECV_WRITE to ACK_DATA (Data captured: %h)", reg_data);
                                state <= ACK_DATA;
                            end else begin
                                bit_counter <= bit_counter + 1;
                                end
                    end
                end

            ACK_DATA: begin
                  
               // $display("In ACK_DATA, SDA: %b, SCL: %b, state: %b", i2c_sda, i2c_scl, state);
                reg_data_ready <= 0;  // default
                
                if (scl_clean && !scl_prev_clean) begin
                   // $display("Transitioning from ACK_DATA to IDLE (Data ready, returning to IDLE).");
                    state <= IDLE;
                end
            end

            RECV_READ: begin
                 
               // $display("In RECV_READ, SDA: %b, SCL: %b, state: %b, bit_counter: %d, captured_data: %h", i2c_sda, i2c_scl, state, bit_counter, captured_data);
                if (scl_clean && !scl_prev_clean) begin
                    if (bit_counter == 0)
                        captured_data <= 8'b0;
                    captured_data[7 - bit_counter] <= sda_clean;
                    if (bit_counter == 7) begin
                        reg_data <= {captured_data[7:1], sda_clean};
                        reg_data_ready<=1;
                         
                       // $display("Transitioning from RECV_READ to ACK_RDATA (Data captured: %h)", reg_data);
                        bit_counter <= 0;
                        state <= ACK_RDATA;
                    end else begin
                        bit_counter <= bit_counter + 1;
                    end
                end
            end

            ACK_RDATA: begin
             sniff_success <= 1;
               // $display("In ACK_RDATA, SDA: %b, SCL: %b, state: %b", i2c_sda, i2c_scl, state);
                reg_data_ready <= 0;  // default
                if (scl_clean && !scl_prev_clean) begin
                    if (stop_cond) begin
                      //  $display("Transitioning from ACK_RDATA to IDLE (Stop condition detected).");
                        state <= STATE_STOP;
                    end else begin
                    sniff_success <= 1;
                     //   $display("Continuing in RECV_READ.");
                        state <= RECV_READ;
                    end
                end
            end

        endcase
         if (stop_cond) begin
            //$display("[%0t] STOP condition detected. Returning to IDLE.", $time);
            state <= IDLE;
        end
                // LED trigger logic
                if (sniff_success) begin
                    led_counter <= 26'd50_000_000; // 0.5 sec at 100 MHz
                    debug_led <= 1;
                end else if (led_counter != 0) begin
                    led_counter <= led_counter - 1;
                    if (led_counter == 1)
                        debug_led <= 0;
                end

       
    end
end
endmodule
