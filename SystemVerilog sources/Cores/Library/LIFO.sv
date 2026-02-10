module LIFO #(DataWidth=32)(
			input wire RESET, CLK, PUSH, POP,
			input wire [DataWidth-1:0] DTI,
			output reg [DataWidth-1:0] DTO
			);

logic [3:0] ptr=0;

reg [DataWidth-1:0] ram [0:15];

always_ff @(posedge CLK or negedge RESET)
if (~RESET)
	begin
	ptr<=0;
	end
else begin

// data register
DTO<=ram[ptr];

// ram pointer
if (PUSH) ptr<=ptr+1'b1;
	else if (POP) ptr<=ptr-1'b1;
	
// write to the ram
if (PUSH) ram[ptr+1]<=DTI;

end

endmodule
