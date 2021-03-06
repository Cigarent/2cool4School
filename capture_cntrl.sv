//TODO: need to output ram_addr for the cmd_cfg block
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
	
	//NOTE: Changed these signals from LOG2:0 to LOG2-1:0
	//FIXME: trig_pos needs to be fixed. The vector lengths dont add up
	logic [LOG2-1:0] trig_pos; // combine H and L together
	logic [LOG2-1:0] smpl_cnt;
	logic [LOG2-1:0] trig_cnt;
	logic set_armed;
	logic clr_armded;
	
	assign armed = clr_armded ? 1'b0 : (set_armed ? 1'b1 : armed); 

	//FIXME: what is [LOG2-8:0]? If it's just {trig_posH, trig_posL} then its just 16 bits
	//so trig_pos would need to be declared as [15:0] instead of LOG2-1:0
	assign trig_pos = {trig_posH[LOG2-8:0], trig_posL};
	
	//main FSM		 
 	typedef enum reg [2:0] {IDLE, RUN, TRIG, SMPL, DONE} state_t; 
 	state_t state, nxt_state; 
 	 
 	always_ff @ (posedge clk, negedge rst_n) begin 
 		if(!rst_n) 
 			state <= IDLE; 
 		else 
 			state <= nxt_state; 
 	end 
	
	always_comb begin
	set_capture_done = 1'b0;

	case(state)
		IDLE: 	if (run) begin
					smpl_cnt = 16'b0000_0000_0000_000;
					trig_cnt = 16'b0000_0000_0000_000;
					nxt_state = RUN;
				end else	
					nxt_state = IDLE;
		
		RUN: 	if (wrt_smpl) begin
					we = 1;
					nxt_state = TRIG;
					if (waddr < ENTRIES - 1)
						waddr = waddr + 1;
					else
						waddr = 0;
					if(triggered) begin
						trig_cnt = trig_cnt + 1;
						nxt_state = TRIG;
					end else begin
						smpl_cnt = smpl_cnt + 1;
						nxt_state = SMPL;
					end
				end else 
					nxt_state = RUN;
				
		TRIG:	if (trig_cnt == trig_pos) begin
					set_capture_done = 1'b1;
					clr_armded = 1'b1;
					nxt_state = DONE;
				end else
					nxt_state = RUN;
				
		SMPL:	if (smpl_cnt + trig_pos == ENTRIES) begin
					set_armed = 1;
				end  
				nxt_state = RUN;
	
		DONE:	if (capture_done)
					nxt_state = DONE;
				else
					nxt_state = IDLE;
	
	endcase//endcase state
	end
	
	
	
	
endmodule
