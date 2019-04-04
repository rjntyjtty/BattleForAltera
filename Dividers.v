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
