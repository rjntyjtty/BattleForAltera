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
	
	reg [7:0] x_coordinate, y_coordinate;
    
	rateDivider (.clock(CLOCK_50), .clk(frame));
    slowRateDivider (.clock(CLOCK_50), .clk(slow_frame));
	ram160x8 groundRAM (.address(x_coordinate), .clock(CLOCK_50), .data(y_coordinate), .wren(write_enable), .q(ground_height_at_x));
	vga_adapter VGA(
			.resetn(1'b1),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			// Signals for the DAC to drive the monitor.
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
	reg [0:0] firing = 1'd0; // check for if shell is fired
	reg [3:0] jump_capacity = 4'd10;
	reg [4:0] fuel = 5'd30;
	reg pTurn = 1'b0;
	
	reg [7:0] x, y;
	reg [17:0] draw_counter;
	reg [5:0] state;
	reg [2:0] colour;
	wire frame, slow_frame;
	
	reg [7:0] tank1_x, tank1_y, tank2_x, tank2_y; // tank positions
	
	wire [7:0] ground_height_at_x; // ground height when pulling the x val from RAM
	
	////////
	reg signed [7:0] shell_x, shell_y;
	reg signed [10:0] proj_x. proj_y;
	reg [5:0] angle;
	reg signed [31:0] para [0:10];
	reg signed [1:0] dir;
	reg spec;
	reg signed [6:0] i;
	reg [1:0] p1_H, p2_H = 1'd3;
	reg [7:0] bl_1_x, bl_1_y, bl_2_x, bl_2_y;
	reg shell_x_direction, shell_y_direction = 1'd0; // shell direction stuff, Max to remove and put his stuff here
	////////
	reg [2:0] block_1_colour, block_2_colour; // remove later
	////////

	reg signed [31:0] a0 [0:10], a5 [0:10], a10 [0:10], a15 [0:10], a20 [0:10], a25 [0:10], a30 [0:10], a35 [0:10], a40 [0:10], a45 [0:10], a50 [0:10], a55 [0:10], a60 [0:10], a65 [0:10], a70 [0:10], a75 [0:10];
	reg signed [13:0] a80 [0:7], a85 [0:7], a90 [0:7], v_c [0:7];

	a0[0] = 1;
	a0[1] = 1;
	a0[2] = 1;
	a0[3] = 2;
	a0[4] = 2;
	a0[5] = 3;
	a0[6] = 4;
	a0[7] = 5;
	a0[8] = 7;
	a0[9] = 8;
	a0[10] = 10;
	a0[11] = 12;
	a0[12] = 13;
	a0[13] = 16;
	a0[14] = 18;
	a0[15] = 20;
	a0[16] = 23;
	a0[17] = 25;
	a0[18] = 28;
	a0[19] = 31;
	a0[20] = 34;
	a0[21] = 38;
	a0[22] = 41;
	a0[23] = 45;
	a0[24] = 48;
	a0[25] = 52;
	a0[26] = 56;
	a0[27] = 61;
	a0[28] = 65;
	a0[29] = 69;
	a0[30] = 74;
	a0[31] = 79;
	a5[0] = 0;
	a5[1] = 0;
	a5[2] = 0;
	a5[3] = 0;
	a5[4] = 0;
	a5[5] = 1;
	a5[6] = 1;
	a5[7] = 2;
	a5[8] = 3;
	a5[9] = 4;
	a5[10] = 5;
	a5[11] = 6;
	a5[12] = 8;
	a5[13] = 9;
	a5[14] = 11;
	a5[15] = 13;
	a5[16] = 15;
	a5[17] = 18;
	a5[18] = 20;
	a5[19] = 23;
	a5[20] = 25;
	a5[21] = 28;
	a5[22] = 31;
	a5[23] = 34;
	a5[24] = 38;
	a5[25] = 41;
	a5[26] = 45;
	a5[27] = 49;
	a5[28] = 53;
	a5[29] = 57;
	a5[30] = 61;
	a5[31] = 66;
	a10[0] = 0;
	a10[1] = -1;
	a10[2] = -1;
	a10[3] = -2;
	a10[4] = -2;
	a10[5] = -2;
	a10[6] = -2;
	a10[7] = -2;
	a10[8] = -1;
	a10[9] = 0;
	a10[10] = 0;
	a10[11] = 1;
	a10[12] = 2;
	a10[13] = 4;
	a10[14] = 5;
	a10[15] = 7;
	a10[16] = 8;
	a10[17] = 10;
	a10[18] = 12;
	a10[19] = 14;
	a10[20] = 17;
	a10[21] = 19;
	a10[22] = 22;
	a10[23] = 25;
	a10[24] = 28;
	a10[25] = 31;
	a10[26] = 34;
	a10[27] = 38;
	a10[28] = 41;
	a10[29] = 45;
	a10[30] = 49;
	a10[31] = 53;
	a15[0] = -1;
	a15[1] = -2;
	a15[2] = -3;
	a15[3] = -4;
	a15[4] = -4;
	a15[5] = -5;
	a15[6] = -5;
	a15[7] = -5;
	a15[8] = -5;
	a15[9] = -5;
	a15[10] = -4;
	a15[11] = -4;
	a15[12] = -3;
	a15[13] = -2;
	a15[14] = -1;
	a15[15] = 0;
	a15[16] = 1;
	a15[17] = 3;
	a15[18] = 5;
	a15[19] = 7;
	a15[20] = 9;
	a15[21] = 11;
	a15[22] = 13;
	a15[23] = 16;
	a15[24] = 18;
	a15[25] = 21;
	a15[26] = 24;
	a15[27] = 27;
	a15[28] = 31;
	a15[29] = 34;
	a15[30] = 38;
	a15[31] = 42;
	a20[0] = -1;
	a20[1] = -3;
	a20[2] = -4;
	a20[3] = -5;
	a20[4] = -6;
	a20[5] = -7;
	a20[6] = -8;
	a20[7] = -9;
	a20[8] = -9;
	a20[9] = -9;
	a20[10] = -9;
	a20[11] = -9;
	a20[12] = -9;
	a20[13] = -8;
	a20[14] = -7;
	a20[15] = -6;
	a20[16] = -5;
	a20[17] = -4;
	a20[18] = -3;
	a20[19] = -1;
	a20[20] = 1;
	a20[21] = 2;
	a20[22] = 5;
	a20[23] = 7;
	a20[24] = 9;
	a20[25] = 12;
	a20[26] = 15;
	a20[27] = 18;
	a20[28] = 21;
	a20[29] = 24;
	a20[30] = 27;
	a20[31] = 31;
	a25[0] = -2;
	a25[1] = -4;
	a25[2] = -6;
	a25[3] = -7;
	a25[4] = -9;
	a25[5] = -10;
	a25[6] = -11;
	a25[7] = -12;
	a25[8] = -13;
	a25[9] = -13;
	a25[10] = -14;
	a25[11] = -14;
	a25[12] = -14;
	a25[13] = -14;
	a25[14] = -14;
	a25[15] = -13;
	a25[16] = -12;
	a25[17] = -11;
	a25[18] = -10;
	a25[19] = -9;
	a25[20] = -7;
	a25[21] = -6;
	a25[22] = -4;
	a25[23] = -2;
	a25[24] = 0;
	a25[25] = 3;
	a25[26] = 5;
	a25[27] = 8;
	a25[28] = 11;
	a25[29] = 14;
	a25[30] = 18;
	a25[31] = 21;
	a30[0] = -2;
	a30[1] = -5;
	a30[2] = -7;
	a30[3] = -9;
	a30[4] = -11;
	a30[5] = -13;
	a30[6] = -15;
	a30[7] = -16;
	a30[8] = -17;
	a30[9] = -18;
	a30[10] = -19;
	a30[11] = -19;
	a30[12] = -20;
	a30[13] = -20;
	a30[14] = -20;
	a30[15] = -20;
	a30[16] = -19;
	a30[17] = -18;
	a30[18] = -17;
	a30[19] = -16;
	a30[20] = -15;
	a30[21] = -14;
	a30[22] = -12;
	a30[23] = -10;
	a30[24] = -8;
	a30[25] = -6;
	a30[26] = -3;
	a30[27] = 0;
	a30[28] = 3;
	a30[29] = 6;
	a30[30] = 9;
	a30[31] = 13;
	a35[0] = -3;
	a35[1] = -6;
	a35[2] = -9;
	a35[3] = -12;
	a35[4] = -14;
	a35[5] = -16;
	a35[6] = -18;
	a35[7] = -20;
	a35[8] = -22;
	a35[9] = -23;
	a35[10] = -24;
	a35[11] = -25;
	a35[12] = -26;
	a35[13] = -26;
	a35[14] = -26;
	a35[15] = -26;
	a35[16] = -26;
	a35[17] = -26;
	a35[18] = -25;
	a35[19] = -24;
	a35[20] = -23;
	a35[21] = -21;
	a35[22] = -20;
	a35[23] = -18;
	a35[24] = -16;
	a35[25] = -13;
	a35[26] = -11;
	a35[27] = -8;
	a35[28] = -5;
	a35[29] = -2;
	a35[30] = 2;
	a35[31] = 5;
	a40[0] = -4;
	a40[1] = -7;
	a40[2] = -11;
	a40[3] = -14;
	a40[4] = -17;
	a40[5] = -20;
	a40[6] = -22;
	a40[7] = -25;
	a40[8] = -27;
	a40[9] = -28;
	a40[10] = -30;
	a40[11] = -31;
	a40[12] = -32;
	a40[13] = -33;
	a40[14] = -33;
	a40[15] = -33;
	a40[16] = -33;
	a40[17] = -33;
	a40[18] = -32;
	a40[19] = -31;
	a40[20] = -30;
	a40[21] = -29;
	a40[22] = -27;
	a40[23] = -25;
	a40[24] = -23;
	a40[25] = -20;
	a40[26] = -18;
	a40[27] = -15;
	a40[28] = -11;
	a40[29] = -8;
	a40[30] = -4;
	a40[31] = 0;
	a45[0] = -4;
	a45[1] = -9;
	a45[2] = -13;
	a45[3] = -17;
	a45[4] = -21;
	a45[5] = -24;
	a45[6] = -27;
	a45[7] = -30;
	a45[8] = -32;
	a45[9] = -34;
	a45[10] = -36;
	a45[11] = -37;
	a45[12] = -39;
	a45[13] = -39;
	a45[14] = -40;
	a45[15] = -40;
	a45[16] = -40;
	a45[17] = -40;
	a45[18] = -39;
	a45[19] = -38;
	a45[20] = -37;
	a45[21] = -35;
	a45[22] = -33;
	a45[23] = -31;
	a45[24] = -29;
	a45[25] = -26;
	a45[26] = -23;
	a45[27] = -19;
	a45[28] = -16;
	a45[29] = -12;
	a45[30] = -7;
	a45[31] = -3;
	a50[0] = -5;
	a50[1] = -11;
	a50[2] = -16;
	a50[3] = -20;
	a50[4] = -25;
	a50[5] = -29;
	a50[6] = -32;
	a50[7] = -35;
	a50[8] = -38;
	a50[9] = -41;
	a50[10] = -43;
	a50[11] = -44;
	a50[12] = -46;
	a50[13] = -47;
	a50[14] = -47;
	a50[15] = -47;
	a50[16] = -47;
	a50[17] = -47;
	a50[18] = -46;
	a50[19] = -45;
	a50[20] = -43;
	a50[21] = -41;
	a50[22] = -39;
	a50[23] = -36;
	a50[24] = -33;
	a50[25] = -29;
	a50[26] = -25;
	a50[27] = -21;
	a50[28] = -16;
	a50[29] = -11;
	a50[30] = -6;
	a50[31] = 0;
	a55[0] = -6;
	a55[1] = -13;
	a55[2] = -19;
	a55[3] = -24;
	a55[4] = -29;
	a55[5] = -34;
	a55[6] = -38;
	a55[7] = -42;
	a55[8] = -45;
	a55[9] = -48;
	a55[10] = -50;
	a55[11] = -52;
	a55[12] = -53;
	a55[13] = -54;
	a55[14] = -54;
	a55[15] = -54;
	a55[16] = -54;
	a55[17] = -53;
	a55[18] = -51;
	a55[19] = -49;
	a55[20] = -47;
	a55[21] = -44;
	a55[22] = -41;
	a55[23] = -37;
	a55[24] = -33;
	a55[25] = -28;
	a55[26] = -23;
	a55[27] = -17;
	a55[28] = -11;
	a55[29] = -4;
	a55[30] = 3;
	a55[31] = 10;
	a60[0] = -8;
	a60[1] = -16;
	a60[2] = -23;
	a60[3] = -29;
	a60[4] = -35;
	a60[5] = -40;
	a60[6] = -45;
	a60[7] = -49;
	a60[8] = -53;
	a60[9] = -55;
	a60[10] = -58;
	a60[11] = -59;
	a60[12] = -60;
	a60[13] = -61;
	a60[14] = -60;
	a60[15] = -60;
	a60[16] = -58;
	a60[17] = -56;
	a60[18] = -53;
	a60[19] = -50;
	a60[20] = -46;
	a60[21] = -42;
	a60[22] = -37;
	a60[23] = -31;
	a60[24] = -25;
	a60[25] = -18;
	a60[26] = -10;
	a60[27] = -2;
	a60[28] = 7;
	a60[29] = 16;
	a60[30] = 26;
	a60[31] = 37;
	a65[0] = -10;
	a65[1] = -19;
	a65[2] = -28;
	a65[3] = -36;
	a65[4] = -42;
	a65[5] = -48;
	a65[6] = -54;
	a65[7] = -58;
	a65[8] = -61;
	a65[9] = -64;
	a65[10] = -66;
	a65[11] = -66;
	a65[12] = -66;
	a65[13] = -66;
	a65[14] = -64;
	a65[15] = -61;
	a65[16] = -58;
	a65[17] = -54;
	a65[18] = -48;
	a65[19] = -42;
	a65[20] = -36;
	a65[21] = -28;
	a65[22] = -19;
	a65[23] = -10;
	a65[24] = 0;
	a65[25] = 11;
	a65[26] = 23;
	a65[27] = 36;
	a65[28] = 50;
	a65[29] = 65;
	a65[30] = 80;
	a65[31] = 96;
	a70[0] = -13;
	a70[1] = -24;
	a70[2] = -35;
	a70[3] = -44;
	a70[4] = -52;
	a70[5] = -58;
	a70[6] = -64;
	a70[7] = -68;
	a70[8] = -70;
	a70[9] = -71;
	a70[10] = -71;
	a70[11] = -70;
	a70[12] = -67;
	a70[13] = -64;
	a70[14] = -58;
	a70[15] = -52;
	a70[16] = -44;
	a70[17] = -35;
	a70[18] = -24;
	a70[19] = -12;
	a70[20] = 1;
	a70[21] = 15;
	a70[22] = 31;
	a70[23] = 48;
	a70[24] = 66;
	a70[25] = 86;
	a70[26] = 107;
	a70[27] = 129;
	a70[28] = 153;
	a70[29] = 177;
	a70[30] = 204;
	a70[31] = 231;
	a75[0] = -17;
	a75[1] = -32;
	a75[2] = -45;
	a75[3] = -56;
	a75[4] = -64;
	a75[5] = -70;
	a75[6] = -74;
	a75[7] = -76;
	a75[8] = -75;
	a75[9] = -72;
	a75[10] = -66;
	a75[11] = -59;
	a75[12] = -49;
	a75[13] = -37;
	a75[14] = -22;
	a75[15] = -5;
	a75[16] = 14;
	a75[17] = 35;
	a75[18] = 59;
	a75[19] = 84;
	a75[20] = 113;
	a75[21] = 143;
	a75[22] = 176;
	a75[23] = 211;
	a75[24] = 248;
	a75[25] = 288;
	a75[26] = 330;
	a75[27] = 374;
	a75[28] = 421;
	a75[29] = 469;
	a75[30] = 520;
	a75[31] = 574;
	a80[0] = 4;
	a80[1] = 9;
	a80[2] = 15;
	a80[3] = 22;
	a80[4] = 42;
	a80[5] = 48;
	a80[6] = 53;
	a80[7] = 56;
	a80[8] = 60;
	a80[9] = 63;
	a80[10] = 65;
	a80[11] = 68;
	a80[12] = 70;
	a80[13] = 73;
	a85[0] = 2;
	a85[1] = 5;
	a85[2] = 7;
	a85[3] = 13;
	a85[4] = 22;
	a85[5] = 25;
	a85[6] = 27;
	a85[7] = 29;
	a85[8] = 31;
	a85[9] = 32;
	a85[10] = 33;
	a85[11] = 35;
	a85[12] = 36;
	a85[13] = 37;
	a90[0] = 0;
	a90[1] = 0;
	a90[2] = 0;
	a90[3] = 0;
	a90[4] = 0;
	a90[5] = 0;
	a90[6] = 0;
	a90[7] = 0;
	a90[8] = 0;
	a90[9] = 0;
	a90[10] = 0;
	a90[11] = 0;
	a90[12] = 0;
	a90[13] = 0;
	v_c[0] = -20;
	v_c[1] = -40;
	v_c[2] = -60;
	v_c[3] = -80;
	v_c[4] = -60;
	v_c[5] = -40;
	v_c[6] = -20;
	v_c[7] = 0;
	v_c[8] = 20;
	v_c[9] = 40;
	v_c[10] = 60;
	v_c[11] = 80;
	v_c[12] = 100;
	v_c[13] = 120;
	 
	localparam  RESET = 6'd0,
	                INIT_MAP = 6'd21
	
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
		if (SW[17]) state = RESET; // reset

		case (state)
		
		INIT_MAP: begin
		    write_enable = 1'd1;

			if (x_coordinate < 8'd160) begin
			    // 1st Map: 3 rectangular mountains 15 pixels tall, each spaced 20 pixels apart
			    if ((x_coordinate >= 8'd20 && x_coordinate < 8'd40) || (x_coordinate >= 8'd60 && x_coordinate < 8'd80) || (x_coordinate >= 8'd100 && x_coordinate < 8'd120)) y_coordinate = 8'd119 - 8'd15
			    else y_coordinate = 8'd119
				
				x_coordinate = x_coordinate + 1'b1;
			end
			else begin
		        write_enable = 1'd0; // turn off write_enabe so we can call values later
		        state = DRAW_MAP; //next, draw map on screen
		    end
		end
		
		DRAW_MAP: begin
		    if (draw_counter < 17'b10000000000000000) begin
		        x_coordinate = draw_counter[7:0]; // lets us pull from RAM
		        if (draw_counter[16:8] > ground_height_at_x) colour = 3'b111; // set ground colour
		        else colour = 3'b000; // sky colour
		        
		        x = draw_counter[7:0]; // draw em
				y = draw_counter[16:8];
		        
		    end
		    else begin
		        draw_counter = 8'd0;
		        state = INIT_TANK_1;
		    end
		end
		
		RESET: begin
			write_enable = 1'd1; // enable drawing here
			shell_y_direction = 1'd0;
			fired = 1'd0;
			
			if (draw_counter < 17'b10000000000000000) begin
				colour = 3'b000;
				x = draw_counter[7:0];
				y = draw_counter[16:8];
				draw_counter = draw_counter + 1'b1;
			end
			else begin
				draw_counter= 8'b00000000;
				state = INIT_MAP;
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
			if (frame && ~firing) state = ERASE_TANK_1;
			else if (slow_frame) state = ERASE_SHELL;
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

		UPDATE_TANK_1: begin // moving player 1's tank in program stored values

			if (~pTurn && fuel != 5'd0) begin
			    x_coordinate = tank1_x;
			    // tank is standing on solid ground: reset jump so can jump top full capacity again
				if (KEY[3] && tank1_y == ground_height_at_x) jump_capacity = 4d'20;
				    
				// tank falling after jump or just walked off cliff edge: while above ground, lower tank onto ground
				else if ((KEY[3] || jump_capacity == 4'd0) && tank1_y < ground_height_at_x) begin
				    jump_capacity == 4'd0; // cannot jump while falling, but can move left and right
				    tank1_y = tank1_y + 1'b1;
				end
			    
				// tank moves 1 pixel right if next ground is same level or lower
				if (~KEY[1] && tank1_x < 8'd144) begin
				    x_coordinate = tank1_x + 1'b1;
				    if (ground_height_at_x >= tank1_x) begin
					    tank1_x = tank1_x + 1'b1;
					    fuel = fuel - 1'b1;
					end
				end
				// tank moves 1 pixel left if next ground is same level or lower
				if (~KEY[2] && tank1_x > 8'd0) begin
				    x_coordinate = tank1_x - 1'b1;
				    if (ground_height_at_x >= tank1_x) begin
					    tank1_x = tank1_x - 1'b1;
					    fuel = fuel - 1'b1;
					end
				end
				// tank is in process of jumping up
				if (~KEY[3] && jump_capacity > 4'd0) begin
					tank1_y = tank1_y - 1'b1;
					jump_capacity = jump_capacity- 1'b1;
					fuel = fuel - 1'b1;
				end
				
				// tank was at bottom of screen, then walked under the floating ground: teleport up 
				// this is super stupid so delete it
				// if (tank1_y > ground_height_at_x && tank1_x > 8'd80) tank1_y = (ground_height_at_x);
			end
			
			state = DRAW_TANK_1; // now update tank's position on the screen
		end
		
		UPDATE_TANK_2: begin
		
			if (pTurn && fuel != 5'd0) begin
				x_coordinate = tank2_x;
			    // tank is standing on solid ground: reset jump so can jump top full capacity again
				if (KEY[3] && tank2_y == ground_height_at_x) jump_capacity = 4d'20;
				    
				// tank falling after jump or just walked off cliff edge: while above ground, lower tank onto ground
				else if ((KEY[3] || jump_capacity == 4'd0) && tank2_y < ground_height_at_x) begin
				    jump_capacity == 4'd0; // cannot jump while falling, but can move left and right
				    tank2_y = tank2_y + 1'b1;
				end
			    
				// tank moves 1 pixel right if next ground is same level or lower
				if (~KEY[1] && tank2_x < 8'd144) begin
				    x_coordinate = tank2_x + 1'b1;
				    if (ground_height_at_x >= tank2_x) begin
					    tank2_x = tank2_x + 1'b1;
					    fuel = fuel - 1'b1;
					end
				end
				// tank moves 1 pixel left if next ground is same level or lower
				if (~KEY[2] && tank2_x > 8'd0) begin
				    x_coordinate = tank2_x - 1'b1;
				    if (ground_height_at_x >= tank2_x) begin
					    tank2_x = tank2_x - 1'b1;
					    fuel = fuel - 1'b1;
					end
				end
				// tank is in process of jumping up
				if (~KEY[3] && jump_capacity > 4'd0) begin
					tank2_y = tank2_y - 1'b1;
					jump_capacity = jump_capacity- 1'b1;
					fuel = fuel - 1'b1;
				end
			end
			
			state = DRAW_TANK_2;
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
				state = UPDATE_TANK_2;
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

		SHELL_FIRED: begin
			if(~KEY[0]) begin
				angle = SW[5:0];
				always @(*)
					case
						6'b000000, 6'b100011: para = a0;
						6'b000001, 6'b100001: para = a5;
						6'b000010, 6'b100010: para = a10;
						6'b000011, 6'b100001: para = a15;
						6'b000100, 6'b100000: para = a20;
						6'b000101, 6'b011111: para = a25;
						6'b000110, 6'b011110: para = a30;
						6'b000111, 6'b011101: para = a35;
						6'b001000, 6'b011100: para = a40;
						6'b001001, 6'b011011: para = a45;
						6'b001010, 6'b011010: para = a50;
						6'b001011, 6'b011001: para = a55;
						6'b001100, 6'b011000: para = a60;
						6'b001101, 6'b010111: para = a65;
						6'b001110, 6'b010110: para = a70;
						6'b001111, 6'b010101: para = a75;
						6'b010000, 6'b010100: para = a80;
						6'b010001, 6'b010011: para = a85;
						default: para = a90
				firing = 1'd1;
				i = 1'b0;
				if(angle > 18) dir = -1;
				else dir = 1;
				if(20 >= angle >= 16) || (angle >= 36) spec = 1'b1;
				else spec = 1'b0;
			end
			state = ERASE_SHELL;
		end

		ERASE_SHELL: begin
			colour = 3'b000;
			x = shell_x;
			y = shell_y;
			
			state = UPDATE_SHELL;
		end

		UPDATE_SHELL: begin // update this to just shoot the projectile
			if (firing) begin
				if((spec) && (i == 14)) || ((~spec) && (i == 32) state = MISS;
				if(spec) begin
					proj_x = shell_x + para[i]*dir;
					proj_y = shell_y + v_c[i];
				end
				else begin
					proj_x = shell_x + 5*dir*(i+1);
					proj_y = shell_y + para[i];
				end
				state = CHECK_SHELL;
			end
			else begin
				shell_y_direction = 1'd0; // set shell to go up
				
				if (~pTurn) begin
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

		CHECK_SHELL: begin
			if(proj_x < 0) || (proj_x > 160) || (proj_y > 120) state = miss;
			if(proj_y > /*RAM get at curr proj_x*/) state = miss;
			if(proj_y < 0) begin
				i = i + 5;
				state = UPDATE_SHELL;
			end
			if(tank1_x <= proj_x <= tank1_x + 5) && (proj_y > tank1_y - 3) state = HIT_T1;
			if(tank2_x <= proj_x <= tank2_x + 5) && (proj_y > tank2_y - 3) state = HIT_T2;
			state = DRAW_SHELL;
		end

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
			state = UPDATE_BLOCK_1;
		end

		HIT_T1: begin
			p1_H = p1_H - 1;
			if(p1_H == 0) state = DEAD;
			state = MISS;
		end

		HIT_T2: begin
			p2_H = p2_H - 1;
			if(p2_H == 0) state = DEAD;
			state = MISS;
		end

		MISS: begin
			// since there is no more manual turn switch, everything happens here
			jump_capacity = 4'd10; // reset them here temporarily
			fuel = 5'd30;
			firing = 1'b0;
			pTurn = ~pTurn;
			state = WAIT;
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

module slowRateDivider (input clock, output clk);
reg [23:0] slow_frame_counter;
reg slow_frame;
	always@(posedge clock)
    begin
        if (slow_frame_counter == 24'b00000000000000000000) begin
		  slow_frame_counter = 24'b100110001001011010000000;
		  slow_frame = 1'b1;
		  end
        else begin
			slow_frame_counter = slow_frame_counter - 1'b1;
			slow_frame = 1'b0;
		  end
    end
	 assign clk = slow_frame;
endmodule


/*if (~shell_x_direction) shell_x = shell_x + 1'b1;
else shell_x = shell_x - 1'b1;
if (shell_y_direction) shell_y = shell_y + 1'b1;
else shell_y = shell_y - 1'b1;

if ((shell_x == 8'd0) || (shell_x == 8'd160)) shell_x_direction = ~shell_x_direction; // bounce around the board
if ((shell_y >= 8'd120) || (shell_y == 8'd0)) shell_y_direction = ~shell_y_direction;

if ( ((shell_y > tank1_y - 8'd2) && (shell_y < tank1_y + 8'd3) && (shell_x >= tank1_x) && (shell_x <= tank1_x + 8'd15)) ||
((shell_y > tank2_y - 8'd2) && (shell_y < tank2_y + 8'd3) && (shell_x >= tank2_x) && (shell_x <= tank2_x + 8'd15))	) state = DEAD; // kill if touch tank
else state = DRAW_SHELL;*/
