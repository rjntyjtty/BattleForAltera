module BattleForAltera(
		CLOCK_50,						//	On Board 50 MHz
		// inputs
        KEY,
		  LEDR,
		  SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input CLOCK_50; //	50 MHz
	input [3:0] KEY;
	input [17:0] SW;
	output [17:0] LEDR;

	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
    
	rateDivider (.clock(CLOCK_50), .clk(frame));
	ram160x8 groundRAM (.address(8'd80), .clock(CLOCK_50), .data(8'd100), .wren(write_enable), .q(ground_height_at_x));
	vga_adapter VGA(
			.resetn(1'b1),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	defparam VGA.BACKGROUND_IMAGE = "black.mif";
	
	reg [0:0] write_enable; // to initialize gound stuff
	reg [0:0] fired = 1'd0; // check for if shell is fired
	
	reg [7:0] x, y;
	reg [17:0] draw_counter;
	reg [5:0] state;
	reg [2:0] colour;
	wire frame;
	
	reg [7:0] tank1_x, tank1_y, tank2_x, tank2_y; // tank positions
	
	wire [7:0] ground_height_at_x; // ground height when pulling the x val from RAM
	
	////////
	reg [7:0] shell_x, shell_y, bl_1_x, bl_1_y, bl_2_x, bl_2_y;
	reg shell_x_direction, shell_y_direction = 1'd0; // shell direction stuff, Max to remove and put his stuff here
	////////
	reg [2:0] block_1_colour, block_2_colour; // remove later
	////////
	 
	localparam  RESET = 6'd0,
	
               INIT_TANK_1 = 6'd1,
					INIT_TANK_2 = 6'd20,
					
               INIT_BALL = 6'd2,
               INIT_BLOCK_1 = 6'd3,
					INIT_BLOCK_2 = 6'd4,
               WAIT = 6'd5,
					
					ERASE_TANK_1 = 6'd6,
               UPDATE_TANK_1 = 6'd7,
					DRAW_TANK_1 = 6'd8,
					
					ERASE_TANK_2 = 6'd17,
               UPDATE_TANK_2 = 6'd18,
					DRAW_TANK_2 = 6'd19,
					
               ERASE_SHELL = 6'd9,
					UPDATE_SHELL = 6'd10,
					DRAW_SHELL = 6'd11,
					UPDATE_BLOCK_1 = 6'd12,
					DRAW_BLOCK_1 = 6'd13,
					UPDATE_BLOCK_2 = 6'd14,
					DRAW_BLOCK_2 = 6'd15,
					DEAD = 6'd16;

	always@(posedge CLOCK_50)
   begin
		colour = 3'b000; // base colour
		x = 8'b00000000;
		y = 8'b00000000;
		if (~KEY[0]) state = RESET; // reset

		case (state)
		
		RESET: begin
			write_enable = 1'd1; // enable drawing here
			shell_y_direction = 1'd0;
			
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b000;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
			else begin
				draw_counter= 8'b00000000;
				state = INIT_TANK_1;
			end
		end
		
    	INIT_TANK_1: begin // update to draw tank here
			write_enable = 1'd0; // update later, rn it makes the hard coded ground

			if (draw_counter < 6'b10000) begin
				tank1_x = 8'd5;
				tank1_y = 8'd110;
				x = tank1_x + draw_counter[3:0];
				y = tank1_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;
				colour = 3'b111;
			end
			else begin
				draw_counter= 8'b00000000;
				state = INIT_TANK_2;
			end
		end
		
    	INIT_TANK_2: begin // update to draw tank here
			write_enable = 1'd0; // update later, rn it makes the hard coded ground

			if (draw_counter < 6'b10000) begin
				tank2_x = 8'd76;
				tank2_y = 8'd110;
				x = tank2_x + draw_counter[3:0];
				y = tank2_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;
				colour = 3'b001;
			end
			else begin
				draw_counter= 8'b00000000;
				state = INIT_BLOCK_1;
			end
		end

		INIT_BLOCK_1: begin
			bl_1_x = 8'd100;
			bl_1_y = 8'd90;
			block_1_colour = 3'b010;
			
			state = INIT_BLOCK_2;
		end
				 
		INIT_BLOCK_2: begin
			bl_2_x = 8'd85;
			bl_2_y = 8'd45;
			block_2_colour = 3'b010;
			
			state = WAIT;
		end

		WAIT: begin
			if (frame && ~fired) state = ERASE_TANK_1;
			else if (frame) state = ERASE_SHELL;
		end
				 
		ERASE_TANK_1: begin
			if (draw_counter < 6'b100000) begin
				x = tank1_x + draw_counter[3:0];
				y = tank1_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;
			end
			else begin
				draw_counter= 8'b00000000;
				state = ERASE_TANK_2;
			end
		end
		
		ERASE_TANK_2: begin
			if (draw_counter < 6'b100000) begin
				x = tank2_x + draw_counter[3:0];
				y = tank2_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;
			end
			else begin
				draw_counter= 8'b00000000;
				state = UPDATE_TANK_1;
			end
		end

		UPDATE_TANK_1: begin

			if (SW[0]) begin
				if (~KEY[1] && tank1_x < 8'd144) tank1_x = tank1_x + 1'b1;
				if (~KEY[2] && tank1_x > 8'd0) tank1_x = tank1_x - 1'b1;
				if (~KEY[3]) tank1_y = tank1_y - 1'b1;
				// if above ground, lower tank onto ground
				if (KEY[3] && (tank1_y < 8'd110 || tank1_y < ground_height_at_x) ) tank1_y = tank1_y + 1'b1;
				// if below, update tank position onto ground
				if (tank1_y > ground_height_at_x && tank1_x > 8'd80) tank1_y = (ground_height_at_x);
			end
			
			state = UPDATE_TANK_2;
		end
		
		UPDATE_TANK_2: begin
		
			if (~SW[0]) begin
				if (~KEY[1] && tank2_x < 8'd144) tank2_x = tank2_x + 1'b1;
				if (~KEY[2] && tank2_x > 8'd0) tank2_x = tank2_x - 1'b1;
				if (~KEY[3]) tank2_y = tank2_y - 1'b1;
				// if above ground, lower tank onto ground
				if (KEY[3] && (tank2_y < 8'd110 || tank2_y < ground_height_at_x) ) tank2_y = tank2_y + 1'b1;
				// if below, update tank position onto ground
				if (tank2_y > ground_height_at_x && tank2_x > 8'd80) tank2_y = (ground_height_at_x);
			end
			
			state = DRAW_TANK_1;
		end

		DRAW_TANK_1: begin
			if (draw_counter < 6'b100000) begin
				colour = 3'b111; // updates for the whole block
				x = tank1_x + draw_counter[3:0];
				y = tank1_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;		
			end
			else begin
				draw_counter= 8'b00000000;
				state = DRAW_TANK_2;
			end
		end
		
		DRAW_TANK_2: begin
			if (draw_counter < 6'b100000) begin
				colour = 3'b001; // updates for the whole block
				x = tank2_x + draw_counter[3:0];
				y = tank2_y + draw_counter[4];
				draw_counter = draw_counter + 1'b1;		
			end
			else begin
				draw_counter= 8'b00000000;
				state = ERASE_SHELL;
			end
		end

		ERASE_SHELL: begin
			colour = 3'b000;
			x = shell_x;
			y = shell_y;
			
			state = UPDATE_SHELL;
		end

		UPDATE_SHELL: begin // update this to just shoot the projectile
			if (SW[17]) begin
				fired = 1'd1;
		
				if (~shell_x_direction) shell_x = shell_x + 1'b1;
				else shell_x = shell_x - 1'b1;
				if (shell_y_direction) shell_y = shell_y + 1'b1;
				else shell_y = shell_y - 1'b1;
				
				if ((shell_x == 8'd0) || (shell_x == 8'd160)) shell_x_direction = ~shell_x_direction; // bounce around the board
				if ((shell_y >= 8'd120) || (shell_y == 8'd0)) shell_y_direction = ~shell_y_direction;
				
				if ( ((shell_y > tank1_y - 8'd2) && (shell_y < tank1_y + 8'd3) && (shell_x >= tank1_x) && (shell_x <= tank1_x + 8'd15)) ||
			((shell_y > tank2_y - 8'd2) && (shell_y < tank2_y + 8'd3) && (shell_x >= tank2_x) && (shell_x <= tank2_x + 8'd15))	) state = DEAD; // kill if touch tank
				else state = DRAW_SHELL;

			end
			else begin
				shell_y_direction = 1'd0; // set shell to go up
				
				if (SW[0]) begin
					shell_x_direction = 1'd0;
					shell_x = tank1_x + 2'd4; // update shell position to tank position
					shell_y = tank1_y - 1'd1;
				end
				else begin
					shell_x_direction = 1'd1;
					shell_x = tank2_x + 2'd4; // update shell position to tank position
					shell_y = tank2_y - 1'd1;
				end
				
				state = UPDATE_BLOCK_1;
			end
		end

		DRAW_SHELL: begin
			colour = 3'b111;
			x = shell_x;
			y = shell_y;
			
			state = UPDATE_BLOCK_1;
		end
				 
		UPDATE_BLOCK_1: begin
			if ((block_1_colour != 3'b000) && (shell_y > bl_1_y - 8'd1) && (shell_y < bl_1_y + 8'd2) && (shell_x >= bl_1_x) && (shell_x <= bl_1_x + 8'd7)) begin
				shell_y_direction = ~shell_y_direction;
				block_1_colour = 3'b000;
			end
			state = DRAW_BLOCK_1;
		end
				 
		DRAW_BLOCK_1: begin
			if (draw_counter < 5'b10000) begin
						x = bl_1_x + draw_counter[2:0];
						y = bl_1_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_1_colour;
			end
			else begin
						draw_counter= 8'b00000000;
						state = UPDATE_BLOCK_2;
			end
		end
				 
		UPDATE_BLOCK_2: begin
			if ((block_2_colour != 3'b000) && (shell_y > bl_2_y - 8'd1) && (shell_y < bl_2_y + 8'd2) && (shell_x >= bl_2_x) && (shell_x <= bl_2_x + 8'd7)) begin
						shell_y_direction = ~shell_y_direction;
						block_2_colour = 3'b000;
			end
			state = DRAW_BLOCK_2;
		end
				 
		DRAW_BLOCK_2: begin
					if (draw_counter < 5'b10000) begin
						x = bl_2_x + draw_counter[2:0];
						y = bl_2_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_2_colour;
						end
					else begin
						draw_counter= 8'b00000000;
						state = WAIT;
					end
		end

		DEAD: begin
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b100;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
		end

		endcase // end cases
		
	end // end always
endmodule

module rateDivider (input clock, output clk);
reg [19:0] frame_counter;
reg frame;
	always@(posedge clock)
    begin
        if (frame_counter == 20'b00000000000000000000) begin
		  frame_counter = 20'b11001011011100110100;
		  frame = 1'b1;
		  end
        else begin
			frame_counter = frame_counter - 1'b1;
			frame = 1'b0;
		  end
    end
	 assign clk = frame;
endmodule