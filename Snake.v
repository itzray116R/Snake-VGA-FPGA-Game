module Snake(start, master_clk, B_direction, B_reset, VGA_R, VGA_G, VGA_B, VGA_hSync, VGA_vSync);
	//insert a HEX for Loose Game Display
	input master_clk; // 50MHz
	input B_direction; // direction cylcling through direction right->down->left->up
	input B_reset; 
	output reg [3:0] VGA_R, VGA_G, VGA_B;  // Red, Green, Blue VGA signals
	output VGA_hSync, VGA_vSync; // Horizontal and Vertical sync signals
	wire [9:0] xCount; // x pixel
	wire [9:0] yCount; // y pixel
	reg [9:0] appleX;
	reg [8:0] appleY;
	wire [9:0] rand_X;
	wire [8:0] rand_Y;
	wire displayArea; // is it in the active display area?
	wire VGA_clk; // 25 MHz
	wire R;
	wire G;
	wire B;
	reg [4:0] direction;
	wire lethal, nonLethal;
	reg bad_collision, good_collision, game_over;
	reg apple_inX, apple_inY, apple, border, found; // Added border
	integer appleCount, count1, count2, count3;
	reg [6:0] size;
	input start; // switch to start game
	reg [9:0] snakeX[0:127];
	reg [8:0] snakeY[0:127];
	reg [9:0] snakeHeadX;
	reg [9:0] snakeHeadY;
	reg snakeHead;
	reg snakeBody;
	wire update;
	integer maxSize = 16;
	wire ButtonDebounced;
	wire resetDebounced;
	
	// Clock reduction from 50MHz to 25MHz
	clk_reduce reduce1(master_clk, VGA_clk);
	
	// VGA signal generation
	VGA_gen gen1(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);
	
	// Random grid generation
	randomGrid rand1(VGA_clk, rand_X, rand_Y);
	
	// Update clock generation
	updateClk UPDATE(master_clk, update);
	
	
	debounce debounce1(B_direction, master_clk, ButtonDebounced);
	debounce debounce2(B_reset, master_clk, resetDebounced);

	
	// Border function
	always @(posedge VGA_clk) begin
		border <= (((xCount >= 0) && (xCount < 11) || (xCount >= 630) && (xCount < 641)) || ((yCount >= 0) && (yCount < 11) || (yCount >= 470) && (yCount < 481)));
	end
	
	// Apple position update
	always @(posedge VGA_clk) begin
		appleCount = appleCount + 1;
		if (appleCount == 1) begin
			appleX <= 20;
			appleY <= 20;
		end else begin    
			if (good_collision) begin
				if ((rand_X < 10) || (rand_X > 630) || (rand_Y < 10) || (rand_Y > 470)) begin
					appleX <= 40;
					appleY <= 30;
				end else begin
					appleX <= rand_X;
					appleY <= rand_Y;
				end
			end else if (~start) begin
				if ((rand_X < 10) || (rand_X > 630) || (rand_Y < 10) || (rand_Y > 470)) begin
					appleX <= 340;
					appleY <= 430;
				end else begin
					appleX <= rand_X;
					appleY <= rand_Y;
				end
			end
		end
	end
	
	// Apple display area
	always @(posedge VGA_clk) begin
		apple_inX <= (xCount > appleX && xCount < (appleX + 10));
		apple_inY <= (yCount > appleY && yCount < (appleY + 10));
		apple = apple_inX && apple_inY;
	end
	
	// Snake position update
	always @(posedge update) begin
		if (start) begin
			for (count1 = 127; count1 > 0; count1 = count1 - 1) begin
				if (count1 <= size - 1) begin
					snakeX[count1] = snakeX[count1 - 1];
					snakeY[count1] = snakeY[count1 - 1];
				end
			end
			case (direction)
				5'b00010: snakeY[0] <= (snakeY[0] - 10);
				5'b00100: snakeX[0] <= (snakeX[0] - 10);
				5'b01000: snakeY[0] <= (snakeY[0] + 10);
				5'b10000: snakeX[0] <= (snakeX[0] + 10);
			endcase    
		end else if (~start) begin
			for (count3 = 1; count3 < 128; count3 = count3 + 1) begin
				snakeX[count3] = 700;
				snakeY[count3] = 500;
			end
		end
	end
	
	// Snake body display area
	always @(posedge VGA_clk) begin
		found = 0;
		for (count2 = 1; count2 < size; count2 = count2 + 1) begin
			if (~found) begin                
				snakeBody = ((xCount > snakeX[count2] && xCount < snakeX[count2] + 10) && (yCount > snakeY[count2] && yCount < snakeY[count2] + 10));
				found = snakeBody;
			end
		end
	end
	
	// Snake head display area
	always @(posedge VGA_clk) begin    
		snakeHead = (xCount > snakeX[0] && xCount < (snakeX[0] + 10)) && (yCount > snakeY[0] && yCount < (snakeY[0] + 10));
	end
	
	assign lethal = border || snakeBody;
	assign nonLethal = apple;
	
	// Collision detection
	always @(posedge VGA_clk) begin
		if (nonLethal && snakeHead) begin
			good_collision <= 1;
			size = size + 1;
		end else if (~start) begin
			size = 1;
		end else begin
			good_collision = 0;
		end
	end
	
	always @(posedge VGA_clk) begin
		if (lethal && snakeHead) begin
			bad_collision <= 1;
		end else begin
			bad_collision = 0;
		end
	end
	
	always @(posedge VGA_clk) begin
		if (bad_collision) begin
			game_over <= 1;
		end else if (~start) begin
			game_over = 0;
		end
	end
	
	// VGA color signals
	assign R = (displayArea && (apple || game_over));
	assign G = (displayArea && ((snakeHead || snakeBody) && ~game_over));
	assign B = (displayArea && (border && ~game_over)); // Added border
	
	always @(posedge VGA_clk) begin
		VGA_R = {4{R}};
		VGA_G = {4{G}};
		VGA_B = {4{B}};
	end 


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

	input master_clk; // 50MHz clock
	output reg VGA_clk; // 25MHz clock
	reg q;

	always @(posedge master_clk) begin
		q <= ~q; 
		VGA_clk <= q;
	end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module VGA_gen(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);

	input VGA_clk;
	output reg [9:0] xCount, yCount; 
	output reg displayArea;  
	output VGA_hSync, VGA_vSync;

	reg p_hSync, p_vSync; 
	
	integer porchHF = 640; // start of horizontal front porch
	integer syncH = 655; // start of horizontal sync
	integer porchHB = 747; // start of horizontal back porch
	integer maxH = 793; // total length of line

	integer porchVF = 480; // start of vertical front porch 
	integer syncV = 490; // start of vertical sync
	integer porchVB = 492; // start of vertical back porch
	integer maxV = 525; // total rows

	always @(posedge VGA_clk) begin
		if (xCount === maxH) begin
			xCount <= 0;
		end else begin
			xCount <= xCount + 1;
		end
	end
	
	always @(posedge VGA_clk) begin
		if (xCount === maxH) begin
			if (yCount === maxV) begin
				yCount <= 0;
			end else begin
				yCount <= yCount + 1;
			end
		end
	end
	
	always @(posedge VGA_clk) begin
		displayArea <= ((xCount < porchHF) && (yCount < porchVF)); 
	end

	always @(posedge VGA_clk) begin
		p_hSync <= ((xCount >= syncH) && (xCount < porchHB)); 
		p_vSync <= ((yCount >= syncV) && (yCount < porchVB)); 
	end

	assign VGA_vSync = ~p_vSync; 
	assign VGA_hSync = ~p_hSync;
endmodule        

//////////////////////////////////////////////////////////////////////////////////////////////////////

module appleLocation(VGA_clk, xCount, yCount, start, apple);
	input VGA_clk, xCount, yCount, start;
	wire [9:0] appleX;
	wire [8:0] appleY;
	reg apple_inX, apple_inY;
	output apple;
	wire [9:0] rand_X;
	wire [8:9] rand_Y;
	randomGrid rand1(VGA_clk, rand_X, rand_Y);
	
	assign appleX = 0;
	assign appleY = 0;
	
	always @(negedge VGA_clk) begin
		apple_inX <= (xCount > appleX && xCount < (appleX + 10));
		apple_inY <= (yCount > appleY && yCount < (appleY + 10));
	end
	
	assign apple = apple_inX && apple_inY;
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module randomGrid(VGA_clk, rand_X, rand_Y);
	input VGA_clk;
	output reg [9:0] rand_X;
	output reg [8:0] rand_Y;
	reg [5:0] pointX, pointY = 10;

	always @(posedge VGA_clk) begin
		pointX <= pointX + 3;    
	end
	
	always @(posedge VGA_clk) begin
		pointY <= pointY + 1;
	end
	
	always @(posedge VGA_clk) begin    
		if (pointX > 62) begin
			rand_X <= 620;
		end else if (pointX < 2) begin
			rand_X <= 20;
		end else begin
			rand_X <= (pointX * 10);
		end
	end
	
	always @(posedge VGA_clk) begin    
		if (pointY > 46) begin // Changed to 469
			rand_Y <= 460;
		end else if (pointY < 2) begin
			rand_Y <= 20;
		end else begin
			rand_Y <= (pointY * 10);
		end
	end
endmodule


//////////////////////////////////////////////////////////////////////////////////////////////////////

module updateClk(master_clk, update);
	input master_clk;
	output reg update;
	reg [21:0] count;    

	always @(posedge master_clk) begin
		count <= count + 1;
		if (count == 1777777) begin
			update <= ~update;
			count <= 0;
		end    
	end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////
module debounce(input pb_1,clk,output pb_out);
wire slow_clk;
wire Q1,Q2,Q2_bar,Q0;
clock_div u1(clk,slow_clk);
my_dff d0(slow_clk, pb_1,Q0 );

my_dff d1(slow_clk, Q0,Q1 );
my_dff d2(slow_clk, Q1,Q2 );
assign Q2_bar = ~Q2;
assign pb_out = Q1 & Q2_bar;
endmodule
// Slow clock for debouncing 
module clock_div(input Clk_100M, output reg slow_clk

    );
    reg [26:0]counter=0;
    always @(posedge Clk_100M)
    begin
        counter <= (counter>=249999)?0:counter+1;
        slow_clk <= (counter < 125000)?1'b0:1'b1;
    end
endmodule
// D-flip-flop for debouncing module 
module my_dff(input DFF_CLOCK, D, output reg Q);

    always @ (posedge DFF_CLOCK) begin
        Q <= D;
    end

endmodule