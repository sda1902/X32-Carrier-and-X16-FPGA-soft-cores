module ALU64X32 (
	input wire CLK, ACT,
	input wire [4:0] DSTi,
	input wire [63:0] A,B,D,
	input wire [1:0] SA, SB, SD,
	input wire [2:0] OpCODE,
	
	output reg [63:0] R,
	output reg [15:0] COUT,
	output wire [4:0] DSTo,
	output reg [1:0] SR,
	output wire RDY,
	output reg OVR, Zero, Sign
	);
	
reg [63:0] TempR;
reg [15:0] RA, RB;
reg [63:0] OpA, OpB, OpD;

integer i0, i1;

assign RDY=ACT;
assign DSTo=DSTi;

always @*
begin

// prepare source operands
case (OpCODE)
	// ADDZX
	3'd0:	begin
			case (SA)
				2'd0:	OpA={56'd0, A[7:0]};
				2'd1:	OpA={48'd0, A[15:0]};
				2'd2:	OpA={32'd0, A[31:0]};
				2'd3:	OpA=A;
				endcase
			case (SB)
				2'd0:	OpB={56'd0, B[7:0]};
				2'd1:	OpB={48'd0, B[15:0]};
				2'd2:	OpB={32'd0, B[31:0]};
				2'd3:	OpB=B;
				endcase
			end
	// ADDSX
	3'd1:	begin
			case (SA)
				2'd0:	OpA={{56{A[7]}}, A[7:0]};
				2'd1:	OpA={{48{A[15]}}, A[15:0]};
				2'd2:	OpA={{32{A[31]}}, A[31:0]};
				2'd3:	OpA=A;
				endcase
			case (SB)
				2'd0:	OpB={{56{B[7]}}, B[7:0]};
				2'd1:	OpB={{48{B[15]}}, B[15:0]};
				2'd2:	OpB={{32{B[31]}}, B[31:0]};
				2'd3:	OpB=B;
				endcase
			end
	// SUBZX
	3'd2:	begin
			case (SA)
				2'd0:	OpA={56'd0, A[7:0]};
				2'd1:	OpA={48'd0, A[15:0]};
				2'd2:	OpA={32'd0, A[31:0]};
				2'd3:	OpA=A;
				endcase
			case (SB)
				2'd0:	OpB={56'd0, B[7:0]};
				2'd1:	OpB={48'd0, B[15:0]};
				2'd2:	OpB={32'd0, B[31:0]};
				2'd3:	OpB=B;
				endcase
			end
	// SUBSX
	3'd3:	begin
			case (SA)
				2'd0:	OpA={{56{A[7]}}, A[7:0]};
				2'd1:	OpA={{48{A[15]}}, A[15:0]};
				2'd2:	OpA={{32{A[31]}}, A[31:0]};
				2'd3:	OpA=A;
				endcase
			case (SB)
				2'd0:	OpB={{56{B[7]}}, B[7:0]};
				2'd1:	OpB={{48{B[15]}}, B[15:0]};
				2'd2:	OpB={{32{B[31]}}, B[31:0]};
				2'd3:	OpB=B;
				endcase
			end
	// another operations
	default: begin
			OpA=A;
			OpB=B;
			end
	endcase
OpD=D;

end

always @(posedge CLK)
	begin
	
	// result size
	SR<=SD;

	for (i1=0; i1<16; i1=i1+1)
		begin
		RA[i1]<=OpA[((i1+1)<<2)-1];
		RB[i1]<=(OpB[((i1+1)<<2)-1])^(~OpCODE[2] & OpCODE[1]);
		end
	
	case (SR)
		2'b00:
			begin
			OVR<=(~RA[1]&~RB[1]&TempR[7])|(RA[1]&RB[7]&~TempR[7]);
			COUT[15]<=(RA[1]&RB[1])|((RA[1]^RB[1])&!TempR[7]);
			end
		2'b01:
			begin
			OVR<=(~RA[3]&~RB[3]&TempR[15])|(RA[3]&RB[3]&~TempR[15]);
			COUT[15]<=(RA[3]&RB[3])|((RA[3]^RB[3])&!TempR[15]);
			end
		2'b10:
			begin
			OVR<=(~RA[7]&~RB[7]&TempR[31])|(RA[7]&RB[7]&~TempR[31]);
			COUT[15]<=(RA[7]&RB[7])|((RA[7]^RB[7])&!TempR[31]);
			end
		2'b11:
			begin
			OVR<=(~RA[15]&~RB[15]&TempR[63])|(RA[15]&RB[15]&~TempR[63]);
			COUT[15]<=(RA[15]&RB[15])|((RA[15]^RB[15])&!TempR[63]);
			end
		endcase
		
	for (i0=0; i0<15; i0=i0+1) COUT[i0]<=(RA[i0]&RB[i0])|((RA[i0]^RB[i0])&!TempR[((i0+1)<<2)-1]);
		
	// processing operands
	casez (OpCODE[2:0])
		3'b000: TempR<=OpA + OpB;
		3'b001: TempR<=OpA + OpB;
		3'b010: TempR<=OpA - OpB;
		3'b011: TempR<=OpA - OpB;
		3'b100: TempR<=OpA & OpB;
		3'b101: TempR<=OpA | OpB;
		3'b110: TempR<=OpA ^ OpB;
		3'b111: TempR<=(OpD & ~OpB) | (OpA & OpB);
		endcase
		
	// output result
	R<=TempR;
	
	// zero flag
	Zero<=~((|TempR[7:0]) |
			(|TempR[15:8] & (|SR)) |
			(|TempR[31:16] & SR[1]) |
			(|TempR[63:32] & SR[1] & SR[0]));
			
	// sign flag
	case (SR)
		2'b00: Sign<=TempR[7];
		2'b01: Sign<=TempR[15];
		2'b10: Sign<=TempR[31];
		2'b11: Sign<=TempR[63];
		endcase
	end

endmodule
