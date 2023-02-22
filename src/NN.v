//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   2021 ICLAB Spring Course
//   Lab04			: Artificial Neural Network (NN)
//   Author         : Shiuan-Yun Ding (mirkat.ding@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : NN.v
//   Module Name : NN
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
// synopsys translate_off
/*
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_add.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_sub.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v"
`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_mult.v"
*/
// synopsys translate_on
module NN(
	// Input signals
	clk,
	rst_n,
	in_valid_d,
	in_valid_t,
	in_valid_w1,
	in_valid_w2,
	data_point,
	target,
	weight1,
	weight2,
	// Output signals
	out_valid,
	out
);

input clk,rst_n,in_valid_d,in_valid_t,in_valid_w1,in_valid_w2;
input [31:0] data_point,target,weight1,weight2;
output out_valid;
output [31:0] out;

//parameter
localparam IDLE   = 3'b000;
localparam   BW   = 3'b001;
localparam   WB   = 3'b010;
localparam   OUT  = 3'b100;

parameter LEARNING_RATE = 32'h3A83126F; 
parameter FP_ZERO = 32'b0_0000_0000_00000000000000000000000 ;
parameter STATE = 3;
parameter DATA_LENGTH = 32;

integer i;

//wire
wire [DATA_LENGTH-1:0] m_out_1_wire,m_out_2_wire,m_out_3_wire;
wire [DATA_LENGTH-1:0] S_A_1_wire,S_A_2_wire,S_A_3_wire;

//reg
reg [STATE-1:0] current_state,next_state;
reg [1:0] counter_reg_state,counter_reg_data;

//reg_combination
reg [DATA_LENGTH-1:0] in_S_A_b1_reg,in_S_A_b2_reg,in_S_A_b3_reg;
reg [DATA_LENGTH-1:0] in_S_A_a1_reg,in_S_A_a2_reg,in_S_A_a3_reg;
reg [DATA_LENGTH-1:0] in_M_a1_reg,in_M_a2_reg,in_M_a3_reg;
reg [DATA_LENGTH-1:0] in_M_b1_reg,in_M_b2_reg,in_M_b3_reg;
reg [2:0]  in_S_A_op_reg;

//data's reg
reg [DATA_LENGTH-1:0] weight1_reg [0:11];
reg [DATA_LENGTH-1:0] weight2_reg [0:2];
reg [DATA_LENGTH-1:0] data_point_reg [0:3];
reg [DATA_LENGTH-1:0] target_reg;

//temp's reg
reg [2:0] grd_reg ;//gradient
reg [DATA_LENGTH-1:0] y_reg [0:2];
reg [DATA_LENGTH-1:0] delta_2;
reg [DATA_LENGTH-1:0] mul_reg [0:2];
reg [DATA_LENGTH-1:0] out_reg;

//output
assign out_valid = current_state[STATE-1] & counter_reg_state == 2'd1 ? 1 : 0;
assign out = current_state[STATE-1] & counter_reg_state == 2'd1 ? out_reg : FP_ZERO;

//flag
wire bw_start = counter_reg_state ==  'd3 & in_valid_d ;//may be merge
wire wb_bw_done  = counter_reg_state ==  'd3;
wire out_done = counter_reg_state == 'd2;

//================================================================
//  FSM
//================================================================ 

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		current_state <= IDLE;
	end 
	else begin
		current_state <= next_state;
	end
end

always @(*) begin 
	case (current_state)
		IDLE : next_state = bw_start    ? BW   : IDLE;
		 BW  : next_state = wb_bw_done  ? WB   : BW;
		 WB  : next_state = wb_bw_done  ? OUT  : WB; 
		 OUT : next_state = out_done    ? IDLE : OUT; 
		default : next_state = IDLE;
	endcase
end

//================================================================
//  counter
//================================================================

//counter_reg_state
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		counter_reg_state <= 'd0;
	end 
	else begin
		case (current_state)
			IDLE  : counter_reg_state <= in_valid_d | in_valid_w1 ? counter_reg_state + 'd1 : 'd0;
			 BW   : counter_reg_state <= counter_reg_state + 'd1 ;
			 WB   : counter_reg_state <= counter_reg_state + 'd1 ;
			 OUT  : counter_reg_state <= out_done ? 'd0 : counter_reg_state + 'd1 ;
			default : counter_reg_state <= 'd0;
		endcase
	end
end

//counter_reg_data
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		counter_reg_data <= 'd0;
	end 
	else begin
		if(current_state == IDLE) begin
			if(counter_reg_state == 'd3) begin
				counter_reg_data <= counter_reg_data + 'd1;
			end
			else begin
				counter_reg_data <= counter_reg_data;
			end
		end
		else begin
			counter_reg_data <= 'd0;
		end
	end
end

//================================================================
//  data storage
//================================================================

//weight1_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		for(i=0;i<12;i=i+1) begin
			weight1_reg[i] <= FP_ZERO;
		end
	end 
	else begin
		if(in_valid_w1) begin
			case (counter_reg_data)
				'd0:weight1_reg[counter_reg_state] <= weight1;
				'd1:weight1_reg[counter_reg_state + 4] <= weight1;
				'd2:weight1_reg[counter_reg_state + 8] <= weight1;
				default : weight1_reg[0] <= weight1_reg[0];
			endcase
		end
		else if(current_state[1] & counter_reg_state == 'd3) begin
			weight1_reg[0] <= S_A_1_wire;
			weight1_reg[4] <= S_A_2_wire;
			weight1_reg[8] <= S_A_3_wire;
		end
		else if(current_state[2]) begin
			case (counter_reg_state)
				 'd0:
				 begin
				 weight1_reg[1] <= S_A_1_wire;
				 weight1_reg[5] <= S_A_2_wire;
				 weight1_reg[9] <= S_A_3_wire;
				 end
				 'd1:
				 begin
				 weight1_reg[2]  <= S_A_1_wire;
				 weight1_reg[6]  <= S_A_2_wire;
				 weight1_reg[10] <= S_A_3_wire;
				 end
				 'd2:
				 begin
				 weight1_reg[3]  <= S_A_1_wire;
				 weight1_reg[7]  <= S_A_2_wire;
				 weight1_reg[11] <= S_A_3_wire;
				 end
				default : weight1_reg[0] <= weight1_reg[0];
			endcase
		end
		else begin
			weight1_reg[0] <= weight1_reg[0];
		end
	end
end

//weight2_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		for(i=0;i<3;i=i+1) begin
			weight2_reg[i] <= FP_ZERO;
		end
	end 
	else begin
		if(in_valid_w2) begin
			weight2_reg[counter_reg_state] <= weight2;
		end
		else if(current_state[1] & counter_reg_state == 'd0) begin
			weight2_reg[0] <= S_A_1_wire;
			weight2_reg[1] <= S_A_2_wire;
			weight2_reg[2] <= S_A_3_wire;
		end
		else begin
			weight2_reg[0] <= weight2_reg[0];
		end
	end
end

//data_point_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		for(i=0;i<4;i=i+1) begin
			data_point_reg[i] <= FP_ZERO;
		end
	end 
	else begin 
		if(in_valid_d) begin
			data_point_reg[counter_reg_state] <= data_point;
		end
		else begin
			data_point_reg[0] <= data_point_reg[0];
		end
	end
end

//target_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		target_reg <= FP_ZERO;
	end 
	else begin
		target_reg <= in_valid_t ? target : target_reg;
	end
end

//out_reg
always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		out_reg <= FP_ZERO;
	end 
	else begin
		if(current_state[0] && counter_reg_state == 'd2) begin
			out_reg <= mul_reg[2];
		end
		else if(current_state[0] && counter_reg_state == 'd3) begin
			out_reg <= S_A_1_wire;
		end
	end
end

//================================================================
//  temp storage
//================================================================

//mul_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		for(i=0;i<3;i=i+1) begin
			mul_reg[i] <= FP_ZERO;
		end	
	end
	else if(current_state[1] & counter_reg_state == 'd0) begin
		mul_reg[0] <= grd_reg[0] ? m_out_1_wire : FP_ZERO;
		mul_reg[1] <= grd_reg[1] ? m_out_2_wire : FP_ZERO;
		mul_reg[2] <= grd_reg[2] ? m_out_3_wire : FP_ZERO;
	end
	else begin
		mul_reg[0] <= m_out_1_wire;
		mul_reg[1] <= m_out_2_wire;
		mul_reg[2] <= m_out_3_wire;
	end
end

//y_reg  RELU 
always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		for(i=0;i<3;i=i+1) begin
			y_reg[i] <= FP_ZERO;
		end	
	end 
	else begin
		if(in_valid_d) begin
			y_reg[0] <= S_A_1_wire;
			y_reg[1] <= S_A_2_wire;
			y_reg[2] <= S_A_3_wire;
		end
		else if(current_state[0] & counter_reg_state == 'd0) begin
			y_reg[0] <= S_A_1_wire[31] ? FP_ZERO : S_A_1_wire;
			y_reg[1] <= S_A_2_wire[31] ? FP_ZERO : S_A_2_wire;
			y_reg[2] <= S_A_3_wire[31] ? FP_ZERO : S_A_3_wire;
		end
		else if(current_state[0] & counter_reg_state == 'd2) begin
			y_reg[0] <= S_A_1_wire;
		end
		else if(current_state[1] & counter_reg_state == 'd2) begin
			y_reg[0] <= mul_reg[0];
			y_reg[1] <= mul_reg[1];
			y_reg[2] <= mul_reg[2];
		end
	    else if(current_state[2] & counter_reg_state == 2'd2) begin
			for(i=0;i<3;i=i+1) begin
				y_reg[i] <= FP_ZERO;
			end	
	    end
		else begin
			y_reg[0] <= y_reg[0];
		end
	end
end


//grd_reg
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		grd_reg <= 'd0;
	end 
	else begin
		if(current_state[0] & counter_reg_state == 'd0) begin
			grd_reg[0] <= S_A_1_wire[31] ? 0 : 1;
			grd_reg[1] <= S_A_2_wire[31] ? 0 : 1;
			grd_reg[2] <= S_A_3_wire[31] ? 0 : 1;
		end
		else begin
			grd_reg <= grd_reg;
		end
	end
end

//delta_2
always @(posedge clk or negedge rst_n) begin 
	if(~rst_n) begin
		delta_2 <= FP_ZERO;
	end 
	else begin
		if(current_state[0] & counter_reg_state == 'd2) begin
			delta_2 <= S_A_3_wire;
		end
		else begin
			delta_2 <= delta_2;
		end
	end
end

//================================================================
//  module IO pin
//================================================================

//in_M_a1_reg
always @(*) begin
	if(in_valid_d) begin
		in_M_a1_reg = data_point;
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_a1_reg = y_reg[0];
			2'd2:in_M_a1_reg = LEARNING_RATE;
			2'd3:in_M_a1_reg = delta_2;
			default : in_M_a1_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_a1_reg = delta_2;
			2'd1:in_M_a1_reg = LEARNING_RATE;
			2'd2:in_M_a1_reg = data_point_reg[0];
			2'd3:in_M_a1_reg = data_point_reg[1];
			default : in_M_a1_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_a1_reg = data_point_reg[2];
			2'd1:in_M_a1_reg = data_point_reg[3];
			default : in_M_a1_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_a1_reg = FP_ZERO;
	end
end

//in_M_a2_reg
always @(*) begin
	if(in_valid_d) begin
		in_M_a2_reg = data_point;
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_a2_reg = y_reg[1];
			2'd2:in_M_a2_reg = LEARNING_RATE;
			2'd3:in_M_a2_reg = delta_2;
			default : in_M_a2_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_a2_reg = delta_2;
			2'd1:in_M_a2_reg = LEARNING_RATE;
			2'd2:in_M_a2_reg = data_point_reg[0];
			2'd3:in_M_a2_reg = data_point_reg[1];
			default : in_M_a2_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_a2_reg = data_point_reg[2];
			2'd1:in_M_a2_reg = data_point_reg[3];
			default : in_M_a2_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_a2_reg = FP_ZERO;
	end
end

//in_M_a3_reg
always @(*) begin
	if(in_valid_d) begin
		in_M_a3_reg = data_point;
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_a3_reg = y_reg[2];
			2'd2:in_M_a3_reg = LEARNING_RATE;
			2'd3:in_M_a3_reg = delta_2;
			default : in_M_a3_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_a3_reg = delta_2;
			2'd1:in_M_a3_reg = LEARNING_RATE;
			2'd2:in_M_a3_reg = data_point_reg[0];
			2'd3:in_M_a3_reg = data_point_reg[1];
			default : in_M_a3_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_a3_reg = data_point_reg[2];
			2'd1:in_M_a3_reg = data_point_reg[3];
			default : in_M_a3_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_a3_reg = FP_ZERO;
	end
end

//in_M_b1_reg
always @(*) begin
	if(in_valid_d) begin
		case (counter_reg_state)
			2'd0:in_M_b1_reg = weight1_reg[0];
			2'd1:in_M_b1_reg = weight1_reg[1];
			2'd2:in_M_b1_reg = weight1_reg[2];
			2'd3:in_M_b1_reg = weight1_reg[3];
			default : in_M_b1_reg = FP_ZERO;
		endcase	
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_b1_reg = weight2_reg[0];
			2'd2:in_M_b1_reg = y_reg[0];
			2'd3:in_M_b1_reg = mul_reg[0];
			default : in_M_b1_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_b1_reg = weight2_reg[0];
			2'd1:in_M_b1_reg = mul_reg[0];
			2'd2:in_M_b1_reg = mul_reg[0];
			2'd3:in_M_b1_reg = y_reg[0];
			default : in_M_b1_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_b1_reg = y_reg[0];
			2'd1:in_M_b1_reg = y_reg[0];
			default : in_M_b1_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_b1_reg = FP_ZERO;
	end
end

//in_M_b2_reg
always @(*) begin
	if(in_valid_d) begin
		case (counter_reg_state)
			2'd0:in_M_b2_reg = weight1_reg[4];
			2'd1:in_M_b2_reg = weight1_reg[5];
			2'd2:in_M_b2_reg = weight1_reg[6];
			2'd3:in_M_b2_reg = weight1_reg[7];
			default : in_M_b2_reg = FP_ZERO;
		endcase	
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_b2_reg = weight2_reg[1];
			2'd2:in_M_b2_reg = y_reg[1];
			2'd3:in_M_b2_reg = mul_reg[1];
			default : in_M_b2_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_b2_reg = weight2_reg[1];
			2'd1:in_M_b2_reg = mul_reg[1];
			2'd2:in_M_b2_reg = mul_reg[1];
			2'd3:in_M_b2_reg = y_reg[1];
			default : in_M_b2_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_b2_reg = y_reg[1];
			2'd1:in_M_b2_reg = y_reg[1];
			default : in_M_b2_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_b2_reg = FP_ZERO;
	end
end

//in_M_b3_reg
always @(*) begin
	if(in_valid_d) begin
		case (counter_reg_state)
			2'd0:in_M_b3_reg = weight1_reg[8];
			2'd1:in_M_b3_reg = weight1_reg[9];
			2'd2:in_M_b3_reg = weight1_reg[10];
			2'd3:in_M_b3_reg = weight1_reg[11];
			default : in_M_b3_reg = FP_ZERO;
		endcase	
	end
	else if(current_state[0]) begin
		case (counter_reg_state)
			2'd1:in_M_b3_reg = weight2_reg[2];
			2'd2:in_M_b3_reg = y_reg[2];
			2'd3:in_M_b3_reg = mul_reg[2];
			default : in_M_b3_reg = FP_ZERO;
		endcase
	end
	else if(current_state[1]) begin
		case (counter_reg_state)
			2'd0:in_M_b3_reg = weight2_reg[2];
			2'd1:in_M_b3_reg = mul_reg[2];
			2'd2:in_M_b3_reg = mul_reg[2];
			2'd3:in_M_b3_reg = y_reg[2];
			default : in_M_b3_reg = FP_ZERO;
		endcase
	end
	else if(current_state[2]) begin
		case (counter_reg_state)
			2'd0:in_M_b3_reg = y_reg[2];
			2'd1:in_M_b3_reg = y_reg[2];
			default : in_M_b3_reg = FP_ZERO;
		endcase
	end
	else begin
		in_M_b3_reg = FP_ZERO;
	end
end

//in_S_A_b1_reg
always @(*) begin
	if(current_state[0] && counter_reg_state == 'd3) begin
		in_S_A_b1_reg = y_reg[0];
	end
	else begin
		in_S_A_b1_reg = mul_reg[0];
	end
end

//in_S_A_b2_reg
always @(*) begin
	if(current_state[0] && counter_reg_state == 'd2) begin
		in_S_A_b2_reg = target_reg;
	end
	else begin
		in_S_A_b2_reg = mul_reg[1];
	end
end

//in_S_A_b3_reg
always @(*) begin
	if(current_state[0] && counter_reg_state == 'd2) begin
		in_S_A_b3_reg = S_A_1_wire;
	end
	else begin
		in_S_A_b3_reg = mul_reg[2];
	end
end

//in_S_A_a1_reg
always @(*) begin
	if(current_state[0] & counter_reg_state == 'd2) begin
		in_S_A_a1_reg = mul_reg[1];
	end
	else if(current_state[0] & counter_reg_state == 'd3) begin
		in_S_A_a1_reg = out_reg;
	end
	else if(current_state[1] & counter_reg_state == 2'd0) begin
		in_S_A_a1_reg = weight2_reg[0];
	end
	else if(current_state[1] & counter_reg_state == 2'd3) begin
		in_S_A_a1_reg = weight1_reg[0];
	end
	else if(current_state[2])begin
		case (counter_reg_state)
			2'd0:in_S_A_a1_reg = weight1_reg[1];
			2'd1:in_S_A_a1_reg = weight1_reg[2];
			2'd2:in_S_A_a1_reg = weight1_reg[3];
			default : in_S_A_a1_reg = FP_ZERO;
		endcase
	end
	else begin
		in_S_A_a1_reg = y_reg[0];
	end
end

//in_S_A_a2_reg
always @(*) begin
	if(current_state[0] & counter_reg_state == 'd2) begin
		in_S_A_a2_reg = mul_reg[2];
	end
	else if(current_state[1] & counter_reg_state == 2'd0) begin
		in_S_A_a2_reg = weight2_reg[1];
	end
	else if(current_state[1] & counter_reg_state == 2'd3) begin
		in_S_A_a2_reg = weight1_reg[4];
	end
	else if(current_state[2])begin
		case (counter_reg_state)
			2'd0:in_S_A_a2_reg = weight1_reg[5];
			2'd1:in_S_A_a2_reg = weight1_reg[6];
			2'd2:in_S_A_a2_reg = weight1_reg[7];
			default : in_S_A_a2_reg = FP_ZERO;
		endcase
	end
	else begin
		in_S_A_a2_reg = y_reg[1];
	end
end

//in_S_A_a3_reg
always @(*) begin
	if(current_state[0] && counter_reg_state == 'd2) begin
		in_S_A_a3_reg = S_A_2_wire;
	end
	else if(current_state[1] & counter_reg_state == 2'd0) begin
		in_S_A_a3_reg = weight2_reg[2];
	end
	else if(current_state[1] & counter_reg_state == 2'd3) begin
		in_S_A_a3_reg = weight1_reg[8];
	end
	else if(current_state[2])begin
		case (counter_reg_state)
			2'd0:in_S_A_a3_reg = weight1_reg[9];
			2'd1:in_S_A_a3_reg = weight1_reg[10];
			2'd2:in_S_A_a3_reg = weight1_reg[11];
			default : in_S_A_a3_reg = FP_ZERO;
		endcase
	end
	else begin
		in_S_A_a3_reg = y_reg[2];
	end
end

//in_S_A_op_reg
always @(*) begin 
	if(current_state[0] & counter_reg_state == 'd2) begin
		in_S_A_op_reg = 3'b010;
	end
	else if(current_state[1] & counter_reg_state == 2'd0) begin
		in_S_A_op_reg = 3'b111;
	end
	else if(current_state[1] & counter_reg_state == 2'd3) begin
		in_S_A_op_reg = 3'b111;
	end
	else if(current_state[2]) begin
		in_S_A_op_reg = 3'b111;
	end
	else begin
		in_S_A_op_reg = 3'b000;
	end
end

//================================================================
//  module initailize
//================================================================

DW_fp_addsub_inst S_A_1 (.inst_a(in_S_A_a1_reg), .inst_b(in_S_A_b1_reg) , .inst_rnd(3'b000), .inst_op(in_S_A_op_reg[0]), .z_inst(S_A_1_wire) );
DW_fp_addsub_inst S_A_2 (.inst_a(in_S_A_a2_reg), .inst_b(in_S_A_b2_reg) , .inst_rnd(3'b000), .inst_op(in_S_A_op_reg[1]), .z_inst(S_A_2_wire) );
DW_fp_addsub_inst S_A_3 (.inst_a(in_S_A_a3_reg), .inst_b(in_S_A_b3_reg) , .inst_rnd(3'b000), .inst_op(in_S_A_op_reg[2]), .z_inst(S_A_3_wire) );

DW_fp_mult_inst M1 (.inst_a(in_M_a1_reg), .inst_b(in_M_b1_reg) , .inst_rnd(3'b000), .z_inst(m_out_1_wire) );
DW_fp_mult_inst M2 (.inst_a(in_M_a2_reg), .inst_b(in_M_b2_reg) , .inst_rnd(3'b000), .z_inst(m_out_2_wire) );
DW_fp_mult_inst M3 (.inst_a(in_M_a3_reg), .inst_b(in_M_b3_reg) , .inst_rnd(3'b000), .z_inst(m_out_3_wire) );

endmodule

//================================================================
//  SUBMODULE : DesignWare
//================================================================

module DW_fp_addsub_inst (inst_a, inst_b , inst_rnd, inst_op, z_inst);

parameter sig_width = 23;      // RANGE 2 TO 253
parameter exp_width = 8;       // RANGE 3 TO 31
parameter ieee_compliance = 0; // RANGE 0 TO 1                  

// declaration of inputs and outputs
input  [sig_width+exp_width:0] inst_a,inst_b;
input  inst_op;
input  [2:0] inst_rnd;
output [sig_width+exp_width:0] z_inst;

DW_fp_addsub #(sig_width, exp_width, ieee_compliance)
	U1(	.a(inst_a),
		.b(inst_b),
		.rnd(inst_rnd),
		.op(inst_op),
		.z(z_inst) );

endmodule

module DW_fp_mult_inst (inst_a, inst_b , inst_rnd, z_inst);

parameter sig_width = 23;      // RANGE 2 TO 253
parameter exp_width = 8;       // RANGE 3 TO 31
parameter ieee_compliance = 0; // RANGE 0 TO 1

// declaration of inputs and outputs
input  [exp_width + sig_width:0] inst_a;
input  [exp_width + sig_width:0] inst_b;
input  [2:0] inst_rnd;
output [exp_width + sig_width:0] z_inst;
//Instance of DW_fp_mult

DW_fp_mult #(sig_width, exp_width, ieee_compliance)
	U1(	.a(inst_a),
		.b(inst_b),
		.rnd(inst_rnd),
		.z(z_inst) );

endmodule
