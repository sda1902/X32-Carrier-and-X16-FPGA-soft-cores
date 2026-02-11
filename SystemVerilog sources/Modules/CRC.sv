module CRC (
	input wire CLK, RST,
	input wire ACT, CMD,
	input wire [4:0] BE,
	input wire [39:0] DI,
	output wire [39:0] DO
	);

reg [7:0] DIReg;
reg [31:0] CRCReg;

reg StrobeFlag;

logic [31:0] A;

assign DO={DIReg,CRCReg};

always_comb
begin

A[0] = DIReg[6] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[30];
A[1] = DIReg[7] ^ DIReg[6] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[30] ^ CRCReg[31];
A[2] = DIReg[7] ^ DIReg[6] ^ DIReg[2] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[30] ^ CRCReg[31];
A[3] = DIReg[7] ^ DIReg[3] ^ DIReg[2] ^ DIReg[1] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[31];
A[4] = DIReg[6] ^ DIReg[4] ^ DIReg[3] ^ DIReg[2] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[28] ^ CRCReg[30];
A[5] = DIReg[7] ^ DIReg[6] ^ DIReg[5] ^ DIReg[4] ^ DIReg[3] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[27] ^ CRCReg[28] ^ CRCReg[29] ^ CRCReg[30] ^ CRCReg[31];
A[6] = DIReg[7] ^ DIReg[6] ^ DIReg[5] ^ DIReg[4] ^ DIReg[2] ^ DIReg[1] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[28] ^ CRCReg[29] ^ CRCReg[30] ^ CRCReg[31];
A[7] = DIReg[7] ^ DIReg[5] ^ DIReg[3] ^ DIReg[2] ^ DIReg[0] ^ CRCReg[24] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[29] ^ CRCReg[31];
A[8] = DIReg[4] ^ DIReg[3] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[0] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[27] ^ CRCReg[28];
A[9] = DIReg[5] ^ DIReg[4] ^ DIReg[2] ^ DIReg[1] ^ CRCReg[1] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[28] ^ CRCReg[29];
A[10] = DIReg[5] ^ DIReg[3] ^ DIReg[2] ^ DIReg[0] ^ CRCReg[2] ^ CRCReg[24] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[29];
A[11] = DIReg[4] ^ DIReg[3] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[3] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[27] ^ CRCReg[28];
A[12] = DIReg[6] ^ DIReg[5] ^ DIReg[4] ^ DIReg[2] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[4] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[28] ^ CRCReg[29] ^ CRCReg[30];
A[13] = DIReg[7] ^ DIReg[6] ^ DIReg[5] ^ DIReg[3] ^ DIReg[2] ^ DIReg[1] ^ CRCReg[5] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[29] ^ CRCReg[30] ^ CRCReg[31];
A[14] = DIReg[7] ^ DIReg[6] ^ DIReg[4] ^ DIReg[3] ^ DIReg[2] ^ CRCReg[6] ^ CRCReg[26] ^ CRCReg[27] ^ CRCReg[28] ^ CRCReg[30] ^ CRCReg[31];
A[15] = DIReg[7] ^ DIReg[5] ^ DIReg[4] ^ DIReg[3] ^ CRCReg[7] ^ CRCReg[27] ^ CRCReg[28] ^ CRCReg[29] ^ CRCReg[31];
A[16] = DIReg[5] ^ DIReg[4] ^ DIReg[0] ^ CRCReg[8] ^ CRCReg[24] ^ CRCReg[28] ^ CRCReg[29];
A[17] = DIReg[6] ^ DIReg[5] ^ DIReg[1] ^ CRCReg[9] ^ CRCReg[25] ^ CRCReg[29] ^ CRCReg[30];
A[18] = DIReg[7] ^ DIReg[6] ^ DIReg[2] ^ CRCReg[10] ^ CRCReg[26] ^ CRCReg[30] ^ CRCReg[31];
A[19] = DIReg[7] ^ DIReg[3] ^ CRCReg[11] ^ CRCReg[27] ^ CRCReg[31];
A[20] = DIReg[4] ^ CRCReg[12] ^ CRCReg[28];
A[21] = DIReg[5] ^ CRCReg[13] ^ CRCReg[29];
A[22] = DIReg[0] ^ CRCReg[14] ^ CRCReg[24];
A[23] = DIReg[6] ^ DIReg[1] ^ DIReg[0] ^ CRCReg[15] ^ CRCReg[24] ^ CRCReg[25] ^ CRCReg[30];
A[24] = DIReg[7] ^ DIReg[2] ^ DIReg[1] ^ CRCReg[16] ^ CRCReg[25] ^ CRCReg[26] ^ CRCReg[31];
A[25] = DIReg[3] ^ DIReg[2] ^ CRCReg[17] ^ CRCReg[26] ^ CRCReg[27];
A[26] = DIReg[6] ^ DIReg[4] ^ DIReg[3] ^ DIReg[0] ^ CRCReg[18] ^ CRCReg[24] ^ CRCReg[27] ^ CRCReg[28] ^ CRCReg[30];
A[27] = DIReg[7] ^ DIReg[5] ^ DIReg[4] ^ DIReg[1] ^ CRCReg[19] ^ CRCReg[25] ^ CRCReg[28] ^ CRCReg[29] ^ CRCReg[31];
A[28] = DIReg[6] ^ DIReg[5] ^ DIReg[2] ^ CRCReg[20] ^ CRCReg[26] ^ CRCReg[29] ^ CRCReg[30];
A[29] = DIReg[7] ^ DIReg[6] ^ DIReg[3] ^ CRCReg[21] ^ CRCReg[27] ^ CRCReg[30] ^ CRCReg[31];
A[30] = DIReg[7] ^ DIReg[4] ^ CRCReg[22] ^ CRCReg[28] ^ CRCReg[31];
A[31] = DIReg[5] ^ CRCReg[23] ^ CRCReg[29]; 

end

always_ff @(posedge CLK or negedge RST)
begin
if (RST==0)
	begin
	DIReg<=0;
	CRCReg<=0;
	end
else begin

// input data byte register
if (ACT & ~CMD & ~BE[4]) DIReg<=DI[39:32];

// CRC register
if ((ACT & ~CMD & ~BE[0])| StrobeFlag) CRCReg[7:0]<=StrobeFlag ? A[7:0] : DI[7:0];
if ((ACT & ~CMD & ~BE[1])| StrobeFlag) CRCReg[15:8]<=StrobeFlag ? A[15:8] : DI[15:8];
if ((ACT & ~CMD & ~BE[2])| StrobeFlag) CRCReg[23:16]<=StrobeFlag ? A[23:16] : DI[23:16];
if ((ACT & ~CMD & ~BE[3])| StrobeFlag) CRCReg[31:24]<=StrobeFlag ? A[31:24] : DI[31:24];

// strobe flag
StrobeFlag<=ACT & ~CMD & ~BE[4];

end
end
	
endmodule
