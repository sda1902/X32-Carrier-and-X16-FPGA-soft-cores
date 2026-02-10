module FPADD128V (
	input wire CLK, RESET, ACT,
	input wire [1:0] CMD,
	input wire [127:0] A, B,
	input wire [2:0] SA, SB, SD,
	input wire [4:0] DSTI,
	output wire RDY, SIGN, ZERO, INF, NAN,
	output wire [2:0] SR,
	output wire [4:0] DSTO,
	output wire [127:0] R
	);

integer i, iB, iC, iD, i64;

logic [14:0] ExpABus, ExpBBus;
logic [14:0] ExpABus32B, ExpBBus32B, ExpABus32C, ExpABus32D, ExpBBus32C, ExpBBus32D, ExpABus64, ExpBBus64;
reg SignA, SignB, IntSignA, IntSignB, NegSignA, NegSignB, NanA, NanB, IntNan, InfA, InfB, IntInf, NegNan, NegInf, AddNan, AddInf, ZeroA, ZeroB;
reg ZeroA32B, ZeroA32C, ZeroA32D, ZeroA64, ZeroB32B, ZeroB32C, ZeroB32D, ZeroB64;
reg SignA32B, SignA32C, SignA32D, SignA64, SignB32B, SignB32C, SignB32D, SignB64;
reg AdderNan, AdderInf, OutNegNan, OutNegInf, OutSign, OutNan, NormNan, ResultNan, ResultInf, ResNan, ResZero, IntAdderNan, IntAdderInf;
reg StartACT, IntACT, NegACT, AddACT, IntAdderACT, AdderACT, OutNegACT, OutACT, ResultACT; 
reg ResSign, ResInf, NormSign, NormInf, ResultZero, ResultSign, OutInf;
reg IntSignA32B, IntSignB32B, IntSignA32C, IntSignB32C, IntSignA32D, IntSignB32D, IntSignA64, IntSignB64;
reg OutSign32B, OutSign32C, OutSign32D, OutSign64, NormSign32B, NormSign32C, NormSign32D, NormSign64;
reg ResultSign32B, ResultSign32C, ResultSign32D, ResultSign64, ResultZero32B, ResultZero32C, ResultZero32D, ResultZero64;
reg OutNegSign32B, OutNegSign32C, OutNegSign32D, OutNegSign64;
reg CompFlag, ModeFlag, IntCompFlag, IntModeFlag, IntExpAgB, IntExpAeB, IntMantAgB, NegCompFlag, NegModeFlag, NegAgB, AddSelA, AddSelB;
reg [14:0] ExpA, ExpB, SParA, SParB, IntExponent, NegExponent, AddExponent, IntAdderExponent, AdderExponent, OutNegExponent, OutExponent,
			NormExponent, ResultExponent, IntExpA, IntExpB, NegExpA, NegExpB;
reg [111:0] MantisaA, MantisaB;
reg [112:0] IntMantisaA, IntMantisaB;
reg [114:0] AddMantisaA, AddMantisaB, AdderMantisa, NormMantisa, OutMantisa, ResultMantisa;
reg [25:0] AddMantisaA32B, AddMantisaB32B, AddMantisaA32C, AddMantisaB32C, AddMantisaA32D, AddMantisaB32D, IntAdder32B, IntAdder32C, IntAdder32D;
reg [25:0] AdderMantisa32B, AdderMantisa32C, AdderMantisa32D, OutNegMantisa32B, OutNegMantisa32C, OutNegMantisa32D;
reg [25:0] OutMantisa32B, OutMantisa32C, OutMantisa32D, NormMantisa32B, NormMantisa32C, NormMantisa32D, ResultMantisa32B, ResultMantisa32C, ResultMantisa32D;
reg [58:0] NegMantisaA_Low, NegMantisaB_Low, IntAdder_Low, OutNegMantisa_Low;
reg [54:0] NegMantisaA_High, NegMantisaB_High, AddMantisaA64, AddMantisaB64, IntAdder64, AdderMantisa64, OutNegMantisa64, OutMantisa64, ResultMantisa64;
reg [54:0] NormMantisa64, NegMantisaA64, NegMantisaB64;
reg [22:0] MantisaA32B, MantisaA32C, MantisaA32D, MantisaB32B, MantisaB32C, MantisaB32D;
reg [23:0] IntMantisaA32B, IntMantisaB32B, IntMantisaA32C, IntMantisaB32C, IntMantisaA32D, IntMantisaB32D;
reg [25:0] NegMantisaA32B, NegMantisaB32B, NegMantisaA32C, NegMantisaB32C, NegMantisaA32D, NegMantisaB32D;
reg [51:0] MantisaA64, MantisaB64;
reg [52:0] IntMantisaA64, IntMantisaB64;
reg [56:0] IntAdderA_High, IntAdderB_High, OutNegMantisa_High;
reg [2:0] StartSR, IntSR, NegSR, AddSR, AdderSR, OutNegSR, OutSR, NormSR, ResultSR, IntAdderSR;
reg [127:0] ResReg;
reg [7:0] SParA64, SParB64, NormValue, SParA32B, SParB32B, SParA32C, SParB32C, SParA32D, SParB32D, ExpA32B, ExpA32C, ExpA32D, ExpB32B, ExpB32C, ExpB32D;
reg [7:0] IntExponent32B, IntExponent32C, IntExponent32D, NegExponent32B, NegExponent32C, NegExponent32D;
reg [7:0] AddExponent32B, AddExponent32C, AddExponent32D, IntAdderExponent32B, IntAdderExponent32C, IntAdderExponent32D;
reg [7:0] AdderExponent32B, AdderExponent32C, AdderExponent32D, OutNegExponent32B, OutNegExponent32C, OutNegExponent32D;
reg [7:0] OutExponent32B, OutExponent32C, OutExponent32D, NormExponent32B, NormExponent32C, NormExponent32D;
reg [7:0] ResultExponent32B, ResultExponent32C, ResultExponent32D;
reg [4:0] StartDST, IntDST, NegDST, AddDST, IntAdderDST, AdderDST, OutNegDST, OutDST, ResultDST;
reg [10:0] ExpA64, ExpB64, IntExponent64, NegExponent64, AddExponent64, IntAdderExponent64, AdderExponent64, OutNegExponent64;
reg [10:0] OutExponent64,NormExponent64, ResultExponent64;
reg [4:0] NormValue32B, NormValue32C, NormValue32D;
reg [5:0] NormValue64;


logic [7:0] NormValWire;
logic [4:0] NormValWire32B, NormValWire32C, NormValWire32D;
logic [5:0] NormValWire64;

assign R=ResReg;
assign RDY=ResultACT;
assign DSTO=ResultDST;
assign SIGN=ResSign;
assign INF=ResInf;
assign NAN=ResNan;
assign ZERO=ResZero;
assign SR=ResultSR;

//=================================================================================================
//			logic
always_comb
begin

ExpABus=(SA==3'd4) ? A[126:112] : (SA[1] & (SA[2]^SA[0])) ? {4'd0, A[62:52]} + 15'd15360 : {7'd0, A[30:23]} + 15'd16256;
ExpBBus=(SB==3'd4) ? B[126:112] : (SB[1] & (SB[2]^SB[0])) ? {4'd0, B[62:52]} + 15'd15360 : {7'd0, B[30:23]} + 15'd16256;

casex (SA)
			// 64 bit
	3'd3:	begin
			ExpABus32B={4'd0, A[62:52]}-11'd896;
			ExpABus32C={4'd0, A[62:52]}-11'd896;
			ExpABus32D={4'd0, A[62:52]}-11'd896;
			ExpABus64={4'd0, A[62:52]};
			end
			// 128 bit
	3'd4:	begin
			ExpABus32B=A[126:112]-15'd16256;
			ExpABus32C=A[126:112]-15'd16256;
			ExpABus32D=A[126:112]-15'd16256;
			ExpABus64=A[126:112]-15'd15360;
			end
			// 4 32-bit
	3'd5:	begin
			ExpABus32B={7'd0, A[62:55]};
			ExpABus32C={7'd0, A[94:87]};
			ExpABus32D={7'd0, A[126:119]};
			ExpABus64={7'd0,A[62:55]}+11'd896;
			end
			// 2 64-bit
	3'd6:	begin
			ExpABus32B<={4'd0, A[62:52]}-11'd896;
			ExpABus32C<={4'd0, A[126:116]}-11'd896;
			ExpABus32D<={4'd0, A[126:116]}-11'd896;
			ExpABus64<={4'd0, A[126:116]};
			end
			// 32 bit
	default	begin
			ExpABus32B<={7'd0, A[30:23]};
			ExpABus32C<={7'd0, A[30:23]};
			ExpABus32D<={7'd0, A[30:23]};
			ExpABus64<={7'd0,A[30:23]}+11'd896;
			end
	endcase

casex (SB)
			// 64 bit
	3'd3:	begin
			ExpBBus32B={4'd0, B[62:52]}-11'd896;
			ExpBBus32C={4'd0, B[62:52]}-11'd896;
			ExpBBus32D={4'd0, B[62:52]}-11'd896;
			ExpBBus64={4'd0, B[62:52]};
			end
			// 128 bit
	3'd4:	begin
			ExpBBus32B=B[126:112]-15'd16256;
			ExpBBus32C=B[126:112]-15'd16256;
			ExpBBus32D=B[126:112]-15'd16256;
			ExpBBus64=B[126:112]-15'd15360;
			end
			// 4 32-bit
	3'd5:	begin
			ExpBBus32B={7'd0, B[62:55]};
			ExpBBus32C={7'd0, B[94:87]};
			ExpBBus32D={7'd0, B[126:119]};
			ExpBBus64={7'd0,B[62:55]}+11'd896;
			end
			// 2 64-bit
	3'd6:	begin
			ExpBBus32B<={4'd0, B[62:52]}-11'd896;
			ExpBBus32C<={4'd0, B[126:116]}-11'd896;
			ExpBBus32D<={4'd0, B[126:116]}-11'd896;
			ExpBBus64<={4'd0, B[126:116]};
			end
			// 32 bit
	default	begin
			ExpBBus32B<={7'd0, B[30:23]};
			ExpBBus32C<={7'd0, B[30:23]};
			ExpBBus32D<={7'd0, B[30:23]};
			ExpBBus64<={7'd0,B[30:23]}+11'd896;
			end
	endcase


NormValWire=8'd0;
for (i=0; i<114; i=i+1)
		if (OutMantisa[i]) NormValWire=i[7:0];
		
NormValWire32B=5'd0;
for (iB=0; iB<25; iB=iB+1)
		if (OutMantisa32B[iB]) NormValWire32B=iB[4:0];

NormValWire32C=5'd0;
for (iC=0; iC<25; iC=iC+1)
		if (OutMantisa32C[iC]) NormValWire32C=iC[4:0];
		
NormValWire32D=5'd0;
for (iD=0; iD<25; iD=iD+1)
		if (OutMantisa32D[iD]) NormValWire32D=iD[4:0];

NormValWire64=6'd0;
for (i64=0; i64<54; i64=i64+1)
		if (OutMantisa64[i64]) NormValWire64=i64[5:0];

end

//=================================================================================================
//			clock
always_ff @(posedge CLK)
begin

//-----------------------------------------------
// 		first stage
// source exponent for single and double channel
CompFlag<=CMD[1];
ModeFlag<=CMD[0];

ExpA<=ExpABus;
ExpB<=ExpBBus;
ExpA32B<=ExpABus32B[7:0];
ExpA32C<=ExpABus32C[7:0];
ExpA32D<=ExpABus32D[7:0];
ExpA64<=ExpABus64[10:0];
ExpB32B<=ExpBBus32B[7:0];
ExpB32C<=ExpBBus32C[7:0];
ExpB32D<=ExpBBus32D[7:0];
ExpB64<=ExpBBus64[10:0];
// source mantisa
MantisaA<=(SA==3'd4) ? A[111:0] : (SA[1] & (SA[2]^SA[0])) ? {A[51:0], 60'd0} : {A[22:0], 89'd0};
MantisaB<=(SB==3'd4) ? B[111:0] : (SB[1] & (SB[2]^SB[0])) ? {B[51:0], 60'd0} : {B[22:0], 89'd0};
casex (SA)
			// 64-bit
	3'd3:	begin
			MantisaA32B<=A[51:29];
			MantisaA32C<=A[51:29];
			MantisaA32D<=A[51:29];
			MantisaA64<=A[51:0];
			end
			// 128-bit
	3'd4:	begin
			MantisaA32B<=A[111:89];
			MantisaA32C<=A[111:89];
			MantisaA32D<=A[111:89];
			MantisaA64<=A[111:60];
			end
			// 4 32-bit
	3'd5:	begin
			MantisaA32B<=A[54:32];
			MantisaA32C<=A[86:64];
			MantisaA32D<=A[118:96];
			MantisaA64<={A[54:32], 29'd0};
			end
			// 2 64 bit
	3'd6:	begin
			MantisaA32B<=A[51:29];
			MantisaA32C<=A[115:93];
			MantisaA32D<=A[115:93];
			MantisaA64<=A[115:64];
			end
			// 32-bit
	default	begin
			MantisaA32B<=A[22:0];
	        MantisaA32C<=A[22:0];
	        MantisaA32D<=A[22:0];
			MantisaA64<={A[22:0], 29'd0};
			end
	endcase
casex (SB)
			// 64-bit
	3'd3:	begin
			MantisaB32B<=B[51:29];
			MantisaB32C<=B[51:29];
			MantisaB32D<=B[51:29];
			MantisaB64<=B[51:0];
			end
			// 128-bit
	3'd4:	begin
			MantisaB32B<=B[111:89];
			MantisaB32C<=B[111:89];
			MantisaB32D<=B[111:89];
			MantisaB64<=B[111:60];
			end
			// 4 32-bit
	3'd5:	begin
			MantisaB32B<=B[54:32];
			MantisaB32C<=B[86:64];
			MantisaB32D<=B[118:96];
			MantisaB64<={B[54:32], 29'd0};
			end
			// 2 64 bit
	3'd6:	begin
			MantisaB32B<=B[51:29];
			MantisaB32C<=B[115:93];
			MantisaB32D<=B[115:93];
			MantisaB64<=B[115:64];
			end
			// 32-bit
	default	begin
			MantisaB32B<=B[22:0];
	        MantisaB32C<=B[22:0];
	        MantisaB32D<=B[22:0];
			MantisaB64<={B[22:0], 29'd0};
			end
	endcase
// creating shift parameters
SParA<=(ExpBBus-ExpABus) & {15{ExpABus<ExpBBus}};
SParB<=(ExpABus-ExpBBus) & {15{ExpBBus<ExpABus}};

SParA32B<=(ExpBBus32B[7:0]-ExpABus32B[7:0]) & {8{ExpABus32B<ExpBBus32B}};
SParB32B<=(ExpABus32B[7:0]-ExpBBus32B[7:0]) & {8{ExpBBus32B<ExpABus32B}};
SParA32C<=(ExpBBus32C[7:0]-ExpABus32C[7:0]) & {8{ExpABus32C<ExpBBus32C}};
SParB32C<=(ExpABus32C[7:0]-ExpBBus32C[7:0]) & {8{ExpBBus32C<ExpABus32C}};
SParA32D<=(ExpBBus32D[7:0]-ExpABus32D[7:0]) & {8{ExpABus32D<ExpBBus32D}};
SParB32D<=(ExpABus32D[7:0]-ExpBBus32D[7:0]) & {8{ExpBBus32D<ExpABus32D}};

SParA64<=(ExpBBus64[7:0]-ExpABus64[7:0]) & {8{ExpABus64<ExpBBus64}};
SParB64<=(ExpABus64[7:0]-ExpBBus64[7:0]) & {8{ExpBBus64<ExpABus64}};

// sign of operand
SignA<=(SA==3'd4) ? A[127] : ((SA==3'd3)|(SA==3'd6) ? A[63] : A[31]);
SignB<=((SB==3'd4) ? B[127] : ((SB==3'd3)|(SB==3'd6) ? B[63] : B[31]))^(CMD[0] & CMD[1]);
casex(SA)
	// 64-bit
	3'd3:	begin SignA32B<=A[63]; SignA32C<=A[63]; SignA32D<=A[63]; SignA64<=A[63]; end
	// 128-bit
	3'd4:	begin SignA32B<=A[127]; SignA32C<=A[127]; SignA32D<=A[127]; SignA64<=A[127]; end
	// 4 32-bit
	3'd5:	begin SignA32B<=A[63]; SignA32C<=A[95]; SignA32D<=A[127]; SignA64<=A[63]; end
	// 2 64-bit
	3'd6:	begin SignA32B<=A[63]; SignA32C<=A[127]; SignA32D<=A[127]; SignA64<=A[127]; end
	// 32-bit
	default	begin SignA32B<=A[31]; SignA32C<=A[31]; SignA32D<=A[31]; SignA64<=A[31]; end
	endcase
casex(SB)
	// 64-bit
	3'd3:	begin SignB32B<=B[63]^CMD[0]; SignB32C<=B[63]^CMD[0]; SignB32D<=B[63]^CMD[0]; SignB64<=B[63]^CMD[0]; end
	// 128-bit
	3'd4:	begin SignB32B<=B[127]^CMD[0]; SignB32C<=B[127]^CMD[0]; SignB32D<=B[127]^CMD[0]; SignB64<=B[127]^CMD[0]; end
	// 4 32-bit
	3'd5:	begin SignB32B<=B[63]^CMD[0]; SignB32C<=B[95]^CMD[0]; SignB32D<=B[127]^CMD[0]; SignB64<=B[63]^CMD[0]; end
	// 2 64-bit
	3'd6:	begin SignB32B<=B[63]^CMD[0]; SignB32C<=B[127]^CMD[0]; SignB32D<=B[127]^CMD[0]; SignB64<=B[127]^CMD[0]; end
	// 32-bit
	default	begin SignB32B<=B[31]^CMD[0]; SignB32C<=B[31]^CMD[0]; SignB32D<=B[31]^CMD[0]; SignB64<=B[31]^CMD[0]; end
	endcase

// Nan detection
NanA<=(SA==3'd4) ? &A[126:112] & (|A[111:0]) : ((SA==3'd3)|(SA==3'd6) ? &A[62:52] & (|A[51:0]) : &A[30:23] & (|A[22:0]));
NanB<=(SB==3'd4) ? &B[126:112] & (|B[111:0]) : ((SB==3'd3)|(SB==3'd6) ? &B[62:52] & (|B[51:0]) : &B[30:23] & (|B[22:0]));
// infinity detection
InfA<=(SA==3'd4) ? &A[126:112] & (~(|A[111:0])) : ((SA==3'd3)|(SA==3'd6) ? &A[62:52] & (~(|A[51:0])) : &A[30:23] & (~(|A[22:0])));
InfB<=(SB==3'd4) ? &B[126:112] & (~(|B[111:0])) : ((SB==3'd3)|(SB==3'd6) ? &B[62:52] & (~(|B[51:0])) : &B[30:23] & (~(|B[22:0])));
// zero flags
casex(SA)
	// 64-bit
	3'd3:	begin
			ZeroA<=~|A[62:0];
			ZeroA32B<=~|A[62:0];
			ZeroA32C<=~|A[62:0];
			ZeroA32D<=~|A[62:0];
			ZeroA64<=~|A[62:0];
			end
	// 128-bit
	3'd4:	begin
			ZeroA<=~|A[127:0];
			ZeroA32B<=~|A[126:0];
			ZeroA32C<=~|A[126:0];
			ZeroA32D<=~|A[126:0];
			ZeroA64<=~|A[126:0];
			end
	// 4 32-bit
	3'd5:	begin
			ZeroA<=~|A[30:0];
			ZeroA32B<=~|A[62:32];
			ZeroA32C<=~|A[94:64];
			ZeroA32D<=~|A[126:96];
			ZeroA64<=~|A[62:32];
			end
	// 2 64-bit
	3'd6:	begin
			ZeroA<=~|A[62:0];
			ZeroA32B<=~|A[62:0];
			ZeroA32C<=~|A[126:64];
			ZeroA32D<=~|A[126:64];
			ZeroA64<=~|A[126:64];
			end
	// 32-bit
	default	begin
			ZeroA<=~|A[30:0];
			ZeroA32B<=~|A[30:0];
			ZeroA32C<=~|A[30:0];
			ZeroA32D<=~|A[30:0];
			ZeroA64<=~|A[30:0];
			end
	endcase
casex(SB)
	// 64-bit
	3'd3:	begin
			ZeroB<=~|B[62:0];
			ZeroB32B<=~|B[62:0];
			ZeroB32C<=~|B[62:0];
			ZeroB32D<=~|B[62:0];
			ZeroB64<=~|B[62:0];
			end
	// 128-bit
	3'd4:	begin
			ZeroB<=~|B[127:0];
			ZeroB32B<=~|B[126:0];
			ZeroB32C<=~|B[126:0];
			ZeroB32D<=~|B[126:0];
			ZeroB64<=~|B[126:0];
			end
	// 4 32-bit
	3'd5:	begin
			ZeroB<=~|B[30:0];
			ZeroB32B<=~|B[62:32];
			ZeroB32C<=~|B[94:64];
			ZeroB32D<=~|B[126:96];
			ZeroB64<=~|B[62:32];
			end
	// 2 64-bit
	3'd6:	begin
			ZeroB<=~|B[62:0];
			ZeroB32B<=~|B[62:0];
			ZeroB32C<=~|B[126:64];
			ZeroB32D<=~|B[126:64];
			ZeroB64<=~|B[126:64];
			end
	// 32-bit
	default	begin
			ZeroB<=~|B[30:0];
			ZeroB32B<=~|B[30:0];
			ZeroB32C<=~|B[30:0];
			ZeroB32D<=~|B[30:0];
			ZeroB64<=~|B[30:0];
			end
	endcase
// result size selection
StartSR<=SD;
// activation and destination
StartACT<=ACT & RESET;
StartDST<=DSTI;

//-----------------------------------------------
//		mantisa shift stage
IntMantisaA<=({1'b1, MantisaA}>>(SParA[7:0] & {8{~ZeroA & ~ZeroB & CompFlag}})) & {113{SParA<15'd113}};
IntMantisaB<=({1'b1, MantisaB}>>(SParB[7:0] & {8{~ZeroA & ~ZeroB & CompFlag}})) & {113{SParB<15'd113}};

IntMantisaA32B<=({1'b1, MantisaA32B}>>(SParA32B[4:0] & {5{~ZeroA32B & ~ZeroB32B}})) & {24{SParA32B<8'd24}};
IntMantisaB32B<=({1'b1, MantisaB32B}>>(SParB32B[4:0] & {5{~ZeroA32B & ~ZeroB32B}})) & {24{SParB32B<8'd24}};
IntMantisaA32C<=({1'b1, MantisaA32C}>>(SParA32C[4:0] & {5{~ZeroA32C & ~ZeroB32C}})) & {24{SParA32C<8'd24}};
IntMantisaB32C<=({1'b1, MantisaB32C}>>(SParB32C[4:0] & {5{~ZeroA32C & ~ZeroB32C}})) & {24{SParB32C<8'd24}};
IntMantisaA32D<=({1'b1, MantisaA32D}>>(SParA32D[4:0] & {5{~ZeroA32D & ~ZeroB32D}})) & {24{SParA32D<8'd24}};
IntMantisaB32D<=({1'b1, MantisaB32D}>>(SParB32D[4:0] & {5{~ZeroA32D & ~ZeroB32D}})) & {24{SParB32D<8'd24}};

IntMantisaA64<=({1'b1, MantisaA64}>>(SParA64[5:0] & {6{~ZeroA64 & ~ZeroB64}})) & {53{SParA64<8'd53}};
IntMantisaB64<=({1'b1, MantisaB64}>>(SParB64[5:0] & {6{~ZeroA64 & ~ZeroB64}})) & {53{SParB64<8'd53}};

// common exponent
IntExponent<=(ExpA & {15{~ZeroA & (ExpA>=ExpB)}})|(ExpB & {15{~ZeroB & (ExpB>ExpA)}});
IntExponent32B<=(ExpA32B & {8{~ZeroA32B & (ExpA32B>=ExpB32B)}})|(ExpB32B & {8{~ZeroB32B & (ExpB32B>ExpA32B)}});
IntExponent32C<=(ExpA32C & {8{~ZeroA32C & (ExpA32C>=ExpB32C)}})|(ExpB32C & {8{~ZeroB32C & (ExpB32C>ExpA32C)}});
IntExponent32D<=(ExpA32D & {8{~ZeroA32D & (ExpA32D>=ExpB32D)}})|(ExpB32D & {8{~ZeroB32D & (ExpB32D>ExpA32D)}});
IntExponent64<=(ExpA64 & {11{~ZeroA64 & (ExpA64>=ExpB64)}})|(ExpB64 & {11{~ZeroB64 & (ExpB64>ExpA64)}});

// compare exponents and signs
IntCompFlag<=CompFlag;
IntModeFlag<=ModeFlag;
IntExpAgB<=(~SignA & SignB)|(~SignA & ~SignB & (ExpA>ExpB))|(SignA & SignB & (ExpA<ExpB))|(ZeroA & SignB)|(ZeroB & ~SignA);
IntExpAeB<=((SignA ~^ SignB)&(ExpA==ExpB))|(ZeroA & ZeroB);
IntMantAgB<=(MantisaA>MantisaB)^(SignA & SignB);
IntExpA<=ExpA;
IntExpB<=ExpB;

// sign
IntSignA<=SignA & ~ZeroA;
IntSignB<=SignB & ~ZeroB;
IntSignA32B<=SignA32B & ~ZeroA32B;
IntSignB32B<=SignB32B & ~ZeroB32B;
IntSignA32C<=SignA32C & ~ZeroA32C;
IntSignB32C<=SignB32C & ~ZeroB32C;
IntSignA32D<=SignA32D & ~ZeroA32D;
IntSignB32D<=SignB32D & ~ZeroB32D;
IntSignA64<=SignA64 & ~ZeroA64;
IntSignB64<=SignB64 & ~ZeroB64;

IntNan<=NanA | NanB;
IntInf<=(InfA | InfB) & ~NanA & ~NanB;
IntSR<=StartSR;
IntACT<=StartACT & RESET;
IntDST<=StartDST;

//-----------------------------------------------
//		first stage of the operand negation
NegMantisaA_Low<={1'b0, IntMantisaA[57:0] ^ {58{IntSignA}}}+{58'd0, IntSignA};
NegMantisaA_High<=IntMantisaA[112:58];
NegMantisaB_Low<={1'b0, IntMantisaB[57:0] ^ {58{IntSignB}}}+{58'd0, IntSignB};
NegMantisaB_High<=IntMantisaB[112:58];

NegMantisaA32B<=({2'd0,IntMantisaA32B}^{26{IntSignA32B}})+{25'd0,IntSignA32B};
NegMantisaB32B<=({2'd0,IntMantisaB32B}^{26{IntSignB32B}})+{25'd0,IntSignB32B};
NegMantisaA32C<=({2'd0,IntMantisaA32C}^{26{IntSignA32C}})+{25'd0,IntSignA32C};
NegMantisaB32C<=({2'd0,IntMantisaB32C}^{26{IntSignB32C}})+{25'd0,IntSignB32C};
NegMantisaA32D<=({2'd0,IntMantisaA32D}^{26{IntSignA32D}})+{25'd0,IntSignA32D};
NegMantisaB32D<=({2'd0,IntMantisaB32D}^{26{IntSignB32D}})+{25'd0,IntSignB32D};
NegMantisaA64<=({2'd0,IntMantisaA64}^{55{IntSignA64}})+{54'd0,IntSignA64};
NegMantisaB64<=({2'd0,IntMantisaB64}^{55{IntSignB64}})+{54'd0,IntSignB64};

// compare datas
NegCompFlag<=~IntCompFlag;
NegModeFlag<=IntModeFlag;
NegAgB<=IntExpAgB | (IntMantAgB & IntExpAeB);
NegExpA<=IntExpA;
NegExpB<=IntExpB;

NegExponent<=IntExponent;
NegExponent32B<=IntExponent32B;
NegExponent32C<=IntExponent32C;
NegExponent32D<=IntExponent32D;
NegExponent64<=IntExponent64;

NegSignA<=IntSignA & |IntMantisaA;
NegSignB<=IntSignB & |IntMantisaB;

NegNan<=IntNan;
NegInf<=IntInf;
NegSR<=IntSR;
NegACT<=IntACT & RESET;
NegDST<=IntDST;

//-----------------------------------------------
//		second stage of the operand negation
AddMantisaA<={{2{NegSignA}}, ((NegMantisaA_High ^ {55{NegSignA}})+{54'd0, NegMantisaA_Low[58]}), NegMantisaA_Low[57:0]};
AddMantisaB<={{2{NegSignB}}, ((NegMantisaB_High ^ {55{NegSignB}})+{54'd0, NegMantisaB_Low[58]}), NegMantisaB_Low[57:0]};
AddMantisaA32B<=NegMantisaA32B;
AddMantisaB32B<=NegMantisaB32B;
AddMantisaA32C<=NegMantisaA32C;
AddMantisaB32C<=NegMantisaB32C;
AddMantisaA32D<=NegMantisaA32D;
AddMantisaB32D<=NegMantisaB32D;
AddMantisaA64<=NegMantisaA64;
AddMantisaB64<=NegMantisaB64;

// compare datas
AddSelA<=(NegAgB ^ ~NegModeFlag) & NegCompFlag;
AddSelB<=(~NegAgB ^ ~NegModeFlag) & NegCompFlag;

AddExponent<=NegCompFlag ? ((NegAgB ^ ~NegModeFlag) ? NegExpA : NegExpB) : NegExponent;
AddExponent32B<=NegExponent32B;
AddExponent32C<=NegExponent32C;
AddExponent32D<=NegExponent32D;
AddExponent64<=NegExponent64;

AddNan<=NegNan;
AddInf<=NegInf;
AddSR<=NegSR;
AddACT<=NegACT & RESET;
AddDST<=NegDST;

//-----------------------------------------------
//		first stage of the mantisa adder
IntAdder_Low<={1'b0, AddMantisaA[57:0] & {58{~AddSelB}}}+{1'b0, AddMantisaB[57:0] & {58{~AddSelA}}};
IntAdderA_High<=AddMantisaA[114:58] & {57{~AddSelB}};
IntAdderB_High<=AddMantisaB[114:58] & {57{~AddSelA}};
IntAdder32B<=AddMantisaA32B+AddMantisaB32B;
IntAdder32C<=AddMantisaA32C+AddMantisaB32C;
IntAdder32D<=AddMantisaA32D+AddMantisaB32D;
IntAdder64<=AddMantisaA64+AddMantisaB64;

IntAdderExponent<=AddExponent;
IntAdderExponent32B<=AddExponent32B;
IntAdderExponent32C<=AddExponent32C;
IntAdderExponent32D<=AddExponent32D;
IntAdderExponent64<=AddExponent64;

IntAdderNan<=AddNan;
IntAdderInf<=AddInf;
IntAdderSR<=AddSR;
IntAdderACT<=AddACT & RESET;
IntAdderDST<=AddDST;

//-----------------------------------------------
//		second stage of the mantisa adder
AdderMantisa<={IntAdderA_High+IntAdderB_High+{56'd0, IntAdder_Low[58]}, IntAdder_Low[57:0]};
AdderMantisa32B<=IntAdder32B;
AdderMantisa32C<=IntAdder32C;
AdderMantisa32D<=IntAdder32D;
AdderMantisa64<=IntAdder64;

AdderExponent<=IntAdderExponent;
AdderExponent32B<=IntAdderExponent32B;
AdderExponent32C<=IntAdderExponent32C;
AdderExponent32D<=IntAdderExponent32D;
AdderExponent64<=IntAdderExponent64;

AdderNan<=IntAdderNan;
AdderInf<=IntAdderInf;
AdderSR<=IntAdderSR;
AdderACT<=IntAdderACT & RESET;
AdderDST<=IntAdderDST;

//-----------------------------------------------
//		First stage of result negation
OutNegMantisa_Low<={1'b0, AdderMantisa[57:0] ^ {58{AdderMantisa[114]}}}+{58'd0, AdderMantisa[114]};
OutNegMantisa_High<=AdderMantisa[114:58];
OutNegMantisa32B<=(AdderMantisa32B ^ {26{AdderMantisa32B[25]}})+{25'd0, AdderMantisa32B[25]};
OutNegMantisa32C<=(AdderMantisa32C ^ {26{AdderMantisa32C[25]}})+{25'd0, AdderMantisa32C[25]};
OutNegMantisa32D<=(AdderMantisa32D ^ {26{AdderMantisa32D[25]}})+{25'd0, AdderMantisa32D[25]};
OutNegMantisa64<=(AdderMantisa64 ^ {55{AdderMantisa64[54]}})+{54'd0, AdderMantisa64[54]};

OutNegExponent<=AdderExponent;
OutNegExponent32B<=AdderExponent32B;
OutNegExponent32C<=AdderExponent32C;
OutNegExponent32D<=AdderExponent32D;
OutNegExponent64<=AdderExponent64;

OutNegSign32B<=AdderMantisa32B[25];
OutNegSign32C<=AdderMantisa32C[25];
OutNegSign32D<=AdderMantisa32D[25];
OutNegSign64<=AdderMantisa64[54];

OutNegNan<=AdderNan;
OutNegInf<=AdderInf;
OutNegSR<=AdderSR;
OutNegACT<=AdderACT & RESET;
OutNegDST<=AdderDST;

//-----------------------------------------------
//		Second stage result negation
OutMantisa<={(OutNegMantisa_High ^ {57{OutNegMantisa_High[56]}})+{56'd0, OutNegMantisa_Low[58]}, OutNegMantisa_Low[57:0]};
OutMantisa32B<=OutNegMantisa32B;
OutMantisa32C<=OutNegMantisa32C;
OutMantisa32D<=OutNegMantisa32D;
OutMantisa64<=OutNegMantisa64;

OutExponent<=OutNegExponent;
OutExponent32B<=OutNegExponent32B;
OutExponent32C<=OutNegExponent32C;
OutExponent32D<=OutNegExponent32D;
OutExponent64<=OutNegExponent64;

OutSign<=OutNegMantisa_High[56];
OutSign32B<=OutNegSign32B;
OutSign32C<=OutNegSign32C;
OutSign32D<=OutNegSign32D;
OutSign64<=OutNegSign64;

OutInf<=OutNegInf;
OutNan<=OutNegNan;
OutSR<=OutNegSR;
OutACT<=OutNegACT & RESET;
OutDST<=OutNegDST;

//-----------------------------------------------
//		result normalisation
NormMantisa<=OutMantisa;
NormMantisa32B<=OutMantisa32B;
NormMantisa32C<=OutMantisa32C;
NormMantisa32D<=OutMantisa32D;
NormMantisa64<=OutMantisa64;

NormExponent<=OutExponent;
NormExponent32B<=OutExponent32B;
NormExponent32C<=OutExponent32C;
NormExponent32D<=OutExponent32D;
NormExponent64<=OutExponent64;

NormValue<=8'd113-NormValWire;
NormValue32B<=5'd24-NormValWire32B;
NormValue32C<=5'd24-NormValWire32C;
NormValue32D<=5'd24-NormValWire32D;
NormValue64<=6'd53-NormValWire64;

NormSign<=OutSign;
NormSign32B<=OutSign32B;
NormSign32C<=OutSign32C;
NormSign32D<=OutSign32D;
NormSign64<=OutSign64;

NormInf<=OutInf;
NormNan<=OutNan;
NormSR<=OutSR;

//-----------------------------------------------
// 		finaly result
ResultMantisa<=NormMantisa << NormValue;
ResultMantisa32B<=NormMantisa32B << NormValue32B;
ResultMantisa32C<=NormMantisa32C << NormValue32C;
ResultMantisa32D<=NormMantisa32D << NormValue32D;
ResultMantisa64<=NormMantisa64 << NormValue64;

// create infinity value
case (NormSR)
	// 64-bit
	3'b011:	begin
			ResultInf<=NormInf | (((NormExponent-NormValue)>15'd17405) & ~NormNan);
			ResultZero<=(~(|NormMantisa) | ((NormExponent-NormValue)<15'd15362)) & ~NormNan & ~NormInf;
			ResultExponent<=NormExponent-NormValue-15'd15359;
			end
	// 128-bit
	3'b100:	begin
			ResultInf<=NormInf;
			ResultZero<=1'b0;
			ResultExponent<=NormExponent-NormValue+15'd1;
			ResultZero<=(~(|NormMantisa)) & ~NormNan & ~NormInf;
			end
	// 4 32-bit
	3'b101:	begin
			ResultInf<=NormInf | (((NormExponent-NormValue)>15'd16509) & ~NormNan);
			ResultZero<=(~(|NormMantisa) | ((NormExponent-NormValue)<15'd16257)) & ~NormNan & ~NormInf;
			ResultExponent<=NormExponent-NormValue-15'd16255;
			end
	// 2 64-bit
	3'b110:	begin
			ResultInf<=NormInf | (((NormExponent-NormValue)>15'd17405) & ~NormNan);
			ResultZero<=(~(|NormMantisa) | ((NormExponent-NormValue)<15'd15362)) & ~NormNan & ~NormInf;
			ResultExponent<=NormExponent-NormValue-15'd15359;
			end
	// 32-bit
	default:	begin
				ResultInf<=NormInf | (((NormExponent-NormValue)>15'd16509) & ~NormNan);
				ResultZero<=(~(|NormMantisa) | ((NormExponent-NormValue)<15'd16257)) & ~NormNan & ~NormInf;
				ResultExponent<=NormExponent-NormValue-15'd16255;
				end
	endcase
ResultExponent32B<=NormExponent32B-NormValue32B+8'd1;
ResultExponent32C<=NormExponent32C-NormValue32C+8'd1;
ResultExponent32D<=NormExponent32D-NormValue32D+8'd1;
ResultExponent64<=NormExponent64-NormValue64+11'd1;

ResultZero32B<=~|NormMantisa32B;
ResultZero32C<=~|NormMantisa32C;
ResultZero32D<=~|NormMantisa32D;
ResultZero64<=~|NormMantisa64;

ResultSign<=NormSign;
ResultSign32B<=NormSign32B;
ResultSign32C<=NormSign32C;
ResultSign32D<=NormSign32D;
ResultSign64<=NormSign64;

ResultNan<=NormNan;
ResultSR<=NormSR;
ResultACT<=OutACT & RESET;
ResultDST<=OutDST;

//-----------------------------------------------
//		create result
casez (ResultSR)
	3'd3:		ResReg<={64'd0, ResultSign, (ResultExponent[10:0] & {11{~ResultZero}}) | {11{ResultNan | ResultInf}}, (ResultMantisa[112:61] & {52{~ResultInf}}) | {52{ResultNan}}};
	3'd4:		ResReg<={ResultSign, (ResultExponent & {15{~ResultZero}}) | {15{ResultNan | ResultInf}}, (ResultMantisa[112:1] & {112{~ResultInf}}) | {112{ResultNan}}};
	3'd5:		ResReg<={ResultSign32D, ResultExponent32D & {8{~ResultZero32D}}, ResultMantisa32D[23:1],
						ResultSign32C, ResultExponent32C & {8{~ResultZero32C}}, ResultMantisa32C[23:1],
						ResultSign32B, ResultExponent32B & {8{~ResultZero32B}}, ResultMantisa32B[23:1],
						ResultSign, (ResultExponent[7:0] & {8{~ResultZero}}) | {8{ResultNan | ResultInf}}, (ResultMantisa[112:90] & {23{~ResultInf}}) | {23{ResultNan}}};
	3'd6:		ResReg<={ResultSign64, ResultExponent64 & {11{~ResultZero64}}, ResultMantisa64[52:1],
						ResultSign, (ResultExponent[10:0] & {11{~ResultZero}}) | {11{ResultNan | ResultInf}}, (ResultMantisa[112:61] & {52{~ResultInf}}) | {52{ResultNan}}};
	default:	ResReg<={96'd0, ResultSign, (ResultExponent[7:0] & {8{~ResultZero}}) | {8{ResultNan | ResultInf}}, (ResultMantisa[112:90] & {23{~ResultInf}}) | {23{ResultNan}}};
	endcase

ResSign<=ResultSign;
ResNan<=ResultNan;
ResInf<=ResultInf;
ResZero<=ResultZero;

end

endmodule
