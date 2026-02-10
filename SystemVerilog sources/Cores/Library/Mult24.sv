module Mult24 (
	input wire CLK,
	input wire [23:0] A,B,
	output wire [24:0] R
);

// mantissa
logic [23:0] MA, MB;

// multiplication partial results
reg [47:0] A0B0;

// first stage
reg [47:0] StageA32;

assign R=StageA32[47:23];

always_comb
begin
MA=A[23:0];
MB=B[23:0];
end


always_ff @(posedge CLK)
begin

// create partial multiplication results
A0B0<=MA*MB;

// 32-bit operation
StageA32<=A0B0;

end


endmodule
