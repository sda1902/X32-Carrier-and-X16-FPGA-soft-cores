/*
DAA		000
DAS		001
NEG		010
BSWAP	011
RND		100
POS		101
FP2INT	110
INT2FP	111
*/

module Misc64X32 (
	input wire CLK, ACT,
	input wire [2:0] OpCODE,
	input wire [2:0] SA, SB, SD,
	
	input wire [4:0] DSTi,
	input wire [15:0] CIN,
	input wire [127:0] A,
	input wire [15:0] B,
	
	output wire RDY,
	output reg ZERO, SIGN, OVR, COUT, NaN,
	output reg [2:0] SR,
	output wire [4:0] DSTo,
	output reg [127:0] R
	);
	
integer i0, i1, i2, i3, i4;

reg [2:0] TempOpCODE, SAReg;
reg [63:0] ABus, DAABus, BSWAPBus, NEGBus, PosA, IFReg;
reg [127:0] Int2FPBus, FP2IntBus;
// CFBus format: {Sign, NAN, INF, Zero, 128-bit value}
reg [131:0] CFBus;
wire [15:0] CTemp;
reg [7:0] PosBus, TempPos;
reg TempINF, TempNaN, TempZero, TempSign, ABReg, FPSign, FPZero;
reg [3:0] CReg;
reg [10:0] Exp64To32Bus;
reg [14:0] Exp128To32Bus, Exp128To64Bus;
reg [23:0] Rnd64To32Bus, Rnd128To32Bus;
reg [52:0] Rnd128To64Bus;
reg [15:0] FP2IntShiftBus, BBus;

	
assign CTemp[0]=(A[3:0]>9);
assign CTemp[1]=(A[7:4]>9) | (CTemp[0] & (A[7:4]==9));
assign CTemp[2]=(A[11:8]>9) | (CTemp[1] & (A[11:8]==9));
assign CTemp[3]=(A[15:12]>9) | (CTemp[2] & (A[15:12]==9));
assign CTemp[4]=(A[19:16]>9) | (CTemp[3] & (A[19:16]==9));
assign CTemp[5]=(A[23:20]>9) | (CTemp[4] & (A[23:20]==9));
assign CTemp[6]=(A[27:24]>9) | (CTemp[5] & (A[27:24]==9));
assign CTemp[7]=(A[31:28]>9) | (CTemp[6] & (A[31:28]==9));
assign CTemp[8]=(A[35:32]>9) | (CTemp[7] & (A[35:32]==9));
assign CTemp[9]=(A[39:36]>9) | (CTemp[8] & (A[39:36]==9));
assign CTemp[10]=(A[43:40]>9) | (CTemp[9] & (A[43:40]==9));
assign CTemp[11]=(A[47:44]>9) | (CTemp[10] & (A[47:44]==9));
assign CTemp[12]=(A[51:48]>9) | (CTemp[11] & (A[51:48]==9));
assign CTemp[13]=(A[55:52]>9) | (CTemp[12] & (A[55:52]==9));
assign CTemp[14]=(A[59:56]>9) | (CTemp[13] & (A[59:56]==9));
assign CTemp[15]=(A[63:60]>9) | (CTemp[14] & (A[63:60]==9));

assign DSTo=DSTi;
assign RDY=ACT;

always @(*)
	begin
	
	// forming POS A bus
	PosA=(A[63:0] ^ {64{A[63]}})+{63'd0,A[63]};
	
	// forming POS value
	PosBus[5:0]=6'b000000;
	for (i0=0; i0<64; i0=i0+1)
		if (PosA[i0]) PosBus[5:0]=i0[5:0];
	PosBus[7:6]=2'b00;

	
	// forming flags (NaN, INF, Zero)
	TempINF=(SA[2] ? &A[126:112] : (SA[0] ? &A[62:52] : &A[30:23])) & (SA[2] ? ~(|A[111:0]) : (SA[0] ? ~(|A[51:0]) : ~(|A[22:0])));
	TempNaN=(SA[2] ? &A[126:112] : (SA[0] ? &A[62:52] : &A[30:23])) & (SA[2] ? |A[111:0] : (SA[0] ? |A[51:0] : |A[22:0]));
	TempZero=SA[2] ? ~(|A[126:0]) : (SA[0] ? ~(|A[62:0]) : ~(|A[30:0]));
	TempSign=SA[2] ? A[127] : (SA[0] ? A[63] : A[31]);
	
	
	NEGBus=ABus+DAABus+TempOpCODE[0];
	
	// round buses
	Rnd64To32Bus={1'b0, A[51:29]}+{23'd0, A[28]};
	Rnd128To32Bus={1'b0, A[111:89]}+{23'd0, A[88]};
	Rnd128To64Bus={1'b0, A[111:60]}+{52'd0, A[59]};
	
	casez ({SA[2],SA[0]})
		2'b00: FP2IntShiftBus=16'd127-({8'd0,A[30:23]}-16'd127);
		2'b01: FP2IntShiftBus=16'd1023-({5'd0,A[62:52]}-16'd1023);
		2'b1?: FP2IntShiftBus=16'd16383-({1'd0,A[126:112]}-16'd16383);
		endcase
		
	casez ({SR[2],SR[0]})
		2'b00: Int2FPBus={64'd0,IFReg} << (5'd23-TempPos[4:0]);
		2'b01: Int2FPBus={64'd0,IFReg} << (6'd52-TempPos[5:0]);
		2'b1?: Int2FPBus={64'd0,IFReg} << (7'd112-TempPos[6:0]);
		endcase
	
	Exp64To32Bus=(A[62:52]-11'd896) + Rnd64To32Bus[23];
	Exp128To32Bus=(A[126:112]-15'd16256) + Rnd128To32Bus[23];
	Exp128To64Bus=(A[126:112]-15'd15360) + Rnd128To64Bus[52];
	
	end


always @(posedge CLK)
	begin
	
	TempOpCODE<=OpCODE;
	TempPos<=PosBus;
	
	// preparing the source operands
	ABus<=A[63:0];
	BBus<=B;
	ABReg<=A[127];
	SAReg<=SA;
	IFReg<=PosA;
	
	// BSWAP result
	case (SA[1:0])
		2'b00: for (i1=0; i1<4; i1=i1+1)
					begin
					BSWAPBus[i1]<=A[7-i1];
					BSWAPBus[7-i1]<=A[i1];
					end
		2'b01: for (i2=0; i2<8; i2=i2+1)
					begin
					BSWAPBus[i2]<=A[15-i2];
					BSWAPBus[15-i2]<=A[i2];
					end
		2'b10: for (i3=0; i3<16; i3=i3+1)
					begin
					BSWAPBus[i3]<=A[31-i3];
					BSWAPBus[31-i3]<=A[i3];
					end
		2'b11: for (i4=0; i4<32; i4=i4+1)
					begin
					BSWAPBus[i4]<=A[63-i4];
					BSWAPBus[63-i4]<=A[i4];
					end
		endcase
	
	// float to integer bus
	casez (SA)
		3'b0?0: FP2IntBus<={1'b1,A[22:0],104'd0} >> FP2IntShiftBus[6:0];
		3'b0?1: FP2IntBus<={1'b1,A[51:0],75'd0} >> FP2IntShiftBus[6:0];
		3'b1??: FP2IntBus<={1'b1,A[111:0],15'd0} >> FP2IntShiftBus[6:0];
		endcase
	FPSign<=TempSign;
	FPZero<=~TempZero;
		
	// floating point rounding
	// CFBus format: {Sign, NAN, INF, Zero, 128-bit value}
	casez ({SD[2],SD[0],SA[2],SA[0]})
		// 32-bit to 32 bit
		4'b0000:	CFBus<={TempSign, TempNaN, TempINF, TempZero, A};
		// 64-bit to 32-bit
		4'b0001:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, 96'd0, A[63], {8{TempINF | TempNaN}}, {23{TempNaN}}};
						else if ((A[62:52]<11'd1151) & (A[62:52]>11'd896)) 
									begin
									CFBus[22:0]<=Rnd64To32Bus[22:0]; 
									CFBus[30:23]<=Exp64To32Bus[7:0];
									CFBus[31]<=A[63];
									CFBus[127:32]<=96'd0;
									CFBus[130:128]<=3'd0;
									CFBus[131]<=TempSign;
									end
								else if (A[62:52]>11'd896) CFBus<={TempSign, 3'b010, 96'd0, A[63], {8{1'b1}}, {23{1'b0}}};
										else CFBus<={TempSign, 3'd1, 128'd0};
		// 128 bit to 32 bit
		4'b001?:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, 96'd0, A[127], {8{TempINF | TempNaN}}, {23{TempNaN}}};
						else if ((A[126:112]<15'd16511) & (A[126:112]>15'd16256)) 
									begin
									CFBus[22:0]<=Rnd128To32Bus[22:0];
									CFBus[30:23]<=Exp128To32Bus[7:0];
									CFBus[31]<=A[127];
									CFBus[127:32]<=96'd0;
									CFBus[130:128]<=3'd0;
									CFBus[131]<=TempSign;
									end
								else if (A[126:112]>15'd16256) CFBus<={TempSign, 3'b010, 96'd0, A[63], {8{1'b1}}, {23{1'b0}}};
										else CFBus<={TempSign, 3'd1, 128'd0};
		// 32-bit to 64 bit
		4'b0100:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, 64'd0, A[31], {11{TempINF | TempNaN}}, {52{TempNaN}}};
						else begin
							CFBus[28:0]<=29'd0;
							CFBus[51:29]<=A[22:0];
							CFBus[62:52]<=A[30:23]+11'd896;
							CFBus[63]<=A[31];
							CFBus[127:64]<=64'd0;
							CFBus[130:128]<=3'd0;
							CFBus[131]<=TempSign;
							end
		// 64-bit to 64 bit
		4'b0101:	CFBus<={TempSign, TempNaN, TempINF, TempZero, A};
		// 128 bit to 64 bit
		4'b011?:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, 64'd0, A[127], {11{TempINF | TempNaN}}, {52{TempNaN}}};
						else if ((A[126:112]<15'd17407) & (A[126:112]>15'd15360)) 
									begin
									CFBus[51:0]<=Rnd128To64Bus[51:0];
									CFBus[62:52]<=Exp128To64Bus[10:0];
									CFBus[63]<=A[127];
									CFBus[127:64]<=64'd0;
									CFBus[130:128]<=3'd0;
									CFBus[131]<=TempSign;
									end
								else if (A[126:112]>15'd15360) CFBus<={TempSign, 3'b010, 64'd0, A[127], {11{1'b1}}, {52{1'b0}}};
										else CFBus<={TempSign, 3'd1, 128'd0};
		// 32 bit to 128 bit
		4'b1?00:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, A[31], {15{TempINF | TempNaN}}, {112{TempNaN}}};
						else begin
							CFBus[88:0]<=89'd0;
							CFBus[111:89]<=A[22:0];
							CFBus[126:112]<={7'd0, A[30:23]}+15'd16256;
							CFBus[127]<=A[31];
							CFBus[130:128]<=3'd0;
							CFBus[131]<=TempSign;
							end
		// 64 bit to 128 bit
		4'b1?01:	if (TempINF | TempNaN | TempZero) CFBus<={TempSign, TempNaN, TempINF, TempZero, A[63], {15{TempINF | TempNaN}}, {112{TempNaN}}};
						else begin
							CFBus[59:0]<=60'd0;
							CFBus[111:60]<=A[51:0];
							CFBus[126:112]<={4'd0, A[62:52]}+15'd15360;
							CFBus[127]<=A[63];
							CFBus[130:128]<=3'd0;
							CFBus[131]<=TempSign;
							end
		// 128-bit to 128 bit
		4'b1?1?:	CFBus<={TempSign, TempNaN, TempINF, TempZero, A};
		endcase
		
	// DAA operand
	DAABus[00]<=OpCODE[0];
	DAABus[02:01]<={2{((CIN[00]^OpCODE[0]) | (A[03:00]>4'h9))^OpCODE[0]}};
	DAABus[04:03]<={2{(OpCODE[0])}};
	DAABus[06:05]<={2{((CIN[01]^OpCODE[0]) | (A[07:04]>4'h9) | (~OpCODE[0] & CTemp[00] & (A[07:04]==4'h9)))^OpCODE[0]}};
	DAABus[08:07]<={2{OpCODE[0]}};
	DAABus[10:09]<={2{((CIN[02]^OpCODE[0]) | (A[11:08]>4'h9) | (~OpCODE[0] & CTemp[01] & (A[11:08]==4'h9)))^OpCODE[0]}};
	DAABus[12:11]<={2{OpCODE[0]}};
	DAABus[14:13]<={2{((CIN[03]^OpCODE[0]) | (A[15:12]>4'h9) | (~OpCODE[0] & CTemp[02] & (A[15:12]==4'h9)))^OpCODE[0]}};
	DAABus[16:15]<={2{OpCODE[0]}};
	DAABus[18:17]<={2{((CIN[04]^OpCODE[0]) | (A[19:16]>4'h9) | (~OpCODE[0] & CTemp[03] & (A[19:16]==4'h9)))^OpCODE[0]}};
	DAABus[20:19]<={2{OpCODE[0]}};
	DAABus[22:21]<={2{((CIN[05]^OpCODE[0]) | (A[23:20]>4'h9) | (~OpCODE[0] & CTemp[04] & (A[23:20]==4'h9)))^OpCODE[0]}};
	DAABus[24:23]<={2{OpCODE[0]}};
	DAABus[26:25]<={2{((CIN[06]^OpCODE[0]) | (A[27:24]>4'h9) | (~OpCODE[0] & CTemp[05] & (A[27:24]==4'h9)))^OpCODE[0]}};
	DAABus[28:27]<={2{OpCODE[0]}};
	DAABus[30:29]<={2{((CIN[07]^OpCODE[0]) | (A[31:28]>4'h9) | (~OpCODE[0] & CTemp[06] & (A[31:28]==4'h9)))^OpCODE[0]}};
	DAABus[32:31]<={2{OpCODE[0]}};
	DAABus[34:33]<={2{((CIN[08]^OpCODE[0]) | (A[35:32]>4'h9) | (~OpCODE[0] & CTemp[07] & (A[35:32]==4'h9)))^OpCODE[0]}};
	DAABus[36:35]<={2{OpCODE[0]}};
	DAABus[38:37]<={2{((CIN[09]^OpCODE[0]) | (A[39:36]>4'h9) | (~OpCODE[0] & CTemp[08] & (A[39:36]==4'h9)))^OpCODE[0]}};
	DAABus[40:39]<={2{OpCODE[0]}};
	DAABus[42:41]<={2{((CIN[10]^OpCODE[0]) | (A[43:40]>4'h9) | (~OpCODE[0] & CTemp[09] & (A[43:40]==4'h9)))^OpCODE[0]}};
	DAABus[44:43]<={2{OpCODE[0]}};
	DAABus[46:45]<={2{((CIN[11]^OpCODE[0]) | (A[47:44]>4'h9) | (~OpCODE[0] & CTemp[10] & (A[47:44]==4'h9)))^OpCODE[0]}};
	DAABus[48:47]<={2{OpCODE[0]}};
	DAABus[50:49]<={2{((CIN[12]^OpCODE[0]) | (A[51:48]>4'h9) | (~OpCODE[0] & CTemp[11] & (A[51:48]==4'h9)))^OpCODE[0]}};
	DAABus[52:51]<={2{OpCODE[0]}};
	DAABus[54:53]<={2{((CIN[13]^OpCODE[0]) | (A[55:52]>4'h9) | (~OpCODE[0] & CTemp[12] & (A[55:52]==4'h9)))^OpCODE[0]}};
	DAABus[56:55]<={2{OpCODE[0]}};
	DAABus[58:57]<={2{((CIN[14]^OpCODE[0]) | (A[59:56]>4'h9) | (~OpCODE[0] & CTemp[13] & (A[59:56]==4'h9)))^OpCODE[0]}};
	DAABus[60:59]<={2{OpCODE[0]}};
	DAABus[62:61]<={2{((CIN[15]^OpCODE[0]) | (A[63:60]>4'h9) | (~OpCODE[0] & CTemp[14] & (A[63:60]==4'h9)))^OpCODE[0]}};
	DAABus[63]<=OpCODE[0];
	
	// forming result
	case (TempOpCODE)
		3'd0: R<={64'd0, NEGBus};
		3'd1: R<={64'd0, NEGBus};
		3'd2: R<={64'd0, ~ABus + 64'd1};
		3'd3: R<={64'd0, BSWAPBus};
		3'd4: R<=CFBus[127:0];
		3'd5: R<={64'd0, 56'd0, TempPos};
		3'd6: R<={64'd0,((FP2IntBus[63:0] ^ {64{FPSign}})+{63'd0,FPSign}) & {64{FPZero}}};
		3'd7: casez ({SR[2],SR[0]})
				2'b00: R<={96'd0,ABus[63] & FPZero,(8'd127+TempPos+BBus[7:0]) & {8{FPZero}},Int2FPBus[22:0] & {23{FPZero}}};
				2'b01: R<={64'd0,ABus[63] & FPZero,(11'd1023+{3'd0,TempPos}+BBus[10:0]) & {11{FPZero}},Int2FPBus[51:0] & {52{FPZero}}};
				2'b1?: R<={ABus[63] & FPZero,(15'd16383+{7'd0,TempPos}+BBus[14:0]) & {15{FPZero}},Int2FPBus[111:0] & {112{FPZero}}};
				endcase
		endcase
		
	SR<=SD;
	
	CReg[0]<=CTemp[1];
	CReg[1]<=CTemp[3];
	CReg[2]<=CTemp[7];
	CReg[3]<=CTemp[15];
	COUT<=~TempOpCODE[2] & (TempOpCODE[2] | ~TempOpCODE[1] | TempOpCODE[0]) & 
			((CReg[0] & ~SR[1] & ~SR[0]) | (CReg[1] & ~SR[1] & SR[0]) | (CReg[2] & SR[1] & ~SR[0]) | (CReg[3] & SR[1] & SR[0]));
	// flags
	// ZERO flag
	casez (TempOpCODE)
		3'b00?: case (SR[1:0])
					2'd0: ZERO<=~(|NEGBus[7:0]);
					2'd1: ZERO<=~(|NEGBus[15:0]);
					2'd2: ZERO<=~(|NEGBus[31:0]);
					2'd3: ZERO<=~(|NEGBus[63:0]);
					endcase
		3'b010: case (SR[1:0])
					2'd0: ZERO<=~(|ABus[7:0]);
					2'd1: ZERO<=~(|ABus[15:0]);
					2'd2: ZERO<=~(|ABus[31:0]);
					2'd3: ZERO<=~(|ABus[63:0]);
					endcase
		3'b011: case (SR[1:0])
					2'd0: ZERO<=~(|BSWAPBus[7:0]);
					2'd1: ZERO<=~(|BSWAPBus[15:0]);
					2'd2: ZERO<=~(|BSWAPBus[31:0]);
					2'd3: ZERO<=~(|BSWAPBus[63:0]);
					endcase
		3'b100: casez ({SR[2],SR[0]})
					2'b00: ZERO<=~(|CFBus[30:0]);
					2'b01: ZERO<=~(|CFBus[62:0]);
					2'b1?: ZERO<=~(|CFBus[126:0]);
					endcase
		3'b101: ZERO<=~(|TempPos);
		3'b110: ZERO<=~(|FP2IntBus);
		3'b111: ZERO<=~(|ABus);
		endcase
		
	// Sign flag
	casez (TempOpCODE)
		3'b00?: case (SR[1:0])
					2'd0: SIGN<=NEGBus[7];
					2'd1: SIGN<=NEGBus[15];
					2'd2: SIGN<=NEGBus[31];
					2'd3: SIGN<=NEGBus[63];
					endcase
		3'b010: case (SR[1:0])
					2'd0: SIGN<=~ABus[7];
					2'd1: SIGN<=~ABus[15];
					2'd2: SIGN<=~ABus[31];
					2'd3: SIGN<=~ABus[63];
					endcase
		3'b011: case (SR[1:0])
					2'd0: SIGN<=BSWAPBus[7];
					2'd1: SIGN<=BSWAPBus[15];
					2'd2: SIGN<=BSWAPBus[31];
					2'd3: SIGN<=BSWAPBus[63];
					endcase
		3'b100: casez ({SR[2],SR[0]})
					2'b00: SIGN<=CFBus[31];
					2'b01: SIGN<=CFBus[63];
					2'b1?: SIGN<=CFBus[127];
					endcase
		3'b101: SIGN<=1'b0;
		3'b110: casez ({SAReg[2],SAReg[0]})
					2'b00: SIGN<=ABus[31];
					2'b01: SIGN<=ABus[63];
					2'b1?: SIGN<=ABReg;
					endcase
		3'b111: case(SAReg[1:0])
					2'd0: SIGN<=ABus[7];
					2'd1: SIGN<=ABus[15];
					2'd2: SIGN<=ABus[31];
					2'd3: SIGN<=ABus[63];
					endcase
		endcase
		
	casez ({SR[2], SR[0]})
		2'b00:	OVR<=CFBus[129] | (&CFBus[30:23] & ~CFBus[130]);
		2'b01:	OVR<=CFBus[129] | (&CFBus[62:52] & ~CFBus[130]);
		2'b1?:	OVR<=CFBus[129] | (&CFBus[126:112] & ~CFBus[130]);
		endcase
	NaN<=CFBus[130];
	end
	
endmodule
