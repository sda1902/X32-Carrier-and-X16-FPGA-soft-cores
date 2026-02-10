module MUX64X32CsLD (
						input CLK, RESETn,
						// transaction channels
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
						// common ISI buses
						output reg CMD,
						output reg [44:0] ADDR,
						output wire [63:0] DATA,
						output reg [7:0] BE,
						output reg [20:0] TAG,
						// flash channel
						input wire FLNEXT,
						output reg FLACT,
						input wire FLDRDY,
						input wire [63:0] FLDAT,
						input wire [20:0] FLTAG,
						// Main RAM channel
						input SDNEXT,
						output reg SDACT,
						input SDDRDY,
						input [63:0] SDDAT,
						input [20:0] SDTAG,
						// IO channel
						input IONEXT,
						output reg IOACT,
						input IODRDY,
						input [63:0] IODAT,
						input [20:0] IOTAG,
						// interface to invalidate the DMA selector registers
						input wire DSELSTB,
						input wire [23:0] DSEL,
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
						input wire [7:0] CoreType,
						// IO Input channels
						input wire [1:0] IOSIZE [0:3],
						output wire [3:0] IOWRDY,
						input wire [3:0] IOWR, IOWLAST,
						input wire [63:0] IOWD [0:3],
						// IO output channels
						input wire [3:0] IORRDY,
						output wire [3:0] IORSTB, IORSTRT, IORLAST,
						output wire [63:0] IORD [0:3]
						);

reg InACTReg, SysACTFlag, SysDRDYFlag;
logic InEnaWire, SysFifoReadWire, IOFifoReadWire, SysFifoEmptyWire, IOFifoEmptyWire, FLFifoReadWire, FLFifoEmptyWire;
wire [84:0] SysDataBus, IODataBus, FLDataBus;
wire [2:0] pcdCSEL;
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
logic [63:0] DATABus, DMADATA;

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

wire DMAACT, DMACMD;
reg DMADRDY;
wire [1:0] DMASize;
wire [8:0] DMATGO;
wire [44:0] DMAAddr;
wire [63:0] DMADTO;


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
		.MNEXT({1'd0,InEnaWire & (pcdCSEL==3'd4),FLNEXT,SDNEXT,LNEXT}), .MACT({1'd0,DMAACT,FLACT,SDACT,LACT}), .MCMD({1'd0,DMACMD,CMD,CMD,LCMD}));

rpcd	pcd	(.CLK(CLK), .RST(RESETn), .ENA(InEnaWire & |{DMAACT, LACT}), .REQ({3'd0, DMAACT, LACT}), .CSEL(pcdCSEL));

VDMA4chL #(.TagWidth(21)) dma	(
									// global
									.RESETn(RESETn), .CLK(CLK), .DTCLR(DTRESET), .DTBASE(DTBASE), .DTLIMIT(DTLIMIT), .DSELSTB(DSELSTB), .DSEL(DSEL),
									// programming interface
									.CACT(SysACTFlag & (ADDR[6:5]==2'd2) & |ADDR[4:3]), .CCMD(CMD), .CADDR(ADDR[4:3]), .CBE(BE), .CDTI(DATA), .CTI(21'd0),
									.CDRDY(), .CDTO(DMADATA), .CTO(),
									// system ISI 
									.NEXT(InEnaWire & (pcdCSEL==3'd4)), .ACT(DMAACT), .CMD(DMACMD), .SZO(DMASize), .ADDRESS(DMAAddr),
									.DTO(DMADTO), .TGO(DMATGO), .DRDY(DMADRDY), .DTI(LDATI), .TGI(LTAGI[8:0]), .SZI(LSIZEI[1:0]),
									// IO input channels 
									.IOSIZE(IOSIZE), .IOWRDY(IOWRDY), .IOWR(IOWR), .IOWLAST(IOWLAST), .IOWD(IOWD),
									// IO output channels
									.IORRDY(IORRDY), .IORSTB(IORSTB), .IORSTRT(IORSTRT), .IORLAST(IORLAST), .IORD(IORD)
									);



/*
===================================================================================================
		Assignments
===================================================================================================
*/
assign LNEXT[0]=InEnaWire & (pcdCSEL==3'd0);
assign LNEXT[1]=InEnaWire & (pcdCSEL==3'd1);
assign LNEXT[2]=InEnaWire & (pcdCSEL==3'd2);
assign LNEXT[3]=InEnaWire & (pcdCSEL==3'd3);
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
				DMADRDY<=1'b0;
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
InACTReg<=(InACTReg & (~FLACT | ~FLNEXT) & (~SDACT | ~SDNEXT) & (~IOACT | ~IONEXT) & ~SysACTFlag) | (|{DMAACT, LACT});

if (InEnaWire)
	casez (pcdCSEL | {3{~|{DMAACT, LACT}}})
		// Core channel
		3'd0:		begin
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
		3'd1:		begin
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
		3'd2:		begin
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
		3'd3:		begin
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
		// DMA channel
		3'd4:		begin
					ADDR<=DMAAddr;
					DOReg<=DMADTO;
					CMD<=DMACMD;
					casez ({DMAAddr[2:0],DMASize})
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
					TAG<={DMAAddr[2:0],DMASize,3'd4, 4'd0, DMATGO};
					FLACT<=DMAACT & (DMAAddr<45'h040000000);
					SDACT<=DMAACT & (DMAAddr>45'h03FFFFFFF) & (DMAAddr<45'h1FFFFFFF0000);
					IOACT<=DMAACT & (DMAAddr>=45'h1FFFFFFF0000) & ~(&DMAAddr[15:7]);
					SysACTFlag<=DMAACT & (DMAAddr>=45'h1FFFFFFFFF80);
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
DMADRDY<=DataOutReg[85] && (DataOutReg[79:77] == 3'd4);

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
		4'b0000: SysIOReg<={DTLIMIT, DTBASE};
		4'b0001: SysIOReg<={8'd0, 8'd0, 8'd0, 8'd0, CENA,MALOCKF,3'd0,CINIT,1'b1,SINIT, 8'd0, CoreType, 8'd0};
		4'b0010: SysIOReg<={8'd0, CPSR, 5'd1, CSR[26:0]};
		4'b0011: SysIOReg<={PTPTR, PTSR};
		4'b0100: SysIOReg<={24'd0, FREEMEM};
		4'b0101: SysIOReg<={24'd0, CACHEDMEM};
		4'b0110: SysIOReg<={16'd0, INTLIMIT, INTENAReg, 7'd0, INTSEL};
		4'b0111: SysIOReg<=ESR;
		4'b1000: SysIOReg<={32'd0, PTRTimerReg, PTRBaseReg};
		4'b1001: SysIOReg<=DMADATA;
		4'b1010: SysIOReg<=DMADATA;
		4'b1011: SysIOReg<=DMADATA;
		4'b1100: SysIOReg<={TMCtrlReg,12'd0,Counter};
		4'b1101: SysIOReg<={12'd0,MaxCounter,12'd0,MinCounter};
		4'b1110: SysIOReg<={8'd0,Psel,8'd0,Csel};
		4'b1111: SysIOReg<={TMStatus[29],1'b0,TMStatus[28:15],TMStatus[14],1'b0,TMStatus[13:0],EmptyMask,Smask,3'd0,TCKScaler,Limit};
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

endmodule: MUX64X32CsLD





/*
=====================================================================================================================================================
																		4-channel DMA
=====================================================================================================================================================
*/
module VDMA4chL #(parameter TagWidth=8)(
				// global
				input wire RESETn, CLK, DTCLR,
				input wire [39:0] DTBASE,
				input wire [23:0] DTLIMIT,
				input wire DSELSTB,
				input wire [23:0] DSEL,
				// programming interface
				input wire CACT, CCMD,
				input wire [1:0] CADDR,
				input wire [7:0] CBE,
				input wire [63:0] CDTI,
				input wire [TagWidth-1:0] CTI,
				output reg CDRDY,
				output reg [63:0] CDTO,
				output reg [TagWidth-1:0] CTO,
				// system ISI 
				input wire NEXT,
				output reg ACT, CMD,
				output reg [1:0] SZO,
				output reg [44:0] ADDRESS,
				output reg [63:0] DTO,
				output reg [8:0] TGO,
				input wire DRDY,
				input wire [63:0] DTI,
				input wire [8:0] TGI,
				input wire [1:0] SZI,
				// IO input channels 
				input wire [1:0] IOSIZE [0:3],
				output wire [3:0] IOWRDY,
				input wire [3:0] IOWR, IOWLAST,
				input wire [63:0] IOWD [0:3],
				// IO output channels
				input wire [3:0] IORRDY,
				output reg [3:0] IORSTB, IORSTRT, IORLAST,
				output reg [63:0] IORD [0:3]
				);

/*

channel parameters
1. Channel's control
	autorestart flag
		input channel uses a special pin
		output channel uses data elements counter.
	enable cyclic transfer flag
	data size (for transfer out of system to the IO device)
	data counter for cyclic IO output or data counter of received data
	data output timer (for output data rate regulation)
	register pair selection flag
	channel selection
2. receive objects list. (Offset and Selector) It relocates in the special object. Data from the input channel puts into the objects. If a restart event occurs, data begins to be stored in the first object.
3. transmit objects list. (offset and selector) It relocates in the special object.
5. current write offset and selector
6. current read offset and selector


control register 01
[3:0]	channel number
		List pointer selection | current pointer selection 1 bit
		read / write counters selection 1 bit
		read data size 2 bits
		write data size 2 bits
		cyclic read operation 1 bit
		cyclic write operation 1 bit
		data output timer 16 bit
		channel valid flag 1 bit
read/write counter - 32 bit

control register 10
read object offset / read list offset
read object selector / read list selector

control register 11
write object offset / write list offset
write object selector / write list selector
*/


logic PairFlag, ESTB, CmdMux, SelMux, IDRDY, ATUNext, BypassA, BypassB, BypassC, BypassD,
		InFifoWENAA, InFifoWENAB, InFifoWENAC, InFifoWENAD, InFifoReadA, InFifoReadB, InFifoReadC, InFifoReadD,
		InFifoEmptyA, InFifoEmptyB, InFifoEmptyC, InFifoEmptyD, OutFifoReadA, OutFifoReadB, OutFifoReadC, OutFifoReadD,
		RSelRegA, RSelRegB, RSelRegC, RSelRegD, CounterSelFlagA, CounterSelFlagB, CounterSelFlagC, CounterSelFlagD,
		WCmdRegA, WCmdRegB, WCmdRegC, WCmdRegD, PtrSelFlagA, PtrSelFlagB, PtrSelFlagC, PtrSelFlagD, CycleRxA, CycleRxB,
		CycleRxC, CycleRxD, WSelRegA, WSelRegB, WSelRegC, WSelRegD, CycleTxA, CycleTxB, CycleTxC, CycleTxD, RxEnaA, RxEnaB,
		RxEnaC, RxEnaD, TxEnaA, TxEnaB, TxEnaC, TxEnaD, WriteNextA, WriteNextB, WriteNextC, WriteNextD,
		TxReadEnaA, TxReadEnaB, TxReadEnaC, TxReadEnaD, ReadNextA, ReadNextB, ReadNextC, ReadNextD, RACTA, RACTB, RACTC, RACTD,
		WACTA, WACTB, WACTC, WACTD, RDRDY_DA, RDRDY_DB, RDRDY_DC, RDRDY_DD, WDRDY_LA, WDRDY_LB, WDRDY_LC, WDRDY_LD,
		OutFifoEmptyA, OutFifoEmptyB, OutFifoEmptyC, OutFifoEmptyD, RDRDY_LA, RDRDY_LB, RDRDY_LC, RDRDY_LD, StartFlagA,
		StartFlagB, StartFlagC, StartFlagD, TmrSelA, TmrSelB, TmrSelC, TmrSelD, ErrorFifoEmpty, ErrorFifoRead;
logic [1:0] SizeIN;
logic [1:0] TxSizeA, TxSizeB, TxSizeC, TxSizeD, RxSizeA, RxSizeB, RxSizeC, RxSizeD;
logic [2:0] InByteCntA, InByteCntB, InByteCntC, InByteCntD, OutByteCntA, OutByteCntB, OutByteCntC, OutByteCntD;
logic [2:0] ChanSel, ChannelReg, PrioritySel, CoderBus;
logic [3:0] InFifoFull, LastMux;
logic [3:0] RLastRegA, RLastRegB, RLastRegC, RLastRegD;
logic [4:0] ECD, TcntA, TcntB, TcntC, TcntD, OutFifoUsedA, OutFifoUsedB, OutFifoUsedC, OutFifoUsedD;
logic [7:0] ReqBus, TagIN, ETAG;
logic [12:0] ErrorFifoBus;
logic [15:0] SelInvd, TxTimerA, TxTimerB, TxTimerC, TxTimerD, TxTmrA, TxTmrB, TxTmrC, TxTmrD;
(* ramstyle = "logic" *) logic [23:0] SELECTORS [0:15];
logic [23:0] RxListSelectorA, RxListSelectorB, RxListSelectorC, RxListSelectorD, RxSelectorA, RxSelectorB, RxSelectorC, RxSelectorD,
				TxListSelectorA, TxListSelectorB, TxListSelectorC, TxListSelectorD, TxSelectorA, TxSelectorB, TxSelectorC, TxSelectorD;
logic [28:0] RxListOffsetA, RxListOffsetB, RxListOffsetC, RxListOffsetD, RxListBaseOffsetA, RxListBaseOffsetB, RxListBaseOffsetC, RxListBaseOffsetD,
				RxOffsetA, RxOffsetB, RxOffsetC, RxOffsetD, TxOffsetA, TxOffsetB, TxOffsetC, TxOffsetD, OffsetMux, ROffsetRegA, ROffsetRegB,
				ROffsetRegC, ROffsetRegD, WOffsetRegA, WOffsetRegB, WOffsetRegC, WOffsetRegD, TxListOffsetA, TxListOffsetB, TxListOffsetC,
				TxListOffsetD, TxListBaseOffsetA, TxListBaseOffsetB, TxListBaseOffsetC, TxListBaseOffsetD, RCntrA, RCntrB, RCntrC, RCntrD;
logic [31:0] TCntrA, TCntrB, TCntrC, TCntrD, TimerA, TimerB, TimerC, TimerD;
logic [55:0] IOWTempRegA, IOWTempRegB, IOWTempRegC, IOWTempRegD;
logic [63:0] DataMux, DataIN, WDataRegA, WDataRegB, WDataRegC, WDataRegD;
logic [64:0] InBusA, InBusB, InBusC, InBusD, InFifoBusA, InFifoBusB, InFifoBusC, InFifoBusD;
logic [67:0] OutFifoBusA, OutFifoBusB, OutFifoBusC, OutFifoBusD;

enum reg [3:0] {rxws, rxrdlist0, rxrdlist1} rxsm0=rxws, rxsm1=rxws, rxsm2=rxws, rxsm3=rxws;
enum reg [3:0] {txws, txrdlist0, txrdlist1, txrd0} txsm0=txws, txsm1=txws, txsm2=txws, txsm3=txws;


integer i0, i1, i2;

assign IOWRDY=~InFifoFull;

// data input FIFO's
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifoA (.data(InBusA), .wrreq(InFifoWENAA), .rdreq(InFifoReadA), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBusA), .empty(InFifoEmptyA), .full(InFifoFull[0]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifoB (.data(InBusB), .wrreq(InFifoWENAB), .rdreq(InFifoReadB), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBusB), .empty(InFifoEmptyB), .full(InFifoFull[1]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifoC (.data(InBusC), .wrreq(InFifoWENAC), .rdreq(InFifoReadC), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBusC), .empty(InFifoEmptyC), .full(InFifoFull[2]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifoD (.data(InBusD), .wrreq(InFifoWENAD), .rdreq(InFifoReadD), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBusD), .empty(InFifoEmptyD), .full(InFifoFull[3]), .almost_empty(), .usedw());

// data output FIFO's
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifoA (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_DA), .rdreq(OutFifoReadA), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBusA), .empty(OutFifoEmptyA), .full(), .almost_empty(), .usedw(OutFifoUsedA));
															
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifoB (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_DB), .rdreq(OutFifoReadB), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBusB), .empty(OutFifoEmptyB), .full(), .almost_empty(), .usedw(OutFifoUsedB));

sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifoC (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_DC), .rdreq(OutFifoReadC), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBusC), .empty(OutFifoEmptyC), .full(), .almost_empty(), .usedw(OutFifoUsedC));

sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifoD (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_DD), .rdreq(OutFifoReadD), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBusD), .empty(OutFifoEmptyD), .full(), .almost_empty(), .usedw(OutFifoUsedD));

// error fifo
sc_fifo #(.LPM_WIDTH(13), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) ErrorFifo (.data({ECD, ETAG}), .wrreq(ESTB), .rdreq(ErrorFifoRead), .clock(CLK), .sclr(~RESETn),
																	.q(ErrorFifoBus), .empty(ErrorFifoEmpty), .full(), .almost_empty(), .usedw());


// address translation unit
ATU16chL  #(.TagWidth(8))	 ATU	(
									// global control
									.RESETn(RESETn), .CLK(CLK), .DTBASE(DTBASE), .DTLIMIT(DTLIMIT),
									// access selectors
									.SELECTORS(SELECTORS), .SELINVD(SelInvd),
									// ISI
									.INEXT(ATUNext), .IACT(|{WACTA,WACTB,WACTC,WACTD} | |{RACTA,RACTB,RACTC,RACTD}), .ICMD(CmdMux), .ICPLMASK(1'b1), .ITIDMASK(1'b1),
									.ISEL({ChanSel, SelMux}), .ICPL(2'd0), .ITID(16'd0), .IOFFSET({5'd0,OffsetMux,3'd0}), .ISZO(2'b11), .IDTO(DataMux), .ITGO({LastMux, ChanSel, SelMux}),
									.IDRDY(IDRDY), .IDTI(DataIN), .ISZI(SizeIN), .ITGI(TagIN),
									// interfaces to the bus subsystem
									.NEXT(NEXT), .ACT(ACT), .CMD(CMD), .SZO(SZO), .ADDRESS(ADDRESS), .DTO(DTO), .TGO(TGO),
									.DRDY(DRDY), .DTI(DTI), .SZI(SZI), .TGI(TGI), 
									// error report
									.EENA(1'b1), .ESTB(ESTB), .ECD(ECD), .ETAG(ETAG)
									);


always_comb
begin

// rotate priority
case (PrioritySel)
	3'b000:	ReqBus={WACTD, WACTC, WACTB, WACTA, RACTD, RACTC, RACTB, RACTA};
	3'b001:	ReqBus={WACTC, WACTB, WACTA, RACTD, RACTC, RACTB, RACTA, WACTD};
	3'b010:	ReqBus={WACTB, WACTA, RACTD, RACTC, RACTB, RACTA, WACTD, WACTC};
	3'b011:	ReqBus={WACTA, RACTD, RACTC, RACTB, RACTA, WACTD, WACTC, WACTB};
	3'b100:	ReqBus={RACTD, RACTC, RACTB, RACTA, WACTD, WACTC, WACTB, WACTA};
	3'b101:	ReqBus={RACTC, RACTB, RACTA, WACTD, WACTC, WACTB, WACTA, RACTD};
	3'b110:	ReqBus={RACTB, RACTA, WACTD, WACTC, WACTB, WACTA, RACTD, RACTC};
	3'b111:	ReqBus={RACTA, WACTD, WACTC, WACTB, WACTA, RACTD, RACTC, RACTB};
	endcase
	
// channel selection
casez (ReqBus[7:1])
	7'b0000_000:	CoderBus=3'd0;
	7'b0000_001:	CoderBus=3'd1;
	7'b0000_01?:	CoderBus=3'd2;
	7'b0000_1??:	CoderBus=3'd3;
	7'b0001_???:	CoderBus=3'd4;
	7'b001?_???:	CoderBus=3'd5;
	7'b01??_???:	CoderBus=3'd6;
	7'b1???_???:	CoderBus=3'd7;
	endcase
	
// create channel selection bus
ChanSel=CoderBus-PrioritySel;

// muxing transactions
case (ChanSel)
	3'd0:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetRegA;
			SelMux=RSelRegA;
			DataMux=64'd0;
			LastMux=RLastRegA;
			end
	3'd1:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetRegB;
			SelMux=RSelRegB;
			DataMux=64'd0;
			LastMux=RLastRegB;
			end
	3'd2:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetRegC;
			SelMux=RSelRegC;
			DataMux=64'd0;
			LastMux=RLastRegC;
			end
	3'd3:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetRegD;
			SelMux=RSelRegD;
			DataMux=64'd0;
			LastMux=RLastRegD;
			end
	3'd4:	begin
			CmdMux=WCmdRegA;
			OffsetMux=WOffsetRegA;
			SelMux=WSelRegA;
			DataMux=WDataRegA;
			LastMux=4'd0;
			end
	3'd5:	begin
			CmdMux=WCmdRegB;
			OffsetMux=WOffsetRegB;
			SelMux=WSelRegB;
			DataMux=WDataRegB;
			LastMux=4'd0;
			end
	3'd6:	begin
			CmdMux=WCmdRegC;
			OffsetMux=WOffsetRegC;
			SelMux=WSelRegC;
			DataMux=WDataRegC;
			LastMux=4'd0;
			end
	3'd7:	begin
			CmdMux=WCmdRegD;
			OffsetMux=WOffsetRegD;
			SelMux=WSelRegD;
			DataMux=WDataRegD;
			LastMux=4'd0;
			end
	endcase


// next nodes
ReadNextA=~RACTA;
ReadNextB=~RACTB;
ReadNextC=~RACTC;
ReadNextD=~RACTD;
WriteNextA=~WACTA;
WriteNextB=~WACTB;
WriteNextC=~WACTC;
WriteNextD=~WACTD;

// fifo read nodes
InFifoReadA=WriteNextA & ~InFifoEmptyA & RxEnaA & |RxSelectorA & (rxsm0!=rxrdlist0);
InFifoReadB=WriteNextB & ~InFifoEmptyB & RxEnaB & |RxSelectorB & (rxsm1!=rxrdlist0);
InFifoReadC=WriteNextC & ~InFifoEmptyC & RxEnaC & |RxSelectorC & (rxsm2!=rxrdlist0);
InFifoReadD=WriteNextD & ~InFifoEmptyD & RxEnaD & |RxSelectorD & (rxsm3!=rxrdlist0);

// data ready 
RDRDY_DA=IDRDY & (TagIN[3:0]==4'h0);
RDRDY_LA=IDRDY & (TagIN[3:0]==4'h1);
RDRDY_DB=IDRDY & (TagIN[3:0]==4'h2);
RDRDY_LB=IDRDY & (TagIN[3:0]==4'h3);
RDRDY_DC=IDRDY & (TagIN[3:0]==4'h4);
RDRDY_LC=IDRDY & (TagIN[3:0]==4'h5);
RDRDY_DD=IDRDY & (TagIN[3:0]==4'h6);
RDRDY_LD=IDRDY & (TagIN[3:0]==4'h7);

WDRDY_LA=IDRDY & (TagIN[3:0]==4'h9);
WDRDY_LB=IDRDY & (TagIN[3:0]==4'hB);
WDRDY_LC=IDRDY & (TagIN[3:0]==4'hD);
WDRDY_LD=IDRDY & (TagIN[3:0]==4'hF);

// TX request
TxReadEnaA=(({1'b0, TcntA}+{1'b0, OutFifoUsedA})<6'd28);
TxReadEnaB=(({1'b0, TcntB}+{1'b0, OutFifoUsedB})<6'd28);
TxReadEnaC=(({1'b0, TcntC}+{1'b0, OutFifoUsedC})<6'd28);
TxReadEnaD=(({1'b0, TcntD}+{1'b0, OutFifoUsedD})<6'd28);

// read output queue A
if (~IORRDY[0] | OutFifoEmptyA | |TxTmrA) OutFifoReadA=1'b0;
	else case (TxSizeA)
			2'b00:	OutFifoReadA=OutFifoBusA[67] ? (OutFifoBusA[66:64]==(OutByteCntA+1'b1)) : &OutByteCntA;
			2'b01:	OutFifoReadA=OutFifoBusA[67] ? (OutFifoBusA[66:65]==(OutByteCntA[2:1]+1'b1)) : &OutByteCntA[2:1];
			2'b10:	OutFifoReadA=OutFifoBusA[67] ? (OutFifoBusA[66]==(~OutByteCntA[2])) : OutByteCntA[2];
			2'b11:	OutFifoReadA=1'b1;
			endcase
// read output queue B
if (~IORRDY[1] | OutFifoEmptyB | |TxTmrB) OutFifoReadB=1'b0;
	else case (TxSizeB)
			2'b00:	OutFifoReadB=OutFifoBusB[67] ? (OutFifoBusB[66:64]==(OutByteCntB+1'b1)) : &OutByteCntB;
			2'b01:	OutFifoReadB=OutFifoBusB[67] ? (OutFifoBusB[66:65]==(OutByteCntB[2:1]+1'b1)) : &OutByteCntB[2:1];
			2'b10:	OutFifoReadB=OutFifoBusB[67] ? (OutFifoBusB[66]==(~OutByteCntB[2])) : OutByteCntB[2];
			2'b11:	OutFifoReadB=1'b1;
			endcase
// read output queue C
if (~IORRDY[2] | OutFifoEmptyC | |TxTmrC) OutFifoReadC=1'b0;
	else case (TxSizeC)
			2'b00:	OutFifoReadC=OutFifoBusC[67] ? (OutFifoBusC[66:64]==(OutByteCntC+1'b1)) : &OutByteCntC;
			2'b01:	OutFifoReadC=OutFifoBusC[67] ? (OutFifoBusC[66:65]==(OutByteCntC[2:1]+1'b1)) : &OutByteCntC[2:1];
			2'b10:	OutFifoReadC=OutFifoBusC[67] ? (OutFifoBusC[66]==(~OutByteCntC[2])) : OutByteCntC[2];
			2'b11:	OutFifoReadC=1'b1;
			endcase
// read output queue D
if (~IORRDY[3] | OutFifoEmptyD | |TxTmrD) OutFifoReadD=1'b0;
	else case (TxSizeD)
			2'b00:	OutFifoReadD=OutFifoBusD[67] ? (OutFifoBusD[66:64]==(OutByteCntD+1'b1)) : &OutByteCntD;
			2'b01:	OutFifoReadD=OutFifoBusD[67] ? (OutFifoBusD[66:65]==(OutByteCntD[2:1]+1'b1)) : &OutByteCntD[2:1];
			2'b10:	OutFifoReadD=OutFifoBusD[67] ? (OutFifoBusD[66]==(~OutByteCntD[2])) : OutByteCntD[2];
			2'b11:	OutFifoReadD=1'b1;
			endcase

// data reading on programming interface
CDRDY=CACT & CCMD & |CADDR;
CTO=CTI;
casez ({CADDR, ChannelReg})
	5'b00_???: CDTO=64'd0;
	// control register group                63:32]                                                      [31:16]                              [15:14]  [13:12]    [11]     [10]       [09]           [08]          [07]     [06:00]
	5'b01_000: CDTO={TmrSelA ? TimerA : CounterSelFlagA ? TCntrA : {RCntrA, 3'd0}, TmrSelA ? {~ErrorFifoEmpty, 2'd0, ErrorFifoBus} : TxTimerA, TxSizeA, RxSizeA, CycleTxA, CycleRxA, PtrSelFlagA, CounterSelFlagA, TmrSelA, 3'd4, 4'd0};
	5'b01_001: CDTO={TmrSelB ? TimerB : CounterSelFlagB ? TCntrB : {RCntrB, 3'd0}, TmrSelB ? {~ErrorFifoEmpty, 2'd0, ErrorFifoBus} : TxTimerB, TxSizeB, RxSizeB, CycleTxB, CycleRxB, PtrSelFlagB, CounterSelFlagB, TmrSelB, 3'd4, 4'd1};
	5'b01_010: CDTO={TmrSelC ? TimerC : CounterSelFlagC ? TCntrC : {RCntrC, 3'd0}, TmrSelC ? {~ErrorFifoEmpty, 2'd0, ErrorFifoBus} : TxTimerC, TxSizeC, RxSizeC, CycleTxC, CycleRxC, PtrSelFlagC, CounterSelFlagC, TmrSelC, 3'd4, 4'd2};
	5'b01_011: CDTO={TmrSelD ? TimerD : CounterSelFlagD ? TCntrD : {RCntrD, 3'd0}, TmrSelD ? {~ErrorFifoEmpty, 2'd0, ErrorFifoBus} : TxTimerD, TxSizeD, RxSizeD, CycleTxD, CycleRxD, PtrSelFlagD, CounterSelFlagD, TmrSelD, 3'd4, 4'd3};
	5'b01_1??: CDTO=64'd0;
	// read selectors and offsets
	5'b10_000: CDTO=PtrSelFlagA ? {8'd0, RxListSelectorA, RxListOffsetA, 1'b0, BypassA, RxEnaA} : {8'd0, RxSelectorA, RxOffsetA, 3'd0};
	5'b10_001: CDTO=PtrSelFlagB ? {8'd0, RxListSelectorB, RxListOffsetB, 1'b0, BypassB, RxEnaB} : {8'd0, RxSelectorB, RxOffsetB, 3'd0};
	5'b10_010: CDTO=PtrSelFlagC ? {8'd0, RxListSelectorC, RxListOffsetC, 1'b0, BypassC, RxEnaC} : {8'd0, RxSelectorC, RxOffsetC, 3'd0};
	5'b10_011: CDTO=PtrSelFlagD ? {8'd0, RxListSelectorD, RxListOffsetD, 1'b0, BypassD, RxEnaD} : {8'd0, RxSelectorD, RxOffsetD, 3'd0};
	5'b10_1??: CDTO=64'd0;
	// write selectors and offsets
	7'b11_000: CDTO=PtrSelFlagA ? {8'd0, TxListSelectorA, TxListOffsetA, 2'd0, TxEnaA} : {8'd0, TxSelectorA, TxOffsetA, 3'd0};
	7'b11_001: CDTO=PtrSelFlagB ? {8'd0, TxListSelectorB, TxListOffsetB, 2'd0, TxEnaB} : {8'd0, TxSelectorB, TxOffsetB, 3'd0};
	7'b11_010: CDTO=PtrSelFlagC ? {8'd0, TxListSelectorC, TxListOffsetC, 2'd0, TxEnaC} : {8'd0, TxSelectorC, TxOffsetC, 3'd0};
	7'b11_011: CDTO=PtrSelFlagD ? {8'd0, TxListSelectorD, TxListOffsetD, 2'd0, TxEnaD} : {8'd0, TxSelectorD, TxOffsetD, 3'd0};
	7'b11_1??: CDTO=64'd0;
	endcase

// read error fifo
ErrorFifoRead=CACT & CCMD & (CADDR==2'd1) & ~CBE[3] & (ChannelReg[1] ? (ChannelReg[0] ? TmrSelD:TmrSelC):(ChannelReg[0] ? TmrSelB:TmrSelA)) & ~ChannelReg[2] & ~ErrorFifoEmpty;

end



always_ff @(posedge CLK or negedge RESETn)
if (~RESETn)
	begin
	InFifoWENAA<=1'b0; InFifoWENAB<=1'b0; InFifoWENAC<=1'b0; InFifoWENAD<=1'b0;
	InByteCntA<=3'd0; InByteCntB<=3'd0; InByteCntC<=3'd0; InByteCntD<=3'd0;
	BypassA<=1'b0; BypassB<=1'b0; BypassC<=1'b0; BypassD<=1'b0;
	PrioritySel<=3'd0;
	RACTA<=1'b0; RACTB<=1'b0; RACTC<=1'b0; RACTD<=1'b0;
	WACTA<=1'b0; WACTB<=1'b0; WACTC<=1'b0; WACTD<=1'b0;
	RxEnaA<=1'b0; RxEnaB<=1'b0; RxEnaC<=1'b0; RxEnaD<=1'b0;
	TxEnaA<=1'b0; TxEnaB<=1'b0; TxEnaC<=1'b0; TxEnaD<=1'b0;
	TmrSelA<=1'b0; TmrSelB<=1'b0; TmrSelC<=1'b0; TmrSelD<=1'b0;
	RxSelectorA<=24'd0; RxSelectorB<=24'd0; RxSelectorC<=24'd0; RxSelectorD<=24'd0;
	TxSelectorA<=24'd0; TxSelectorB<=24'd0; TxSelectorC<=24'd0; TxSelectorD<=24'd0;
	RCntrA<=29'd0; RCntrB<=29'd0; RCntrC<=29'd0; RCntrD<=29'd0;
	TCntrA<=32'd0; TCntrB<=32'd0; TCntrC<=32'd0; TCntrD<=32'd0;
	SelInvd<=16'd0;
	TcntA<=5'd0; TcntB<=5'd0; TcntC<=5'd0; TcntD<=5'd0;
	StartFlagA<=1'b0; StartFlagB<=1'b0; StartFlagC<=1'b0; StartFlagD<=1'b0;
	IORSTB<=4'd0;
	IORSTRT<=4'd0;
	IORLAST<=4'd0;
	end
else begin


// read transaction counters
if (ATUNext & (ChanSel==3'd0) & RACTA & ~SelMux & ~RDRDY_DA & ~&TcntA) TcntA<=TcntA+1'b1;
	else if (RDRDY_DA & ~(ATUNext & (ChanSel==3'd0) & RACTA & ~SelMux) & |TcntA) TcntA<=TcntA-1'b1;
if (ATUNext & (ChanSel==3'd1) & RACTB & ~SelMux & ~RDRDY_DB & ~&TcntB) TcntB<=TcntB+1'b1;
	else if (RDRDY_DB & ~(ATUNext & (ChanSel==3'd1) & RACTB & ~SelMux) & |TcntB) TcntB<=TcntB-1'b1;
if (ATUNext & (ChanSel==3'd2) & RACTC & ~SelMux & ~RDRDY_DC & ~&TcntC) TcntC<=TcntC+1'b1;
	else if (RDRDY_DC & ~(ATUNext & (ChanSel==3'd2) & RACTC & ~SelMux) & |TcntC) TcntC<=TcntC-1'b1;
if (ATUNext & (ChanSel==3'd3) & RACTD & ~SelMux & ~RDRDY_DD & ~&TcntD) TcntD<=TcntD+1'b1;
	else if (RDRDY_DD & ~(ATUNext & (ChanSel==3'd3) & RACTD & ~SelMux) & |TcntD) TcntD<=TcntD-1'b1;


// RX size
if (BypassA ? IORSTB[0] : IOWR[0]) RxSizeA<=BypassA ? TxSizeA : IOSIZE[0];
if (BypassB ? IORSTB[1] : IOWR[1]) RxSizeB<=BypassB ? TxSizeB : IOSIZE[1];
if (BypassC ? IORSTB[2] : IOWR[2]) RxSizeC<=BypassC ? TxSizeC : IOSIZE[2];
if (BypassD ? IORSTB[3] : IOWR[3]) RxSizeD<=BypassD ? TxSizeD : IOSIZE[3];


// cahhnel's priority rotation
if ((|{WACTA,WACTB,WACTC,WACTD} | |{RACTA,RACTB,RACTC,RACTD}) & ATUNext) PrioritySel<=PrioritySel+1'b1;

// channel selection register
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0]) ChannelReg<={|CDTI[5:2], CDTI[1:0]};

// timer selection flags
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0] & (ChannelReg==3'd0)) TmrSelA<=CDTI[7];
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0] & (ChannelReg==3'd1)) TmrSelB<=CDTI[7];
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0] & (ChannelReg==3'd2)) TmrSelC<=CDTI[7];
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0] & (ChannelReg==3'd3)) TmrSelD<=CDTI[7];

// write to the control fields and address registers
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[1])
	begin
	CounterSelFlagA<=CDTI[08];
	PtrSelFlagA<=CDTI[09];
	CycleRxA<=CDTI[10];
	CycleTxA<=CDTI[11];
	TxSizeA<=CDTI[15:14];
	end
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[1])
	begin
	CounterSelFlagB<=CDTI[08];
	PtrSelFlagB<=CDTI[09];
	CycleRxB<=CDTI[10];
	CycleTxB<=CDTI[11];
	TxSizeB<=CDTI[15:14];
	end
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[1])
	begin
	CounterSelFlagC<=CDTI[08];
	PtrSelFlagC<=CDTI[09];
	CycleRxC<=CDTI[10];
	CycleTxC<=CDTI[11];
	TxSizeC<=CDTI[15:14];
	end
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[1])
	begin
	CounterSelFlagD<=CDTI[08];
	PtrSelFlagD<=CDTI[09];
	CycleRxD<=CDTI[10];
	CycleTxD<=CDTI[11];
	TxSizeD<=CDTI[15:14];
	end

// transmit timers
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[2]) TxTimerA[7:0]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[2]) TxTimerB[7:0]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[2]) TxTimerC[7:0]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[2]) TxTimerD[7:0]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[3]) TxTimerA[15:8]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[3]) TxTimerB[15:8]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[3]) TxTimerC[15:8]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[3]) TxTimerD[15:8]<=CDTI[31:24];

// current RX offset
if (WDRDY_LA) RxOffsetA<=29'd0;
	else if (InFifoReadA) RxOffsetA<=RxOffsetA+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0]) RxOffsetA[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[1]) RxOffsetA[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[2]) RxOffsetA[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[3]) RxOffsetA[28:21]<=CDTI[31:24];
			end
if (WDRDY_LB) RxOffsetB<=29'd0;
	else if (InFifoReadB) RxOffsetB<=RxOffsetB+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0]) RxOffsetB[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[1]) RxOffsetB[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[2]) RxOffsetB[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[3]) RxOffsetB[28:21]<=CDTI[31:24];
			end
if (WDRDY_LC) RxOffsetC<=29'd0;
	else if (InFifoReadC) RxOffsetC<=RxOffsetC+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0]) RxOffsetC[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[1]) RxOffsetC[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[2]) RxOffsetC[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[3]) RxOffsetC[28:21]<=CDTI[31:24];
			end
if (WDRDY_LD) RxOffsetD<=29'd0;
	else if (InFifoReadD) RxOffsetD<=RxOffsetD+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0]) RxOffsetD[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[1]) RxOffsetD[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[2]) RxOffsetD[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[3]) RxOffsetD[28:21]<=CDTI[31:24];
			end

// current RX counter
if (WDRDY_LA) RCntrA<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd4) & WACTA & |RCntrA & ~WSelRegA) RCntrA<=RCntrA-1'b1;
			else begin
			if (~CounterSelFlagA & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[4]) RCntrA[04:00]<=CDTI[39:35];
			if (~CounterSelFlagA & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[5]) RCntrA[12:05]<=CDTI[47:40];
			if (~CounterSelFlagA & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[6]) RCntrA[20:13]<=CDTI[55:48];
			if (~CounterSelFlagA & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[7]) RCntrA[28:21]<=CDTI[63:56];
			end
if (WDRDY_LB) RCntrB<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd5) & WACTB & |RCntrB & ~WSelRegB) RCntrB<=RCntrB-1'b1;
			else begin
			if (~CounterSelFlagB & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[4]) RCntrB[04:00]<=CDTI[39:35];
			if (~CounterSelFlagB & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[5]) RCntrB[12:05]<=CDTI[47:40];
			if (~CounterSelFlagB & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[6]) RCntrB[20:13]<=CDTI[55:48];
			if (~CounterSelFlagB & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[7]) RCntrB[28:21]<=CDTI[63:56];
			end
if (WDRDY_LC) RCntrC<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd6) & WACTC & |RCntrC & ~WSelRegC) RCntrC<=RCntrC-1'b1;
			else begin
			if (~CounterSelFlagC & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[4]) RCntrC[04:00]<=CDTI[39:35];
			if (~CounterSelFlagC & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[5]) RCntrC[12:05]<=CDTI[47:40];
			if (~CounterSelFlagC & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[6]) RCntrC[20:13]<=CDTI[55:48];
			if (~CounterSelFlagC & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[7]) RCntrC[28:21]<=CDTI[63:56];
			end
if (WDRDY_LD) RCntrD<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd7) & WACTD & |RCntrD & ~WSelRegD) RCntrD<=RCntrD-1'b1;
			else begin
			if (~CounterSelFlagD & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[4]) RCntrD[04:00]<=CDTI[39:35];
			if (~CounterSelFlagD & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[5]) RCntrD[12:05]<=CDTI[47:40];
			if (~CounterSelFlagD & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[6]) RCntrD[20:13]<=CDTI[55:48];
			if (~CounterSelFlagD & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[7]) RCntrD[28:21]<=CDTI[63:56];
			end

// current RX selector
if (WDRDY_LA) RxSelectorA<=DataIN[55:32];
	else if ((ATUNext & (ChanSel==3'd4) & WACTA & ~|RCntrA[28:1] & ~WSelRegA)|(InFifoReadA & InFifoBusA[64])) RxSelectorA<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[4]) RxSelectorA[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[5]) RxSelectorA[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[6]) RxSelectorA[23:16]<=CDTI[55:48];
			end
if (WDRDY_LB) RxSelectorB<=DataIN[55:32];
	else if ((ATUNext & (ChanSel==3'd5) & WACTB & ~|RCntrB[28:1] & ~WSelRegB)|(InFifoReadB & InFifoBusB[64])) RxSelectorB<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[4]) RxSelectorB[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[5]) RxSelectorB[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[6]) RxSelectorB[23:16]<=CDTI[55:48];
			end
if (WDRDY_LC) RxSelectorC<=DataIN[55:32];
	else if ((ATUNext & (ChanSel==3'd6) & WACTC & ~|RCntrC[28:1] & ~WSelRegC)|(InFifoReadC & InFifoBusC[64])) RxSelectorC<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[4]) RxSelectorC[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[5]) RxSelectorC[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[6]) RxSelectorC[23:16]<=CDTI[55:48];
			end
if (WDRDY_LD) RxSelectorD<=DataIN[55:32];
	else if ((ATUNext & (ChanSel==3'd7) & WACTD & ~|RCntrD[28:1] & ~WSelRegD)|(InFifoReadD & InFifoBusD[64])) RxSelectorD<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[4]) RxSelectorD[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[5]) RxSelectorD[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[6]) RxSelectorD[23:16]<=CDTI[55:48];
			end

// RX list offset and control flags
if ((ESTB & (ETAG[3:1]==3'd4))|(WDRDY_LA & ~|DataIN[63:32])) RxEnaA<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0]) RxEnaA<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd5))|(WDRDY_LB & ~|DataIN[63:32])) RxEnaB<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0]) RxEnaB<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd6))|(WDRDY_LC & ~|DataIN[63:32])) RxEnaC<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0]) RxEnaC<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd7))|(WDRDY_LD & ~|DataIN[63:32])) RxEnaD<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0]) RxEnaD<=CDTI[0];
	
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[0]) BypassA<=CDTI[1];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[0]) BypassB<=CDTI[1];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[0]) BypassC<=CDTI[1];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[0]) BypassD<=CDTI[1];

if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0]) RxListBaseOffsetA[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0]) RxListBaseOffsetB[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0]) RxListBaseOffsetC[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0]) RxListBaseOffsetD[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[1]) RxListBaseOffsetA[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[1]) RxListBaseOffsetB[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[1]) RxListBaseOffsetC[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[1]) RxListBaseOffsetD[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[2]) RxListBaseOffsetA[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[2]) RxListBaseOffsetB[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[2]) RxListBaseOffsetC[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[2]) RxListBaseOffsetD[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[3]) RxListBaseOffsetA[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[3]) RxListBaseOffsetB[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[3]) RxListBaseOffsetC[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[3]) RxListBaseOffsetD[28:21]<=CDTI[31:24];

if ((rxsm0==rxrdlist0) & WriteNextA) RxListOffsetA<=RxListOffsetA+1'b1;
	else if (InFifoReadA & InFifoBusA[64]) RxListOffsetA<=RxListBaseOffsetA;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0]) RxListOffsetA[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[1]) RxListOffsetA[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[2]) RxListOffsetA[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[3]) RxListOffsetA[28:21]<=CDTI[31:24];
			end
if ((rxsm1==rxrdlist0) & WriteNextB) RxListOffsetB<=RxListOffsetB+1'b1;
	else if (InFifoReadB & InFifoBusB[64]) RxListOffsetB<=RxListBaseOffsetB;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0]) RxListOffsetB[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[1]) RxListOffsetB[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[2]) RxListOffsetB[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[3]) RxListOffsetB[28:21]<=CDTI[31:24];
			end
if ((rxsm2==rxrdlist0) & WriteNextC) RxListOffsetC<=RxListOffsetC+1'b1;
	else if (InFifoReadC & InFifoBusC[64]) RxListOffsetC<=RxListBaseOffsetC;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0]) RxListOffsetC[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[1]) RxListOffsetC[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[2]) RxListOffsetC[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[3]) RxListOffsetC[28:21]<=CDTI[31:24];
			end
if ((rxsm3==rxrdlist0) & WriteNextD) RxListOffsetD<=RxListOffsetD+1'b1;
	else if (InFifoReadD & InFifoBusD[64]) RxListOffsetD<=RxListBaseOffsetD;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0]) RxListOffsetD[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[1]) RxListOffsetD[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[2]) RxListOffsetD[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[3]) RxListOffsetD[28:21]<=CDTI[31:24];
			end

// RX list selector
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[4]) RxListSelectorA[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[4]) RxListSelectorB[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[4]) RxListSelectorC[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[4]) RxListSelectorD[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[5]) RxListSelectorA[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[5]) RxListSelectorB[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[5]) RxListSelectorC[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[5]) RxListSelectorD[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[6]) RxListSelectorA[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[6]) RxListSelectorB[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[6]) RxListSelectorC[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd2) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[6]) RxListSelectorD[23:16]<=CDTI[55:48];

// current TX offset 
if (RDRDY_LA) TxOffsetA<=29'd0;
	else if ((txsm0==txrd0) & ReadNextA) TxOffsetA<=TxOffsetA+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[0]) TxOffsetA[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[1]) TxOffsetA[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[2]) TxOffsetA[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[3]) TxOffsetA[28:21]<=CDTI[31:24];
			end
if (RDRDY_LB) TxOffsetB<=29'd0;
	else if ((txsm1==txrd0) & ReadNextB) TxOffsetB<=TxOffsetB+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[0]) TxOffsetB[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[1]) TxOffsetB[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[2]) TxOffsetB[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[3]) TxOffsetB[28:21]<=CDTI[31:24];
			end
if (RDRDY_LC) TxOffsetC<=29'd0;
	else if ((txsm2==txrd0) & ReadNextC) TxOffsetC<=TxOffsetC+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[0]) TxOffsetC[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[1]) TxOffsetC[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[2]) TxOffsetC[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[3]) TxOffsetC[28:21]<=CDTI[31:24];
			end
if (RDRDY_LD) TxOffsetD<=29'd0;
	else if ((txsm3==txrd0) & ReadNextD) TxOffsetD<=TxOffsetD+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[0]) TxOffsetD[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[1]) TxOffsetD[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[2]) TxOffsetD[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[3]) TxOffsetD[28:21]<=CDTI[31:24];
			end

// transmit counter
if (RDRDY_LA) TCntrA<=DataIN[31:00];
	else if ((txsm0==txrd0) & ReadNextA) TCntrA<=|TCntrA[31:3] ? TCntrA-4'b1000 : 32'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlagA & ~CBE[4]) TCntrA[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlagA & ~CBE[5]) TCntrA[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlagA & ~CBE[6]) TCntrA[23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlagA & ~CBE[7]) TCntrA[31:24]<=CDTI[63:56];
			end
if (RDRDY_LB) TCntrB<=DataIN[31:00];
	else if ((txsm1==txrd0) & ReadNextB) TCntrB<=|TCntrB[31:3] ? TCntrB-4'b1000 : 32'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlagB & ~CBE[4]) TCntrB[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlagB & ~CBE[5]) TCntrB[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlagB & ~CBE[6]) TCntrB[23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlagB & ~CBE[7]) TCntrB[31:24]<=CDTI[63:56];
			end
if (RDRDY_LC) TCntrC<=DataIN[31:00];
	else if ((txsm2==txrd0) & ReadNextC) TCntrC<=|TCntrC[31:3] ? TCntrC-4'b1000 : 32'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlagC & ~CBE[4]) TCntrC[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlagC & ~CBE[5]) TCntrC[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlagC & ~CBE[6]) TCntrC[23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlagC & ~CBE[7]) TCntrC[31:24]<=CDTI[63:56];
			end
if (RDRDY_LD) TCntrD<=DataIN[31:00];
	else if ((txsm3==txrd0) & ReadNextD) TCntrD<=|TCntrD[31:3] ? TCntrD-4'b1000 : 32'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlagD & ~CBE[4]) TCntrD[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlagD & ~CBE[5]) TCntrD[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlagD & ~CBE[6]) TCntrD[23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlagD & ~CBE[7]) TCntrD[31:24]<=CDTI[63:56];
			end

// current TX selector
if (RDRDY_LA) TxSelectorA<=DataIN[55:32];
	else if ((txsm0==txrd0) & ReadNextA & (~|TCntrA[31:3] | (TCntrA==32'd8))) TxSelectorA<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[4]) TxSelectorA[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[5]) TxSelectorA[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlagA & ~CBE[6]) TxSelectorA[23:16]<=CDTI[55:48];
			end
if (RDRDY_LB) TxSelectorB<=DataIN[55:32];
	else if ((txsm1==txrd0) & ReadNextB & (~|TCntrB[31:3] | (TCntrB==32'd8))) TxSelectorB<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[4]) TxSelectorB[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[5]) TxSelectorB[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlagB & ~CBE[6]) TxSelectorB[23:16]<=CDTI[55:48];
			end
if (RDRDY_LC) TxSelectorC<=DataIN[55:32];
	else if ((txsm2==txrd0) & ReadNextC & (~|TCntrC[31:3] | (TCntrC==32'd8))) TxSelectorC<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[4]) TxSelectorC[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[5]) TxSelectorC[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlagC & ~CBE[6]) TxSelectorC[23:16]<=CDTI[55:48];
			end
if (RDRDY_LD) TxSelectorD<=DataIN[55:32];
	else if ((txsm3==txrd0) & ReadNextD & (~|TCntrD[31:3] | (TCntrD==32'd8))) TxSelectorD<=24'd0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[4]) TxSelectorD[07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[5]) TxSelectorD[15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlagD & ~CBE[6]) TxSelectorD[23:16]<=CDTI[55:48];
			end

// TX list offset and enable flag
if ((ESTB & (ETAG[3:1]==3'd0))|(RDRDY_LA & ~|DataIN[63:32] & ~CycleTxA)) TxEnaA<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0]) TxEnaA<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd1))|(RDRDY_LB & ~|DataIN[63:32] & ~CycleTxB)) TxEnaB<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0]) TxEnaB<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd2))|(RDRDY_LC & ~|DataIN[63:32] & ~CycleTxC)) TxEnaC<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0]) TxEnaC<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd3))|(RDRDY_LD & ~|DataIN[63:32] & ~CycleTxD)) TxEnaD<=1'b0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0]) TxEnaD<=CDTI[0];
	
// transmit counters
if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagA & (ChannelReg==3'd0) & ~CBE[0] & CDTI[0]) TimerA<=32'd0;
	else if (TxEnaA & ~&TimerA) TimerA<=TimerA+1'b1;
if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagB & (ChannelReg==3'd1) & ~CBE[0] & CDTI[0]) TimerB<=32'd0;
	else if (TxEnaB & ~&TimerB) TimerB<=TimerB+1'b1;
if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagC & (ChannelReg==3'd2) & ~CBE[0] & CDTI[0]) TimerC<=32'd0;
	else if (TxEnaC & ~&TimerC) TimerC<=TimerC+1'b1;
if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagD & (ChannelReg==3'd3) & ~CBE[0] & CDTI[0]) TimerD<=32'd0;
	else if (TxEnaD & ~&TimerD) TimerD<=TimerD+1'b1;

if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[0]) TxListBaseOffsetA[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[0]) TxListBaseOffsetB[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[0]) TxListBaseOffsetC[04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[0]) TxListBaseOffsetD[04:00]<=CDTI[07:03];

if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[1]) TxListBaseOffsetA[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[1]) TxListBaseOffsetB[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[1]) TxListBaseOffsetC[12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[1]) TxListBaseOffsetD[12:05]<=CDTI[15:08];

if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[2]) TxListBaseOffsetA[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[2]) TxListBaseOffsetB[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[2]) TxListBaseOffsetC[20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[2]) TxListBaseOffsetD[20:13]<=CDTI[23:16];

if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[3]) TxListBaseOffsetA[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[3]) TxListBaseOffsetB[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[3]) TxListBaseOffsetC[28:21]<=CDTI[31:24];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[3]) TxListBaseOffsetD[28:21]<=CDTI[31:24];

if ((txsm0==txrdlist0) & ReadNextA) TxListOffsetA<=TxListOffsetA+1'b1;
	else if (RDRDY_LA & ~|DataIN[63:32]) TxListOffsetA<=TxListBaseOffsetA;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[0]) TxListOffsetA[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[1]) TxListOffsetA[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[2]) TxListOffsetA[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[3]) TxListOffsetA[28:21]<=CDTI[31:24];
			end
if ((txsm1==txrdlist0) & ReadNextB) TxListOffsetB<=TxListOffsetB+1'b1;
	else if (RDRDY_LB & ~|DataIN[63:32]) TxListOffsetB<=TxListBaseOffsetB;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[0]) TxListOffsetB[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[1]) TxListOffsetB[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[2]) TxListOffsetB[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[3]) TxListOffsetB[28:21]<=CDTI[31:24];
			end
if ((txsm2==txrdlist0) & ReadNextC) TxListOffsetC<=TxListOffsetC+1'b1;
	else if (RDRDY_LC & ~|DataIN[63:32]) TxListOffsetC<=TxListBaseOffsetC;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[0]) TxListOffsetC[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[1]) TxListOffsetC[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[2]) TxListOffsetC[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[3]) TxListOffsetC[28:21]<=CDTI[31:24];
			end
if ((txsm3==txrdlist0) & ReadNextD) TxListOffsetD<=TxListOffsetD+1'b1;
	else if (RDRDY_LD & ~|DataIN[63:32]) TxListOffsetD<=TxListBaseOffsetD;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[0]) TxListOffsetD[04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[1]) TxListOffsetD[12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[2]) TxListOffsetD[20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[3]) TxListOffsetD[28:21]<=CDTI[31:24];
			end

// TX list selector
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[4]) TxListSelectorA[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[4]) TxListSelectorB[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[4]) TxListSelectorC[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[4]) TxListSelectorD[07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[5]) TxListSelectorA[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[5]) TxListSelectorB[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[5]) TxListSelectorC[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[5]) TxListSelectorD[15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlagA & ~CBE[6]) TxListSelectorA[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlagB & ~CBE[6]) TxListSelectorB[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlagC & ~CBE[6]) TxListSelectorC[23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlagD & ~CBE[6]) TxListSelectorD[23:16]<=CDTI[55:48];


// selectors invalidation in the ATU
SelInvd[00]<=RDRDY_LA | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~&CBE[7:4]);
SelInvd[01]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagA & (ChannelReg==3'd0) & ~&CBE[7:4];
SelInvd[02]<=RDRDY_LB | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~&CBE[7:4]);
SelInvd[03]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagB & (ChannelReg==3'd1) & ~&CBE[7:4];
SelInvd[04]<=RDRDY_LC | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~&CBE[7:4]);
SelInvd[05]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagC & (ChannelReg==3'd2) & ~&CBE[7:4];
SelInvd[06]<=RDRDY_LD | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~&CBE[7:4]);
SelInvd[07]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlagD & (ChannelReg==3'd3) & ~&CBE[7:4];
SelInvd[08]<=WDRDY_LA | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagA & (ChannelReg==3'd0) & ~&CBE[7:4]);
SelInvd[09]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagA & (ChannelReg==3'd0) & ~&CBE[7:4];
SelInvd[10]<=WDRDY_LB | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagB & (ChannelReg==3'd1) & ~&CBE[7:4]);
SelInvd[11]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagB & (ChannelReg==3'd1) & ~&CBE[7:4];
SelInvd[12]<=WDRDY_LC | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagC & (ChannelReg==3'd2) & ~&CBE[7:4]);
SelInvd[13]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagC & (ChannelReg==3'd2) & ~&CBE[7:4];
SelInvd[14]<=WDRDY_LD | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlagD & (ChannelReg==3'd3) & ~&CBE[7:4]);
SelInvd[15]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlagD & (ChannelReg==3'd3) & ~&CBE[7:4];


// input data from io bus A
casez ({BypassA ? TxSizeA : IOSIZE[0], InByteCntA})
	// byte data
	5'b00_000:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 56'h000000_00000000, BypassA ? IORD[0][7:0] : IOWD[0][7:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[7:0]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_001:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 48'h0000_00000000, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[7:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[15:8]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_010:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 40'h00_00000000, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[15:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[23:16]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_011:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 32'h00000000, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[23:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[31:24]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_100:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 24'h000000, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[31:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[39:32]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_101:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 16'h0000, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[39:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[47:40]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_110:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 8'h00, BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[47:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[55:48]<=BypassA ? IORD[0][7:0] : IOWD[0][7:0];
				end
	5'b00_111:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], BypassA ? IORD[0][7:0] : IOWD[0][7:0], IOWTempRegA[55:0]};
				InFifoWENAA<=BypassA ? IORSTB[0] : IOWR[0];
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+1'b1)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+1'b1)&{3{~IOWLAST[0]}} : InByteCntA);
				end
	// word data
	5'b01_00?:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 48'h0000_00000000, BypassA ? IORD[0][15:0] : IOWD[0][15:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+2'b10)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+2'b10)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[15:0]<=BypassA ? IORD[0][15:0] : IOWD[0][15:0];
				end
	5'b01_01?:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 32'h00000000, BypassA ? IORD[0][15:0] : IOWD[0][15:0], IOWTempRegA[15:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+2'b10)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+2'b10)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[31:16]<=BypassA ? IORD[0][15:0] : IOWD[0][15:0];
				end
	5'b01_10?:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 16'h0000, BypassA ? IORD[0][15:0] : IOWD[0][15:0], IOWTempRegA[31:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+2'b10)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+2'b10)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[47:32]<=BypassA ? IORD[0][15:0] : IOWD[0][15:0];
				end
	5'b01_11?:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], BypassA ? IORD[0][15:0] : IOWD[0][15:0], IOWTempRegA[47:0]};
				InFifoWENAA<=BypassA ? IORSTB[0] : IOWR[0];
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+2'b10)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+2'b10)&{3{~IOWLAST[0]}} : InByteCntA);
				end
	// dword data
	5'b10_0??:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], 32'h00000000, BypassA ? IORD[0][31:0] : IOWD[0][31:0]};
				InFifoWENAA<=BypassA ? (IORSTB[0] & IORLAST[0]):(IOWR[0] & IOWLAST[0]);
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+3'b100)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+3'b100)&{3{~IOWLAST[0]}} : InByteCntA);
				IOWTempRegA[31:0]<=BypassA ? IORD[0][31:0] : IOWD[0][31:0];
				end
	5'b10_1??:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], BypassA ? IORD[0][31:0] : IOWD[0][31:0],IOWTempRegA[31:0]};
				InFifoWENAA<=BypassA ? IORSTB[0]:IOWR[0];
				InByteCntA<=BypassA ? (IORSTB[0] ? (InByteCntA+3'b100)&{3{~IORLAST[0]}} : InByteCntA) : (IOWR[0] ? (InByteCntA+3'b100)&{3{~IOWLAST[0]}} : InByteCntA);
				end
	// qword data
	5'b11_???:	begin
				InBusA<={BypassA ? 1'b0 : IOWLAST[0], BypassA ? IORD[0] : IOWD[0]};
				InFifoWENAA<=BypassA ? IORSTB[0]:IOWR[0];
				InByteCntA<=BypassA ? (IORSTB[0] ? 3'd0 : InByteCntA) : (IOWR[0] ? 3'd0 : InByteCntA);
				end
	endcase

// input data from io bus B
casez ({BypassB ? TxSizeB : IOSIZE[1], InByteCntB})
	// byte data
	5'b00_000:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 56'h000000_00000000, BypassB ? IORD[1][7:0] : IOWD[1][7:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[7:0]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_001:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 48'h0000_00000000, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[7:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[15:8]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_010:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 40'h00_00000000, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[15:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[23:16]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_011:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 32'h00000000, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[23:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[31:24]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_100:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 24'h000000, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[31:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[39:32]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_101:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 16'h0000, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[39:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[47:40]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_110:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 8'h00, BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[47:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[55:48]<=BypassB ? IORD[1][7:0] : IOWD[1][7:0];
				end
	5'b00_111:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], BypassB ? IORD[1][7:0] : IOWD[1][7:0], IOWTempRegB[55:0]};
				InFifoWENAB<=BypassB ? IORSTB[1] : IOWR[1];
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+1'b1)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+1'b1)&{3{~IOWLAST[1]}} : InByteCntB);
				end
	// word data
	5'b01_00?:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 48'h0000_00000000, BypassB ? IORD[1][15:0] : IOWD[1][15:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+2'b10)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+2'b10)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[15:0]<=BypassB ? IORD[1][15:0] : IOWD[1][15:0];
				end
	5'b01_01?:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 32'h00000000, BypassB ? IORD[1][15:0] : IOWD[1][15:0], IOWTempRegB[15:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+2'b10)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+2'b10)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[31:16]<=BypassB ? IORD[1][15:0] : IOWD[1][15:0];
				end
	5'b01_10?:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 16'h0000, BypassB ? IORD[1][15:0] : IOWD[1][15:0], IOWTempRegB[31:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+2'b10)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+2'b10)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[47:32]<=BypassB ? IORD[1][15:0] : IOWD[1][15:0];
				end
	5'b01_11?:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], BypassB ? IORD[1][15:0] : IOWD[1][15:0], IOWTempRegB[47:0]};
				InFifoWENAB<=BypassB ? IORSTB[1] : IOWR[1];
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+2'b10)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+2'b10)&{3{~IOWLAST[1]}} : InByteCntB);
				end
	// dword data
	5'b10_0??:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], 32'h00000000, BypassB ? IORD[1][31:0] : IOWD[1][31:0]};
				InFifoWENAB<=BypassB ? (IORSTB[1] & IORLAST[1]):(IOWR[1] & IOWLAST[1]);
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+3'b100)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+3'b100)&{3{~IOWLAST[1]}} : InByteCntB);
				IOWTempRegB[31:0]<=BypassB ? IORD[1][31:0] : IOWD[1][31:0];
				end
	5'b10_1??:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], BypassB ? IORD[1][31:0] : IOWD[1][31:0],IOWTempRegB[31:0]};
				InFifoWENAB<=BypassB ? IORSTB[1]:IOWR[1];
				InByteCntB<=BypassB ? (IORSTB[1] ? (InByteCntB+3'b100)&{3{~IORLAST[1]}} : InByteCntB) : (IOWR[1] ? (InByteCntB+3'b100)&{3{~IOWLAST[1]}} : InByteCntB);
				end
	// qword data
	5'b11_???:	begin
				InBusB<={BypassB ? 1'b0 : IOWLAST[1], BypassB ? IORD[1] : IOWD[1]};
				InFifoWENAB<=BypassB ? IORSTB[1]:IOWR[1];
				InByteCntB<=BypassB ? (IORSTB[1] ? 3'd0 : InByteCntB) : (IOWR[1] ? 3'd0 : InByteCntB);
				end
	endcase

// input data from io bus C
casez ({BypassC ? TxSizeC : IOSIZE[2], InByteCntC})
	// byte data
	5'b00_000:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 56'h000000_00000000, BypassC ? IORD[2][7:0] : IOWD[2][7:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[7:0]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_001:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 48'h0000_00000000, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[7:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[15:8]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_010:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 40'h00_00000000, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[15:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[23:16]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_011:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 32'h00000000, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[23:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[31:24]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_100:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 24'h000000, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[31:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[39:32]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_101:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 16'h0000, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[39:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[47:40]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_110:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 8'h00, BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[47:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[55:48]<=BypassC ? IORD[2][7:0] : IOWD[2][7:0];
				end
	5'b00_111:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], BypassC ? IORD[2][7:0] : IOWD[2][7:0], IOWTempRegC[55:0]};
				InFifoWENAC<=BypassC ? IORSTB[2] : IOWR[2];
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+1'b1)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+1'b1)&{3{~IOWLAST[2]}} : InByteCntC);
				end
	// word data
	5'b01_00?:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 48'h0000_00000000, BypassC ? IORD[2][15:0] : IOWD[2][15:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+2'b10)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+2'b10)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[15:0]<=BypassC ? IORD[2][15:0] : IOWD[2][15:0];
				end
	5'b01_01?:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 32'h00000000, BypassC ? IORD[2][15:0] : IOWD[2][15:0], IOWTempRegC[15:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+2'b10)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+2'b10)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[31:16]<=BypassC ? IORD[2][15:0] : IOWD[2][15:0];
				end
	5'b01_10?:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 16'h0000, BypassC ? IORD[2][15:0] : IOWD[2][15:0], IOWTempRegC[31:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+2'b10)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+2'b10)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[47:32]<=BypassC ? IORD[2][15:0] : IOWD[2][15:0];
				end
	5'b01_11?:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], BypassC ? IORD[2][15:0] : IOWD[2][15:0], IOWTempRegC[47:0]};
				InFifoWENAC<=BypassC ? IORSTB[2] : IOWR[2];
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+2'b10)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+2'b10)&{3{~IOWLAST[2]}} : InByteCntC);
				end
	// dword data
	5'b10_0??:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], 32'h00000000, BypassC ? IORD[2][31:0] : IOWD[2][31:0]};
				InFifoWENAC<=BypassC ? (IORSTB[2] & IORLAST[2]):(IOWR[2] & IOWLAST[2]);
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+3'b100)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+3'b100)&{3{~IOWLAST[2]}} : InByteCntC);
				IOWTempRegC[31:0]<=BypassC ? IORD[2][31:0] : IOWD[2][31:0];
				end
	5'b10_1??:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], BypassC ? IORD[2][31:0] : IOWD[2][31:0],IOWTempRegC[31:0]};
				InFifoWENAC<=BypassC ? IORSTB[2]:IOWR[2];
				InByteCntC<=BypassC ? (IORSTB[2] ? (InByteCntC+3'b100)&{3{~IORLAST[2]}} : InByteCntC) : (IOWR[2] ? (InByteCntC+3'b100)&{3{~IOWLAST[2]}} : InByteCntC);
				end
	// qword data
	5'b11_???:	begin
				InBusC<={BypassC ? 1'b0 : IOWLAST[2], BypassC ? IORD[2] : IOWD[2]};
				InFifoWENAC<=BypassC ? IORSTB[2]:IOWR[2];
				InByteCntC<=BypassC ? (IORSTB[2] ? 3'd0 : InByteCntC) : (IOWR[2] ? 3'd0 : InByteCntC);
				end
	endcase

// input data from io bus D
casez ({BypassD ? TxSizeD : IOSIZE[3], InByteCntD})
	// byte data
	5'b00_000:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 56'h000000_00000000, BypassD ? IORD[3][7:0] : IOWD[3][7:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[7:0]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_001:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 48'h0000_00000000, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[7:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[15:8]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_010:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 40'h00_00000000, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[15:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[23:16]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_011:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 32'h00000000, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[23:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[31:24]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_100:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 24'h000000, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[31:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[39:32]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_101:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 16'h0000, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[39:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[47:40]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_110:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 8'h00, BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[47:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[55:48]<=BypassD ? IORD[3][7:0] : IOWD[3][7:0];
				end
	5'b00_111:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], BypassD ? IORD[3][7:0] : IOWD[3][7:0], IOWTempRegD[55:0]};
				InFifoWENAD<=BypassD ? IORSTB[3] : IOWR[3];
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+1'b1)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+1'b1)&{3{~IOWLAST[3]}} : InByteCntD);
				end
	// word data
	5'b01_00?:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 48'h0000_00000000, BypassD ? IORD[3][15:0] : IOWD[3][15:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+2'b10)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+2'b10)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[15:0]<=BypassD ? IORD[3][15:0] : IOWD[3][15:0];
				end
	5'b01_01?:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 32'h00000000, BypassD ? IORD[3][15:0] : IOWD[3][15:0], IOWTempRegD[15:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+2'b10)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+2'b10)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[31:16]<=BypassD ? IORD[3][15:0] : IOWD[3][15:0];
				end
	5'b01_10?:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 16'h0000, BypassD ? IORD[3][15:0] : IOWD[3][15:0], IOWTempRegD[31:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+2'b10)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+2'b10)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[47:32]<=BypassD ? IORD[3][15:0] : IOWD[3][15:0];
				end
	5'b01_11?:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], BypassD ? IORD[3][15:0] : IOWD[3][15:0], IOWTempRegD[47:0]};
				InFifoWENAD<=BypassD ? IORSTB[3] : IOWR[3];
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+2'b10)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+2'b10)&{3{~IOWLAST[3]}} : InByteCntD);
				end
	// dword data
	5'b10_0??:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], 32'h00000000, BypassD ? IORD[3][31:0] : IOWD[3][31:0]};
				InFifoWENAD<=BypassD ? (IORSTB[3] & IORLAST[3]):(IOWR[3] & IOWLAST[3]);
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+3'b100)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+3'b100)&{3{~IOWLAST[3]}} : InByteCntD);
				IOWTempRegD[31:0]<=BypassD ? IORD[3][31:0] : IOWD[3][31:0];
				end
	5'b10_1??:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], BypassD ? IORD[3][31:0] : IOWD[3][31:0],IOWTempRegD[31:0]};
				InFifoWENAD<=BypassD ? IORSTB[3]:IOWR[3];
				InByteCntD<=BypassD ? (IORSTB[3] ? (InByteCntD+3'b100)&{3{~IORLAST[3]}} : InByteCntD) : (IOWR[3] ? (InByteCntD+3'b100)&{3{~IOWLAST[3]}} : InByteCntD);
				end
	// qword data
	5'b11_???:	begin
				InBusD<={BypassD ? 1'b0 : IOWLAST[3], BypassD ? IORD[3] : IOWD[3]};
				InFifoWENAD<=BypassD ? IORSTB[3]:IOWR[3];
				InByteCntD<=BypassD ? (IORSTB[3] ? 3'd0 : InByteCntD) : (IOWR[3] ? 3'd0 : InByteCntD);
				end
	endcase


/*

Receiving machines

*/
case (rxsm0)
	rxws:			if (~InFifoEmptyA & RxEnaA & ~|RxSelectorA & |RxListSelectorA) rxsm0<=rxrdlist0;
						else rxsm0<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNextA) rxsm0<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_LA) rxsm0<=rxws;
						else rxsm0<=rxrdlist1;
	endcase

case (rxsm1)
	rxws:			if (~InFifoEmptyB & RxEnaB & ~|RxSelectorB & |RxListSelectorB) rxsm1<=rxrdlist0;
						else rxsm1<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNextB) rxsm1<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_LB) rxsm1<=rxws;
						else rxsm1<=rxrdlist1;
	endcase

case (rxsm2)
	rxws:			if (~InFifoEmptyC & RxEnaC & ~|RxSelectorC & |RxListSelectorC) rxsm2<=rxrdlist0;
						else rxsm2<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNextC) rxsm2<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_LC) rxsm2<=rxws;
						else rxsm2<=rxrdlist1;
	endcase

case (rxsm3)
	rxws:			if (~InFifoEmptyD & RxEnaD & ~|RxSelectorD & |RxListSelectorD) rxsm3<=rxrdlist0;
						else rxsm3<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNextD) rxsm3<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_LD) rxsm3<=rxws;
						else rxsm3<=rxrdlist1;
	endcase

/*

Transmitting machines

*/
case (txsm0)
	txws:			if (~TxEnaA) txsm0<=txws;
						else if (~|TxSelectorA & |TxListSelectorA & OutFifoEmptyA & ~|TcntA) txsm0<=txrdlist0;
								else if (|TxSelectorA & |TCntrA & TxReadEnaA) txsm0<=txrd0;
										else txsm0<=txws;
	// read objects list
	txrdlist0:		if (ReadNextA) txsm0<=txrdlist1;
						else txsm0<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_LA) txsm0<=txrdlist1;
						else txsm0<=txws;
	// reading data from memory
	txrd0:			if (ReadNextA) txsm0<=txws;
						else txsm0<=txrd0;
	endcase

case (txsm1)
	txws:			if (~TxEnaB) txsm1<=txws;
						else if (~|TxSelectorB & |TxListSelectorB & OutFifoEmptyB & ~|TcntB) txsm1<=txrdlist0;
								else if (|TxSelectorB & |TCntrB & TxReadEnaB) txsm1<=txrd0;
										else txsm1<=txws;
	// read objects list
	txrdlist0:		if (ReadNextB) txsm1<=txrdlist1;
						else txsm1<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_LB) txsm1<=txrdlist1;
						else txsm1<=txws;
	// reading data from memory
	txrd0:			if (ReadNextB) txsm1<=txws;
						else txsm1<=txrd0;
	endcase

case (txsm2)
	txws:			if (~TxEnaC) txsm2<=txws;
						else if (~|TxSelectorC & |TxListSelectorC & OutFifoEmptyC & ~|TcntC) txsm2<=txrdlist0;
								else if (|TxSelectorC & |TCntrC & TxReadEnaC) txsm2<=txrd0;
										else txsm2<=txws;
	// read objects list
	txrdlist0:		if (ReadNextC) txsm2<=txrdlist1;
						else txsm2<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_LC) txsm2<=txrdlist1;
						else txsm2<=txws;
	// reading data from memory
	txrd0:			if (ReadNextC) txsm2<=txws;
						else txsm2<=txrd0;
	endcase

case (txsm3)
	txws:			if (~TxEnaD) txsm3<=txws;
						else if (~|TxSelectorD & |TxListSelectorD & OutFifoEmptyD & ~|TcntD) txsm3<=txrdlist0;
								else if (|TxSelectorD & |TCntrD & TxReadEnaD) txsm3<=txrd0;
										else txsm3<=txws;
	// read objects list
	txrdlist0:		if (ReadNextD) txsm3<=txrdlist1;
						else txsm3<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_LD) txsm3<=txrdlist1;
						else txsm3<=txws;
	// reading data from memory
	txrd0:			if (ReadNextD) txsm3<=txws;
						else txsm3<=txrd0;
	endcase

		
		
		
		

/*

read memory channels

*/
RACTA<=(RACTA | (txsm0==txrdlist0) | (txsm0==txrd0)) & ~(ATUNext & (ChanSel==3'd0) & RACTA);
if (ReadNextA)
	begin
	ROffsetRegA<=(txsm0==txrd0) ? TxOffsetA : TxListOffsetA;
	RSelRegA<=(txsm0!=txrd0);
	RLastRegA<={(txsm0==txrd0) & ReadNextA & ~|TCntrA[31:4] & (|TCntrA[2:0] ? ~TCntrA[3] : 1'b1), TCntrA[2:0]};
	SELECTORS[00]<=TxSelectorA;
	SELECTORS[01]<=TxListSelectorA;
	end

RACTB<=(RACTB | (txsm1==txrdlist0) | (txsm1==txrd0)) & ~(ATUNext & (ChanSel==3'd1) & RACTB);
if (ReadNextB)
	begin
	ROffsetRegB<=(txsm1==txrd0) ? TxOffsetB : TxListOffsetB;
	RSelRegB<=(txsm1!=txrd0);
	RLastRegB<={(txsm1==txrd0) & ReadNextB & ~|TCntrB[31:4] & (|TCntrB[2:0] ? ~TCntrB[3] : 1'b1), TCntrB[2:0]};
	SELECTORS[02]<=TxSelectorB;
	SELECTORS[03]<=TxListSelectorB;
	end

RACTC<=(RACTC | (txsm2==txrdlist0) | (txsm2==txrd0)) & ~(ATUNext & (ChanSel==3'd2) & RACTC);
if (ReadNextC)
	begin
	ROffsetRegC<=(txsm2==txrd0) ? TxOffsetC : TxListOffsetC;
	RSelRegC<=(txsm2!=txrd0);
	RLastRegC<={(txsm2==txrd0) & ReadNextC & ~|TCntrC[31:4] & (|TCntrC[2:0] ? ~TCntrC[3] : 1'b1), TCntrC[2:0]};
	SELECTORS[04]<=TxSelectorC;
	SELECTORS[05]<=TxListSelectorC;
	end

RACTD<=(RACTD | (txsm3==txrdlist0) | (txsm3==txrd0)) & ~(ATUNext & (ChanSel==3'd3) & RACTD);
if (ReadNextD)
	begin
	ROffsetRegD<=(txsm3==txrd0) ? TxOffsetD : TxListOffsetD;
	RSelRegD<=(txsm3!=txrd0);
	RLastRegD<={(txsm3==txrd0) & ReadNextD & ~|TCntrD[31:4] & (|TCntrD[2:0] ? ~TCntrD[3] : 1'b1), TCntrD[2:0]};
	SELECTORS[06]<=TxSelectorD;
	SELECTORS[07]<=TxListSelectorD;
	end

/*

write to the memory channels request registers

*/

WACTA<=(WACTA | (~InFifoEmptyA & RxEnaA & |RxSelectorA) | (rxsm0==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd4) & WACTA);
if (WriteNextA)
	begin
	WOffsetRegA<=(rxsm0==rxws) ? RxOffsetA : RxListOffsetA;
	WSelRegA<=(rxsm0!=rxws);
	WDataRegA<=InFifoBusA[63:0];
	WCmdRegA<=(rxsm0!=rxws);
	SELECTORS[08]<=RxSelectorA;
	SELECTORS[09]<=RxListSelectorA;
	end

WACTB<=(WACTB | (~InFifoEmptyB & RxEnaB & |RxSelectorB) | (rxsm1==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd5) & WACTB);
if (WriteNextB)
	begin
	WOffsetRegB<=(rxsm1==rxws) ? RxOffsetB : RxListOffsetB;
	WSelRegB<=(rxsm1!=rxws);
	WDataRegB<=InFifoBusB[63:0];
	WCmdRegB<=(rxsm1!=rxws);
	SELECTORS[10]<=RxSelectorB;
	SELECTORS[11]<=RxListSelectorB;
	end

WACTC<=(WACTC | (~InFifoEmptyC & RxEnaC & |RxSelectorC) | (rxsm2==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd6) & WACTC);
if (WriteNextC)
	begin
	WOffsetRegC<=(rxsm2==rxws) ? RxOffsetC : RxListOffsetC;
	WSelRegC<=(rxsm2!=rxws);
	WDataRegC<=InFifoBusC[63:0];
	WCmdRegC<=(rxsm2!=rxws);
	SELECTORS[12]<=RxSelectorC;
	SELECTORS[13]<=RxListSelectorC;
	end

WACTD<=(WACTD | (~InFifoEmptyD & RxEnaD & |RxSelectorD) | (rxsm3==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd7) & WACTD);
if (WriteNextD)
	begin
	WOffsetRegD<=(rxsm3==rxws) ? RxOffsetD : RxListOffsetD;
	WSelRegD<=(rxsm3!=rxws);
	WDataRegD<=InFifoBusD[63:0];
	WCmdRegD<=(rxsm3!=rxws);
	SELECTORS[14]<=RxSelectorD;
	SELECTORS[15]<=RxListSelectorD;
	end

/*
		data output to the channels
*/
//-------------------- channel A
// data strobe A
IORSTB[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA;
IORSTRT[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA & StartFlagA;
// start flag A
StartFlagA<=(StartFlagA & ~IORSTB[0]) | RDRDY_LA;
casez ({TxSizeA, OutByteCntA})
	5'b00_000:	IORD[0]<={56'd0, OutFifoBusA[07:00]};
	5'b00_001:	IORD[0]<={56'd0, OutFifoBusA[15:08]};
	5'b00_010:	IORD[0]<={56'd0, OutFifoBusA[23:16]};
	5'b00_011:	IORD[0]<={56'd0, OutFifoBusA[31:24]};
	5'b00_100:	IORD[0]<={56'd0, OutFifoBusA[39:32]};
	5'b00_101:	IORD[0]<={56'd0, OutFifoBusA[47:40]};
	5'b00_110:	IORD[0]<={56'd0, OutFifoBusA[55:48]};
	5'b00_111:	IORD[0]<={56'd0, OutFifoBusA[63:56]};
		
	5'b01_00?:	IORD[0]<={48'd0, OutFifoBusA[15:00]};
	5'b01_01?:	IORD[0]<={48'd0, OutFifoBusA[31:16]};
	5'b01_10?:	IORD[0]<={48'd0, OutFifoBusA[47:32]};
	5'b01_11?:	IORD[0]<={48'd0, OutFifoBusA[63:48]};
		
	5'b10_0??:	IORD[0]<={32'd0, OutFifoBusA[31:00]};
	5'b10_1??:	IORD[0]<={32'd0, OutFifoBusA[63:32]};
		
	5'b11_???:	IORD[0]<=OutFifoBusA[63:00];
	endcase

case (TxSizeA)
	2'b00:		IORLAST[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA & OutFifoBusA[67] & ((OutByteCntA+1'b1)==OutFifoBusA[66:64]);
	2'b01:		IORLAST[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA & OutFifoBusA[67] & ((OutByteCntA[2:1]+1'b1)==OutFifoBusA[66:65]);
	2'b10:		IORLAST[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA & OutFifoBusA[67] & ((~OutByteCntA[2])==OutFifoBusA[66]);
	2'b11:		IORLAST[0]<=IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA & OutFifoBusA[67];
	endcase

// data element counter
if (RDRDY_LA) OutByteCntA<=3'd0;
	else if (IORRDY[0] & ~OutFifoEmptyA & ~|TxTmrA)
			case (TxSizeA)
				2'b00:	OutByteCntA<=OutByteCntA+1'b1;
				2'b01:	OutByteCntA<=OutByteCntA+2'd2;
				2'b10:	OutByteCntA<=OutByteCntA+3'd4;
				2'b11:	OutByteCntA<=3'd0;
				endcase
// data interval counter
if (RDRDY_LA) TxTmrA<=16'd0;
	else if (|TxTmrA) TxTmrA<=TxTmrA-1'b1;
			else if (IORRDY[0] & ~OutFifoEmptyA) TxTmrA<=TxTimerA;
			
//-------------------- channel B
// data strobe B
IORSTB[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB;
IORSTRT[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB & StartFlagB;
// start flag B
StartFlagB<=(StartFlagB & ~IORSTB[1]) | RDRDY_LB;
casez ({TxSizeB, OutByteCntB})
	5'b00_000:	IORD[1]<={56'd0, OutFifoBusB[07:00]};
	5'b00_001:	IORD[1]<={56'd0, OutFifoBusB[15:08]};
	5'b00_010:	IORD[1]<={56'd0, OutFifoBusB[23:16]};
	5'b00_011:	IORD[1]<={56'd0, OutFifoBusB[31:24]};
	5'b00_100:	IORD[1]<={56'd0, OutFifoBusB[39:32]};
	5'b00_101:	IORD[1]<={56'd0, OutFifoBusB[47:40]};
	5'b00_110:	IORD[1]<={56'd0, OutFifoBusB[55:48]};
	5'b00_111:	IORD[1]<={56'd0, OutFifoBusB[63:56]};
		
	5'b01_00?:	IORD[1]<={48'd0, OutFifoBusB[15:00]};
	5'b01_01?:	IORD[1]<={48'd0, OutFifoBusB[31:16]};
	5'b01_10?:	IORD[1]<={48'd0, OutFifoBusB[47:32]};
	5'b01_11?:	IORD[1]<={48'd0, OutFifoBusB[63:48]};
		
	5'b10_0??:	IORD[1]<={32'd0, OutFifoBusB[31:00]};
	5'b10_1??:	IORD[1]<={32'd0, OutFifoBusB[63:32]};
		
	5'b11_???:	IORD[1]<=OutFifoBusB[63:00];
	endcase

case (TxSizeB)
	2'b00:		IORLAST[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB & OutFifoBusB[67] & ((OutByteCntB+1'b1)==OutFifoBusB[66:64]);
	2'b01:		IORLAST[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB & OutFifoBusB[67] & ((OutByteCntB[2:1]+1'b1)==OutFifoBusB[66:65]);
	2'b10:		IORLAST[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB & OutFifoBusB[67] & ((~OutByteCntB[2])==OutFifoBusB[66]);
	2'b11:		IORLAST[1]<=IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB & OutFifoBusB[67];
	endcase

// data element counter
if (RDRDY_LB) OutByteCntB<=3'd0;
	else if (IORRDY[1] & ~OutFifoEmptyB & ~|TxTmrB)
			case (TxSizeB)
				2'b00:	OutByteCntB<=OutByteCntB+1'b1;
				2'b01:	OutByteCntB<=OutByteCntB+2'd2;
				2'b10:	OutByteCntB<=OutByteCntB+3'd4;
				2'b11:	OutByteCntB<=3'd0;
				endcase
// data interval counter
if (RDRDY_LB) TxTmrB<=16'd0;
	else if (|TxTmrB) TxTmrB<=TxTmrB-1'b1;
			else if (IORRDY[1] & ~OutFifoEmptyB) TxTmrB<=TxTimerB;

//-------------------- channel С
// data strobe С
IORSTB[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC;
IORSTRT[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC & StartFlagC;
// start flag С
StartFlagC<=(StartFlagC & ~IORSTB[2]) | RDRDY_LC;
casez ({TxSizeC, OutByteCntC})
	5'b00_000:	IORD[2]<={56'd0, OutFifoBusC[07:00]};
	5'b00_001:	IORD[2]<={56'd0, OutFifoBusC[15:08]};
	5'b00_010:	IORD[2]<={56'd0, OutFifoBusC[23:16]};
	5'b00_011:	IORD[2]<={56'd0, OutFifoBusC[31:24]};
	5'b00_100:	IORD[2]<={56'd0, OutFifoBusC[39:32]};
	5'b00_101:	IORD[2]<={56'd0, OutFifoBusC[47:40]};
	5'b00_110:	IORD[2]<={56'd0, OutFifoBusC[55:48]};
	5'b00_111:	IORD[2]<={56'd0, OutFifoBusC[63:56]};
		
	5'b01_00?:	IORD[2]<={48'd0, OutFifoBusC[15:00]};
	5'b01_01?:	IORD[2]<={48'd0, OutFifoBusC[31:16]};
	5'b01_10?:	IORD[2]<={48'd0, OutFifoBusC[47:32]};
	5'b01_11?:	IORD[2]<={48'd0, OutFifoBusC[63:48]};
		
	5'b10_0??:	IORD[2]<={32'd0, OutFifoBusC[31:00]};
	5'b10_1??:	IORD[2]<={32'd0, OutFifoBusC[63:32]};
		
	5'b11_???:	IORD[2]<=OutFifoBusC[63:00];
	endcase

case (TxSizeC)
	2'b00:		IORLAST[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC & OutFifoBusC[67] & ((OutByteCntC+1'b1)==OutFifoBusC[66:64]);
	2'b01:		IORLAST[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC & OutFifoBusC[67] & ((OutByteCntC[2:1]+1'b1)==OutFifoBusC[66:65]);
	2'b10:		IORLAST[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC & OutFifoBusC[67] & ((~OutByteCntC[2])==OutFifoBusC[66]);
	2'b11:		IORLAST[2]<=IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC & OutFifoBusC[67];
	endcase

// data element counter
if (RDRDY_LC) OutByteCntC<=3'd0;
	else if (IORRDY[2] & ~OutFifoEmptyC & ~|TxTmrC)
			case (TxSizeC)
				2'b00:	OutByteCntC<=OutByteCntC+1'b1;
				2'b01:	OutByteCntC<=OutByteCntC+2'd2;
				2'b10:	OutByteCntC<=OutByteCntC+3'd4;
				2'b11:	OutByteCntC<=3'd0;
				endcase
// data interval counter
if (RDRDY_LC) TxTmrC<=16'd0;
	else if (|TxTmrC) TxTmrC<=TxTmrC-1'b1;
			else if (IORRDY[2] & ~OutFifoEmptyC) TxTmrC<=TxTimerC;

//-------------------- channel D
// data strobe D
IORSTB[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD;
IORSTRT[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD & StartFlagD;
// start flag D
StartFlagD<=(StartFlagD & ~IORSTB[3]) | RDRDY_LD;
casez ({TxSizeD, OutByteCntD})
	5'b00_000:	IORD[3]<={56'd0, OutFifoBusD[07:00]};
	5'b00_001:	IORD[3]<={56'd0, OutFifoBusD[15:08]};
	5'b00_010:	IORD[3]<={56'd0, OutFifoBusD[23:16]};
	5'b00_011:	IORD[3]<={56'd0, OutFifoBusD[31:24]};
	5'b00_100:	IORD[3]<={56'd0, OutFifoBusD[39:32]};
	5'b00_101:	IORD[3]<={56'd0, OutFifoBusD[47:40]};
	5'b00_110:	IORD[3]<={56'd0, OutFifoBusD[55:48]};
	5'b00_111:	IORD[3]<={56'd0, OutFifoBusD[63:56]};
		
	5'b01_00?:	IORD[3]<={48'd0, OutFifoBusD[15:00]};
	5'b01_01?:	IORD[3]<={48'd0, OutFifoBusD[31:16]};
	5'b01_10?:	IORD[3]<={48'd0, OutFifoBusD[47:32]};
	5'b01_11?:	IORD[3]<={48'd0, OutFifoBusD[63:48]};
		
	5'b10_0??:	IORD[3]<={32'd0, OutFifoBusD[31:00]};
	5'b10_1??:	IORD[3]<={32'd0, OutFifoBusD[63:32]};
		
	5'b11_???:	IORD[3]<=OutFifoBusD[63:00];
	endcase

case (TxSizeD)
	2'b00:		IORLAST[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD & OutFifoBusD[67] & ((OutByteCntD+1'b1)==OutFifoBusD[66:64]);
	2'b01:		IORLAST[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD & OutFifoBusD[67] & ((OutByteCntD[2:1]+1'b1)==OutFifoBusD[66:65]);
	2'b10:		IORLAST[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD & OutFifoBusD[67] & ((~OutByteCntD[2])==OutFifoBusD[66]);
	2'b11:		IORLAST[3]<=IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD & OutFifoBusD[67];
	endcase

// data element counter
if (RDRDY_LD) OutByteCntD<=3'd0;
	else if (IORRDY[3] & ~OutFifoEmptyD & ~|TxTmrD)
			case (TxSizeD)
				2'b00:	OutByteCntD<=OutByteCntD+1'b1;
				2'b01:	OutByteCntD<=OutByteCntD+2'd2;
				2'b10:	OutByteCntD<=OutByteCntD+3'd4;
				2'b11:	OutByteCntD<=3'd0;
				endcase
// data interval counter
if (RDRDY_LD) TxTmrD<=16'd0;
	else if (|TxTmrD) TxTmrD<=TxTmrD-1'b1;
			else if (IORRDY[3] & ~OutFifoEmptyD) TxTmrD<=TxTimerD;


end


endmodule: VDMA4chL



/*
=====================================================================================================================================================
																		ATU
=====================================================================================================================================================
*/
typedef struct packed	{
							reg WE, RE;						// [173:172]
							reg [1:0] DPL, Type;			// [171:168] 
							reg [23:0] ULSel, LLSel;		// [167:120] 
							reg [31:0] ULimit, LLimit;		// [119:056] 
							reg [15:0] TaskID;				// [055:040] 
							reg [39:0] Base;				// [039:000] 
							} Descriptor;

module ATU16chL  #(parameter TagWidth=8)	(
					// global control
					input wire RESETn, CLK,
					input wire [39:0] DTBASE,
					input wire [23:0] DTLIMIT,
					// access selectors
					input wire [23:0] SELECTORS [0:15],
					input wire [15:0] SELINVD,
					// ISI
					output wire INEXT,
					input wire IACT, ICMD, ICPLMASK, ITIDMASK,
					input wire [3:0] ISEL,
					input wire [1:0] ICPL,
					input wire [15:0] ITID,
					input wire [36:0] IOFFSET,
					input wire [1:0] ISZO,
					input wire [63:0] IDTO,
					input wire [TagWidth-1:0] ITGO,
					output reg IDRDY,
					output reg [63:0] IDTI,
					output reg [1:0] ISZI,
					output reg [TagWidth-1:0] ITGI,
					// interfaces to the bus subsystem
					input wire NEXT,
					output reg ACT, CMD,
					output reg [1:0] SZO,
					output reg [44:0] ADDRESS,
					output reg [63:0] DTO,
					output reg [TagWidth:0] TGO,
					input wire DRDY,
					input wire [63:0] DTI,
					input wire [1:0] SZI,
					input wire [TagWidth:0] TGI,
					// error report
					input wire EENA,
					output reg ESTB,
					output reg [4:0] ECD,
					output reg [TagWidth-1:0] ETAG
					);

logic InACT, OutNext, NewSelRequest, BadTypeRequest, LLRequest, ULRequest, InTDIMask, TIDReqest, CPLRequest, InNext, InCMD, InCPLMask;
logic [1:0] InCPL, InSize, ErrSize;
logic [3:0] InSelIndex, LocalUsed, NetworkUsed, StreamUsed;
logic [4:0] ReadCnt;
logic [15:0] InTaskID;
logic [23:0] NewSelValue;
logic [23:0] InSel;
logic [36:0] InOffset;
logic [63:0] InData;
logic [TagWidth-1:0] InTAG;

Descriptor InDescriptor;
(* ramstyle = "logic" *) Descriptor Descriptors [0:15];

enum reg [3:0] {Ws, Lds0, Lds1, Lds2, Lds3, Rds0, Rds1, Rds2, Lls, Uls, Errs0, Errs1, Errs2, Errs3, Errs4, Crs} sm=Ws;

integer i0, i1;


assign INEXT=InNext;



always_comb begin

OutNext=~ACT | (ACT & NEXT);
InNext=~InACT;

end



always_ff @(posedge CLK or negedge RESETn)
if (~RESETn)
	begin
	InACT<=1'b0;
	ACT<=1'b0;
	sm<=Ws;
	NewSelRequest<=1'b0;
	BadTypeRequest<=1'b0;
	LLRequest<=1'b0;
	ULRequest<=1'b0;
	TIDReqest<=1'b0;
	CPLRequest<=1'b0;
	ESTB<=1'b0;
	ReadCnt<=5'd0;
	IDRDY<=1'b0;
	InDescriptor<=174'd0;
	Descriptors[00]<=174'd0;
	Descriptors[01]<=174'd0;
	Descriptors[02]<=174'd0;
	Descriptors[03]<=174'd0;
	Descriptors[04]<=174'd0;
	Descriptors[05]<=174'd0;
	Descriptors[06]<=174'd0;
	Descriptors[07]<=174'd0;
	Descriptors[08]<=174'd0;
	Descriptors[09]<=174'd0;
	Descriptors[10]<=174'd0;
	Descriptors[11]<=174'd0;
	Descriptors[12]<=174'd0;
	Descriptors[13]<=174'd0;
	Descriptors[14]<=174'd0;
	Descriptors[15]<=174'd0;
	end
else begin

// input activation
InACT<=(InACT | IACT) & ~(OutNext & InACT & (InDescriptor.Type==2'd2) & ((InCPL<=InDescriptor.DPL) | InCPLMask) & ((InTaskID==InDescriptor.TaskID) | ~|InDescriptor.TaskID | InTDIMask) &
							(InOffset[36:5]>=InDescriptor.LLimit) & (InOffset[36:5]<InDescriptor.ULimit) & (~InCMD | InDescriptor.RE) & (InCMD | InDescriptor.WE)) &
					(sm!=Errs0) & (sm!=Errs1) & (sm!=Errs2) & (sm!=Errs3) & (sm!=Errs4);

// input stage registers
if (InNext)
	begin
	InCMD<=ICMD;
	InSelIndex<=ISEL;
	InSel[23:0]<=SELECTORS[ISEL][23:0];
	InOffset<=IOFFSET;
	InCPL<=ICPL;
	InTaskID<=ITID;
	InSize<=ISZO;
	InTAG<=ITGO;
	InTDIMask<=ITIDMASK;
	InCPLMask<=ICPLMASK;
	InData<=IDTO;
	end

if (InNext | (sm==Rds1)) InDescriptor<=Descriptors[(sm==Rds1) ? InSelIndex : ISEL];


// output transaction stage
ACT<=(ACT & ~NEXT) | (InACT & (InDescriptor.Type==2'd2) & ((InCPL<=InDescriptor.DPL) | InCPLMask) & ((InTaskID==InDescriptor.TaskID) | ~|InDescriptor.TaskID | InTDIMask) &
								(~InCMD | InDescriptor.RE) & (InCMD | InDescriptor.WE) & (InOffset[36:5]>=InDescriptor.LLimit) & (InOffset[36:5]<InDescriptor.ULimit)) |
					(sm==Lds1) | (sm==Lds2) | (sm==Lds3);
if (OutNext)
	begin
	CMD<=InCMD | (sm==Lds1) | (sm==Lds2) | (sm==Lds3);
	ADDRESS[4:0]<=((sm==Ws)|(sm==Rds2)) ? InOffset[4:0] : {(sm==Lds3),(sm==Lds2),3'd0};
	ADDRESS[44:5]<=((sm==Ws)|(sm==Rds2)) ? InDescriptor.Base+InOffset[36:5]-InDescriptor.LLimit : DTBASE+NewSelValue;
	SZO<=InSize | {(sm!=Ws)&(sm!=Rds2), (sm!=Ws)&(sm!=Rds2)};
	TGO<=((sm==Ws)|(sm==Rds2)) ? {1'b0,InTAG} : {1'b1,{TagWidth-2{1'b0}},(sm==Lds3),(sm==Lds2)};
	DTO<=InData;
	end

// request to load new descriptor
NewSelRequest<=InACT & ~InDescriptor.Type[1] & ~InDescriptor.Type[0];
// inaccessible object
BadTypeRequest<=InACT & ((~InCMD & ~InDescriptor.WE) | (InCMD & ~InDescriptor.RE)) & (InDescriptor.Type==2'd2);
// lower limit violation
LLRequest<=InACT & (InOffset[36:5]<InDescriptor.LLimit) & (InDescriptor.Type==2'd2);
// upper limit violation
ULRequest<=InACT & (InOffset[36:5]>=InDescriptor.ULimit) & (InDescriptor.Type==2'd2);
// TaskID violation
TIDReqest<=InACT & (InTaskID!=InDescriptor.TaskID) & |InDescriptor.TaskID & ~InTDIMask & (InDescriptor.Type==2'd2);
// CPL violation
CPLRequest<=InACT & (InCPL>InDescriptor.DPL) & ~InCPLMask & (InDescriptor.Type==2'd2);

// new selector
if (sm==Ws) NewSelValue<=InSel;
	else if (sm==Lls) NewSelValue<=InDescriptor.LLSel;
			else if (sm==Uls) NewSelValue<=InDescriptor.ULSel;

// descriptor load machine
case (sm)
	Ws:		if (NewSelRequest) sm<=Lds0;
				else if (BadTypeRequest | TIDReqest | CPLRequest) sm<=Errs1;
						else if (LLRequest) sm<=Lls;
								else if (ULRequest) sm<=Uls;
										else sm<=Ws;
	// load new descriptor
	// check selector
	Lds0:	if (~|NewSelValue | (NewSelValue>=DTLIMIT)) sm<=Errs0;
				else sm<=Lds1;
	// load base address and control word
	Lds1:	if (OutNext) sm<=Lds2;
				else sm<=Lds1;
	// load link selectors
	Lds2:	if (OutNext) sm<=Lds3;
				else sm<=Lds2;
	// load limits
	Lds3:	if (OutNext) sm<=Rds0;
				else sm<=Lds3;
	// waiting for descriptor
	Rds0:	if (DRDY & TGI[TagWidth] & (TGI[1:0]==2'd2)) sm<=Rds1;
				else sm<=Rds0;
	// Reload descriptor InDSC
	Rds1:	if (~Descriptors[InSelIndex][169]) sm<=Errs4;
				else sm<=Rds2;
	// waiting for renew transaction status
	Rds2:	sm<=Ws;
	
	// load lower selector
	Lls:	if (|InDescriptor.LLSel) sm<=Lds0;
				else sm<=Errs2;
				
	// load upper selector
	Uls:	if (|InDescriptor.ULSel) sm<=Lds0;
				else sm<=Errs3;
	
	// invalid selector
	Errs0:	if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// read\write eror
	Errs1:	if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// lower limit error
	Errs2: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// upper limit error
	Errs3: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// descriptor type error
	Errs4: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
				
	// invalid read request processng
	Crs:	if (|ReadCnt) sm<=Crs;
				else sm<=Rds2;
	endcase


// descriptor registers
for (i0=0; i0<16; i0=i0+1)
	if (SELINVD[i0]) Descriptors[i0]<=174'd0;
		else if ((i0[3:0]==InSelIndex) & DRDY & TGI[TagWidth] & (TGI[1:0]==2'd0)) Descriptors[i0]<={DTI[61:56], 24'd0, 24'd0, 32'd0, 32'd0, DTI[55:0]};
				else if ((i0[3:0]==InSelIndex) & DRDY & TGI[TagWidth] & (TGI[1:0]==2'd1)) Descriptors[i0]<={Descriptors[i0][173:168], DTI[55:32], DTI[23:00], 32'd0, 32'd0, Descriptors[i0][55:0]};
						else if ((i0[3:0]==InSelIndex) & DRDY & TGI[TagWidth] & (TGI[1:0]==2'd2)) Descriptors[i0]<={Descriptors[i0][173:120], DTI, Descriptors[i0][55:0]};


// error strobe
ESTB<=((sm==Errs0) | (sm==Errs1) | (sm==Errs2) | (sm==Errs3) | (sm==Errs4)) & EENA;
// error code register
if (sm==Errs0) ECD<=5'h0;																															// invalid selector
	else if (sm==Errs4) ECD<=5'h10;																												// descriptor type error
			else if ((sm==Errs1)|(sm==Errs2)|(sm==Errs3)) ECD<={1'b0, TIDReqest, CPLRequest, BadTypeRequest, LLRequest | ULRequest};	// read or write error or CPL violation or TaskID violation


// read transactions counter
if (((ACT & NEXT)  & CMD & ~TGO[TagWidth]) & ~(DRDY & ~TGI[TagWidth])) ReadCnt<=ReadCnt+1'b1;
	else if (~((ACT & NEXT) & CMD & ~TGO[TagWidth]) & DRDY & ~TGI[TagWidth]) ReadCnt<=ReadCnt-1'b1;

// error parameter registers
if (((sm==Errs0) | (sm==Errs1) | (sm==Errs2) | (sm==Errs3) | (sm==Errs4)))
	begin
	ETAG<=InTAG;
	ErrSize<=InSize;
	end


// read channel
IDRDY<=(DRDY & ~TGI[TagWidth]) | ((sm==Crs) & ~|ReadCnt);
if (~DRDY) {ITGI, ISZI, IDTI}<={ETAG, ErrSize, 59'd0, ECD};
	else {ITGI, ISZI, IDTI}<={TGI[TagWidth-1:0], SZI, DTI};

end

endmodule: ATU16chL
