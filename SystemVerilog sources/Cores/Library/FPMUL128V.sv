module FPMUL128V (
	input wire CLK, RESET,
	input wire ACT,
	input wire [1:0] CMD,
	input wire [4:0] DSTI,
	input wire [127:0] A, B,
	input wire [2:0] SA, SB, SD,
	// 32-bit channel
	output reg RDYSD, RDYQ, ZEROSD, SIGNSD, INFSD, NANSD, ZEROQ, SIGNQ, INFQ, NANQ, 
	output reg [2:0] SR,
	output reg [4:0] DSTSD, DSTQ,
	output wire [127:0] RSD,
	output wire [127:0] RQ
	);

logic [24:0] RM32, RM32B, RM32C, RM32D;
logic [53:0] RM64, RM64B;
logic [113:0] RM128;

reg [63:0] RSDReg, HRSDReg;
reg [127:0] RQReg;

reg [107:0] MantissaA, MantissaB;
reg [52:0] Mantissa64A, Mantissa64B;
reg [23:0] Mantissa32BA, Mantissa32CA, Mantissa32DA, Mantissa32BB, Mantissa32CB, Mantissa32DB;
reg [15:0] ExponentA, ExponentB;
reg [14:0] ExponentA64, ExponentB64;
reg SignA, SignA32B, SignA32C, SignA32D, ZeroA, InfA, NaNA, InfB, NaNB, SignB, SignB32B, SignB32C, SignB32D, ZeroB, Sign64A, Sign64B;
reg [2:0] SizeR, Sign32B, Sign32C, Sign32D, Sign64;
reg [5:0] Zero, Nan, Inf, Sign;
reg [4:0] ACTReg;
reg [6:0] CMDReg;
reg [2:0] Size [4:0];
reg [15:0] Exp [5:0];
reg [14:0] Exp32B [1:0];
reg [14:0] Exp32C [1:0];
reg [17:0] Exp32D [1:0];
reg [4:0] DSTReg [4:0];
reg [14:0] Exp64 [2:0];

reg [7:0] Exp32Reg, Exp32RegB, Exp32RegC, Exp32RegD;
reg [22:0] Mantissa32Reg, Mantissa32RegB, Mantissa32RegC, Mantissa32RegD;
logic [10:0] Exp64BusB;
logic [14:0] ExponentA32B, ExponentB32B, ExponentA32C, ExponentB32C, ExponentA32D, ExponentB32D;
logic [15:0] Exp64Bus, Exp32Bus;
logic [51:0] Mantissa64Bus, Mantissa64BusB;
logic [15:0] Exp128Bus;
reg InfSDReg, ZeroSDReg;
logic InfQWire, ZeroQWire;

// integer multiplier resources
reg [63:0] IRegA, IRegB, ShortResReg, ShortDelReg;
reg [63:0] TempReg [3:0];
reg [127:0] AddReg [1:0];
logic [2:0] ISDBus;
reg [2:0] IACTReg;
reg InSign, TempSign, AddSign, ISign;
reg [127:0] IMulReg, IResReg;
reg [127:0] IDelayReg [1:0];

Mult108 mult (.CLK(CLK), .A(MantissaA), .B(MantissaB), .R32(RM32), .R64(RM64), .R128(RM128));
Mult53 M64 (.CLK(CLK), .A(Mantissa64A), .B(Mantissa64B), .R(RM64B));
Mult24 M32B (.CLK(CLK), .A(Mantissa32BA), .B(Mantissa32BB), .R(RM32B));
Mult24 M32C (.CLK(CLK), .A(Mantissa32CA), .B(Mantissa32CB), .R(RM32C));
Mult24 M32D (.CLK(CLK), .A(Mantissa32DA), .B(Mantissa32DB), .R(RM32D));

//=================================================================================================
//			assignments part

assign RSD={HRSDReg, RSDReg};
assign RQ=RQReg;


//=================================================================================================
//			Asynchronous part
always_comb
begin

Exp64Bus=(Exp[2]-16'd15360 + RM64[53]) | {16{(Exp[2]>16'd17406)|(Exp[2]<16'd15361)}};
Exp64BusB=Exp64[2][10:0] + RM64B[53];
Mantissa64Bus=((RM64[53] ? RM64[52:1] : RM64[51:0]) & {52{~Zero[2] & ~Inf[2]}}) | {52{Nan[2]}};
Mantissa64BusB=RM64B[53] ? RM64B[52:1] : RM64B[51:0];

Exp128Bus=Exp[5]+{15'd0, RM128[113]};
InfQWire=Inf[5] | (Exp128Bus[15] & ~Exp128Bus[14]);
ZeroQWire=Zero[5] | (Exp128Bus[15] & Exp128Bus[14]);

case ({SB[1:0],SA[1:0]})
	4'b0000: ISDBus=3'b001;
	4'b0001: ISDBus=3'b010;
	4'b0010: ISDBus=3'b011;
	4'b0011: ISDBus=3'b100;
	4'b0100: ISDBus=3'b010;
	4'b0101: ISDBus=3'b010;
	4'b0110: ISDBus=3'b011;
	4'b0111: ISDBus=3'b100;
	4'b1000: ISDBus=3'b011;
	4'b1001: ISDBus=3'b011;
	4'b1010: ISDBus=3'b011;
	4'b1011: ISDBus=3'b100;
	4'b1100: ISDBus=3'b100;
	4'b1101: ISDBus=3'b100;
	4'b1110: ISDBus=3'b100;
	4'b1111: ISDBus=3'b100;
	endcase

Exp32Bus=Exp[1] - 16'd16256 + RM32[24];

end

//=================================================================================================
//			Synchronous part by low frequency clock
always_ff @(posedge CLK)
begin

casez (SA)
		// 64-bit source operand A
		3'b011:	begin
				ExponentA<=16'd15360+{5'd0,A[62:52]};
				ExponentA32B<={4'd0, A[62:52]}-11'd896;
				ExponentA32C<={4'd0, A[62:52]}-11'd896;
				ExponentA32D<={4'd0, A[62:52]}-11'd896;
				ExponentA64<={4'd0, A[62:52]};
				MantissaA<={1'b1, A[51:0], 55'd0};
				SignA<=A[63];
				SignA32B<=A[63];
				SignA32C<=A[63];
				SignA32D<=A[63];
				Sign64A<=A[63];
				ZeroA<=~(|A[62:0]);
				InfA<=(&A[62:52])&(~(|A[51:0]));
				NaNA<=(&A[62:52])&(|A[51:0]);
				
				Mantissa64A<={1'b1, A[51:0]};
				
				Mantissa32BA<={1'b1, A[51:29]};
				Mantissa32CA<={1'b1, A[51:29]};
				Mantissa32DA<={1'b1, A[51:29]};
				end
		// 128-bit source operand A
		3'b100:	begin
				ExponentA<={1'b0, A[126:112]};
				ExponentA32B<=A[126:112]-15'd16256;
				ExponentA32C<=A[126:112]-15'd16256;
				ExponentA32D<=A[126:112]-15'd16256;
				ExponentA64<=A[126:112]-15'd15360;
				MantissaA<={1'b1, A[111:5]};
				SignA<=A[127];
				SignA32B<=A[127];
				SignA32C<=A[127];
				SignA32D<=A[127];
				Sign64A<=A[127];
				ZeroA<=~(|A[126:0]);
				InfA<=(&A[126:112])&(~(|A[111:0]));
				NaNA<=(&A[126:112])&(|A[111:0]);
				
				Mantissa64A<={1'b1, A[111:60]};
				
				Mantissa32BA<={1'b1, A[111:89]};
				Mantissa32CA<={1'b1, A[111:89]};
				Mantissa32DA<={1'b1, A[111:89]};
				end
		// four 32-bit data
		3'b101:	begin
				ExponentA<=16'd16256+{8'd0, A[30:23]};
				ExponentA32B<={7'd0, A[62:55]};
				ExponentA32C<={7'd0, A[94:87]};
				ExponentA32D<={7'd0, A[126:119]};
				ExponentA64<={7'd0,A[62:55]}+ 11'd896;
				
				SignA<=A[31];
				SignA32B<=A[63];
				SignA32C<=A[95];
				SignA32D<=A[127];
				Sign64A<=A[63];
				MantissaA<={1'b1, A[22:0], 84'd0};
				
				ZeroA<=0;
				InfA<=0;
				NaNA<=0;
				
				Mantissa64A<={1'b1, A[54:32], 29'd0};
				
				Mantissa32BA<={1'b1, A[54:32]};
				Mantissa32CA<={1'b1, A[86:64]};
				Mantissa32DA<={1'b1, A[118:96]};
				end
		// two 64-bit data
		3'b110:	begin
				ExponentA<=16'd15360+{5'd0,A[62:52]};
				ExponentA32B<={4'd0, A[62:52]}-11'd896;
				ExponentA32C<={4'd0, A[126:116]}-11'd896;
				ExponentA32D<={4'd0, A[126:116]}-11'd896;
				ExponentA64<={4'd0, A[126:116]};
				
				ZeroA<=0;
				InfA<=0;
				NaNA<=0;
				
				SignA<=A[63];
				SignA32B<=A[63];
				SignA32C<=A[127];
				SignA32D<=A[127];
				Sign64A<=A[127];
				MantissaA<={1'b1, A[51:0], 55'd0};
				
				Mantissa64A<={1'b1, A[115:64]};
				
				Mantissa32BA<={1'b1, A[51:29]};
				Mantissa32CA<={1'b1, A[115:93]};
				Mantissa32DA<={1'b1, A[115:93]};
				end
		// 32-bit source operand A
		default:begin
				ExponentA<=16'd16256+{8'd0, A[30:23]};
				ExponentA32B<={7'd0, A[30:23]};
				ExponentA32C<={7'd0, A[30:23]};
				ExponentA32D<={7'd0, A[30:23]};
				ExponentA64<={7'd0,A[30:23]}+11'd896;
				MantissaA<={1'b1, A[22:0], 84'd0};
				SignA<=A[31];
				SignA32B<=A[31];
				SignA32C<=A[31];
				SignA32D<=A[31];
				Sign64A<=A[31];
				ZeroA<=~(|A[30:0]);
				InfA<=(&A[30:23])&(~(|A[22:0]));
				NaNA<=(&A[30:23])&(|A[22:0]);
				
				Mantissa64A<={1'b1, A[22:0], 29'd0};
				
				Mantissa32BA<={1'b1, A[22:0]};
				Mantissa32CA<={1'b1, A[22:0]};
				Mantissa32DA<={1'b1, A[22:0]};
				end
		endcase

casez (SB)
		// 64-bit source operand B
		3'b011:	begin
				ExponentB<=16'd15360+{5'd0,B[62:52]};
				ExponentB32B<={4'd0, B[62:52]}-11'd896;
				ExponentB32C<={4'd0, B[62:52]}-11'd896;
				ExponentB32D<={4'd0, B[62:52]}-11'd896;
				ExponentB64<={4'd0, B[62:52]};
				MantissaB<={1'b1, B[51:0], 55'd0};
				SignB<=B[63];
				SignB32B<=B[63];
				SignB32C<=B[63];
				SignB32D<=B[63];
				Sign64B<=B[63];
				ZeroB<=~(|B[62:0]);
				InfB<=(&B[62:52])&(~(|B[51:0]));
				NaNB<=(&B[62:52])&(|B[51:0]);
				
				Mantissa64B<={1'b1, B[51:0]};
				
				Mantissa32BB<={1'b1, B[51:29]};
				Mantissa32CB<={1'b1, B[51:29]};
				Mantissa32DB<={1'b1, B[51:29]};
				end
		// 128-bit source operand B
		3'b100:	begin
				ExponentB<={1'b0,B[126:112]};
				ExponentB32B<=B[126:112]-15'd16256;
				ExponentB32C<=B[126:112]-15'd16256;
				ExponentB32D<=B[126:112]-15'd16256;
				ExponentB64<=B[126:112]-15'd15360;
				MantissaB<={1'b1, B[111:5]};
				SignB<=B[127];
				SignB32B<=B[127];
				SignB32C<=B[127];
				SignB32D<=B[127];
				Sign64B<=B[127];
				ZeroB<=~(|B[126:0]);
				InfB<=(&B[126:112])&(~(|B[111:0]));
				NaNB<=(&B[126:112])&(|B[111:0]);
				
				Mantissa64B<={1'b1, B[111:60]};
				
				Mantissa32BB<={1'b1, B[111:89]};
				Mantissa32CB<={1'b1, B[111:89]};
				Mantissa32DB<={1'b1, B[111:89]};
				end
		// four 32-bit data
		3'b101:	begin
				SignB<=B[31];
				SignB32B<=B[63];
				SignB32C<=B[95];
				SignB32D<=B[127];
				Sign64B<=B[63];
				
				ZeroB<=0;
				InfB<=0;
				NaNB<=0;
				
				ExponentB<=16'd16256+{8'd0, B[30:23]};
				ExponentB32B<={7'd0, B[62:55]};
				ExponentB32C<={7'd0, B[94:87]};
				ExponentB32D<={7'd0, B[126:119]};
				ExponentB64<={7'd0,B[62:55]}+11'd896;
				
				MantissaB<={1'b1, B[22:0], 84'd0};
				
				Mantissa64B<={1'b1, B[54:32], 29'd0};
				
				Mantissa32BB<={1'b1, B[54:32]};
				Mantissa32CB<={1'b1, B[86:64]};
				Mantissa32DB<={1'b1, B[118:96]};
				end
		// two 64-bit data
		3'b110:	begin
				SignB<=B[63];
				SignB32B<=B[63];
				SignB32C<=B[127];
				SignB32D<=B[127];
				Sign64B<=B[127];
				
				ZeroB<=0;
				InfB<=0;
				NaNB<=0;

				ExponentB<=16'd15360+{5'd0,B[62:52]};
				ExponentB32B<={4'd0, B[62:52]}-11'd896;
				ExponentB32C<={4'd0, B[126:116]}-11'd896;
				ExponentB32D<={4'd0, B[126:116]}-11'd896;
				ExponentB64<={4'd0, B[126:116]};
				
				MantissaB<={1'b1, B[51:0], 55'd0};
				
				Mantissa64B<={1'b1, B[115:64]};
				
				Mantissa32BB<={1'b1, B[51:29]};
				Mantissa32CB<={1'b1, B[115:93]};
				Mantissa32DB<={1'b1, B[115:93]};
				end
		// 32-bit source operand B
		default:begin
				ExponentB<=16'd16256+{8'd0, B[30:23]};
				ExponentB32B<={7'd0, B[30:23]};
				ExponentB32C<={7'd0, B[30:23]};
				ExponentB32D<={7'd0, B[30:23]};
				ExponentB64<={7'd0,B[30:23]}+11'd896;
				MantissaB<={1'b1, B[22:0], 84'd0};
				SignB<=B[31];
				SignB32B<=B[31];				
				SignB32C<=B[31];				
				SignB32D<=B[31];				
				Sign64B<=B[31];
				ZeroB<=~(|B[30:0]);
				InfB<=(&B[30:23])&(~(|B[22:0]));
				NaNB<=(&B[30:23])&(|B[22:0]);
				
				Mantissa64B<={1'b1, B[22:0], 29'd0};
				
				Mantissa32BB<={1'b1, B[22:0]};
				Mantissa32CB<={1'b1, B[22:0]};
				Mantissa32DB<={1'b1, B[22:0]};
				end
		endcase

// result size
SizeR<=CMD[1] ? SD : ISDBus;

//-----------------------------------------------
// operands for integer multiplication
case (SA[1:0])
	2'd0: IRegA<={56'd0,(A[7:0] ^ {8{A[7] & CMD[0]}})+{7'd0,A[7] & CMD[0]}};
	2'd1: IRegA<={48'd0,(A[15:0] ^ {16{A[15] & CMD[0]}})+{15'd0,A[15] & CMD[0]}};
	2'd2: IRegA<={32'd0,(A[31:0] ^ {32{A[31] & CMD[0]}})+{31'd0,A[31] & CMD[0]}};
	2'd3: IRegA<=(A[63:0] ^ {64{A[63] & CMD[0]}})+{63'd0,A[63] & CMD[0]};
	endcase
case (SB[1:0])
	2'd0: IRegB<={56'd0,(B[7:0] ^ {8{B[7] & CMD[0]}})+{7'd0,B[7] & CMD[0]}};
	2'd1: IRegB<={48'd0,(B[15:0] ^ {16{B[15] & CMD[0]}})+{15'd0,B[15] & CMD[0]}};
	2'd2: IRegB<={32'd0,(B[31:0] ^ {32{B[31] & CMD[0]}})+{31'd0,B[31] & CMD[0]}};
	2'd3: IRegB<=(B[63:0] ^ {64{B[63] & CMD[0]}})+{63'd0,B[63] & CMD[0]};
	endcase
	
InSign<=CMD[0] & (((A[7] & ~SA[1] & ~SA[0])|(A[15] & ~SA[1] & SA[0])|(A[31] & SA[1] & ~SA[0])|(A[63] & SA[1] & SA[0]))^
				((B[7] & ~SB[1] & ~SB[0])|(B[15] & ~SB[1] & SB[0])|(B[31] & SB[1] & ~SB[0])|(B[63] & SB[1] & SB[0])));
	
TempReg[0]<=IRegA[31:0] * IRegB[31:0];
TempReg[1]<=IRegA[63:32] * IRegB[31:0];
TempReg[2]<=IRegA[31:0] * IRegB[63:32];
TempReg[3]<=IRegA[63:32] * IRegB[63:32];
TempSign<=InSign;

AddReg[0]<={32'd0,TempReg[1],32'd0}+{64'd0,TempReg[0]};
AddReg[1]<={TempReg[3],64'd0}+{32'd0,TempReg[2],32'd0};
AddSign<=TempSign;

ShortResReg<=(TempReg[0] ^ {64{TempSign}})+{63'd0,TempSign};
ShortDelReg<=ShortResReg;

IMulReg<=AddReg[0]+AddReg[1];
ISign<=AddSign;

IResReg<=(IMulReg ^ {128{ISign}}) + {127'd0,ISign};
IDelayReg[0]<=IResReg;
IDelayReg[1]<=IDelayReg[0];


//-----------------------------------------------
//			temporary registers

Sign[0]<=SignA ^ SignB;
Zero[0]<=(ZeroA | ZeroB) & ~NaNA & ~NaNB;
Nan[0]<=NaNA | NaNB;
Inf[0]<=(InfA | InfB) & ~NaNA & ~NaNB;
Exp[0]<=ExponentA+ExponentB-16'd16383;
Exp32B[0]<=ExponentA32B+ExponentB32B-8'd127;
Exp32C[0]<=ExponentA32C+ExponentB32C-8'd127;
Exp32D[0]<=ExponentA32D+ExponentB32D-8'd127;
Exp64[0]<=ExponentA64+ExponentB64-11'd1023;

Size[0]<=SizeR;
Sign32B[0]<=SignA32B ^ SignB32B;
Sign32C[0]<=SignA32C ^ SignB32C;
Sign32D[0]<=SignA32D ^ SignB32D;
Sign64[0]<=Sign64A ^ Sign64B;

Sign[1]<=Sign[0];
Zero[1]<=Zero[0];
Nan[1]<=Nan[0];
Inf[1]<=Inf[0];
Exp[1]<=Exp[0];
Exp32B[1]<=Exp32B[0];
Exp32C[1]<=Exp32C[0];
Exp32D[1]<=Exp32D[0];
Exp64[1]<=Exp64[0];
Size[1]<=Size[0];
Sign32B[1]<=Sign32B[0];
Sign32C[1]<=Sign32C[0];
Sign32D[1]<=Sign32D[0];
Sign64[1]<=Sign64[0];

Sign[2]<=Sign[1];
Zero[2]<=Zero[1];
Nan[2]<=Nan[1];
Inf[2]<=Inf[1];
Exp[2]<=Exp[1];
Exp64[2]<=Exp64[1];
Size[2]<=Size[1];
Sign32B[2]<=Sign32B[1];
Sign32C[2]<=Sign32C[1];
Sign32D[2]<=Sign32D[1];
Sign64[2]<=Sign64[1];

Sign[3]<=Sign[2];
Zero[3]<=Zero[2];
Nan[3]<=Nan[2];
Inf[3]<=Inf[2];
Exp[3]<=Exp[2];
Size[3]<=Size[2];

Sign[4]<=Sign[3];
Zero[4]<=Zero[3];
Nan[4]<=Nan[3];
Inf[4]<=Inf[3];
Exp[4]<=Exp[3];
Size[4]<=Size[3];

Sign[5]<=Sign[4];
Zero[5]<=Zero[4];
Nan[5]<=Nan[4];
Inf[5]<=Inf[4];
Exp[5]<=Exp[4];

// activation
ACTReg[0]<=ACT & RESET;
ACTReg[1]<=ACTReg[0] & RESET;
ACTReg[2]<=ACTReg[1] & RESET;
ACTReg[3]<=ACTReg[2] & RESET;
ACTReg[4]<=ACTReg[3] & RESET;
// command
CMDReg[0]<=CMD[1];
CMDReg[1]<=CMDReg[0];
CMDReg[2]<=CMDReg[1];
CMDReg[3]<=CMDReg[2];
CMDReg[4]<=CMDReg[3];
CMDReg[5]<=CMDReg[4];
CMDReg[6]<=CMDReg[5];

DSTReg[0]<=DSTI;
DSTReg[1]<=DSTReg[0];
DSTReg[2]<=DSTReg[1];
DSTReg[3]<=DSTReg[2];
DSTReg[4]<=DSTReg[3];


//-----------------------------------------------
// 	create 32-bit or 64-bit result

// data ready signal and tag
RDYSD<=ACTReg[1] & (~Size[0][2] | (Size[0][2] & ^Size[0][1:0])) & RESET;
DSTSD<=DSTReg[1];

Exp32Reg<=Exp32Bus[7:0] | {8{(Exp[1]>16'd16510) | (Exp[1]<16'd16257)}};
Exp32RegB<=Exp32B[1][7:0] + RM32B[24];
Exp32RegC<=Exp32C[1][7:0] + RM32C[24];
Exp32RegD<=Exp32D[1][7:0] + RM32D[24];
InfSDReg<=(Inf[1] | (&Size[1][1:0] ? (Exp[1]>16'd17406) : (Exp[1]>16'd16510))) & ~Nan[1];
ZeroSDReg<=(Zero[1] | (&Size[1][1:0] ? (Exp[1]<16'd15361) : (Exp[1]<16'd16257))) & ~Nan[1];
Mantissa32Reg<=((RM32[24] ? RM32[23:1] : RM32[22:0]) & {23{~Zero[1] & ~Inf[1]}}) | {23{Nan[1]}};
Mantissa32RegB<=RM32B[24] ? RM32B[23:1] : RM32B[22:0];
Mantissa32RegC<=RM32C[24] ? RM32C[23:1] : RM32C[22:0];
Mantissa32RegD<=RM32D[24] ? RM32D[23:1] : RM32D[22:0];

// mantissa
RSDReg<=CMDReg[3] ? (((Size[2]==3'd3)|(Size[2]==3'd6) ? {Sign[2], Exp64Bus[10:0] | {11{Nan[2] | InfSDReg}}, (Mantissa64Bus & {52{~InfSDReg}})|{52{Nan[2]}}} : 
					{Sign32B[2], Exp32RegB, Mantissa32RegB, Sign[2], Exp32Reg | {8{Nan[2] | InfSDReg}}, (Mantissa32Reg & {23{~InfSDReg}})|{23{Nan[2]}}}) & {64{~ZeroSDReg}}) :
						ShortDelReg;
HRSDReg<=(Size[2]==3'd3)|(Size[2]==3'd6) ? {Sign64[2], Exp64BusB, Mantissa64BusB} : {Sign32D[2], Exp32RegD, Mantissa32RegD, Sign32C[2], Exp32RegC, Mantissa32RegC};

// flags
ZEROSD<=CMDReg[3] ? ZeroSDReg : ~(|ShortDelReg);
NANSD<=Nan[2];
SIGNSD<=CMDReg[3] ? Sign[2] : ShortDelReg[63];
INFSD<=InfSDReg;
// size of the result
SR<=Size[1];

//-----------------------------------------------
// create 128-bit result
RDYQ<=ACTReg[4] & Size[3][2] & ~|Size[3][1:0] & RESET;
DSTQ<=DSTReg[4];

RQReg[111:0]<=CMDReg[6] ? (((RM128[113] ? RM128[112:1] : RM128[111:0]) & {112{~ZeroQWire & ~InfQWire}}) | {112{Nan[5]}}) : IDelayReg[1][111:0];
RQReg[126:112]<=CMDReg[6] ? ((Exp128Bus[14:0] & {15{~ZeroQWire}}) | {15{InfQWire | Nan[5]}}) : IDelayReg[1][126:112];
RQReg[127]<=CMDReg[6] ? Sign[5] : IDelayReg[1][127];

//flags
ZEROQ<=CMDReg[6] ? ZeroQWire : ~(|IDelayReg[1]);
NANQ<=Nan[5];
SIGNQ<=CMDReg[6] ? Sign[5] : IDelayReg[1][127];
INFQ<=InfQWire;

end

endmodule
