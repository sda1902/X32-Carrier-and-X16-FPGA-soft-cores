module Flash16noSPI (
input wire CLKH, RESET,
// internal interface
output wire NEXT,
input wire ACT, CMD,
input wire [31:0] ADDR,
input wire [7:0] BE,
input wire [63:0] DTI,
input wire [20:0] TAGI,
output reg DRDY,
output reg [63:0] DTO,
output reg [20:0] TAGO
);


// internal memory buffers for RAM-BIOS
reg [7:0] IntMemA [0:8191];
reg [7:0] IntMemB [0:8191];
reg [7:0] IntMemC [0:8191];
reg [7:0] IntMemD [0:8191];
reg [7:0] IntMemE [0:8191];
reg [7:0] IntMemF [0:8191];
reg [7:0] IntMemG [0:8191];
reg [7:0] IntMemH [0:8191];

reg Zreg=0, DRDYreg=0;
reg [20:0] TAGOreg;
reg [63:0] DTOreg;

initial begin

$readmemh("X16Kernel0", IntMemA, 0);
$readmemh("X16Kernel1", IntMemB, 0);
$readmemh("X16Kernel2", IntMemC, 0);
$readmemh("X16Kernel3", IntMemD, 0);
$readmemh("X16Kernel4", IntMemE, 0);
$readmemh("X16Kernel5", IntMemF, 0);
$readmemh("X16Kernel6", IntMemG, 0);
$readmemh("X16Kernel7", IntMemH, 0);

end

assign NEXT=1'b1;

//=================================================================================================
//				Synchronous part
//=================================================================================================
always_ff @(posedge CLKH or negedge RESET)
if (~RESET)
	begin
	DRDY<=0;
	DRDYreg<=0;
	end
else begin

// write to memory
if (~BE[0] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemA[ADDR[15:3]]<=DTI[7:0];
if (~BE[1] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemB[ADDR[15:3]]<=DTI[15:8];
if (~BE[2] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemC[ADDR[15:3]]<=DTI[23:16];
if (~BE[3] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemD[ADDR[15:3]]<=DTI[31:24];
if (~BE[4] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemE[ADDR[15:3]]<=DTI[39:32];
if (~BE[5] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemF[ADDR[15:3]]<=DTI[47:40];
if (~BE[6] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemG[ADDR[15:3]]<=DTI[55:48];
if (~BE[7] & ~CMD & ACT & NEXT & ~|ADDR[31:16]) IntMemH[ADDR[15:3]]<=DTI[63:56];

// read from memory
// data out
DTOreg[7:0]<=IntMemA[ADDR[15:3]];
DTOreg[15:8]<=IntMemB[ADDR[15:3]];
DTOreg[23:16]<=IntMemC[ADDR[15:3]];
DTOreg[31:24]<=IntMemD[ADDR[15:3]];
DTOreg[39:32]<=IntMemE[ADDR[15:3]];
DTOreg[47:40]<=IntMemF[ADDR[15:3]];
DTOreg[55:48]<=IntMemG[ADDR[15:3]];
DTOreg[63:56]<=IntMemH[ADDR[15:3]];

Zreg<=~|ADDR[31:16];

DTO<=DTOreg & {64{Zreg}};
	
// tag output
TAGOreg<=TAGI;
TAGO<=TAGOreg;

// data ready signal
DRDYreg<=ACT & CMD;
DRDY<=DRDYreg;

end

endmodule
