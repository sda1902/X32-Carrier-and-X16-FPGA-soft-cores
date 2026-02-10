module Shifter64X32 (
	input wire CLK, ACT,
	input wire [63:0] A,
	input wire [5:0] B, 
	input wire [6:0] C,
	input wire [63:0] D,
	input wire [4:0] DSTi,
	input wire [1:0] SA, SD,
	input wire [2:0] OPR,
	
	output reg [63:0] R,
	output reg [4:0] DSTo,
	output reg RDY, OVR, ZERO, COUT, SIGN,
	output reg [1:0] SR
	);
	
reg [63:0] TempR [4:0];
reg [63:0] IntR;
reg [2:0] TempOPR;
reg [1:0] TempSA;
reg TempCOUT, TempMSB, IntCOUT, IntMSB;
wire [5:0] ShiftPar, CSMask;
wire [127:0] LSLBus, LSRBus, ASRBus;
reg OpLSL, OpLSR, OpCSL, OpCSR, OpASR, OpSET, OpGET;

reg [63:0] SourceReg, MaskReg, ValueReg;
wire [6:0] ShiftParA, ShiftParB;
wire [127:0] MaskABus, MaskBBus, ValueBus;

integer i, j;

// reduce shift parameter by operand size
assign ShiftPar[2:0]=B[2:0], ShiftPar[3]=B[3] & (|SA), ShiftPar[4]=B[4] & SA[1], ShiftPar[5]=B[5] & SA[1] & SA[0];
assign CSMask[2:0]=3'b111, CSMask[3]=|SA, CSMask[4]=SA[1], CSMask[5]=&SA;

assign LSLBus={A, 64'd0};

assign LSRBus[7:0]=A[7:0], LSRBus[15:8]=(SA==2'b00) ? 8'd0 : A[15:8], LSRBus[31:16]=~SA[1] ? 16'd0 : A[31:16];
assign LSRBus[63:32]=(SA==2'b11) ? A[63:32] : 32'd0, LSRBus[127:64]=64'd0;

assign ASRBus[7:0]=A[7:0], ASRBus[15:8]=(SA==2'b00) ? {8{A[7]}} : A[15:8], ASRBus[31:16]=~SA[1] ? {16{A[15]}} : A[31:16];
assign ASRBus[63:32]=(SA==2'b11) ? A[63:32] : {32{A[31]}}, ASRBus[127:64]={64{A[63]}};

assign ShiftParA={1'b0,B};
assign ShiftParB={1'b0,B}+C;
assign MaskABus={{64{1'b1}}, 64'd0};
assign MaskBBus={64'd0, {64{1'b1}}};
assign ValueBus={A, 64'd0};


always @(posedge CLK)
	begin
	TempMSB<=((SA==2'b00) & A[7]) | ((SA==2'b01) & A[15]) | ((SA==2'b10) & A[31]) | ((SA==2'b11) & A[63]);
	TempSA<=SD;
	OpLSL<=(OPR==3'b000);
	OpLSR<=(OPR==3'b001);
	OpCSL<=(OPR==3'b010);
	OpCSR<=(OPR==3'b011);
	OpASR<=(OPR==3'b101);
	OpSET<=(OPR==3'b110);
	OpGET<=(OPR==3'b111);
	
	// busses for field set and field get
	for (j=0; j<64; j=j+1)
		begin
		MaskReg[j]<=OPR[0] ? MaskBBus[7'd64+j-C] : MaskABus[7'd64+j-ShiftParA] & MaskBBus[7'd64+j-ShiftParB];
		ValueReg[j]<=ValueBus[7'd64+j-ShiftParA];
		end
	SourceReg<=D;
	
	// shift buses
	TempR[0][0]<=(|ShiftPar) ? 1'b0 : LSLBus[64];
	TempR[1][0]<=A[ShiftPar];
	TempR[2][0]<=(A[8-ShiftPar] & (SA==2'b00)) | (A[16-ShiftPar] & (SA==2'b01)) | (A[32-ShiftPar] & (SA==2'b10)) | (A[64-ShiftPar] & (SA==2'b11));
	TempR[3][0]<=A[ShiftPar];
	TempR[4][0]<=A[ShiftPar];
	
	for (i=1; i<63; i=i+1)
		begin
		TempR[0][i]<=LSLBus[7'd64+i-ShiftPar];
		TempR[1][i]<=LSRBus[i+ShiftPar];
		TempR[2][i]<=A[(i-ShiftPar) & CSMask];
		TempR[3][i]<=A[(i+ShiftPar) & CSMask];
		TempR[4][i]<=ASRBus[i+ShiftPar];
		end
	TempR[0][63]<=LSLBus[127-ShiftPar];
	TempR[1][63]<=(|ShiftPar) ? 1'b0 : LSRBus[64];
	TempR[2][63]<=A[(63-ShiftPar) & 6'b111111];
	TempR[3][63]<=A[(63+ShiftPar) & 6'b111111];
	TempR[4][63]<=A[63];

	IntR<=(TempR[0] & {64{OpLSL}}) |
			(TempR[1] & {64{OpLSR}}) |
			(TempR[2] & {64{OpCSL}}) |
			(TempR[3] & {64{OpCSR}}) |
			(TempR[4] & {64{OpASR}}) |
			(((SourceReg & ~MaskReg) | (ValueReg & MaskReg)) & {64{OpSET}}) |
			(TempR[1] & MaskReg & {64{OpGET}});

	R<=IntR;		
	ZERO<=~(|IntR[7:0] | (|IntR[15:8] & (|SR)) | (|IntR[31:16] & SR[1]) | (|IntR[63:32] & SR[1] & SR[0]));
	SIGN<=(IntR[7] & ~SR[1] & ~SR[0])|(IntR[15] & ~SR[1] & SR[0])|(IntR[31] & SR[1] & SR[0])|(IntR[63] & SR[1] & SR[0]);
	// COUT forming
	TempCOUT<=OPR[0] ? A[ShiftPar-1] : (A[8-ShiftPar] & (SA==2'b00)) | (A[16-ShiftPar] & (SA==2'b01)) | (A[32-ShiftPar] & (SA==2'b10)) | (A[64-ShiftPar] & (SA==2'b11));
	IntCOUT<=TempCOUT;
	// overflow forming
	IntMSB<=TempMSB;
	OVR<=IntMSB ^ (((SR==2'b00) & IntR[7]) | ((SR==2'b01) & IntR[15]) | ((SR==2'b10) & IntR[31]) | ((SR==2'b11) & IntR[63]));

	COUT<=IntCOUT;
	RDY<=ACT;
	DSTo<=DSTi;
	SR<=TempSA;
	end

endmodule
