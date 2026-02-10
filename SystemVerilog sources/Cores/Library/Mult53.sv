module Mult53 (
	input wire CLK,
	input wire [52:0] A,B,
	output wire [53:0] R
);

// mantissa
logic [52:0] MA, MB;

// multiplication partial results
reg [35:0] A0B0, A1B0, A2B0;
reg [35:0] A0B1, A1B1, A2B1;
reg [35:0] A0B2, A1B2, A2B2;

// first stage
reg [55:0] StageA64_Low;
reg [54:0] StageA64_Medium;
reg [35:0] StageA64_High;

// second stage
reg [71:0] StageB64;

assign R=StageB64[69:16];

always_comb
begin
MA=A;
MB=B;
end


always_ff @(posedge CLK)
begin

// create partial multiplication results
A0B0<=MA[17:0]*MB[17:0];
A1B0<=MA[35:18]*MB[17:0];
A2B0<={1'b0, MA[52:36]}*MB[17:0];

A0B1<=MA[17:0]*MB[35:18];
A1B1<=MA[35:18]*MB[35:18];
A2B1<={1'b0, MA[52:36]}*MB[35:18];

A0B2<=MA[17:0]*{1'b0, MB[52:36]};
A1B2<=MA[35:18]*{1'b0, MB[52:36]};
A2B2<={1'b0, MA[52:36]}*{1'b0, MB[52:36]};

// 64-bit operation
StageA64_Low<={2'd0, A2B0, A0B0[35:18]}+{2'd0, A2B1[17:0], A1B0}+{2'd0, A1B2[17:0], A0B1};
StageA64_Medium<={1'b0, A2B1[35:18], A1B1}+{1'b0, A1B2[35:18], A0B2};
StageA64_High<=A2B2;

StageB64<={StageA64_High, 36'd0}+{17'd0, StageA64_Medium}+{34'd0, StageA64_Low[55:18]};

end


endmodule
