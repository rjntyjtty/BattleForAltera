/*
  ____        _   _   _        ______                    _ _                 
 |  _ \      | | | | | |      |  ____|             /\   | | |                
 | |_) | __ _| |_| |_| | ___  | |__ ___  _ __     /  \  | | |_ ___ _ __ __ _ 
 |  _ < / _` | __| __| |/ _ \ |  __/ _ \| '__|   / /\ \ | | __/ _ \ '__/ _` |
 | |_) | (_| | |_| |_| |  __/ | | | (_) | |     / ____ \| | ||  __/ | | (_| |
 |____/ \__,_|\__|\__|_|\___| |_|  \___/|_|    /_/    \_\_|\__\___|_|  \__,_|


     ███████ ]▄▄▄▄▄▄▄▄▃									 		  ▃▄▄▄▄▄▄▄▄[ ███████ 
▂▄▅█████████▅▄▃▂													       ▂▃▄▅█████████▅▄▂
I███████████████████].											   .[███████████████████I					
 ◥⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙◤												     ◤⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙▲⊙◥ 
____________________________________________________________________________________
████████████████████████████████████████████████████████████████████████████████████

////////////////////////////////////////////
CSCB58 Final Project
Winter 2019
////////////////////////////////////////////
Authors:

Sean Applebaum
David Cui
Max Sun
Carrie Zhong
////////////////////////////////////////////

*/


module BattleForAltera(
		CLOCK_50,						//	On Board 50 MHz
		// Inputs
      KEY,								// Tank controls
		SW,								// Tank controls
		// Outputs
		HEX0,
		HEX1,
		HEX2,
		HEX4,
		HEX6,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,					//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   							//	VGA Blue[9:0]
	);

	input		CLOCK_50; 			//	50 MHz
	input		[3:0] KEY;
	input		[17:0] SW;

	output	[6:0] HEX0;
	output	[6:0] HEX1;
	output	[6:0] HEX2;
	output	[6:0] HEX4;
	output	[6:0] HEX6;
	output	VGA_CLK;   			//	VGA Clock
	output	VGA_HS;				//	VGA H_SYNC
	output	VGA_VS;				//	VGA V_SYNC
	output	VGA_BLANK_N;		//	VGA BLANK
	output	VGA_SYNC_N;			//	VGA SYNC
	output	[9:0]	VGA_R;   	//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 	//	VGA Green[9:0]
	output	[9:0]	VGA_B;   	//	VGA Blue[9:0]
   
	/// RAM ///
	reg [7:0] x_coordinate, y_coordinate; // Input coordinates for RAM
	reg write_enable; // To read/write from RAM
	wire [7:0] ground_height_at_x; // ground height when pulling the x val from RAM
	ram160x8 leftgroundRAM (.address(x_coordinate), .clock(CLOCK_50), .data(y_coordinate), .wren(write_enable), .q(ground_height_at_x));
	
	/// Dividers ///
	rateDivider mainDivider (.clock(CLOCK_50), .clk(frame)); // Main divider
	slowRateDivider firingDivider (.clock(CLOCK_50), .clk(slow_frame)); // Divider for when firing shell
	
	/// Hex Displays ///
	hex_display hd_H1(.IN(p1_H), .OUT(HEX6)); // Output Player 1's Health to HEX6
	hex_display hd_H2(.IN(p2_H), .OUT(HEX4)); // Output Player 2's Health to HEX4
	hex_display hd_ones(.IN(ang_HEX[3:0]), .OUT(HEX0));	//
	hex_display hd_tens(.IN(ang_HEX[7:4]), .OUT(HEX1));	// Output angle of current Player's shot
	hex_display hd_huns(.IN(ang_HEX[11:8]), .OUT(HEX2));	//
	
	/// VGA ///
	reg [7:0] x, y; // Positions to be plotted at
	reg [2:0] colour; // Colour to draw (RGB)
	
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
	
	/// Tanks ///
	reg [7:0] tank1_x, tank1_y, tank2_x, tank2_y; // tank positions
	reg [1:0] tank_1_barrel = 2'b00; // Barrel position for Tank 1
	reg [1:0] tank_2_barrel = 2'b00; // Barrel position for Tank 1
	reg [1:0] p1_H, p2_H = 2'd3; // Tanks health
	reg [4:0] fuel = 5'd30; // Current fuel value
	reg pTurn = 1'b0; // Current player's turn (0 = Player 1, 1 = Player 2)
	
	/// Misc ///
	reg [17:0] draw_counter; // Counter used for drawing sequentially
	reg [5:0] state; // Current game state
	reg [11:0] ang_HEX; // Angle of current player converted to HEX
	reg firing = 1'd0; // Check for if shell is fired
	wire frame, slow_frame; // FPS
	
	/// Projectile Motion ///
	reg [5:0] angle; // Current Player's selected angle
	reg spec; // Increment via y instead of x (for high angles)
	reg signed [7:0] shell_x, shell_y; // Firing position of tank
	reg signed [10:0] proj_x, proj_y; // Positions of shell
	reg signed [0:10] para [31:0]; // Pre-drawn parabola based on angle
	reg signed [1:0] dir; // Direction of shell firing
	reg signed [6:0] i; // Index/Incrementer
	
	/// Absolute Chaos, better known as a lot of hard code ///
	wire signed [0:10] a0 [31:0], a5 [31:0], a10 [31:0], a15 [31:0], a20 [31:0], a25 [31:0], a30 [31:0], a35 [31:0], a40 [31:0], a45 [31:0], a50 [31:0], a55 [31:0], a60 [31:0], a65 [31:0], a70 [31:0], a75 [31:0];
	wire signed [0:7] a80 [13:0], a85 [13:0], a90 [13:0], v_c [13:0];
	
	// The mentioned hard code, all to avoid FPN ///
	assign a0[0] = 1;
	assign a0[1] = 1;
	assign a0[2] = 1;
	assign a0[3] = 2;
	assign a0[4] = 2;
	assign a0[5] = 3;
	assign a0[6] = 4;
	assign a0[7] = 5;
	assign a0[8] = 7;
	assign a0[9] = 8;    
	assign a0[10] = 10;  
	assign a0[11] = 12;
	assign a0[12] = 13;
	assign a0[13] = 16;
	assign a0[14] = 18;
	assign a0[15] = 20;
	assign a0[16] = 23;
	assign a0[17] = 25;
	assign a0[18] = 28;
	assign a0[19] = 31;
	assign a0[20] = 34;
	assign a0[21] = 38;
	assign a0[22] = 41;
	assign a0[23] = 45;
	assign a0[24] = 48;
	assign a0[25] = 52;
	assign a0[26] = 56;
	assign a0[27] = 61;
	assign a0[28] = 65;
	assign a0[29] = 69;
	assign a0[30] = 74;
	assign a0[31] = 79;
	assign a5[0] = 0;
	assign a5[1] = 0;
	assign a5[2] = 0;
	assign a5[3] = 0;
	assign a5[4] = 0;
	assign a5[5] = 1;
	assign a5[6] = 1;
	assign a5[7] = 2;
	assign a5[8] = 3;
	assign a5[9] = 4;
	assign a5[10] = 5;
	assign a5[11] = 6;
	assign a5[12] = 8;
	assign a5[13] = 9;
	assign a5[14] = 11;
	assign a5[15] = 13;
	assign a5[16] = 15;
	assign a5[17] = 18;
	assign a5[18] = 20;
	assign a5[19] = 23;
	assign a5[20] = 25;
	assign a5[21] = 28;
	assign a5[22] = 31;
	assign a5[23] = 34;
	assign a5[24] = 38;
	assign a5[25] = 41;
	assign a5[26] = 45;
	assign a5[27] = 49;
	assign a5[28] = 53;
	assign a5[29] = 57;
	assign a5[30] = 61;
	assign a5[31] = 66;
	assign a10[0] = 0;
	assign a10[1] = -1;
	assign a10[2] = -1;
	assign a10[3] = -2;
	assign a10[4] = -2;
	assign a10[5] = -2;
	assign a10[6] = -2;
	assign a10[7] = -2;
	assign a10[8] = -1;
	assign a10[9] = 0;
	assign a10[10] = 0;
	assign a10[11] = 1;
	assign a10[12] = 2;
	assign a10[13] = 4;
	assign a10[14] = 5;
	assign a10[15] = 7;
	assign a10[16] = 8;
	assign a10[17] = 10;
	assign a10[18] = 12;
	assign a10[19] = 14;
	assign a10[20] = 17;
	assign a10[21] = 19;
	assign a10[22] = 22;
	assign a10[23] = 25;
	assign a10[24] = 28;
	assign a10[25] = 31;
	assign a10[26] = 34;
	assign a10[27] = 38;
	assign a10[28] = 41;
	assign a10[29] = 45;
	assign a10[30] = 49;
	assign a10[31] = 53;
	assign a15[0] = -1;
	assign a15[1] = -2;
	assign a15[2] = -3;
	assign a15[3] = -4;
	assign a15[4] = -4;
	assign a15[5] = -5;
	assign a15[6] = -5;
	assign a15[7] = -5;
	assign a15[8] = -5;
	assign a15[9] = -5;
	assign a15[10] = -4;
	assign a15[11] = -4;
	assign a15[12] = -3;
	assign a15[13] = -2;
	assign a15[14] = -1;
	assign a15[15] = 0;
	assign a15[16] = 1;
	assign a15[17] = 3;
	assign a15[18] = 5;
	assign a15[19] = 7;
	assign a15[20] = 9;
	assign a15[21] = 11;
	assign a15[22] = 13;
	assign a15[23] = 16;
	assign a15[24] = 18;
	assign a15[25] = 21;
	assign a15[26] = 24;
	assign a15[27] = 27;
	assign a15[28] = 31;
	assign a15[29] = 34;
	assign a15[30] = 38;
	assign a15[31] = 42;
	assign a20[0] = -1;
	assign a20[1] = -3;
	assign a20[2] = -4;
	assign a20[3] = -5;
	assign a20[4] = -6;
	assign a20[5] = -7;
	assign a20[6] = -8;
	assign a20[7] = -9;
	assign a20[8] = -9;
	assign a20[9] = -9;
	assign a20[10] = -9;
	assign a20[11] = -9;
	assign a20[12] = -9;
	assign a20[13] = -8;
	assign a20[14] = -7;
	assign a20[15] = -6;
	assign a20[16] = -5;
	assign a20[17] = -4;
	assign a20[18] = -3;
	assign a20[19] = -1;
	assign a20[20] = 1;
	assign a20[21] = 2;
	assign a20[22] = 5;
	assign a20[23] = 7;
	assign a20[24] = 9;
	assign a20[25] = 12;
	assign a20[26] = 15;
	assign a20[27] = 18;
	assign a20[28] = 21;
	assign a20[29] = 24;
	assign a20[30] = 27;
	assign a20[31] = 31;
	assign a25[0] = -2;
	assign a25[1] = -4;
	assign a25[2] = -6;
	assign a25[3] = -7;
	assign a25[4] = -9;
	assign a25[5] = -10;
	assign a25[6] = -11;
	assign a25[7] = -12;
	assign a25[8] = -13;
	assign a25[9] = -13;
	assign a25[10] = -14;
	assign a25[11] = -14;
	assign a25[12] = -14;
	assign a25[13] = -14;
	assign a25[14] = -14;
	assign a25[15] = -13;
	assign a25[16] = -12;
	assign a25[17] = -11;
	assign a25[18] = -10;
	assign a25[19] = -9;
	assign a25[20] = -7;
	assign a25[21] = -6;
	assign a25[22] = -4;
	assign a25[23] = -2;
	assign a25[24] = 0;
	assign a25[25] = 3;
	assign a25[26] = 5;
	assign a25[27] = 8;
	assign a25[28] = 11;
	assign a25[29] = 14;
	assign a25[30] = 18;
	assign a25[31] = 21;
	assign a30[0] = -2;
	assign a30[1] = -5;
	assign a30[2] = -7;
	assign a30[3] = -9;
	assign a30[4] = -11;
	assign a30[5] = -13;
	assign a30[6] = -15;
	assign a30[7] = -16;
	assign a30[8] = -17;
	assign a30[9] = -18;
	assign a30[10] = -19;
	assign a30[11] = -19;
	assign a30[12] = -20;
	assign a30[13] = -20;
	assign a30[14] = -20;
	assign a30[15] = -20;
	assign a30[16] = -19;
	assign a30[17] = -18;
	assign a30[18] = -17;
	assign a30[19] = -16;
	assign a30[20] = -15;
	assign a30[21] = -14;
	assign a30[22] = -12;
	assign a30[23] = -10;
	assign a30[24] = -8;
	assign a30[25] = -6;
	assign a30[26] = -3;
	assign a30[27] = 0;
	assign a30[28] = 3;
	assign a30[29] = 6;
	assign a30[30] = 9;
	assign a30[31] = 13;
	assign a35[0] = -3;
	assign a35[1] = -6;
	assign a35[2] = -9;
	assign a35[3] = -12;
	assign a35[4] = -14;
	assign a35[5] = -16;
	assign a35[6] = -18;
	assign a35[7] = -20;
	assign a35[8] = -22;
	assign a35[9] = -23;
	assign a35[10] = -24;
	assign a35[11] = -25;
	assign a35[12] = -26;
	assign a35[13] = -26;
	assign a35[14] = -26;
	assign a35[15] = -26;
	assign a35[16] = -26;
	assign a35[17] = -26;
	assign a35[18] = -25;
	assign a35[19] = -24;
	assign a35[20] = -23;
	assign a35[21] = -21;
	assign a35[22] = -20;
	assign a35[23] = -18;
	assign a35[24] = -16;
	assign a35[25] = -13;
	assign a35[26] = -11;
	assign a35[27] = -8;
	assign a35[28] = -5;
	assign a35[29] = -2;
	assign a35[30] = 2;
	assign a35[31] = 5;
	assign a40[0] = -4;
	assign a40[1] = -7;
	assign a40[2] = -11;
	assign a40[3] = -14;
	assign a40[4] = -17;
	assign a40[5] = -20;
	assign a40[6] = -22;
	assign a40[7] = -25;
	assign a40[8] = -27;
	assign a40[9] = -28;
	assign a40[10] = -30;
	assign a40[11] = -31;
	assign a40[12] = -32;
	assign a40[13] = -33;
	assign a40[14] = -33;
	assign a40[15] = -33;
	assign a40[16] = -33;
	assign a40[17] = -33;
	assign a40[18] = -32;
	assign a40[19] = -31;
	assign a40[20] = -30;
	assign a40[21] = -29;
	assign a40[22] = -27;
	assign a40[23] = -25;
	assign a40[24] = -23;
	assign a40[25] = -20;
	assign a40[26] = -18;
	assign a40[27] = -15;
	assign a40[28] = -11;
	assign a40[29] = -8;
	assign a40[30] = -4;
	assign a40[31] = 0;
	assign a45[0] = -4;
	assign a45[1] = -9;
	assign a45[2] = -13;
	assign a45[3] = -17;
	assign a45[4] = -21;
	assign a45[5] = -24;
	assign a45[6] = -27;
	/// Have a nice day ///
	assign a45[7] = -30;
	assign a45[8] = -32;
	assign a45[9] = -34;
	assign a45[10] = -36;
	assign a45[11] = -37;
	assign a45[12] = -39;
	assign a45[13] = -39;
	assign a45[14] = -40;
	assign a45[15] = -40;
	assign a45[16] = -40;
	assign a45[17] = -40;
	assign a45[18] = -39;
	assign a45[19] = -38;
	assign a45[20] = -37;
	assign a45[21] = -35;
	assign a45[22] = -33;
	assign a45[23] = -31;
	assign a45[24] = -29;
	assign a45[25] = -26;
	assign a45[26] = -23;
	assign a45[27] = -19;
	assign a45[28] = -16;
	assign a45[29] = -12;
	assign a45[30] = -7;
	assign a45[31] = -3;
	assign a50[0] = -5;
	assign a50[1] = -11;
	assign a50[2] = -16;
	assign a50[3] = -20;
	assign a50[4] = -25;
	assign a50[5] = -29;
	assign a50[6] = -32;
	assign a50[7] = -35;
	assign a50[8] = -38;
	assign a50[9] = -41;
	assign a50[10] = -43;
	assign a50[11] = -44;
	assign a50[12] = -46;
	assign a50[13] = -47;
	assign a50[14] = -47;
	assign a50[15] = -47;
	assign a50[16] = -47;
	assign a50[17] = -47;
	assign a50[18] = -46;
	assign a50[19] = -45;
	assign a50[20] = -43;
	assign a50[21] = -41;
	assign a50[22] = -39;
	assign a50[23] = -36;
	assign a50[24] = -33;
	assign a50[25] = -29;
	assign a50[26] = -25;
	assign a50[27] = -21;
	assign a50[28] = -16;
	assign a50[29] = -11;
	assign a50[30] = -6;
	assign a50[31] = 0;
	assign a55[0] = -6;
	assign a55[1] = -13;
	assign a55[2] = -19;
	assign a55[3] = -24;
	assign a55[4] = -29;
	assign a55[5] = -34;
	assign a55[6] = -38;
	assign a55[7] = -42;
	assign a55[8] = -45;
	assign a55[9] = -48;
	assign a55[10] = -50;
	assign a55[11] = -52;
	assign a55[12] = -53;
	assign a55[13] = -54;
	assign a55[14] = -54;
	assign a55[15] = -54;
	assign a55[16] = -54;
	assign a55[17] = -53;
	assign a55[18] = -51;
	assign a55[19] = -49;
	assign a55[20] = -47;
	assign a55[21] = -44;
	assign a55[22] = -41;
	assign a55[23] = -37;
	assign a55[24] = -33;
	assign a55[25] = -28;
	assign a55[26] = -23;
	assign a55[27] = -17;
	assign a55[28] = -11;
	assign a55[29] = -4;
	assign a55[30] = 3;
	assign a55[31] = 10;
	assign a60[0] = -8;
	assign a60[1] = -16;
	assign a60[2] = -23;
	assign a60[3] = -29;
	assign a60[4] = -35;
	assign a60[5] = -40;
	assign a60[6] = -45;
	assign a60[7] = -49;
	assign a60[8] = -53;
	assign a60[9] = -55;
	assign a60[10] = -58;
	assign a60[11] = -59;
	assign a60[12] = -60;
	assign a60[13] = -61;
	assign a60[14] = -60;
	assign a60[15] = -60;
	assign a60[16] = -58;
	assign a60[17] = -56;
	assign a60[18] = -53;
	assign a60[19] = -50;
	assign a60[20] = -46;
	assign a60[21] = -42;
	assign a60[22] = -37;
	assign a60[23] = -31;
	assign a60[24] = -25;
	assign a60[25] = -18;
	assign a60[26] = -10;
	assign a60[27] = -2;
	assign a60[28] = 7;
	assign a60[29] = 16;
	assign a60[30] = 26;
	assign a60[31] = 37;
	assign a65[0] = -10;
	assign a65[1] = -19;
	assign a65[2] = -28;
	assign a65[3] = -36;
	assign a65[4] = -42;
	assign a65[5] = -48;
	assign a65[6] = -54;
	assign a65[7] = -58;
	assign a65[8] = -61;
	assign a65[9] = -64;
	assign a65[10] = -66;
	assign a65[11] = -66;
	assign a65[12] = -66;
	assign a65[13] = -66;
	assign a65[14] = -64;
	assign a65[15] = -61;
	assign a65[16] = -58;
	assign a65[17] = -54;
	assign a65[18] = -48;
	assign a65[19] = -42;
	assign a65[20] = -36;
	assign a65[21] = -28;
	assign a65[22] = -19;
	assign a65[23] = -10;
	assign a65[24] = 0;
	assign a65[25] = 11;
	assign a65[26] = 23;
	assign a65[27] = 36;
	assign a65[28] = 50;
	assign a65[29] = 65;
	assign a65[30] = 80;
	assign a65[31] = 96;
	assign a70[0] = -13;
	assign a70[1] = -24;
	assign a70[2] = -35;
	assign a70[3] = -44;
	assign a70[4] = -52;
	assign a70[5] = -58;
	assign a70[6] = -64;
	assign a70[7] = -68;
	assign a70[8] = -70;
	assign a70[9] = -71;
	assign a70[10] = -71;
	assign a70[11] = -70;
	assign a70[12] = -67;
	assign a70[13] = -64;
	assign a70[14] = -58;
	assign a70[15] = -52;
	assign a70[16] = -44;
	assign a70[17] = -35;
	assign a70[18] = -24;
	assign a70[19] = -12;
	assign a70[20] = 1;
	assign a70[21] = 15;
	assign a70[22] = 31;
	assign a70[23] = 48;
	assign a70[24] = 66;
	assign a70[25] = 86;
	assign a70[26] = 107;
	assign a70[27] = 129;
	assign a70[28] = 153;
	assign a70[29] = 177;
	assign a70[30] = 204;
	assign a70[31] = 231;
	assign a75[0] = -17;
	assign a75[1] = -32;
	assign a75[2] = -45;
	assign a75[3] = -56;
	assign a75[4] = -64;
	assign a75[5] = -70;
	assign a75[6] = -74;
	assign a75[7] = -76;
	assign a75[8] = -75;
	assign a75[9] = -72;
	assign a75[10] = -66;
	assign a75[11] = -59;
	assign a75[12] = -49;
	assign a75[13] = -37;
	assign a75[14] = -22;
	assign a75[15] = -5;
	assign a75[16] = 14;
	assign a75[17] = 35;
	assign a75[18] = 59;
	assign a75[19] = 84;
	assign a75[20] = 113;
	assign a75[21] = 143;
	assign a75[22] = 176;
	assign a75[23] = 211;
	assign a75[24] = 248;
	assign a75[25] = 288;
	assign a75[26] = 330;
	assign a75[27] = 374;
	assign a75[28] = 421;
	assign a75[29] = 469;
	assign a75[30] = 520;
	assign a75[31] = 574;
	assign a80[0] = 4;
	assign a80[1] = 9;
	assign a80[2] = 15;
	assign a80[3] = 22;
	assign a80[4] = 42;
	assign a80[5] = 48;
	assign a80[6] = 53;
	assign a80[7] = 56;
	assign a80[8] = 60;
	assign a80[9] = 63;
	assign a80[10] = 65;
	assign a80[11] = 68;
	assign a80[12] = 70;
	assign a80[13] = 73;
	assign a85[0] = 2;
	assign a85[1] = 5;
	assign a85[2] = 7;
	assign a85[3] = 13;
	assign a85[4] = 22;
	assign a85[5] = 25;
	assign a85[6] = 27;
	assign a85[7] = 29;
	assign a85[8] = 31;
	assign a85[9] = 32;
	assign a85[10] = 33;
	assign a85[11] = 35;
	assign a85[12] = 36;
	assign a85[13] = 37;
	assign a90[0] = 0;
	assign a90[1] = 0;
	assign a90[2] = 0;
	assign a90[3] = 0;
	assign a90[4] = 0;
	assign a90[5] = 0;
	assign a90[6] = 0;
	assign a90[7] = 0;
	assign a90[8] = 0;
	assign a90[9] = 0;
	assign a90[10] = 0;
	assign a90[11] = 0;
	assign a90[12] = 0;
	assign a90[13] = 0;
	assign v_c[0] = -20;
	assign v_c[1] = -40;
	assign v_c[2] = -60;
	assign v_c[3] = -80;
	assign v_c[4] = -60;
	assign v_c[5] = -40;
	assign v_c[6] = -20;
	assign v_c[7] = 0;
	assign v_c[8] = 20;
	assign v_c[9] = 40;
	assign v_c[10] = 60;
	assign v_c[11] = 80;
	assign v_c[12] = 100;
	assign v_c[13] = 120;
	
	/// State Defenitions ///
	localparam  RESET = 6'd0,
	            INIT_MAP = 6'd1,
					DRAW_MAP = 6'd2,
					INIT_TANK_1 = 6'd3,
					INIT_TANK_2 = 6'd4,

					WAIT = 6'd5,

					ERASE_TANK_1 = 6'd6,
               UPDATE_TANK_1 = 6'd7,
					DRAW_TANK_1 = 6'd8,
					ERASE_TANK_2 = 6'd9,
             	UPDATE_TANK_2 = 6'd10,
					DRAW_TANK_2 = 6'd11,

					SHELL_FIRED = 6'd12,
					ERASE_SHELL = 6'd13,
					UPDATE_SHELL = 6'd14,
					CHECK_SHELL = 6'd15,
					DRAW_SHELL = 6'd16,
					HIT_T1 = 6'd17,
					HIT_T2 = 6'd18,
					MISS = 6'd19,

					DEAD1 = 6'd20,
					DEAD2 = 6'd21;

	always@(posedge CLOCK_50)
   begin
		colour = 3'b000; // base colour
		x = 8'b00000000;
		y = 8'b00000000;
		if (SW[17]) state = RESET; // reset

		case (state)
		
		/// RESET: State that resets the game data and screen, as well as sends to re-initializing states. ///
		RESET: begin
			write_enable = 1'd1; // Enable writing access to RAM
			firing = 1'b0; // Stop firing if firing when reset
			p1_H = 2'd3; // Set player 1 health to 3
			p2_H = 2'd3; // Set player 2 health to 3
			pTurn = 1'b0; // Reset to player 1
			
			/// Fill screen black ///
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b000;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
			else begin // When done filling screen black
				draw_counter= 8'b00000000; // Reset drawing counter
				state = INIT_MAP; // Initiate the map to draw (if multiple maps, will require logic to determine which map to initialize)
			end
		end
		
		/// INIT_MAP: State that initializes the map, if more maps are added they would be a new state and what state to go to would
		///           have the logic added added to the RESET state as to which map to initialize ///
		INIT_MAP: begin
		   write_enable = 1'd1; // Enable writing access to RAM
			if (draw_counter < 17'b10000000000000000) begin
				x_coordinate = draw_counter[7:0]; // Use draw counter to increment x_coordinate
			   /// 1st Map: 3 rectangular mountains 15 pixels tall, each spaced 20 pixels apart ///
			   if ((x_coordinate >= 8'd20 && x_coordinate < 8'd40) || (x_coordinate >= 8'd60 && x_coordinate < 8'd80) || (x_coordinate >= 8'd100 && x_coordinate < 8'd120)) y_coordinate = (8'd115 - 8'd15);
			   if (x_coordinate >= 8'd0 && x_coordinate < 8'd20) y_coordinate = 8'd75;
				if (x_coordinate >= 8'd40 && x_coordinate < 8'd80) y_coordinate = 8'd90;
				if (x_coordinate >= 8'd80 && x_coordinate < 8'd100) y_coordinate = 8'd115;
				if (x_coordinate >= 8'd120 && x_coordinate < 8'd140) y_coordinate = 8'd105;
				if (x_coordinate >= 8'd140 && x_coordinate < 8'd160) y_coordinate = 8'd85;
				
				draw_counter = draw_counter + 1'd1; // Increment drawing counter
			end
			else begin
		        write_enable = 1'd0; // Turn off write_enable so we can read from RAM later
				  x_coordinate = 8'd0; // Reset the x coordinate
				  draw_counter = 8'd120; // Set drawing counter to max y for map drawing
		        state = DRAW_MAP; // next, draw map on screen
		    end
		end
		
		/// DRAW_MAP: State that draws the map based on whatever map was initialized prior by reading from the RAM. ///
		DRAW_MAP: begin
			 // If current coordinate to draw is within the screen
		    if (x_coordinate < 8'd160) begin
				  colour = 3'b111; // Set map colour to white
				  draw_counter = draw_counter - 1'b1; // Decrement drawing counter
				  x = x_coordinate;
				  y = draw_counter[7:0]; // Use draw counter to decrement y coordinate
				  // If draw counter reaches ground
				  if (draw_counter < ground_height_at_x) begin
				   // Increment x coordinate
					x_coordinate = x_coordinate + 1'b1;
					// Reset drawing counter
					draw_counter= 8'd120;
				  end
		    end
		    else begin
				  // reset vars
		        x_coordinate = 8'd0;
				  draw_counter= 8'b00000000;
		        state = INIT_TANK_1; // Initiate the first tank
		    end
		end
		
		/// INIT_TANK_1: State to initialize position of first tank, note there will be logic to determine starting positions if more maps added ///
    	INIT_TANK_1: begin // update to draw tank here
			// Set positions
			tank1_x = 8'd5;
			tank1_y = 8'd75 - 8'd5; // Note the height of the tank is 5 pixels
			draw_counter= 8'b00000000;
			state = INIT_TANK_2;
		end
		
		/// INIT_TANK_2: State to initialize position of first tank, note there will be logic to determine starting positions if more maps added ///
    	INIT_TANK_2: begin // update to draw tank here
			tank2_x = 8'd150;
			tank2_y = 8'd85 - 8'd5; // Note the height of the tank is 5 pixels
			state = WAIT;
		end

		/// WAIT: Allows rate dividers to slow movemnt of tank movements and shell firing ///
		WAIT: begin
			if (frame && ~firing) state = ERASE_TANK_1; // If normal FPS and not firing, then begin next frame at normal speed on the tick
			else if (slow_frame) state = ERASE_SHELL; // If slower FPS, then erase the currently firing shell on the tick
		end
		
		/// ERASE_TANK_1: Erase the tank so it can be redrawn in next position ///
		ERASE_TANK_1: begin
			if (draw_counter < 9'b100000000) begin
				if (draw_counter[3:0] <= 4'd5) // If within width of tank
				x = tank1_x + draw_counter[3:0]; // Then erase that x
				else x = 8'd0;
				if (draw_counter[8:4] <= 4'd5) // If within height of tank
				y = tank1_y + draw_counter[8:4] - 2'd2; // Then erase that y
				else y = 8'd0;
				draw_counter = draw_counter + 1'b1; // Increment drawing counter
			end
			else begin
				draw_counter= 8'b00000000; 
				state = ERASE_TANK_2; // Erase the next tank
			end
		end
		
		/// ERASE_TANK_2: Erase the tank so it can be redrawn in next position ///
		ERASE_TANK_2: begin
			if (draw_counter < 9'b100000000) begin
				if (draw_counter[3:0] <= 4'd5) // If within width of tank 
				x = tank2_x + draw_counter[3:0] - 1'b1;  // Then erase that x
				else x = 8'd0;
				if (draw_counter[8:4] <= 4'd5) // If within height of tank
				y = tank2_y + draw_counter[8:4] - 2'd2; // Then erase that y
				else y = 8'd0;
				draw_counter = draw_counter + 1'b1; // Increment drawing counter
			end
			else begin
				draw_counter= 8'b00000000;
				state = UPDATE_TANK_1;
			end
		end

		/// UPDATE_TANK_1: Moves tank based on input and current position ///
		UPDATE_TANK_1: begin
			// If this player's turn
			if (~pTurn) begin
			   x_coordinate = tank1_x; // Set x_coordinate to left side of tank
				// If moving right
				if (~KEY[1] && tank1_x < 8'd154) begin
				   x_coordinate = x_coordinate + 8'd8; // Update x_coordinate to far right of tank plus one
					tank1_x = tank1_x + 1'd1; // move tank right
					// If tank needs to 'teleport' up to the right
					if (tank1_y != (ground_height_at_x - 3'd5)) begin tank1_y = ((ground_height_at_x - 3'd5)); tank1_x = tank1_x + 8'd8; end
				end
				// If moving left
				if (~KEY[2] && tank1_x > 8'd0) begin
				   x_coordinate = x_coordinate - 2'd2; // Update x_coordinate to far left of tank minus one
					tank1_x = tank1_x - 1'd1; // move tank left
					// If tank needs to 'teleport' up to the left
					if (tank1_y != (ground_height_at_x - 3'd5)) begin tank1_y = ((ground_height_at_x - 3'd5)); tank1_x = tank1_x - 8'd5; end
				end
			end
			
			state = UPDATE_TANK_2; // now update other tank's position on the screen
		end
		
		/// UPDATE_TANK_2: Moves tank based on input and current position ///
		UPDATE_TANK_2: begin
			if (pTurn) begin
				x_coordinate = tank2_x; // Set x_coordinate to left side of tank
				// If moving right
				if (~KEY[1] && tank2_x < 8'd154) begin
				    x_coordinate = x_coordinate + 8'd8; // Update x_coordinate to far right of tank plus one
					tank2_x = tank2_x + 1'd1; // move tank right
					// If tank needs to 'teleport' up to the right
					if (tank2_y != (ground_height_at_x - 3'd5)) begin tank2_y = ((ground_height_at_x - 3'd5)); tank2_x = tank2_x + 8'd7; end
				end
				// tank moves 1 pixel left if next ground is same level or lower
				if (~KEY[2] && tank2_x > 8'd0) begin
				    x_coordinate = x_coordinate - 2'd3; // Update x_coordinate to far left of tank minus one
					tank2_x = tank2_x - 1'd1; // move tank left
					// If tank needs to 'teleport' up to the left
					if (tank2_y != (ground_height_at_x - 3'd5)) begin tank2_y = ((ground_height_at_x - 3'd5)); tank2_x = tank2_x - 8'd6; end
				end
			end
			state = DRAW_TANK_1; // Begin drawing the updated tanks
		end
		
		/// Draw the first tank ///
		DRAW_TANK_1: begin
		if (draw_counter < 7'b1000000) begin
			if (draw_counter[2:0] < 3'b101)
				x = tank1_x + draw_counter[2:0];
			else
				x = tank1_x + 1'b1;
			if (draw_counter[5:3] < 3'b100)
				y = tank1_y + draw_counter[5:3];
			else
				y = tank1_y + 1'b1;
			draw_counter = draw_counter + 1'b1;
			 // updates for the whole block
			case (draw_counter)
				6'b111111: begin //Draw main shooter block
					x = tank1_x + 3'b100;
					y = tank1_y - 1'b1;
					colour = 3'b010;
				end
				6'b111110: begin //Draw (moved) shooter block based on angle from tank barrel wire
					if (tank_1_barrel == 2'b00) begin
						x = tank1_x + 3'b101;
						y = tank1_y - 1'b1;
						colour = 3'b010;
					end
					else if (tank_1_barrel == 2'b01) begin
						x = tank1_x + 3'b101;
						y = tank1_y - 2'b10;
						colour = 3'b010;
					end
					else if (tank_1_barrel == 2'b10) begin
						x = tank1_x + 3'b011;
						y = tank1_y - 2'b10;
						colour = 3'b010;
					end
					else begin
						x = tank1_x + 3'b100;
						y = tank1_y - 2'b10;
						colour = 3'b010;
					end
				end
				// Specific pixel coloration (counting from top left to the right)
				6'b000001: begin
					colour = 3'b000;
				end
				6'b000011: begin
					colour = 3'b111;
				end
				6'b000100: begin
					colour = 3'b111;
				end
				6'b000101: begin
					colour = 3'b000;
				end
				6'b011001: begin
					colour = 3'b001;
				end
				6'b011011: begin
					colour = 3'b001;
				end
				6'b011101: begin
					colour = 3'b001;
				end
				6'b011101: begin
					colour = 3'b001;
				end
				default: begin
					colour = 3'b010;
				end
			endcase
			end
			else begin
				draw_counter= 8'b00000000;
				state = DRAW_TANK_2; // Draw the next tank
			end
		end
		
		/// Draw the second tank ///
		DRAW_TANK_2: begin
		if (draw_counter < 7'b1000000) begin
			if (draw_counter[2:0] < 3'b101)
				x = tank2_x + draw_counter[2:0];
			else
				x = tank2_x + 1'b1;
			if (draw_counter[5:3] < 3'b100)
				y = tank2_y + draw_counter[5:3];
			else
				y = tank2_y + 1'b1;
			draw_counter = draw_counter + 1'b1;
			 // updates for the whole block
			case (draw_counter)
				6'b111111: begin //Draw main shooter block
					x = tank2_x;
					y = tank2_y - 1'b1;
					colour = 3'b010;
				end
				6'b111110: begin //Draw (moved) shooter block based on angle from tank barrel wire
					if (tank_2_barrel == 2'b00) begin
						x = tank2_x - 1'b1;
						y = tank2_y - 1'b1;
						colour = 3'b010;
					end
					else if (tank_2_barrel == 2'b01) begin
						x = tank2_x - 1'b1;
						y = tank2_y - 2'b10;
						colour = 3'b010;
					end
					else if (tank_2_barrel == 2'b10) begin
						x = tank2_x + 1'b1;
						y = tank2_y - 2'b10;
						colour = 3'b010;
					end
					else begin
						x = tank2_x;
						y = tank2_y - 2'b10;
						colour = 3'b010;
					end
				end
				// Specific pixel coloration (counting from top left to the right)
				6'b000001: begin
					colour = 3'b000;
				end
				6'b000010: begin
					colour = 3'b111;
				end
				6'b000011: begin
					colour = 3'b111;
				end
				6'b000101: begin
					colour = 3'b000;
				end
				6'b011001: begin
					colour = 3'b100;
				end
				6'b011011: begin
					colour = 3'b100;
				end
				6'b011101: begin
					colour = 3'b100;
				end
				6'b011101: begin
					colour = 3'b100;
				end
				default: begin
					colour = 3'b010;
				end
			endcase
			end
			else begin
				draw_counter= 8'b00000000;
				state = SHELL_FIRED; //
			end
		end
		
		/// SHELL_FIRED: Fire the shell if neccesary and determine angles ///
		SHELL_FIRED: begin
			// Based on the angle, determine the binary HEX angle and tank barrel position based on player turn
			case(SW[5:0]) // (Reccomended to collapse here)
				6'b000000: begin
					ang_HEX = 12'b1010_1010_0000;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000001: begin
					ang_HEX = 12'b1010_1010_0101;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000010: begin
					ang_HEX = 12'b1010_0001_0000;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000011: begin
					ang_HEX = 12'b1010_0001_0101;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000100: begin
					ang_HEX = 12'b1010_0010_0000;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000101: begin
					ang_HEX = 12'b1010_0010_0101;
					if (~pTurn) tank_1_barrel = 2'b00;
					else tank_2_barrel = 2'b10;
					end
				6'b000110: begin
					ang_HEX = 12'b1010_0011_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b000111: begin
					ang_HEX = 12'b1010_0011_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001000: begin
					ang_HEX = 12'b1010_0100_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001001: begin
					ang_HEX = 12'b1010_0100_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001010: begin
					ang_HEX = 12'b1010_0101_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001011: begin
					ang_HEX = 12'b1010_0101_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001100: begin
					ang_HEX = 12'b1010_0110_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001101: begin
					ang_HEX = 12'b1010_0110_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001110: begin
					ang_HEX = 12'b1010_0111_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b001111: begin
					ang_HEX = 12'b1010_0111_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b010000: begin
					ang_HEX = 12'b1010_1000_0000;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b010001: begin
					ang_HEX = 12'b1010_1000_0101;
					if (~pTurn) tank_1_barrel = 2'b01;
					else tank_2_barrel = 2'b10;
					end
				6'b010010: begin //90 degrees
					ang_HEX = 12'b1010_1001_0000;
					if (~pTurn) tank_1_barrel = 2'b11;
					else tank_2_barrel = 2'b11;
					end
				6'b010011: begin
					ang_HEX = 12'b1010_1001_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b010100: begin
					ang_HEX = 12'b0001_0000_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b010101: begin
					ang_HEX = 12'b0001_0000_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b010110: begin
					ang_HEX = 12'b0001_0001_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b010111: begin
					ang_HEX = 12'b0001_0001_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011000: begin
					ang_HEX = 12'b0001_0010_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011001: begin
					ang_HEX = 12'b0001_0010_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011010: begin
					ang_HEX = 12'b0001_0011_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011011: begin
					ang_HEX = 12'b0001_0011_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011100: begin
					ang_HEX = 12'b0001_0100_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011101: begin
					ang_HEX = 12'b0001_0100_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b01;
					end
				6'b011110: begin
					ang_HEX = 12'b0001_0101_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				6'b011111: begin
					ang_HEX = 12'b0001_0101_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end			
				6'b100000: begin
					ang_HEX = 12'b0001_0110_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				6'b100001: begin
					ang_HEX = 12'b0001_0110_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				6'b100010: begin
					ang_HEX = 12'b0001_0111_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				6'b100011: begin
					ang_HEX = 12'b0001_0111_0101;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				6'b100100: begin
					ang_HEX = 12'b0001_1000_0000;
					if (~pTurn) tank_1_barrel = 2'b10;
					else tank_2_barrel = 2'b00;
					end
				default: begin
					ang_HEX = 12'b1011_1100_1100;
					if (~pTurn) tank_1_barrel = 2'b11;
					else tank_2_barrel = 2'b11;
					end
			endcase
			// If firing
			if(~KEY[0]) begin
				angle = SW[5:0];
					// Set parabola array values based on angle
					case (angle) // (Reccomended to collapse here)
						6'b000000, 6'b100100: begin
														para[0] = a0[0];
														para[1] = a0[1];
														para[2] = a0[2];
														para[3] = a0[3];
														para[4] = a0[4];
														para[5] = a0[5];
														para[6] = a0[6];
														para[7] = a0[7];
														para[8] = a0[8];
														para[9] = a0[9];
														para[10] = a0[10];
														para[11] = a0[11];
														para[12] = a0[12];
														para[13] = a0[13];
														para[14] = a0[14];
														para[15] = a0[15];
														para[16] = a0[16];
														para[17] = a0[17];
														para[18] = a0[18];
														para[19] = a0[19];
														para[20] = a0[20];
														para[21] = a0[21];
														para[22] = a0[22];
														para[23] = a0[23];
														para[24] = a0[24];
														para[25] = a0[25];
														para[26] = a0[26];
														para[27] = a0[27];
														para[28] = a0[28];
														para[29] = a0[29];
														para[30] = a0[30];
														para[31] = a0[31];
													 end
						6'b000001, 6'b100011: begin 
														para[0] = a5[0];
														para[1] = a5[1];
														para[2] = a5[2];
														para[3] = a5[3];
														para[4] = a5[4];
														para[5] = a5[5];
														para[6] = a5[6];
														para[7] = a5[7];
														para[8] = a5[8];
														para[9] = a5[9];
														para[10] = a5[10];
														para[11] = a5[11];
														para[12] = a5[12];
														para[13] = a5[13];
														para[14] = a5[14];
														para[15] = a5[15];
														para[16] = a5[16];
														para[17] = a5[17];
														para[18] = a5[18];
														para[19] = a5[19];
														para[20] = a5[20];
														para[21] = a5[21];
														para[22] = a5[22];
														para[23] = a5[23];
														para[24] = a5[24];
														para[25] = a5[25];
														para[26] = a5[26];
														para[27] = a5[27];
														para[28] = a5[28];
														para[29] = a5[29];
														para[30] = a5[30];
														para[31] = a5[31];
													 end
						6'b000010, 6'b100010: begin
														para[0] = a10[0];
														para[1] = a10[1];
														para[2] = a10[2];
														para[3] = a10[3];
														para[4] = a10[4];
														para[5] = a10[5];
														para[6] = a10[6];
														para[7] = a10[7];
														para[8] = a10[8];
														para[9] = a10[9];
														para[10] = a10[10];
														para[11] = a10[11];
														para[12] = a10[12];
														para[13] = a10[13];
														para[14] = a10[14];
														para[15] = a10[15];
														para[16] = a10[16];
														para[17] = a10[17];
														para[18] = a10[18];
														para[19] = a10[19];
														para[20] = a10[20];
														para[21] = a10[21];
														para[22] = a10[22];
														para[23] = a10[23];
														para[24] = a10[24];
														para[25] = a10[25];
														para[26] = a10[26];
														para[27] = a10[27];
														para[28] = a10[28];
														para[29] = a10[29];
														para[30] = a10[30];
														para[31] = a10[31];
													 end
						6'b000011, 6'b100001: begin
														para[0] = a15[0];
														para[1] = a15[1];
														para[2] = a15[2];
														para[3] = a15[3];
														para[4] = a15[4];
														para[5] = a15[5];
														para[6] = a15[6];
														para[7] = a15[7];
														para[8] = a15[8];
														para[9] = a15[9];
														para[10] = a15[10];
														para[11] = a15[11];
														para[12] = a15[12];
														para[13] = a15[13];
														para[14] = a15[14];
														para[15] = a15[15];
														para[16] = a15[16];
														para[17] = a15[17];
														para[18] = a15[18];
														para[19] = a15[19];
														para[20] = a15[20];
														para[21] = a15[21];
														para[22] = a15[22];
														para[23] = a15[23];
														para[24] = a15[24];
														para[25] = a15[25];
														para[26] = a15[26];
														para[27] = a15[27];
														para[28] = a15[28];
														para[29] = a15[29];
														para[30] = a15[30];
														para[31] = a15[31];
													 end
			    		6'b000100, 6'b100000: begin
														para[0] = a20[0];
														para[1] = a20[1];
														para[2] = a20[2];
														para[3] = a20[3];
														para[4] = a20[4];
														para[5] = a20[5];
														para[6] = a20[6];
														para[7] = a20[7];
														para[8] = a20[8];
														para[9] = a20[9];
														para[10] = a20[10];
														para[11] = a20[11];
														para[12] = a20[12];
														para[13] = a20[13];
														para[14] = a20[14];
														para[15] = a20[15];
														para[16] = a20[16];
														para[17] = a20[17];
														para[18] = a20[18];
														para[19] = a20[19];
														para[20] = a20[20];
														para[21] = a20[21];
														para[22] = a20[22];
														para[23] = a20[23];
														para[24] = a20[24];
														para[25] = a20[25];
														para[26] = a20[26];
														para[27] = a20[27];
														para[28] = a20[28];
														para[29] = a20[29];
														para[30] = a20[30];
														para[31] = a20[31];
													 end
						6'b000101, 6'b011111: begin
														para[0] = a25[0];
														para[1] = a25[1];
														para[2] = a25[2];
														para[3] = a25[3];
														para[4] = a25[4];
														para[5] = a25[5];
														para[6] = a25[6];
														para[7] = a25[7];
														para[8] = a25[8];
														para[9] = a25[9];
														para[10] = a25[10];
														para[11] = a25[11];
														para[12] = a25[12];
														para[13] = a25[13];
														para[14] = a25[14];
														para[15] = a25[15];
														para[16] = a25[16];
														para[17] = a25[17];
														para[18] = a25[18];
														para[19] = a25[19];
														para[20] = a25[20];
														para[21] = a25[21];
														para[22] = a25[22];
														para[23] = a25[23];
														para[24] = a25[24];
														para[25] = a25[25];
														para[26] = a25[26];
														para[27] = a25[27];
														para[28] = a25[28];
														para[29] = a25[29];
														para[30] = a25[30];
														para[31] = a25[31];
													 end
						6'b000110, 6'b011110: begin
														para[0] = a30[0];
														para[1] = a30[1];
														para[2] = a30[2];
														para[3] = a30[3];
														para[4] = a30[4];
														para[5] = a30[5];
														para[6] = a30[6];
														para[7] = a30[7];
														para[8] = a30[8];
														para[9] = a30[9];
														para[10] = a30[10];
														para[11] = a30[11];
														para[12] = a30[12];
														para[13] = a30[13];
														para[14] = a30[14];
														para[15] = a30[15];
														para[16] = a30[16];
														para[17] = a30[17];
														para[18] = a30[18];
														para[19] = a30[19];
														para[20] = a30[20];
														para[21] = a30[21];
														para[22] = a30[22];
														para[23] = a30[23];
														para[24] = a30[24];
														para[25] = a30[25];
														para[26] = a30[26];
														para[27] = a30[27];
														para[28] = a30[28];
														para[29] = a30[29];
														para[30] = a30[30];
														para[31] = a30[31];
													 end
						6'b000111, 6'b011101: begin
														para[0] = a35[0];
														para[1] = a35[1];
														para[2] = a35[2];
														para[3] = a35[3];
														para[4] = a35[4];
														para[5] = a35[5];
														para[6] = a35[6];
														para[7] = a35[7];
														para[8] = a35[8];
														para[9] = a35[9];
														para[10] = a35[10];
														para[11] = a35[11];
														para[12] = a35[12];
														para[13] = a35[13];
														para[14] = a35[14];
														para[15] = a35[15];
														para[16] = a35[16];
														para[17] = a35[17];
														para[18] = a35[18];
														para[19] = a35[19];
														para[20] = a35[20];
														para[21] = a35[21];
														para[22] = a35[22];
														para[23] = a35[23];
														para[24] = a35[24];
														para[25] = a35[25];
														para[26] = a35[26];
														para[27] = a35[27];
														para[28] = a35[28];
														para[29] = a35[29];
														para[30] = a35[30];
														para[31] = a35[31];
													 end
						6'b001000, 6'b011100: begin
														para[0] = a40[0];
														para[1] = a40[1];
														para[2] = a40[2];
														para[3] = a40[3];
														para[4] = a40[4];
														para[5] = a40[5];
														para[6] = a40[6];
														para[7] = a40[7];
														para[8] = a40[8];
														para[9] = a40[9];
														para[10] = a40[10];
														para[11] = a40[11];
														para[12] = a40[12];
														para[13] = a40[13];
														para[14] = a40[14];
														para[15] = a40[15];
														para[16] = a40[16];
														para[17] = a40[17];
														para[18] = a40[18];
														para[19] = a40[19];
														para[20] = a40[20];
														para[21] = a40[21];
														para[22] = a40[22];
														para[23] = a40[23];
														para[24] = a40[24];
														para[25] = a40[25];
														para[26] = a40[26];
														para[27] = a40[27];
														para[28] = a40[28];
														para[29] = a40[29];
														para[30] = a40[30];
														para[31] = a40[31];
													 end
						6'b001001, 6'b011011: begin
														para[0] = a45[0];
														para[1] = a45[1];
														para[2] = a45[2];
														para[3] = a45[3];
														para[4] = a45[4];
														para[5] = a45[5];
														para[6] = a45[6];
														para[7] = a45[7];
														para[8] = a45[8];
														para[9] = a45[9];
														para[10] = a45[10];
														para[11] = a45[11];
														para[12] = a45[12];
														para[13] = a45[13];
														para[14] = a45[14];
														para[15] = a45[15];
														para[16] = a45[16];
														para[17] = a45[17];
														para[18] = a45[18];
														para[19] = a45[19];
														para[20] = a45[20];
														para[21] = a45[21];
														para[22] = a45[22];
														para[23] = a45[23];
														para[24] = a45[24];
														para[25] = a45[25];
														para[26] = a45[26];
														para[27] = a45[27];
														para[28] = a45[28];
														para[29] = a45[29];
														para[30] = a45[30];
														para[31] = a45[31];
													 end
						6'b001010, 6'b011010: begin
														para[0] = a50[0];
														para[1] = a50[1];
														para[2] = a50[2];
														para[3] = a50[3];
														para[4] = a50[4];
														para[5] = a50[5];
														para[6] = a50[6];
														para[7] = a50[7];
														para[8] = a50[8];
														para[9] = a50[9];
														para[10] = a50[10];
														para[11] = a50[11];
														para[12] = a50[12];
														para[13] = a50[13];
														para[14] = a50[14];
														para[15] = a50[15];
														para[16] = a50[16];
														para[17] = a50[17];
														para[18] = a50[18];
														para[19] = a50[19];
														para[20] = a50[20];
														para[21] = a50[21];
														para[22] = a50[22];
														para[23] = a50[23];
														para[24] = a50[24];
														para[25] = a50[25];
														para[26] = a50[26];
														para[27] = a50[27];
														para[28] = a50[28];
														para[29] = a50[29];
														para[30] = a50[30];
														para[31] = a50[31];
													 end
						6'b001011, 6'b011001: begin
														para[0] = a55[0];
														para[1] = a55[1];
														para[2] = a55[2];
														para[3] = a55[3];
														para[4] = a55[4];
														para[5] = a55[5];
														para[6] = a55[6];
														para[7] = a55[7];
														para[8] = a55[8];
														para[9] = a55[9];
														para[10] = a55[10];
														para[11] = a55[11];
														para[12] = a55[12];
														para[13] = a55[13];
														para[14] = a55[14];
														para[15] = a55[15];
														para[16] = a55[16];
														para[17] = a55[17];
														para[18] = a55[18];
														para[19] = a55[19];
														para[20] = a55[20];
														para[21] = a55[21];
														para[22] = a55[22];
														para[23] = a55[23];
														para[24] = a55[24];
														para[25] = a55[25];
														para[26] = a55[26];
														para[27] = a55[27];
														para[28] = a55[28];
														para[29] = a55[29];
														para[30] = a55[30];
														para[31] = a55[31];
													 end
						6'b001100, 6'b011000: begin
														para[0] = a60[0];
														para[1] = a60[1];
														para[2] = a60[2];
														para[3] = a60[3];
														para[4] = a60[4];
														para[5] = a60[5];
														para[6] = a60[6];
														para[7] = a60[7];
														para[8] = a60[8];
														para[9] = a60[9];
														para[10] = a60[10];
														para[11] = a60[11];
														para[12] = a60[12];
														para[13] = a60[13];
														para[14] = a60[14];
														para[15] = a60[15];
														para[16] = a60[16];
														para[17] = a60[17];
														para[18] = a60[18];
														para[19] = a60[19];
														para[20] = a60[20];
														para[21] = a60[21];
														para[22] = a60[22];
														para[23] = a60[23];
														para[24] = a60[24];
														para[25] = a60[25];
														para[26] = a60[26];
														para[27] = a60[27];
														para[28] = a60[28];
														para[29] = a60[29];
														para[30] = a60[30];
														para[31] = a60[31];
													 end
						6'b001101, 6'b010111: begin
														para[0] = a65[0];
														para[1] = a65[1];
														para[2] = a65[2];
														para[3] = a65[3];
														para[4] = a65[4];
														para[5] = a65[5];
														para[6] = a65[6];
														para[7] = a65[7];
														para[8] = a65[8];
														para[9] = a65[9];
														para[10] = a65[10];
														para[11] = a65[11];
														para[12] = a65[12];
														para[13] = a65[13];
														para[14] = a65[14];
														para[15] = a65[15];
														para[16] = a65[16];
														para[17] = a65[17];
														para[18] = a65[18];
														para[19] = a65[19];
														para[20] = a65[20];
														para[21] = a65[21];
														para[22] = a65[22];
														para[23] = a65[23];
														para[24] = a65[24];
														para[25] = a65[25];
														para[26] = a65[26];
														para[27] = a65[27];
														para[28] = a65[28];
														para[29] = a65[29];
														para[30] = a65[30];
														para[31] = a65[31];
													 end
						6'b001110, 6'b010110: begin
														para[0] = a70[0];
														para[1] = a70[1];
														para[2] = a70[2];
														para[3] = a70[3];
														para[4] = a70[4];
														para[5] = a70[5];
														para[6] = a70[6];
														para[7] = a70[7];
														para[8] = a70[8];
														para[9] = a70[9];
														para[10] = a70[10];
														para[11] = a70[11];
														para[12] = a70[12];
														para[13] = a70[13];
														para[14] = a70[14];
														para[15] = a70[15];
														para[16] = a70[16];
														para[17] = a70[17];
														para[18] = a70[18];
														para[19] = a70[19];
														para[20] = a70[20];
														para[21] = a70[21];
														para[22] = a70[22];
														para[23] = a70[23];
														para[24] = a70[24];
														para[25] = a70[25];
														para[26] = a70[26];
														para[27] = a70[27];
														para[28] = a70[28];
														para[29] = a70[29];
														para[30] = a70[30];
														para[31] = a70[31];
													 end
						6'b001111, 6'b010101: begin
														para[0] = a75[0];
														para[1] = a75[1];
														para[2] = a75[2];
														para[3] = a75[3];
														para[4] = a75[4];
														para[5] = a75[5];
														para[6] = a75[6];
														para[7] = a75[7];
														para[8] = a75[8];
														para[9] = a75[9];
														para[10] = a75[10];
														para[11] = a75[11];
														para[12] = a75[12];
														para[13] = a75[13];
														para[14] = a75[14];
														para[15] = a75[15];
														para[16] = a75[16];
														para[17] = a75[17];
														para[18] = a75[18];
														para[19] = a75[19];
														para[20] = a75[20];
														para[21] = a75[21];
														para[22] = a75[22];
														para[23] = a75[23];
														para[24] = a75[24];
														para[25] = a75[25];
														para[26] = a75[26];
														para[27] = a75[27];
														para[28] = a75[28];
														para[29] = a75[29];
														para[30] = a75[30];
														para[31] = a75[31];
													 end
						6'b010000, 6'b010100: begin
														para[0] = a80[0];
														para[1] = a80[1];
														para[2] = a80[2];
														para[3] = a80[3];
														para[4] = a80[4];
														para[5] = a80[5];
														para[6] = a80[6];
														para[7] = a80[7];
														para[8] = a80[8];
														para[9] = a80[9];
														para[10] = a80[10];
														para[11] = a80[11];
														para[12] = a80[12];
														para[13] = a80[13];
													 end
						6'b010001, 6'b010011: begin
														para[0] = a85[0];
														para[1] = a85[1];
														para[2] = a85[2];
														para[3] = a85[3];
														para[4] = a85[4];
														para[5] = a85[5];
														para[6] = a85[6];
														para[7] = a85[7];
														para[8] = a85[8];
														para[9] = a85[9];
														para[10] = a85[10];
														para[11] = a85[11];
														para[12] = a85[12];
														para[13] = a85[13];
													 end
						default: begin
										para[0] = a90[0];
										para[1] = a90[1];
										para[2] = a90[2];
										para[3] = a90[3];
										para[4] = a90[4];
										para[5] = a90[5];
										para[6] = a90[6];
										para[7] = a90[7];
										para[8] = a90[8];
										para[9] = a90[9];	
										para[10] = a90[10];
										para[11] = a90[11];
										para[12] = a90[12];
										para[13] = a90[13];
									end
					endcase

				firing = 1'd1; // Set var for future firing checks
				i = 1'b0; // Set incrementer to 0
				// Set direction and check for special cases
				if(angle > 18) dir = -1;
				else dir = 1;
				if(((20 >= angle) && (angle >= 16)) || (angle > 36)) spec = 1'b1;
				else spec = 1'b0;
				state = UPDATE_SHELL; // Update the shell that is firing
			end
			else state = ERASE_SHELL; // Erase the shell that is not firing or no longer firing
			
		end

		/// ERASE_SHELL: Erase the shell ///
		ERASE_SHELL: begin
			colour = 3'b000;
			if(firing) begin
			x = proj_x;
			y = proj_y;
			end
			else begin // If not firing, erase at initial firing position instead
			x = shell_x;
			y = shell_y;
			end
			state = UPDATE_SHELL; // Update the shell position
		end

		/// Update the shell position ///
		UPDATE_SHELL: begin
			// Get next position of shell and update if firing
			if (firing) begin
				if(((spec) && (i == 14)) || ((~spec) && (i == 32))) state = MISS;
				if(spec) begin
					proj_x = shell_x + para[i]*dir;
					proj_y = shell_y + v_c[i];
				end
				else begin
					proj_x = shell_x + 5*dir*(i+1);
					proj_y = shell_y + para[i];
				end
				state = CHECK_SHELL; // Check the updated shell position
			end
			// Ensure shell stays in initial firing position relative to tank when not firing
			else begin
				if (~pTurn) begin
					shell_x = tank1_x + 2'd4; // update shell position to tank position
					shell_y = tank1_y - 1'd1;
				end
				else begin
					shell_x = tank2_x + 3'd4; // update shell position to tank position
					shell_y = tank2_y - 1'd1;
				end
				state = WAIT; // Wait for shell to continue firing or finish firing after updating the shell
			end
		end

		/// CHECK_SHELL: Determine if updated shell position ///
		CHECK_SHELL: begin
			// If out of bounds
			if((proj_x < 0) || (proj_x > 160) || (proj_y > 125)) state = MISS;
			else x_coordinate = proj_x; // Set x_coordinate for ground RAM checks
			// If out of bounds
			if((proj_x < 0) || (proj_x > 160) || (proj_y > 125)) state = MISS;
			else if(proj_y < 0) begin
				i = i + 1; // Increment index
				state = WAIT; // Wait for next position
			end
			else if((tank1_x <= proj_x) && (proj_x <= tank1_x + 4) && (proj_y >= tank1_y)) state = HIT_T1; // Hit tank 1
			else if((tank2_x <= proj_x) && (proj_x <= tank2_x + 4) && (proj_y >= tank2_y)) state = HIT_T2; // Hit tank 2
			else if(proj_y >= ground_height_at_x) begin // If in the ground
				state = MISS;
			end
			else state = DRAW_SHELL;
		end

		/// DRAW_SHELL: Draw the updated shell position ///
		DRAW_SHELL: begin
			colour = 3'b111;
			if(~firing) begin
			x = shell_x;
			y = shell_y;
			end
			else begin
			x = proj_x;
			y = proj_y;
			end
			i = i + 1; // Increment index
			state = WAIT;
		end

		/// HIT_T1: When player 1 is hit ///
		HIT_T1: begin
			p1_H = p1_H - 1; 
			if(p1_H == 0) state = DEAD1;
			else state = MISS;
		end 

		/// HIT_T1: When player 2 is hit ///
		HIT_T2: begin
			p2_H = p2_H - 1;
			if(p2_H == 0) state = DEAD2;
			else state = MISS;
		end

		/// Switch turns on a miss ///
		MISS: begin
			// since there is no more manual turn switch, everything happens here
			fuel = 5'd30;
			firing = 1'b0;
			pTurn = ~pTurn;
			state = WAIT;
		end

		/// When player 2 wins ///
		DEAD1: begin
		// Fill the screen red
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b100;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
		end
		
		/// When player 1 wins ///
		DEAD2: begin
			// Fill the screen blue
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b001;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
		end
		endcase // end cases
	end // end always
endmodule