module MUX64X32CsL (
	input CLK, RESETn,

	output wire [3:0]	LNEXT,
	input wire [3:0]	LACT,
	input wire [3:0]	LCMD,
	input wire [1:0] LSIZEO [3:0],
	input wire [44:0] LADDR [3:0],
	input wire [63:0] LDATO [3:0],
	input wire [12:0] LTAGO [3:0],
	output reg [3:0] LDRDY,
	output reg [63:0] LDATI,
	output reg [12:0] LTAGI,
	output reg [2:0] LSIZEI,

	output reg CMD,
	output reg [44:0] ADDR,
	output wire [63:0] DATA,
	output reg [7:0] BE,
	output reg [20:0] TAG,
	
	input wire FLNEXT,
	output reg FLACT,
	input wire FLDRDY,
	input wire [63:0] FLDAT,
	input wire [20:0] FLTAG,
	
	input SDNEXT,
	output reg SDACT,
	input SDDRDY,
	input [63:0] SDDAT,
	input [20:0] SDTAG,
	
	input IONEXT,
	output reg IOACT,
	input IODRDY,
	input [63:0] IODAT,
	input [20:0] IOTAG,
	// control and status lines
	output reg [39:0] DTBASE,
	output reg [23:0] DTLIMIT, INTSEL,
	output reg [15:0] INTLIMIT,
	output reg INTRST, INTENA, ESRRD, CENA, MALOCKF, PTINTR, DTRESET,
	input wire [26:0] CSR,
	input wire [23:0] CPSR,
	input wire [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] ESR,
	output wire [2:0] CPSRSTB,
	output wire [3:0] CSRSTB,
	input wire SINIT,
	input wire CINIT,
	input wire TCK,
	input wire TCKOVR,
	input wire HALT,
	// performance data source
	input wire [3:0] IV,
	input wire [23:0] CSEL,
	input wire EMPTY,
	input wire [7:0] TCKScaler,
	input wire [7:0] CoreType
	);

reg InACTReg, SysACTFlag, SysDRDYFlag;
logic InEnaWire, SysFifoReadWire, IOFifoReadWire, SysFifoEmptyWire, IOFifoEmptyWire, FLFifoReadWire, FLFifoEmptyWire;
wire [84:0] SysDataBus, IODataBus, FLDataBus;
reg [85:0] DataOutReg;
reg [63:0] DOReg, SysIOReg;
reg [20:0] SysTAGReg;
// task table registers
reg [31:0] PTSR;
reg [31:0] PTPTR;
// task timer resources
reg [15:0] PTRBaseReg, PTRTimerReg, PTPTRBus;
reg [11:0] PTWDCntr;
reg PTWDFlag;
reg PTRReloadFlag, PTRCountFlag, INTENAReg;
logic [63:0] DATABus;

// Performance metter resources
reg [3:0] Pram [0:131071];
reg [16:0] RPtr, WPtr, Limit, DWPtr;
reg UpdateFlag, EmptyMask, RestartFlag, AddFlag;
reg [19:0] Counter, MinCounter, MaxCounter;
reg [23:0] Psel, Csel;
reg [2:0] Smask;
reg [3:0] IVReg, PramReg;
reg [31:0] TMCtrlReg;
logic [29:0] TMStatus;
logic [19:0] CntBus;
logic AddMask;
logic [3:0] IVBus;


sc_fifo SysFifo(.data({SysTAGReg,SysIOReg}), .wrreq(SysDRDYFlag), .rdreq(SysFifoReadWire), .clock(CLK), .sclr(~RESETn),
				.q(SysDataBus), .empty(SysFifoEmptyWire), .usedw());
defparam SysFifo.LPM_WIDTH=85, SysFifo.LPM_NUMWORDS=8, SysFifo.LPM_WIDTHU=3;

sc_fifo IOFifo(.data({IOTAG,IODAT}), .wrreq(IODRDY), .rdreq(IOFifoReadWire), .clock(CLK), .sclr(~RESETn),
				.q(IODataBus), .empty(IOFifoEmptyWire), .usedw());
defparam IOFifo.LPM_WIDTH=85, IOFifo.LPM_NUMWORDS=16, IOFifo.LPM_WIDTHU=4;

sc_fifo FLFifo(.data({FLTAG,FLDAT}), .wrreq(FLDRDY), .rdreq(FLFifoReadWire), .clock(CLK), .sclr(~RESETn),
				.q(FLDataBus), .empty(FLFifoEmptyWire), .usedw());
defparam FLFifo.LPM_WIDTH=85, FLFifo.LPM_NUMWORDS=64, FLFifo.LPM_WIDTHU=6;

TM tmon(.CLK(CLK), .RST(RESETn), .CTRL(TMCtrlReg), .STATS(TMStatus),
		.MNEXT({2'd0,FLNEXT,SDNEXT,LNEXT}), .MACT({2'd0,FLACT,SDACT,LACT}), .MCMD({2'd0,CMD,CMD,LCMD}));


/*
===================================================================================================
		Assignments
===================================================================================================
*/
assign LNEXT[0]=InEnaWire;
assign LNEXT[1]=InEnaWire & ~LACT[0];
assign LNEXT[2]=InEnaWire & ~LACT[1] & ~LACT[0];
assign LNEXT[3]=InEnaWire & ~LACT[2] & ~LACT[1] & ~LACT[0];
assign DATA=DATABus;

// strobes for CPSR
assign CPSRSTB[0]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[4];
assign CPSRSTB[1]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[5];
assign CPSRSTB[2]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[6];

// strobes for CSR
assign CSRSTB[0]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[0];
assign CSRSTB[1]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[1];
assign CSRSTB[2]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[2];
assign CSRSTB[3]=SysACTFlag & ~CMD & (ADDR[6:3]==4'd2) & ~BE[3];

/*
===================================================================================================
		Asynchronous logic.
===================================================================================================
*/
always_comb
begin

InEnaWire=~InACTReg | (FLACT & FLNEXT) | (SDACT & SDNEXT) | (IOACT & IONEXT) | SysACTFlag;

// reading system FIFO
SysFifoReadWire=~SysFifoEmptyWire & ~SDDRDY;
// reading IO FIFO
IOFifoReadWire=~IOFifoEmptyWire & SysFifoEmptyWire & ~SDDRDY;
// reading FL FIFO
FLFifoReadWire=~FLFifoEmptyWire & SysFifoEmptyWire & IOFifoEmptyWire & ~SDDRDY;

// encoding data that to be write to the memory
case (TAG[17:16])
	2'b00:	DATABus={8{DOReg[7:0]}};
	2'b01:	DATABus={4{DOReg[15:0]}};
	2'b10:	DATABus={2{DOReg[31:0]}};
	2'b11:	DATABus=DOReg;
endcase

// task table index increment
PTPTRBus=(PTPTR[15:0]+16'd1) & {16{~((PTPTR[15:0] + 16'd1)==PTPTR[31:16])}};

// value for average counter
CntBus=Counter+{16'd0,IVReg}-{16'd0,(PramReg & {4{UpdateFlag}})};

// adder mask flag
AddMask=(~(EMPTY | HALT) | EmptyMask) & ((Csel==CSEL) | (~(|Csel))) & ((Psel==CPSR) | (~(|Psel))) & ((Smask==CSR[26:24]) | (~(|Smask)));

// adder value
case (IV)
	4'h0: IVBus=0;
	4'h1: IVBus=1;
	4'h2: IVBus=1;
	4'h3: IVBus=2;
	4'h4: IVBus=1;
	4'h5: IVBus=2;
	4'h6: IVBus=2;
	4'h7: IVBus=3;
	4'h8: IVBus=1;
	4'h9: IVBus=2;
	4'hA: IVBus=2;
	4'hB: IVBus=3;
	4'hC: IVBus=2;
	4'hD: IVBus=3;
	4'hE: IVBus=3;
	4'hF: IVBus=4;
	endcase

end
/*
===================================================================================================
		Synchronous design part
===================================================================================================
*/
always_ff @(negedge RESETn or posedge CLK)
begin
if (~RESETn)	begin
				InACTReg<=1'b0;
				FLACT<=1'b0;
				SDACT<=1'b0;
				IOACT<=1'b0;
				SysACTFlag<=1'b0;
				DataOutReg<=86'd0;
				DTBASE<=40'd0;
				DTLIMIT<=24'd0;
				CENA<=1'b0;
				MALOCKF<=1'b0;
				PTSR<=32'd0;
				PTPTR<=32'd0;
				INTSEL<=24'd0;
				INTRST<=1'b0;
				INTENA<=1'b0;
				INTLIMIT<=16'd0;
				PTRBaseReg<=16'd0;
				PTRTimerReg<=16'd0;
				PTWDCntr<=0;
				PTWDFlag<=0;
				PTRReloadFlag<=1'b0;
				PTRCountFlag<=1'b0;
				PTINTR<=1'b0;
				SysDRDYFlag<=1'b0;
				LDRDY<=0;
				INTENAReg<=0;
				DTRESET<=0;

				UpdateFlag<=0;
				RPtr<=0;
				WPtr<=0;
				Limit<=17'd10000;
				EmptyMask<=0;
				MinCounter<=20'hFFFFF;
				MaxCounter<=0;
				Counter<=0;
				Csel<=0;
				Psel<=0;
				Smask<=0;
				RestartFlag<=0;
				AddFlag<=0;
				
				TMCtrlReg<=32'h3FFF0000;
				end
else begin
// activation register
InACTReg<=(InACTReg & (~FLACT | ~FLNEXT) & (~SDACT | ~SDNEXT) & (~IOACT | ~IONEXT) & ~SysACTFlag) | (|LACT);

if (InEnaWire)
	casez (LACT)
		// Core channel
		4'b???1:	begin
					ADDR<=LADDR[0];
					DOReg<=LDATO[0];
					CMD<=LCMD[0];
					casez ({LADDR[0][2:0],LSIZEO[0]})
						5'b00000:	BE<=8'b11111110;
						5'b00100:	BE<=8'b11111101;
						5'b01000:	BE<=8'b11111011;
						5'b01100:	BE<=8'b11110111;
						5'b10000:	BE<=8'b11101111;
						5'b10100:	BE<=8'b11011111;
						5'b11000:	BE<=8'b10111111;
						5'b11100:	BE<=8'b01111111;
						5'b00?01:	BE<=8'b11111100;
						5'b01?01:	BE<=8'b11110011;
						5'b10?01:	BE<=8'b11001111;
						5'b11?01:	BE<=8'b00111111;
						5'b0??10:	BE<=8'b11110000;
						5'b1??10:	BE<=8'b00001111;
						5'b???11:	BE<=8'b00000000;
						endcase
					TAG<={LADDR[0][2:0],LSIZEO[0],3'd0,LTAGO[0]};
					FLACT<=LACT[0] & (LADDR[0]<45'h040000000);
					SDACT<=LACT[0] & (LADDR[0]>45'h03FFFFFFF) & (LADDR[0]<45'h1FFFFFFF0000);
					IOACT<=LACT[0] & (LADDR[0]>=45'h1FFFFFFF0000) & ~(&LADDR[0][15:7]);
					SysACTFlag<=LACT[0] & (LADDR[0]>=45'h1FFFFFFFFF80);
					end
		// Portal channel
		4'b??10:	begin
					ADDR<=LADDR[1];
					DOReg<=LDATO[1];
					CMD<=LCMD[1];
					casez ({LADDR[1][2:0],LSIZEO[1]})
						5'b00000:	BE<=8'b11111110;
						5'b00100:	BE<=8'b11111101;
						5'b01000:	BE<=8'b11111011;
						5'b01100:	BE<=8'b11110111;
						5'b10000:	BE<=8'b11101111;
						5'b10100:	BE<=8'b11011111;
						5'b11000:	BE<=8'b10111111;
						5'b11100:	BE<=8'b01111111;
						5'b00?01:	BE<=8'b11111100;
						5'b01?01:	BE<=8'b11110011;
						5'b10?01:	BE<=8'b11001111;
						5'b11?01:	BE<=8'b00111111;
						5'b0??10:	BE<=8'b11110000;
						5'b1??10:	BE<=8'b00001111;
						5'b???11:	BE<=8'b00000000;
						endcase
					TAG<={LADDR[1][2:0],LSIZEO[1],3'd1,LTAGO[1]};
					FLACT<=LACT[1] & (LADDR[1]<45'h040000000);
					SDACT<=LACT[1] & (LADDR[1]>45'h03FFFFFFF) & (LADDR[1]<45'h1FFFFFFF0000);
					IOACT<=LACT[1] & (LADDR[1]>=45'h1FFFFFFF0000) & ~(&LADDR[1][15:7]);
					SysACTFlag<=LACT[1] & (LADDR[1]>=45'h1FFFFFFFFF80);
					end
		// stream channel
		4'b?100:	begin
					ADDR<=LADDR[2];
					DOReg<=LDATO[2];
					CMD<=LCMD[2];
					casez ({LADDR[2][2:0],LSIZEO[2]})
						5'b00000:	BE<=8'b11111110;
						5'b00100:	BE<=8'b11111101;
						5'b01000:	BE<=8'b11111011;
						5'b01100:	BE<=8'b11110111;
						5'b10000:	BE<=8'b11101111;
						5'b10100:	BE<=8'b11011111;
						5'b11000:	BE<=8'b10111111;
						5'b11100:	BE<=8'b01111111;
						5'b00?01:	BE<=8'b11111100;
						5'b01?01:	BE<=8'b11110011;
						5'b10?01:	BE<=8'b11001111;
						5'b11?01:	BE<=8'b00111111;
						5'b0??10:	BE<=8'b11110000;
						5'b1??10:	BE<=8'b00001111;
						5'b???11:	BE<=8'b00000000;
						endcase
					TAG<={LADDR[2][2:0],LSIZEO[2],3'd2,LTAGO[2]};
					FLACT<=LACT[2] & (LADDR[2]<45'h040000000);
					SDACT<=LACT[2] & (LADDR[2]>45'h03FFFFFFF) & (LADDR[2]<45'h1FFFFFFF0000);
					IOACT<=LACT[2] & (LADDR[2]>=45'h1FFFFFFF0000) & ~(&LADDR[2][15:7]);
					SysACTFlag<=LACT[2] & (LADDR[2]>=45'h1FFFFFFFFF80);
					end
		// Context controller
		4'b1000:	begin
					ADDR<=LADDR[3];
					DOReg<=LDATO[3];
					CMD<=LCMD[3];
					casez ({LADDR[3][2:0],LSIZEO[3]})
						5'b00000:	BE<=8'b11111110;
						5'b00100:	BE<=8'b11111101;
						5'b01000:	BE<=8'b11111011;
						5'b01100:	BE<=8'b11110111;
						5'b10000:	BE<=8'b11101111;
						5'b10100:	BE<=8'b11011111;
						5'b11000:	BE<=8'b10111111;
						5'b11100:	BE<=8'b01111111;
						5'b00?01:	BE<=8'b11111100;
						5'b01?01:	BE<=8'b11110011;
						5'b10?01:	BE<=8'b11001111;
						5'b11?01:	BE<=8'b00111111;
						5'b0??10:	BE<=8'b11110000;
						5'b1??10:	BE<=8'b00001111;
						5'b???11:	BE<=8'b00000000;
						endcase
					TAG<={LADDR[3][2:0],LSIZEO[3],3'd3,LTAGO[3]};
					FLACT<=LACT[3] & (LADDR[3]<45'h040000000);
					SDACT<=LACT[3] & (LADDR[3]>45'h03FFFFFFF) & (LADDR[3]<45'h1FFFFFFF0000);
					IOACT<=LACT[3] & (LADDR[3]>=45'h1FFFFFFF0000) & ~(&LADDR[3][15:7]);
					SysACTFlag<=LACT[3] & (LADDR[3]>=45'h1FFFFFFFFF80);
					end
		default:	begin
					FLACT<=1'b0;
					SDACT<=1'b0;
					IOACT<=1'b0;
					SysACTFlag<=1'b0;
					end
		endcase
//
// Processign readed data
//
casez ({~IOFifoEmptyWire, ~SysFifoEmptyWire, SDDRDY})
	3'b??1:	DataOutReg[84:0]<={SDTAG,SDDAT};
	3'b?10:	DataOutReg[84:0]<=SysDataBus;
	3'b100:	DataOutReg[84:0]<=IODataBus;
	default	DataOutReg[84:0]<=FLDataBus;
	endcase
			
DataOutReg[85]<=SDDRDY | ~IOFifoEmptyWire | ~FLFifoEmptyWire | ~SysFifoEmptyWire;

// DRDY signals and tags
LDRDY[0]<=DataOutReg[85] && (DataOutReg[79:77] == 3'd0);
LDRDY[1]<=DataOutReg[85] && (DataOutReg[79:77] == 3'd1);
LDRDY[2]<=DataOutReg[85] && (DataOutReg[79:77] == 3'd2);
LDRDY[3]<=DataOutReg[85] && (DataOutReg[79:77] == 3'd3);

LTAGI<=DataOutReg[76:64];

LSIZEI<={1'b0, DataOutReg[81:80]};
// swapping bytes
casez (DataOutReg[84:80])
	5'b00100:	LDATI[7:0]<=DataOutReg[15:8];
	5'b01000:	LDATI[15:0]<=DataOutReg[31:16];
	5'b01100:	LDATI[7:0]<=DataOutReg[31:24];
	5'b10000:	LDATI[15:0]<=DataOutReg[47:32];
	5'b10100:	LDATI[7:0]<=DataOutReg[47:40];
	5'b11000:	LDATI[15:0]<=DataOutReg[63:48];
	5'b11100:	LDATI[7:0]<=DataOutReg[63:56];
	5'b00?01:	LDATI[15:0]<=DataOutReg[15:0];
	5'b01?01:	LDATI[15:0]<=DataOutReg[31:16];
	5'b10?01:	LDATI[15:0]<=DataOutReg[47:32];
	5'b11?01:	LDATI[15:0]<=DataOutReg[63:48];
	5'b0??10:	LDATI[31:0]<=DataOutReg[31:0];
	5'b1??10:	LDATI[31:0]<=DataOutReg[63:32];
	default:	LDATI<=DataOutReg[63:0];
	endcase

//---------------------------------------------------------
// 			Control registers system

// DTR - descriptor register reading and writing. DTBASE and DTLIMIT
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[0]) DTBASE[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[1]) DTBASE[15:8]<=DATA[15:8];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[2]) DTBASE[23:16]<=DATA[23:16];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[3]) DTBASE[31:24]<=DATA[31:24];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[4]) DTBASE[39:32]<=DATA[39:32];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[5]) DTLIMIT[7:0]<=DATA[47:40];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[6]) DTLIMIT[15:8]<=DATA[55:48];
if (SysACTFlag & ~CMD & ~(|ADDR[6:3]) & ~BE[7]) DTLIMIT[23:16]<=DATA[63:56];

DTRESET<=SysACTFlag & ~CMD & ~(|ADDR[6:3]);

// controller enable bit
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd1) & ~BE[3]) CENA<=DATA[31];
// memory allocation enable flag
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd1) & ~BE[3]) MALOCKF<=DATA[30];

// registers PTSR and PTPTR
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[0]) PTSR[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[1]) PTSR[15:8]<=DATA[15:8];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[2]) PTSR[23:16]<=DATA[23:16];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[3]) PTSR[31:24]<=DATA[31:24];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[4]) PTPTR[7:0]<=DATA[39:32];
		else if (PTINTR & ~PTWDFlag) PTPTR[7:0]<=PTPTRBus[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[5]) PTPTR[15:8]<=DATA[47:40];
		else if (PTINTR & ~PTWDFlag) PTPTR[15:8]<=PTPTRBus[15:8];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[6]) PTPTR[23:16]<=DATA[55:48];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd3) & ~BE[7]) PTPTR[31:24]<=DATA[63:56];

// interrupt control registers
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[0]) INTSEL[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[1]) INTSEL[15:8]<=DATA[15:8];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[2]) INTSEL[23:16]<=DATA[23:16];
// reset bit of the interrupt controller
INTRST<=SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[3] & DATA[24];
// enable interrupt controller
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[3]) INTENAReg<=DATA[31];
INTENA<=INTENAReg & CSR[21];
// number of records in the interrupt table
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[4]) INTLIMIT[7:0]<=DATA[39:32];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd6) & ~BE[5]) INTLIMIT[15:8]<=DATA[47:40];

// read error status register flag
ESRRD<=SysACTFlag & CMD & (ADDR[6:3]==4'd7) & RESETn;

//=================================================================================================
//		Task timer
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd8) & ~BE[0]) PTRBaseReg[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==4'd8) & ~BE[1]) PTRBaseReg[15:8]<=DATA[15:8];
// reload timer flag
PTRReloadFlag<=(SysACTFlag & ~CMD & (ADDR[6:3]==4'd8) & ~BE[1]);
// timer-counter
PTRTimerReg<=TCKOVR ? 16'd2 : (PTRReloadFlag ? PTRBaseReg : PTRTimerReg-{15'd0,PTRCountFlag});
// PTR count flag
PTRCountFlag<=TCK & (|PTRTimerReg) & CSR[22] & PTSR[31] & ~HALT;
// Task switch request
PTINTR<=((PTRTimerReg==16'd1) & PTRCountFlag)|(CSR[22] & PTSR[31] & (&PTWDCntr));
// WatchDog counter
PTWDCntr<=(PTWDCntr+12'd1) & {12{~(|PTRTimerReg)}};
PTWDFlag<=CSR[22] & PTSR[31] & (&PTWDCntr);

//---------------------------------------------------------
// output patch from system registers

// data ready register
SysDRDYFlag<=SysACTFlag & CMD;

if (SysACTFlag & CMD)
	begin
	SysTAGReg<=TAG;
	case (ADDR[6:3])
		4'd0: SysIOReg<={DTLIMIT, DTBASE};
		4'd1: SysIOReg<={8'd0, 8'd0, 8'd0, 8'd0, CENA,MALOCKF,3'd0,CINIT,1'b1,SINIT, 8'd0, CoreType, 8'd0};
		4'd2: SysIOReg<={8'd0, CPSR, 5'd1, CSR[26:0]};
		4'd3: SysIOReg<={PTPTR, PTSR};
		4'd4: SysIOReg<={24'd0, FREEMEM};
		4'd5: SysIOReg<={24'd0, CACHEDMEM};
		4'd6: SysIOReg<={16'd0, INTLIMIT, INTENAReg, 7'd0, INTSEL};
		4'd7: SysIOReg<=ESR;
		4'd8: SysIOReg<={32'd0, PTRTimerReg, PTRBaseReg};
		4'd9: SysIOReg<=64'd0;
		4'd10: SysIOReg<=64'd0;
		4'd11: SysIOReg<=64'd0;
		4'd12: SysIOReg<={TMCtrlReg,12'd0,Counter};
		4'd13: SysIOReg<={12'd0,MaxCounter,12'd0,MinCounter};
		4'd14: SysIOReg<={8'd0,Psel,8'd0,Csel};
		4'd15: SysIOReg<={TMStatus[29],1'b0,TMStatus[28:15],TMStatus[14],1'b0,TMStatus[13:0],EmptyMask,Smask,3'd0,TCKScaler,Limit};
		endcase
	end
/*

Measure performance
	1. minimum				/ 20 bit
	2. maximim				/ 20 bit
	3. current				/ 20 bit
Settings
	1. process selector		/ 24 bit
	2. code selector		/ 24 bit
	3. measure interval 	/ 17 bit
	4. empty state mask bit	/ 1 bit
	5. state mask			/ 3 bit

*/
// code selector register
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[0]) Csel[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[1]) Csel[15:8]<=DATA[15:8];
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[2]) Csel[23:16]<=DATA[23:16];

// process selector register
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[4]) Psel[7:0]<=DATA[39:32];
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[5]) Psel[15:8]<=DATA[47:40];
if (SysACTFlag & ~CMD & (ADDR[6:3]==14) & ~BE[6]) Psel[23:16]<=DATA[55:48];

// empty and state mask
if (SysACTFlag & ~CMD & (ADDR[6:3]==15) & ~BE[3]) 
	begin
	EmptyMask<=DATA[31];
	Smask<=DATA[30:28];
	end

// measure limit
if (SysACTFlag & ~CMD & (ADDR[6:3]==15) & ~BE[0]) Limit[7:0]<=DATA[7:0];
if (SysACTFlag & ~CMD & (ADDR[6:3]==15) & ~BE[1]) Limit[15:8]<=DATA[15:8];
if (SysACTFlag & ~CMD & (ADDR[6:3]==15) & ~BE[2]) Limit[16]<=DATA[16];

// trafic monitor control register
if (SysACTFlag & ~CMD & (ADDR[6:3]==12) & ~BE[4]) TMCtrlReg[7:0]<=DATA[39:32];
if (SysACTFlag & ~CMD & (ADDR[6:3]==12) & ~BE[5]) TMCtrlReg[15:8]<=DATA[47:40];
if (SysACTFlag & ~CMD & (ADDR[6:3]==12) & ~BE[6]) TMCtrlReg[23:16]<=DATA[55:48];
if (SysACTFlag & ~CMD & (ADDR[6:3]==12) & ~BE[7]) TMCtrlReg[31:24]<=DATA[63:56];

// restart flag
RestartFlag<=SysACTFlag & ~CMD & ADDR[6] & ADDR[5];

// enable decrement flag
UpdateFlag<=(UpdateFlag | (Limit==WPtr)) & ~RestartFlag;

// average counter
if (RestartFlag) Counter<=20'd0;
	else if (AddFlag) Counter<=CntBus;
	
// minimum performance
if (RestartFlag) MinCounter<=20'hFFFFF;
	else if ((MinCounter>Counter) & UpdateFlag) MinCounter<=Counter;

// maximum performance
if (RestartFlag) MaxCounter<=20'd0;
	else if ((MaxCounter<Counter) & UpdateFlag) MaxCounter<=Counter;
	
// ram enable
AddFlag<=AddMask;

// instruction number register
IVReg<=IVBus & {4{AddMask}};

// decrement value
PramReg<=Pram[RPtr];

// read pointer
if ((RestartFlag)|(Limit==RPtr)) RPtr<=0;
	else if (UpdateFlag & AddMask) RPtr<=RPtr+17'd1;
// write pointer
if (AddFlag) Pram[DWPtr]<=IVReg;
if ((RestartFlag)|(Limit==WPtr)) WPtr<=0;
	else if (AddMask) WPtr<=WPtr+17'd1;
DWPtr<=WPtr;

end
end

endmodule: MUX64X32CsL
