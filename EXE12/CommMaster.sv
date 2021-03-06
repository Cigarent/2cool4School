module CommMaster(clk, rst_n, cmd_cmplt, TX, snd_cmd, cmd);

input[15:0] cmd;
input snd_cmd, clk, rst_n;

output logic cmd_cmplt, TX;
logic sel, trmt, tx_done;
logic [7:0] tx_data, ff_low_bit;

///////////instantiate UART transmitor module///////////
UART_tx iDUT_tx(.clk(clk), .rst_n(rst_n), .TX(TX), .trmt(trmt), .TX_DATA(tx_data),.tx_done(tx_done));

///////////define state machine///////////
typedef enum reg[1:0] {IDLE, SEND_HIGH, SEND_LOW, CMD_SEND} state_t;
state_t state, next_state;

///////////flip flop holding lower bits of the input///////////
always_ff @(posedge clk)
	if (snd_cmd)
		ff_low_bit <= cmd[7:0];
	else
		ff_low_bit <= ff_low_bit;

///////////the mux filtering higher/lower bits of the data///////////
assign tx_data = sel ? cmd[15:8] : ff_low_bit ;		
		
/////////////////  state machine  /////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;

//////////////// state transition logic  /////////////		
always_comb begin
	sel = 0;
	trmt = 0;
	cmd_cmplt = 0;			//initialize all the signal for every loop
	next_state = IDLE;
	
	case (state)
	IDLE: if (snd_cmd) begin
		sel = 1;
		trmt = 1;
		next_state = SEND_HIGH;
	end
	
	SEND_HIGH: if (tx_done) begin // check if higher bits all sent
		trmt = 1;
		next_state = SEND_LOW;
	end else begin
		sel = 1;				 // signal to mux for higher bits
		next_state = SEND_HIGH;
	end
		
	SEND_LOW:if (tx_done) begin  // check if lower bits all sent
		cmd_cmplt = 1;
		next_state = CMD_SEND;
	end else
		next_state = SEND_LOW;
		
	CMD_SEND: if (snd_cmd) begin  // wait until next send signal is asserted
		sel = 1;
		trmt = 1;
		next_state = SEND_HIGH;
	end else begin
		cmd_cmplt = 1;
		next_state = CMD_SEND;
	end
	
	endcase
end

endmodule