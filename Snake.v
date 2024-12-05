module Snake(start, master_clk, B_direction, B_reset, VGA_R, VGA_G, VGA_B, VGA_hSync, VGA_vSync);
    // Snake game module with VGA output for display

    input master_clk; // 50MHz clock input
    input B_direction; // Button for changing snake direction
    input B_reset; // Button for resetting the game
    output reg [3:0] VGA_R, VGA_G, VGA_B; // Red, Green, Blue VGA signals
    output VGA_hSync, VGA_vSync; // Horizontal and Vertical sync signals

    // Internal signals
    wire [9:0] xCount; // x pixel count for VGA
    wire [9:0] yCount; // y pixel count for VGA
    reg [9:0] appleX; // X position of the apple
    reg [8:0] appleY; // Y position of the apple
    wire [9:0] rand_X; // Random X position for apple
    wire [8:0] rand_Y; // Random Y position for apple
    wire displayArea; // Indicates if the current pixel is in the active display area
    wire VGA_clk; // 25 MHz clock for VGA
    wire R; // Red signal for VGA
    wire G; // Green signal for VGA
    wire B; // Blue signal for VGA
    reg [4:0] direction; // Direction of the snake
    wire lethal, nonLethal; // Collision detection signals
    reg bad_collision, good_collision, game_over; // Game state flags
    reg apple_inX, apple_inY, apple, border, found; // Flags for apple and border detection
    integer appleCount, count1, count2, count3; // Counters for apple and snake
    reg [6:0] size; // Size of the snake
    input start; // Switch to start the game
    reg [9:0] snakeX[0:127]; // X positions of the snake body segments
    reg [8:0] snakeY[0:127]; // Y positions of the snake body segments
    reg [9:0] snakeHeadX; // X position of the snake head
    reg [9:0] snakeHeadY; // Y position of the snake head
    reg snakeHead; // Flag for snake head display
    reg snakeBody; // Flag for snake body display
    wire update; // Update signal for snake movement
    integer maxSize = 16; // Maximum size of the snake
    wire ButtonDebounced; // Debounced button signal for direction
    wire resetDebounced; // Debounced button signal for reset

    // Clock reduction from 50MHz to 25MHz for VGA
    clk_reduce reduce1(master_clk, VGA_clk);
    
    // VGA signal generation
    VGA_gen gen1(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);
    
    // Random grid generation for apple placement
    randomGrid rand1(VGA_clk, rand_X, rand_Y);
    
    // Update clock generation for snake movement
    updateClk UPDATE(master_clk, update);
    
    // Debounce the direction and reset buttons
    debounce debounce1(B_direction, master_clk, ButtonDebounced);
    debounce debounce2(B_reset, master_clk, resetDebounced);

    // Border detection logic
    always @(posedge VGA_clk) begin
        border <= (((xCount >= 0) && (xCount < 3) || (xCount >= 637) && (xCount < 640)) || ((yCount >= 0) && (yCount < 3) || (yCount >= 477) && (yCount < 480)));
    end
    
    // Apple position update logic
    always @(posedge VGA_clk) begin
        appleCount = appleCount + 1; // Increment apple count
        if (appleCount == 1) begin
            appleX <= 20; // Initial apple position
            appleY <= 20;
        end else begin    
            if (good_collision) begin // If snake eats the apple
                if ((rand_X < 10) || (rand_X > 630) || (rand_Y < 10) || (rand_Y > 470)) begin
                    appleX <= 40; // Set apple to a valid position
                    appleY <= 30;
                end else begin
                    appleX <= rand_X; // Random position for apple
                    appleY <= rand_Y;
                end
            end else if (~start) begin // If game is not started
                if ((rand_X < 10) || (rand_X > 630) || (rand_Y < 10) || (rand_Y > 470)) begin
                    appleX <= 340; // Set apple to a valid position
                    appleY <= 430;
                end else begin
                    appleX <= rand_X; // Random position for apple
                    appleY <= rand_Y;
                end
            end
        end
    end
    
    // Apple display area detection
    always @(posedge VGA_clk) begin
        apple_inX <= (xCount > appleX && xCount < (appleX + 10)); // Check if xCount is within apple's x range
        apple_inY <= (yCount > appleY && yCount < (appleY + 10)); // Check if yCount is within apple's y range
        apple = apple_inX && apple_inY; // Set apple flag if in both ranges
    end
    
    // Snake position update logic
    always @(posedge update) begin
        if (start) begin // If the game has started
            for (count1 = 127; count1 > 0; count1 = count1 - 1) begin
                if (count1 <= size - 1) begin // Update snake body positions
                    snakeX[count1] = snakeX[count1 - 1];
                    snakeY[count1] = snakeY[count1 - 1];
                end
            end
            case (direction) // Move snake head based on direction
                5'b00010: snakeY[0] <= (snakeY[0] - 10); // Up
                5'b00100: snakeX[0] <= (snakeX[0] - 10); // Left
                5'b01000: snakeY[0] <= (snakeY[0] + 10); // Down
                5'b10000: snakeX[0] <= (snakeX[0] + 10); // Right
            endcase    
        end else if (~start) begin // If game is not started
            for (count3 = 1; count3 < 128; count3 = count3 + 1) begin
                snakeX[count3] = 320; // Reset snake position
                snakeY[count3] = 240;
            end
        end
    end
    
    // Snake body display area detection
    always @(posedge VGA_clk) begin
        found = 0; // Reset found flag
        for (count2 = 1; count2 < size; count2 = count2 + 1) begin
            if (~found) begin                
                snakeBody = ((xCount > snakeX[count2] && xCount < snakeX[count2] + 10) && (yCount > snakeY[count2] && yCount < snakeY[count2] + 10)); // Check if pixel is within snake body
                found = snakeBody; // Set found flag if snake body is detected
            end
        end
    end
    
    // Snake head display area detection
    always @(posedge VGA_clk) begin    
        snakeHead = (xCount > snakeX[0] && xCount < (snakeX[0] + 10)) && (yCount > snakeY[0] && yCount < (snakeY[0] + 10)); // Check if pixel is within snake head
    end
    
    assign lethal = border || snakeBody; // Collision with border or body
    assign nonLethal = apple; // Collision with apple
    
    // Collision detection logic
    always @(posedge VGA_clk) begin
        if (nonLethal && snakeHead) begin // If snake eats the apple
            good_collision <= 1; // Set good collision flag
            size = size + 1; // Increase snake size
        end else if (~start) begin // If game is not started
            size = 1; // Reset size
        end else begin
            good_collision = 0; // Reset good collision flag
        end
    end
    
    always @(posedge VGA_clk) begin
        if (lethal && snakeHead) begin // If snake collides with border or body
            bad_collision <= 1; // Set bad collision flag
        end else begin
            bad_collision = 0; // Reset bad collision flag
        end
    end
    
    always @(posedge VGA_clk) begin
        if (bad_collision) begin // If bad collision occurs
            game_over <= 1; // Set game over flag
        end else if (~start) begin
            game_over = 0; // Reset game over flag
        end
    end
    
    // VGA color signals assignment
    assign R = (displayArea && (apple || game_over)); // Red for apple or game over
    assign G = (displayArea && ((snakeHead || snakeBody) && ~game_over)); // Green for snake head or body if not game over
    assign B = (displayArea && (border && ~game_over)); // Blue for border if not game over

    // Assigning color signals to VGA output
    always @(posedge VGA_clk) begin
        VGA_R = {4{R}}; // Set red color signal
        VGA_G = {4{G}}; // Set green color signal
        VGA_B = {4{B}}; // Set blue color signal
    end 

    // Direction change logic based on button press
    always @(posedge B_direction) begin
        case (direction)
            5'b00010: direction <= 5'b10000; // Up to Right
            5'b10000: direction <= 5'b01000; // Right to Down
            5'b01000: direction <= 5'b00100; // Down to Left
            5'b00100: direction <= 5'b00010; // Left to Up
            default: direction <= 5'b00010; // Default to Up
        endcase
    end

endmodule

/////////////////////////////////////////////////////////////////////////////////////////////////

module clk_reduce(master_clk, VGA_clk);
    // Module to reduce clock frequency from 50MHz to 25MHz for VGA

    input master_clk; // 50MHz clock input
    output reg VGA_clk; // 25MHz clock output
    reg q; // Internal register for toggling

    always @(posedge master_clk) begin
        q <= ~q; // Toggle q on each master clock edge
        VGA_clk <= q; // Assign toggled value to VGA clock
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module VGA_gen(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);
    // VGA signal generation module

    input VGA_clk; // 25MHz VGA clock
    output reg [9:0] xCount, yCount; // Pixel counters for x and y
    output reg displayArea; // Indicates if the current pixel is in the display area
    output VGA_hSync, VGA_vSync; // Horizontal and vertical sync signals

    reg p_hSync, p_vSync; // Internal registers for sync signals

    // VGA timing parameters
    integer porchHF = 640; // Start of horizontal front porch
    integer syncH = 656; // Start of horizontal sync
    integer porchHB = 752; // Start of horizontal back porch
    integer maxH = 800; // Total length of line

    integer porchVF = 480; // Start of vertical front porch 
    integer syncV = 490; // Start of vertical sync
    integer porchVB = 492; // Start of vertical back porch
    integer maxV = 525; // Total rows

    always @(posedge VGA_clk) begin
        if (xCount === maxH) begin
            xCount <= 0; // Reset xCount at the end of the line
        end else begin
            xCount <= xCount + 1; // Increment xCount
        end
    end
    
    always @(posedge VGA_clk) begin
        if (xCount === maxH) begin
            if (yCount === maxV) begin
                yCount <= 0; // Reset yCount at the end of the frame
            end else begin
                yCount <= yCount + 1; // Increment yCount
            end
        end
    end
    
    always @(posedge VGA_clk) begin
        displayArea <= ((xCount < porchHF) && (yCount < porchVF)); // Determine if in display area
    end

    always @(posedge VGA_clk) begin
        p_hSync <= ((xCount >= syncH) && (xCount < porchHB)); // Horizontal sync signal
        p_vSync <= ((yCount >= syncV) && (yCount < porchVB)); // Vertical sync signal
    end

    assign VGA_vSync = ~p_vSync; // Invert vertical sync signal
    assign VGA_hSync = ~p_hSync; // Invert horizontal sync signal
endmodule        

//////////////////////////////////////////////////////////////////////////////////////////////////////

module appleLocation(VGA_clk, xCount, yCount, start, apple);
    // Module to determine apple location for the snake game

    input VGA_clk, xCount, yCount, start; // Inputs for clock, x and y counts, and game start signal
    wire [9:0] appleX; // X position of the apple
    wire [8:0] appleY; // Y position of the apple
    reg apple_inX, apple_inY; // Flags for apple position detection
    output apple; wire [9:0] rand_X; // Random X position for apple
    wire [8:0] rand_Y; // Random Y position for apple
    randomGrid rand1(VGA_clk, rand_X, rand_Y); // Instance of random grid generator
    
    assign appleX = 0; // Initial X position of the apple
    assign appleY = 0; // Initial Y position of the apple
    
    always @(negedge VGA_clk) begin
        apple_inX <= (xCount > appleX && xCount < (appleX + 10)); // Check if xCount is within apple's x range
        apple_inY <= (yCount > appleY && yCount < (appleY + 10)); // Check if yCount is within apple's y range
    end
    
    assign apple = apple_inX && apple_inY; // Set apple flag if in both ranges
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module randomGrid(VGA_clk, rand_X, rand_Y);
    // Module to generate random positions for the apple

    input VGA_clk; // 25MHz VGA clock
    output reg [9:0] rand_X; // Random X position output
    output reg [8:0] rand_Y; // Random Y position output
    reg [5:0] pointX, pointY = 10; // Internal counters for random generation

    always @(posedge VGA_clk) begin
        pointX <= pointX + 3; // Increment pointX for random X generation
    end
    
    always @(posedge VGA_clk) begin
        pointY <= pointY + 1; // Increment pointY for random Y generation
    end
    
    always @(posedge VGA_clk) begin    
        if (pointX > 62) begin
            rand_X <= 620; // Limit random X position
        end else if (pointX < 2) begin
            rand_X <= 20; // Minimum random X position
        end else begin
            rand_X <= (pointX * 10); // Scale pointX to pixel position
        end
    end
    
    always @(posedge VGA_clk) begin    
        if (pointY > 46) begin // Limit random Y position
            rand_Y <= 460;
        end else if (pointY < 2) begin
            rand_Y <= 20; // Minimum random Y position
        end else begin
            rand_Y <= (pointY * 10); // Scale pointY to pixel position
        end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module updateClk(master_clk, update);
    // Module to generate an update signal for snake movement

    input master_clk; // 50MHz clock input
    output reg update; // Update signal output
    reg [21:0] count; // Counter for generating update signal

    always @(posedge master_clk) begin
        count <= count + 1; // Increment counter
        if (count == 1777777) begin // Generate update signal every ~1 second
            update <= ~update; // Toggle update signal
            count <= 0; // Reset counter
        end    
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////
module debounce(input pb_1, clk, output pb_out);
    // Debounce module for button inputs

    wire slow_clk; // Slow clock for debouncing
    wire Q1, Q2, Q2_bar, Q0; // Internal flip-flop outputs
    clock_div u1(clk, slow_clk); // Instance of clock divider
    my_dff d0(slow_clk, pb_1, Q0); // First flip-flop for debouncing

    my_dff d1(slow_clk, Q0, Q1); // Second flip-flop
    my_dff d2(slow_clk, Q1, Q2); // Third flip-flop
    assign Q2_bar = ~Q2; // Inverted output of the last flip-flop
    assign pb_out = Q1 & Q2_bar; // Output is high when Q1 is high and Q2 is low
endmodule

// Slow clock for debouncing 
module clock_div(input Clk_100M, output reg slow_clk);
    // Clock divider module to create a slower clock for debouncing

    reg [26:0] counter = 0; // Counter for clock division
    always @(posedge Clk_100M) begin
        counter <= (counter >= 249999) ? 0 : counter + 1; // Reset counter after reaching limit
        slow_clk <= (counter < 125000) ? 1'b0 : 1'b1; // Generate slow clock signal
    end
endmodule

// D-flip-flop for debouncing module 
module my_dff(input DFF_CLOCK, D, output reg Q);
    // D flip-flop module for debouncing

    always @(posedge DFF_CLOCK) begin
        Q <= D; // On the rising edge of the clock, assign D to Q
    end
endmodule