module FPDIV128V (
	input wire CLK, ACT, RST,
	input wire [1:0] CMD,
	input wire [2:0] SA, SB, SD,
	input wire [127:0] A, B,
	input wire [4:0] DSTi,
	
	output reg [127:0] R,
	output reg [4:0] DSTo,
	output reg [2:0] SR,
	output reg RDY, Zero, Sign, Inf, NaN, NEXT
);

logic CanSubtractWire, CanSubtractWire32B, CanSubtractWire32C, CanSubtractWire32D, CanSubtractWire64;
logic [111:0] IntABus, IntBBus;

reg ProcFlag, SignA, SignB, StartFlag, StopFlag, IntNan, NanA, NanB, IntSign, IntegerSign,
	IntInf, InfA, InfB, IntZero, ZeroA, ZeroB, SqrtStartFlag, SqrtStopFlag, SqrtCycleFlag,
	SearchFlag, SignA32B, SignA32C, SignA32D, SignB32B, SignB32C, SignB32D, SignA64, SignB64,
	IntSign32B, IntSign32C, IntSign32D, IntSign64, DStartFlag;
reg [1:0] CMDReg;
reg [111:0] FractionA, FractionB;
reg [14:0] ExponentA, ExponentB, IntExponent, SqrtExponent;
reg [112:0] Dividend, Divisor, Quotient;
reg [113:0] NumReg, BitReg, ResReg, SumReg;
reg [6:0] CntReg, LimitReg;
reg [2:0] Size, SDReg;
reg [4:0] DSTReg;
reg [6:0] NDividendReg, NDivisorReg, CorrReg;
reg [23:0] Dividend32B, Dividend32C, Dividend32D, Divisor32B, Divisor32C, Divisor32D, Quotient32B, Quotient32C, Quotient32D;
reg [52:0] Dividend64, Divisor64, Quotient64;
reg [22:0] FractionA32B, FractionA32C, FractionA32D, FractionB32B, FractionB32C, FractionB32D;
reg [51:0] FractionA64, FractionB64;
reg [14:0] ExponentA32B, ExponentB32B, ExponentA32C, ExponentB32C, ExponentA32D, ExponentB32D, IntExponent32B, IntExponent32C, IntExponent32D, Rexp, Rexp64;
reg [14:0] ExponentA64, ExponentB64, IntExponent64;

assign NEXT=~ProcFlag;


//=================================================================================================
//			Asynchronous logic
always_comb
begin

CanSubtractWire=(Dividend>=Divisor);
CanSubtractWire32B=(Dividend32B>=Divisor32B);
CanSubtractWire32C=(Dividend32C>=Divisor32C);
CanSubtractWire32D=(Dividend32D>=Divisor32D);
CanSubtractWire64=(Dividend64>=Divisor64);


// create source integer buses
case ({CMD[0],SA[1:0]})
	3'd0: IntABus={A[7:0],104'd0};
	3'd1: IntABus={A[15:0],96'd0};
	3'd2: IntABus={A[31:0],80'd0};
	3'd3: IntABus={A[63:0],48'd0};
	3'd4: IntABus={(A[7:0] ^ {8{A[7]}})+{7'd0,A[7]},104'd0};
	3'd5: IntABus={(A[15:0] ^ {16{A[15]}})+{15'd0,A[15]},96'd0};
	3'd6: IntABus={(A[31:0] ^ {32{A[31]}})+{31'd0,A[31]},80'd0};
	3'd7: IntABus={(A[63:0] ^ {64{A[63]}})+{63'd0,A[63]},48'd0};
	endcase

case ({CMD[0],SA[1:0]})
	3'd0: IntBBus={B[7:0],104'd0};
	3'd1: IntBBus={B[15:0],96'd0};
	3'd2: IntBBus={B[31:0],80'd0};
	3'd3: IntBBus={B[63:0],48'd0};
	3'd4: IntBBus={(B[7:0] ^ {8{B[7]}})+{7'd0,B[7]},104'd0};
	3'd5: IntBBus={(B[15:0] ^ {16{B[15]}})+{15'd0,B[15]},96'd0};
	3'd6: IntBBus={(B[31:0] ^ {32{B[31]}})+{31'd0,B[31]},80'd0};
	3'd7: IntBBus={(B[63:0] ^ {64{B[63]}})+{63'd0,B[63]},48'd0};
	endcase
	
Rexp=(CMDReg[0] ? SqrtExponent : IntExponent)-15'd16256;
Rexp64=(CMDReg[0] ? SqrtExponent : IntExponent)-15'd15360;

end

//=================================================================================================
//			Synchronous
always_ff @(posedge CLK)
begin
//-----------------------------------------------
//	receive source operands
if (~ProcFlag)
	begin
	// mantisa
	FractionA<=CMD[1] ? ((SA==3'd4) ? A[111:0] : ((SA==3'd3)|(SA==3'd6) ? {A[51:0], 60'd0} : {A[22:0], 89'd0})) : IntABus;
	FractionB<=CMD[1] ? ((SB==3'd4) ? B[111:0] : ((SB==3'd3)|(SB==3'd6) ? {B[51:0], 60'd0} : {B[22:0], 89'd0})) : IntBBus;
	casex (SA)
		3'd3: 	begin FractionA32B<=A[51:29]; FractionA32C<=A[51:29]; FractionA32D<=A[51:29]; FractionA64<=A[51:0]; end
		3'd4: 	begin FractionA32B<=A[111:89]; FractionA32C<=A[111:89]; FractionA32D<=A[111:89]; FractionA64<=A[111:60]; end
		3'd5:	begin FractionA32B<=A[54:32]; FractionA32C<=A[86:64]; FractionA32D<=A[118:96]; FractionA64<={A[54:32],29'd0}; end
		3'd6:	begin FractionA32B<=A[51:29]; FractionA32C<=A[115:93]; FractionA32D<=A[115:93]; FractionA64<=A[115:64]; end
		default	begin FractionA32B<=A[22:0]; FractionA32C<=A[22:0]; FractionA32D<=A[22:0]; FractionA64<={A[22:0],29'd0}; end
		endcase
	casex (SB)
		3'd3: 	begin FractionB32B<=B[51:29]; FractionB32C<=B[51:29]; FractionB32D<=B[51:29]; FractionB64<=B[51:0]; end
		3'd4: 	begin FractionB32B<=B[111:89]; FractionB32C<=B[111:89]; FractionB32D<=B[111:89]; FractionB64<=B[111:60]; end
		3'd5:	begin FractionB32B<=B[54:32]; FractionB32C<=B[86:64]; FractionB32D<=B[118:96]; FractionB64<={B[54:32],29'd0}; end
		3'd6:	begin FractionB32B<=B[51:29]; FractionB32C<=B[115:93]; FractionB32D<=B[115:93]; FractionB64<=B[115:64]; end
		default	begin FractionB32B<=B[22:0]; FractionB32C<=B[22:0]; FractionB32D<=B[22:0]; FractionB64<={B[22:0],29'd0}; end
		endcase
	// exponent
	ExponentA<=(SA==3'd4) ? A[126:112] : ((SA==3'd3)|(SA==3'd6) ? {4'd0, A[62:52]}+15'd15360 : {7'd0, A[30:23]}+15'd16256);
	ExponentB<=(SB==3'd4) ? B[126:112] : ((SB==3'd3)|(SB==3'd6) ? {4'd0, B[62:52]}+15'd15360 : {7'd0, B[30:23]}+15'd16256);
	casex(SA)
		3'd3:	begin ExponentA32B<={4'd0, A[62:52]}-11'd896; ExponentA32C<={4'd0, A[62:52]}-11'd896; ExponentA32D<={4'd0, A[62:52]}-11'd896; ExponentA64<={4'd0, A[62:52]}; end
		3'd4:	begin ExponentA32B<=A[126:112]-15'd16256; ExponentA32C<=A[126:112]-15'd16256; ExponentA32D<=A[126:112]-15'd16256; ExponentA64<=A[126:112]-15'd15360; end
		3'd5:	begin ExponentA32B<={7'd0, A[62:55]}; ExponentA32C<={7'd0, A[94:87]}; ExponentA32D<={7'd0, A[126:119]}; ExponentA64<={7'd0,A[62:55]}+11'd896; end
		3'd6:	begin ExponentA32B<={4'd0, A[62:52]}-11'd896; ExponentA32C<={4'd0, A[126:116]}-11'd896; ExponentA32D<={4'd0, A[126:116]}-11'd896; ExponentA64<={4'd0, A[126:116]}; end
		default begin ExponentA32B<={7'd0, A[30:23]}; ExponentA32C<={7'd0, A[30:23]}; ExponentA32D<={7'd0, A[30:23]}; ExponentA64<={7'd0,A[30:23]}+11'd896; end
		endcase
	casex(SB)
		3'd3:	begin ExponentB32B<={4'd0, B[62:52]}-11'd896; ExponentB32C<={4'd0, B[62:52]}-11'd896; ExponentB32D<={4'd0, B[62:52]}-11'd896; ExponentB64<={4'd0, B[62:52]}; end
		3'd4:	begin ExponentB32B<=B[126:112]-15'd16256; ExponentB32C<=B[126:112]-15'd16256; ExponentB32D<=B[126:112]-15'd16256; ExponentB64<=B[126:112]-15'd15360; end
		3'd5:	begin ExponentB32B<={7'd0, B[62:55]}; ExponentB32C<={7'd0, B[94:87]}; ExponentB32D<={7'd0, B[126:119]}; ExponentB64<={7'd0,B[62:55]}+11'd896; end
		3'd6:	begin ExponentB32B<={4'd0, B[62:52]}-11'd896; ExponentB32C<={4'd0, B[126:116]}-11'd896; ExponentB32D<={4'd0, B[126:116]}-11'd896; ExponentB64<={4'd0, B[126:116]}; end
		default begin ExponentB32B<={7'd0, B[30:23]}; ExponentB32C<={7'd0, B[30:23]}; ExponentB32D<={7'd0, B[30:23]}; ExponentB64<={7'd0,B[30:23]}+11'd896; end
		endcase
	// sign
	SignA<=((SA==3'd4) ? A[127] : ((SA==3'd3)|(SA==3'd6) ? A[63] : A[31])) & CMD[1] & ~CMD[0];
	SignB<=(SB==3'd4) ? B[127] : ((SB==3'd3)|(SB==3'd6) ? B[63] : B[31]);
	casex(SA)
		3'd3:	begin SignA32B<=A[63]; SignA32C<=A[63]; SignA32D<=A[63]; SignA64<=A[63]; end
		3'd4:	begin SignA32B<=A[127]; SignA32C<=A[127]; SignA32D<=A[127]; SignA64<=A[127]; end
		3'd5:	begin SignA32B<=A[31]; SignA32C<=A[63]; SignA32D<=A[95]; SignA64<=A[63]; end
		3'd6:	begin SignA32B<=A[63]; SignA32C<=A[127]; SignA32D<=A[127]; SignA64<=A[127]; end
		default	begin SignA32B<=A[31]; SignA32C<=A[31]; SignA32D<=A[31]; SignA64<=A[31]; end
		endcase
	casex(SB)
		3'd3:	begin SignB32B<=B[63]; SignB32C<=B[63]; SignB32D<=B[63]; SignB64<=B[63]; end
		3'd4:	begin SignB32B<=B[127]; SignB32C<=B[127]; SignB32D<=B[127]; SignB64<=B[127]; end
		3'd5:	begin SignB32B<=B[31]; SignB32C<=B[63]; SignB32D<=B[95]; SignB64<=B[63]; end
		3'd6:	begin SignB32B<=B[63]; SignB32C<=B[127]; SignB32D<=B[127]; SignB64<=B[127]; end
		default	begin SignB32B<=B[31]; SignB32C<=B[31]; SignB32D<=B[31]; SignB64<=B[31]; end
		endcase
	// result size
	if ((SA==3'd5)|(SB==3'd5)) Size<=3'd5;
		else if ((SA==3'd6)|(SB==3'd6)) Size<=3'd6;
			else if (SA>SB) Size<=SB;
				else Size<=SA;
	if ((SA==3'd5)|(SB==3'd5)) SDReg<=3'd5;
		else if ((SA==3'd6)|(SB==3'd6)) SDReg<=3'd6;
			else SDReg<=SD;
	// flags
	NanA<=((SA==3'd4) ? &A[126:112] & (|A[111:0]) : ((SA==3'd3)|(SA==3'd6) ? &A[62:52] & (|A[51:0]) : &A[30:23] & (|A[22:0]))) & CMD[1] & ~CMD[0];
	NanB<=(SB==3'd4) ? &B[126:112] & (|B[111:0]) : ((SB==3'd3)|(SB==3'd6) ? &B[62:52] & (|B[51:0]) : &B[30:23] & (|B[22:0]));
	InfA<=((SA==3'd4) ? &A[126:112] & (~(|A[111:0])) : ((SA==3'd3)|(SA==3'd6) ? &A[62:52] & (~(|A[51:0])) : &A[30:23] & (~(|A[22:0])))) & CMD[1] & ~CMD[0];
	InfB<=(SB==3'd4) ? &B[126:112] & (~(|B[111:0])) : ((SB==3'd3)|(SB==3'd6) ? &B[62:52] & (~(|B[51:0])) : &B[30:23] & (~(|B[22:0])));
	ZeroA<=((SA==3'd4) ? ~(|A[126:0]) : ((SA==3'd3)|(SA==3'd6) ? ~(|A[62:0]) : ~(|A[30:0]))) & (~CMD[0] | ~CMD[1]);
	ZeroB<=(SB==3'd4) ? ~(|B[126:0]) : ((SB==3'd3)|(SB==3'd6) ? ~(|B[62:0]) : ~(|B[30:0]));
	// destination
	DSTReg<=DSTi;
	// integer sign
	IntegerSign<=((A[7] & ~SA[1] & ~SA[0])|(A[15] & ~SA[1] & SA[0])|(A[31] & SA[1] & ~SA[0])|(A[63] & SA[1] & SA[0])) ^
				((B[7] & ~SA[1] & ~SA[0])|(B[15] & ~SA[1] & SA[0])|(B[31] & SA[1] & ~SA[0])|(A[63] & SA[1] & SA[0]));
	end
// command
if (~ProcFlag | ~RST) CMDReg<=CMD & {2{RST}};

// processing flag
ProcFlag<=(ProcFlag | ACT) & (~StopFlag | ~ProcFlag) & RST & (~ProcFlag | ~SqrtStopFlag);


// division start flag
StartFlag<=ACT & ~ProcFlag & ~(&CMD);
DStartFlag<=StartFlag & RST;

// square root start flag
SqrtStartFlag<=ACT & ~ProcFlag & (&CMD) & RST;

// square cycle flag
SqrtCycleFlag<=~SqrtCycleFlag & ~SqrtStartFlag & RST;

// search first bit flag
SearchFlag<=((SearchFlag & (~ProcFlag | ~Dividend[112] | ~Divisor[112])) | (ACT & ~CMD[1] & ~ProcFlag)) & RST;

// normalization counter
NDividendReg<=(NDividendReg+{6'd0,SearchFlag & ~Dividend[112]}) & {7{~StartFlag}};
NDivisorReg<=(NDivisorReg+{6'd0,SearchFlag & ~Divisor[112]}) & {7{~StartFlag}};
CorrReg<=NDividendReg-NDivisorReg-7'd1;

// sum register
SumReg<=ResReg+BitReg;

if (SqrtCycleFlag | SqrtStartFlag | ~RST) BitReg<=(SqrtStartFlag ? {~ExponentA[0], ExponentA[0], 112'd0} : BitReg >> 2) & {114{RST}};
if (SqrtCycleFlag | SqrtStartFlag)
	begin
	// number register for square root
	if ((NumReg>=SumReg) | SqrtStartFlag) NumReg<=SqrtStartFlag ? {2'b01,FractionA} : NumReg - SumReg;
	// bit register for square root
	// result register for square root
	if (NumReg>=SumReg) ResReg<=((ResReg>>1) + BitReg)  & {114{~SqrtStartFlag}};
		else ResReg<=(ResReg >> 1) & {114{~SqrtStartFlag}};
	end

if (CMDReg[1] & CMDReg[0] & (|BitReg[1:0]) & SqrtCycleFlag) SqrtExponent<={ExponentA[14],~ExponentA[14],ExponentA[13:1]-{12'd0,~ExponentA[0]}};

// square root stop flag
SqrtStopFlag<=CMDReg[1] & CMDReg[0] & (|BitReg[1:0]) & SqrtCycleFlag;

// division stop flag
StopFlag<=((CntReg==LimitReg)|(DStartFlag & ~CMDReg[1] & (Dividend<Divisor))) & RST;

// dividend
if (StartFlag | (CanSubtractWire & ~SearchFlag) | (SearchFlag & ~Dividend[112])) Dividend<=StartFlag ? {CMDReg[1], FractionA} : (SearchFlag ? Dividend << 1 : Dividend - Divisor);
if (StartFlag | CanSubtractWire32B) Dividend32B<=StartFlag ? {1'b1, FractionA32B} : Dividend32B-Divisor32B;
if (StartFlag | CanSubtractWire32C) Dividend32C<=StartFlag ? {1'b1, FractionA32C} : Dividend32C-Divisor32C;
if (StartFlag | CanSubtractWire32D) Dividend32D<=StartFlag ? {1'b1, FractionA32D} : Dividend32D-Divisor32D;
if (StartFlag | CanSubtractWire64) Dividend64<=StartFlag ? {1'b1, FractionA64} : Dividend64-Divisor64;

// divisor
if (StartFlag | (SearchFlag & ~Divisor[112]) | ~SearchFlag) Divisor<=StartFlag ? {CMDReg[1], FractionB} : (SearchFlag ? Divisor << 1 : Divisor >> 1);
Divisor32B<=StartFlag ? {1'b1, FractionB32B} : Divisor32B >> 1;
Divisor32C<=StartFlag ? {1'b1, FractionB32C} : Divisor32C >> 1;
Divisor32D<=StartFlag ? {1'b1, FractionB32D} : Divisor32D >> 1;
Divisor64<=StartFlag ? {1'b1, FractionB64} : Divisor64 >> 1;

// quotient
if (StartFlag) Quotient<=113'd0;
	else if (ProcFlag & (~CMDReg[0] | ~CMDReg[1]) & (CntReg<=LimitReg) & ~SearchFlag) Quotient[8'd112-CntReg]<=CanSubtractWire;
if (StartFlag) Quotient32B<=24'd0;
	else if (ProcFlag & (~CMDReg[0] | ~CMDReg[1]) & (CntReg<=LimitReg) & ~SearchFlag) Quotient32B[7'd23-CntReg]<=CanSubtractWire32B;
if (StartFlag) Quotient32C<=24'd0;
	else if (ProcFlag & (~CMDReg[0] | ~CMDReg[1]) & (CntReg<=LimitReg) & ~SearchFlag) Quotient32C[7'd23-CntReg]<=CanSubtractWire32C;
if (StartFlag) Quotient32D<=24'd0;
	else if (ProcFlag & (~CMDReg[0] | ~CMDReg[1]) & (CntReg<=LimitReg) & ~SearchFlag) Quotient32D[7'd23-CntReg]<=CanSubtractWire32D;
if (StartFlag) Quotient64<=53'd0;
	else if (ProcFlag & (~CMDReg[0] | ~CMDReg[1]) & (CntReg<=LimitReg) & ~SearchFlag) Quotient64[7'd52-CntReg]<=CanSubtractWire64;

// counter
if (StartFlag | ~RST) CntReg<=0;
else if ((CntReg==7'd1) & (IntNan | IntInf | IntZero)) CntReg<=LimitReg;
	else CntReg<=CntReg+{6'd0, ProcFlag & ~(&CMDReg) & (CntReg<=LimitReg) & ~SearchFlag};

// counter limit value
if (StartFlag | ~RST)
	casez ({CMDReg[1],Size})
		4'b0?00:	LimitReg<=RST ? 7'd7 : 7'd120;
		4'b0?01:	LimitReg<=RST ? 7'd15 : 7'd120;
		4'b0?10:	LimitReg<=RST ? 7'd31 : 7'd120;
		4'b0?11:	LimitReg<=RST ? 7'd63 : 7'd120;
		4'b10?0:	LimitReg<=RST ? 7'd23 : 7'd120;
		4'b10?1:	LimitReg<=RST ? 7'd52 : 7'd120;
		4'b1100:	LimitReg<=RST ? 7'd112 : 7'd120;
		4'b1101:	LimitReg<=RST ? 7'd23 : 7'd120;
		4'b1110:	LimitReg<=RST ? 7'd52 : 7'd120;
		default: LimitReg<=7'd120;
		endcase

// output result
RDY<=(StopFlag | (CMDReg[1] & CMDReg[0] & (|BitReg[1:0]) & SqrtCycleFlag)) & RST;
DSTo<=DSTReg;
SR<=CMDReg[1] ? SDReg : Size;

//-----------------------------------------------
// internal exponent and flags
IntExponent<=ExponentA-ExponentB+15'd16382+{14'd0, Quotient[112]};
IntExponent32B<=ExponentA32B-ExponentB32B+8'd126+{7'd0, Quotient32B[23]};
IntExponent32C<=ExponentA32C-ExponentB32C+8'd126+{7'd0, Quotient32C[23]};
IntExponent32D<=ExponentA32D-ExponentB32D+8'd126+{7'd0, Quotient32D[23]};
IntExponent64<=ExponentA64-ExponentB64+11'd1022+{10'd0, Quotient64[52]};

IntNan<=NanA | (NanB & ~CMDReg[0]);

IntSign<=SignA ^ SignB;
IntSign32B<=SignA32B ^ SignB32B;
IntSign32C<=SignA32C ^ SignB32C;
IntSign32D<=SignA32D ^ SignB32D;
IntSign64<=SignA64 ^ SignB64;

// create result
if (~CMDReg[1])
	begin
	casez ({CMDReg[0],Size[1:0]})
		3'b000:	R<={64'd0,56'd0,Quotient[112:105] >> CorrReg[2:0]};
		3'b001:	R<={64'd0,48'd0,Quotient[112:97] >> CorrReg[3:0]};
		3'b010:	R<={64'd0,32'd0,Quotient[112:81] >> CorrReg[4:0]};
		3'b011:	R<={64'd0,Quotient[112:49] >> CorrReg[5:0]};
		3'b100: R<={64'd0,56'd0,((Quotient[112:105] >> CorrReg[2:0]) ^ {8{IntegerSign}})+{7'd0,IntegerSign}};
		3'b101: R<={64'd0,48'd0,((Quotient[112:97] >> CorrReg[3:0]) ^ {16{IntegerSign}})+{15'd0,IntegerSign}};
		3'b110: R<={64'd0,32'd0,((Quotient[112:81] >> CorrReg[4:0]) ^ {32{IntegerSign}})+{31'd0,IntegerSign}};
		3'b111: R<={64'd0,((Quotient[112:49] >> CorrReg[5:0]) ^ {64{IntegerSign}})+{63'd0,IntegerSign}};
		endcase
	end
	else begin
	casex (SDReg)
		// 64-bit
		3'd3:	begin
				IntInf<=(InfA | (IntExponent>15'd17406) | ZeroB) & ~CMDReg[0];
				IntZero<=(ZeroA | (IntExponent<15'd15359) | (InfB & ~InfA)) & ~ZeroB & ~NanB & ~CMDReg[0];
				R[51:0]<=CMDReg[0] ? ResReg[55:4] : ((Quotient[112] ? Quotient[111:60] : Quotient[110:59]) & {52{~IntZero & ~IntInf}}) | {52{IntNan}};
				R[62:52]<=(Rexp64[10:0] & {11{~IntZero}}) | {11{IntInf | IntNan}};
				R[63]<=IntSign & ~CMDReg[0];
				R[127:64]<=64'd0;
				end
		// 128-bit
		3'd4:	begin
				IntInf<=(InfA | ZeroB) & ~CMDReg[0];
				IntZero<=(ZeroA | (InfB & ~InfA)) & ~ZeroB & ~NanB & ~CMDReg[0];
				R[111:0]<=CMDReg[0] ? {ResReg[55:0], 56'd0} : ((Quotient[112] ? Quotient[111:0] : {Quotient[110:0], 1'b0}) & {112{~IntZero & ~IntInf}}) | {112{IntNan}};
				R[126:112]<=((CMDReg[0] ? SqrtExponent : IntExponent) & {15{~IntZero}}) | {15{IntInf | IntNan}};
				R[127]<=IntSign & ~CMDReg[0];
				end
		// 4 32-bit
		3'd5:	begin
				IntInf<=(InfA | (IntExponent>15'd16510) | ZeroB) & ~CMDReg[0];
				IntZero<=(ZeroA | (IntExponent<15'd16255) | (InfB & ~InfA)) & ~ZeroB & ~NanB & ~CMDReg[0];
				R[22:0]<=CMDReg[0] ? ResReg[55:33] : ((Quotient[112] ? Quotient[111:89] : Quotient[110:88]) & {23{~IntZero & ~IntInf}}) | {23{IntNan}};
				R[30:23]<=(Rexp[7:0] & {8{~IntZero}}) | {8{IntInf | IntNan}};
				R[31]<=IntSign & ~CMDReg[0];
				R[63:32]<={IntSign32B, IntExponent32B[7:0], Quotient32B[23] ? Quotient32B[22:0] : {Quotient32B[21:0],1'b0}};
				R[95:64]<={IntSign32C, IntExponent32C[7:0], Quotient32C[23] ? Quotient32C[22:0] : {Quotient32C[21:0],1'b0}};
				R[127:96]<={IntSign32D, IntExponent32D[7:0], Quotient32D[23] ? Quotient32D[22:0] : {Quotient32D[21:0],1'b0}};
				end
		// 2 64-bit
		3'd6:	begin
				IntInf<=(InfA | (IntExponent>15'd17406) | ZeroB) & ~CMDReg[0];
				IntZero<=(ZeroA | (IntExponent<15'd15359) | (InfB & ~InfA)) & ~ZeroB & ~NanB & ~CMDReg[0];
				R[51:0]<=CMDReg[0] ? ResReg[55:4] : ((Quotient[112] ? Quotient[111:60] : Quotient[110:59]) & {52{~IntZero & ~IntInf}}) | {52{IntNan}};
				R[62:52]<=(Rexp64[10:0] & {11{~IntZero}}) | {11{IntInf | IntNan}};
				R[63]<=IntSign & ~CMDReg[0];
				R[127:64]<={IntSign64, IntExponent64[10:0], Quotient64[52] ? Quotient64[51:0] : {Quotient64[50:0], 1'b0}};
				end
		// 32-bit
		default	begin
				IntInf<=(InfA | (IntExponent>15'd16510) | ZeroB) & ~CMDReg[0];
				IntZero<=(ZeroA | (IntExponent<15'd16255) | (InfB & ~InfA)) & ~ZeroB & ~NanB & ~CMDReg[0];
				R[22:0]<=CMDReg[0] ? ResReg[55:33] : ((Quotient[112] ? Quotient[111:89] : Quotient[110:88]) & {23{~IntZero & ~IntInf}}) | {23{IntNan}};
				R[30:23]<=(Rexp[7:0] & {8{~IntZero}}) | {8{IntInf | IntNan}};
				R[31]<=IntSign & ~CMDReg[0];
				R[127:32]<=96'd0;
				end
		endcase
	end

Zero<=IntZero;
Sign<=IntSign;
Inf<=IntInf;
NaN<=IntNan;

end

endmodule
