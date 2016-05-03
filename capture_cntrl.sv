module capture_cntrl(clk, rst_n, wrt_smpl, we, waddr, trig_posH, trig_posL, run, triggered, 
			capture_done, armed, set_capture_done);

	parameter ENTRIES = 384, LOG2 = 9;	

	input clk, rst_n;					//system clk and rst
	input wrt_smpl;						//wrt_smpl signal from Capture Logic
	input [7:0] trig_posH, trig_posL; 	//trig_pos from cmd_cfg
	input triggered;					//triggered from triggerd logic
	input run;							//bit 4 from Trigcfg from cmd_cfg
	input capture_done;					//bit 5 from Trigcfg from cmd_cfg
	
	output logic [LOG2-1:0] waddr; 		//write address to RAM
	output logic we; 					//write enable to RAM
	output logic armed;					//output armed to trigger logic
	output logic set_capture_done;		//output set_capture_done to cmd_cfg;
	
	logic [15:0] trig_pos; 				// combine H and L together
	logic [15:0] smpl_cnt;
	logic smpl_cnt_rst, smpl_cnt_inc;
	logic [15:0] trig_cnt;
	logic trig_cnt_rst, trig_cnt_inc;
	logic set_armed, clr_armed;
	logic waddr_inc, waddr_rst;
	
	assign trig_pos = {trig_posH, trig_posL};
		/****8
	assign trig_cnt = trig_cnt_rst ? 0 : (trig_cnt_inc ? trig_cnt + 1 : trig_cnt);

	assign smpl_cnt = smpl_cnt_rst ? 0 : (smpl_cnt_inc ? smpl_cnt + 1 : smpl_cnt);

	assign waddr = waddr_rst ? 0 : (waddr_inc ? waddr + 1 : waddr);
	****/
	always_ff @ (posedge clk, negedge rst_n) begin 
 		if(!rst_n) 
 			armed <= 1'b0; 
 		else if (set_armed)
 			armed <= 1'b1;
		else if(clr_armed)
			armed <= 1'b0;
 	end 	
	
	
	always_ff @ (posedge clk, negedge rst_n) begin 
 		if(!rst_n) 
 			waddr <= 0; 
		else if(waddr_rst) 
 			waddr <= 0; 
 		else if (waddr_inc)
 			waddr <= waddr + 1; 
 	end 
	
	always_ff @ (posedge clk, negedge rst_n) begin 
	 	if(!rst_n) 
 			smpl_cnt <= 0; 
 		else if(smpl_cnt_rst) 
 			smpl_cnt <= 0; 
 		else if (smpl_cnt_inc)
 			smpl_cnt <= smpl_cnt + 1; 
 	end 

	always_ff @ (posedge clk, negedge rst_n) begin
	 	if(!rst_n) 
 			trig_cnt <= 0; 
 		else if(trig_cnt_rst) 
 			trig_cnt <= 0; 
 		else if (trig_cnt_inc)
 			trig_cnt <= trig_cnt + 1; 
 	end 
	
	
	//main FSM		 
 	typedef enum reg [2:0] {SMPL, DONE, TRIG, IDLE, RUN} state_t; 
 	state_t state, nxt_state; 
 	 
 	always_ff @ (posedge clk, negedge rst_n) begin 
 		if(!rst_n) 
 			state <= IDLE; 
 		else 
 			state <= nxt_state; 
 	end 
	
	always_comb begin
		set_capture_done = 0;
		nxt_state = IDLE;
		we = 0;
		set_armed = 0;
		clr_armed = 0;
		smpl_cnt_rst = 0;
		trig_cnt_rst = 0;
		trig_cnt_inc = 0;
		smpl_cnt_inc = 0;
		waddr_rst = 0;
		waddr_inc = 0;

		case(state)
			IDLE: 	begin
					if (run) begin
						smpl_cnt_rst = 1;
						trig_cnt_rst = 1;
						nxt_state = RUN;
					end else	
						nxt_state = IDLE;
					end

						
			RUN: 	begin
					if (wrt_smpl) begin
						we = 1;
						if (waddr < ENTRIES - 1) 
							waddr_inc = 1;
						else 
							waddr_rst = 1;
							
					if(triggered) begin
						trig_cnt_inc = 1;
						nxt_state = TRIG;
					end else begin
						smpl_cnt_inc = 1;
						nxt_state = SMPL;
					end
					end	else 
						nxt_state = RUN;
					end
					
			TRIG:	begin
					if (trig_cnt == trig_pos) begin
						we = 1;
						set_capture_done = 1'b1;
						clr_armed = 1'b1;
						nxt_state = DONE;
					end else
						nxt_state = RUN;
					end
					
					
			SMPL:	begin
						nxt_state = RUN;
						if (smpl_cnt + trig_pos == ENTRIES) begin
							set_armed = 1;
						end 
					end
		
			default:begin
					if (capture_done)
						nxt_state = DONE;
					else
						nxt_state = IDLE;
					end
		endcase//endcase state
	end
	
	
	
	
endmodule
