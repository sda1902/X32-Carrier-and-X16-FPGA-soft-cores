module X16LSRAM #(TCKScale=20, SRAMMode=0, SPI=1'b1)(
	input wire EXTCLK, EXTRESET,
	output wire FATAL,
	// internal memory interface
	output wire CMD,
	output wire [44:0] ADDR,
	output wire [63:0] DATA,
	output wire [7:0] BE,
	output wire [20:0] TAG,

	// IO subsystem channel
	input wire IONEXT,
	output wire IOACT,
	input wire IODRDY,
	input wire [63:0] IODAT,
	input wire [20:0] IOTAG,

	// SPI Flash interface
	output wire SPICK,
	output wire SPIRST,
	output wire SPICS,
	output wire SPISO,
	input wire SPISI,
	
	// interrupt interface
	output wire INTACK,
	input wire INTREQ,
	input wire [15:0] INTCODE,
	
	// portal interface
	output wire PortalACT,
	output wire [3:0] PortalCMD,
	output wire [127:0] PortalParA, PortalParB, PortalParC,
	input wire PortalRDY, PortalNAN, PortalINF, PortalZERO, PortalSIGN,
	input wire [3:0] PortalDST,
	input wire [127:0] PortalR
	);

integer i;

reg RST;

// TE counter
reg [7:0] TECntReg;
reg TickFlag, IntFlag, IntReqFlag, DIntReqFlag;

// common buses
logic [39:0] DTBASEBus;
logic [23:0] DTLIMITBus, CPSRBus;
logic [31:0] CSRBus;
logic [39:0] FREEMEMBus, CACHEDMEMBus;

logic CoreFlashNEXT, CoreFlashDRDY;
logic [63:0] CoreFlashDTO;
logic [20:0] CoreFlashTAGO;

logic EfifoVALID;
reg DEfifoVALID;
logic [63:0] EfifoECD;

logic TmuxFLACT, TmuxSDACT;
logic [2:0] TmuxLNEXT, TmuxLDRDY;
logic [63:0] TmuxLDATI;
logic [12:0] TmuxLTAGI;
logic [2:0] TmuxLSIZEI;
logic [23:0] TmuxINTSEL;
logic [15:0] TmuxINTLIMIT;
logic [3:0] TmuxNENA;
logic TmuxINTRST, TmuxINTENA, TmuxESRRD, TmuxCENA, TMuxMALOCKF, TmuxPTINTR;
logic [2:0] TmuxCPSRSTB;
logic [3:0] TmuxCSRSTB;
logic [1:0] TmuxLSIZEO [2:0];
logic [44:0] TmuxLADDR [2:0];
logic [63:0] TmuxLDATO [2:0];
logic [12:0] TmuxLTAGO [2:0];

logic SDCacheINEXT, SDCacheIDRDY;
logic [63:0] SDCacheIDATo;
logic [20:0] SDCacheITAGo;

logic CoreCLOAD, CoreACT, CoreCMD, CoreDRDY, CoreMSGREQ, CoreMALLOCREQ, CorePARREQ, CoreStreamNEXT, CoreStreamACT, CoreNetACT;
logic CoreEMPTY, CoreENDMSG, CoreBKPT, CoreESTB, CoreHALT, CoreNPCS, CoreSMSGBKPT;
logic [1:0] CoreOS;
logic [2:0] CoreSZi;
logic [44:0] CoreADDRESS;
logic [41:0] CoreFFTMemADDR;
logic [36:0] CoreOFFSET, CoreRIP;
logic [31:0] CoreSELECTOR;
logic [63:0] CoreDTo, CoreDTi, CorePARAM, CoreCDATA;
logic [7:0] CoreTAGo, CoreTAGi;
logic [3:0] CorePARREG;
logic [28:0] CoreECD;
logic [3:0] CoreIV;
logic [23:0] CoreCSEL;
reg CEXECFlag, CEXECReg, CSTOPFlag, HFCoreHaltReg, ESMSGFlag, ESMSGReg, CONTINUEReg, CONTINUEFlag;

logic StreamDFifoEMPTY, StreamDFifoRSTB;
logic [74:0] StreamDFifoDO;

logic NetDFifoEMPTY, NetDFifoRSTB;
logic [74:0] NetDFifoDO;

logic FpuSNEXT;

logic [32:0] RteEXTDO [3:0];
logic [3:0] RteEXTSTBI, RteEXTSTBO;
logic [32:0] RteEXTDI [3:0];

logic StreamCoreNEXT, StreamCoreACT, StreamCoreCMD, StreamCoreDRDY, StreamACT, StreamCMD, StreamINIT, StreamCoreADDR;
logic [23:0] StreamCoreSEL;
logic [63:0] StreamCoreDTI, StreamCoreDTO, StreamNetDATA, StreamDTO;
logic [7:0] StreamCoreTAGI, StreamCoreTAGO;
logic [2:0] StreamCoreSIZEO;
logic [1:0] StreamSIZEO;
logic [44:0] StreamADDR;
logic [4:0] StreamTAGO;

logic [1:0] ContACT, ContCMD;
logic [2:0] ContEUSZi;
logic [44:0] ContADDR [1:0];
logic [1:0] ContSIZE [1:0];
logic [7:0] ContTAGo [1:0];
logic [63:0] ContDTo [1:0];
logic [63:0] ContEUDTi;
logic [7:0] ContEUTAGi;
logic ContEUNEXT, ContEUDRDY, ContEURESTART, ContEURD, ContNETMSGREQ, ContMSGACK, ContRST, ContREADY, ContESTB;
logic ContEUCLOAD, ContCORESTOP, ContCONTINUE, ContLIRESET;
logic [5:0] ContRA;
logic [31:0] ContNETMSGPAR, ContERC;
logic MsgrEUCONTINUE;

//=====================================================================================================================
//				Flash controller (internal buffer and external SPI)
generate
if (SPI==1'b1)
	Flash16  CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO),
				// interface to the external memory
				.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));
	else Flash16noSPI  CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO));
endgenerate

//=====================================================================================================================
//				ERROR FIFO system
extern module ErrorFIFOL (
	input wire CLK, RESET,
	input wire [23:0] CPSR,
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire CoreSTB,
	input wire [28:0] CoreECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);

ErrorFIFOL Efifo(.CLK(EXTCLK), .RESET(RST), .CPSR(CPSRBus),
				// read fifo interface
				.ERD(TmuxESRRD & EfifoVALID), .VALID(EfifoVALID), .ECD(EfifoECD),
				// error interface from core
				.CoreSTB(CoreESTB), .CoreECD(CoreECD),
				// error report from context controller
				.ContSTB(ContESTB), .ContECD(ContERC)
				);

//=====================================================================================================================
// 				BUS MULTIPLEXER
// 0 - core /througth context controller
// 1 - stream
// 2 - context controller channel (MCU)
extern module MUX64X16L (
	input CLK, RESETn,

	output wire [2:0]	LNEXT,
	input wire [2:0]	LACT,
	input wire [2:0]	LCMD,
	input wire [1:0] LSIZEO [2:0],
	input wire [44:0] LADDR [2:0],
	input wire [63:0] LDATO [2:0],
	input wire [12:0] LTAGO [2:0],
	output reg [2:0] LDRDY,
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
	output reg INTRST, INTENA, ESRRD, CENA, MALOCKF, PTINTR,
	input wire [31:0] CSR,
	input wire [23:0] CPSR,
	input wire [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] ESR,
	output wire [2:0] CPSRSTB,
	output wire [3:0] CSRSTB,
	input wire SINIT,
	input wire NINIT,
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
MUX64X16L Tmux(.CLK(EXTCLK), .RESETn(RST), 
			// services interface
			.LNEXT(TmuxLNEXT),
			.LACT({ContACT[1], StreamACT, ContACT[0]}),
			.LCMD({ContCMD[1], StreamCMD, ContCMD[0]}),
			.LSIZEO(TmuxLSIZEO), .LADDR(TmuxLADDR), .LDATO(TmuxLDATO), .LTAGO(TmuxLTAGO),
			.LDRDY(TmuxLDRDY), .LDATI(TmuxLDATI), .LTAGI(TmuxLTAGI), .LSIZEI(TmuxLSIZEI),
			// local memory interface
			.CMD(CMD), .ADDR(ADDR), .DATA(DATA), .BE(BE), .TAG(TAG),
			.FLNEXT(CoreFlashNEXT), .FLACT(TmuxFLACT), .FLDRDY(CoreFlashDRDY), .FLDAT(CoreFlashDTO), .FLTAG(CoreFlashTAGO),
			.SDNEXT(SDCacheINEXT), .SDACT(TmuxSDACT), .SDDRDY(SDCacheIDRDY), .SDDAT(SDCacheIDATo), .SDTAG(SDCacheITAGo),
			.IONEXT(IONEXT), .IOACT(IOACT), .IODRDY(IODRDY), .IODAT(IODAT), .IOTAG(IOTAG),
			// status and control lines and buses
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .INTSEL(TmuxINTSEL), .INTLIMIT(TmuxINTLIMIT), .INTRST(TmuxINTRST),
			.INTENA(TmuxINTENA), .ESRRD(TmuxESRRD), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR),
			.CSR(CSRBus), .CPSR(CPSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .ESR({EfifoECD[63:56] & {8{EfifoVALID}},EfifoECD[55:0]}),
			.CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB), .SINIT(StreamINIT), .NINIT(1'b1), .CINIT(ContREADY), .TCK(TickFlag), .TCKOVR(CoreNPCS), .HALT(CoreHALT),
			.IV(CoreIV), .CSEL(CoreCSEL), .EMPTY(CoreEMPTY), .TCKScaler(TCKScale), .CoreType(8'd10));
//=====================================================================================================================
//				SRAM unit

generate

case (SRAMMode[1:0])
	2'd0: InternalMemory256K #(.TagWidth(21))SSRAM(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[17:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd1: InternalMemory512K #(.TagWidth(21))SSRAM(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[18:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd2: InternalMemory1M #(.TagWidth(21))SSRAM(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[19:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd3: InternalMemory2M #(.TagWidth(21))SSRAM(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[20:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	endcase

endgenerate

assign SDCacheINEXT=1'b1;
			
//=====================================================================================================================
// 				CORE UNIT
extern module EU64X16L (
	input wire CLK, RESET, CLOAD,
	input wire [15:0] TASKID,
	input wire [23:0] CPSR,
	// interface to datapatch of memory subsystem
	input wire NEXT, StreamNEXT,
	output reg ACT, StreamACT, CMD, 
	output reg [1:0] OS,
	output reg [44:0] ADDRESS,
	output reg [36:0] OFFSET,
	output reg [31:0] SELECTOR,
	output reg [63:0] DTo,
	output reg [7:0] TAGo,
	input wire DRDY,
	input wire [7:0] TAGi,
	input wire [2:0] SZi,
	input wire [63:0] DTi,
	// interface to the descriptor pre-loading system
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [1:0] CPL,
	// interface to message control subsystem
	output wire [63:0] PARAM,
	output wire [3:0] PARREG,
	output wire MSGREQ, MALLOCREQ, PARREQ, ENDMSG, BKPT,
	output reg EMPTY,
	output wire HALT,
	output wire NPCS,
	output wire SMSGBKPT,
	input wire CEXEC, ESMSG, CONTINUE,
	input wire CSTOP, LIRESET,
	// context store interface
	input wire [5:0] RA,
	output reg [63:0] CDATA,
	output wire [36:0] RIP,
	// error reporting interface
	output wire ESTB,
	output wire [28:0] ECD,
	// test purpose pins
	output wire FATAL,
	// Performance monitor outputs
	output reg [3:0] IV,
	output wire [23:0] CSEL,
	// portal interface 
	// PortalNAN, PortalINF, PortalZERO, PortalSIGN and PortalR must be placed on a next clock cycle after PortalRDY & PortalDST
	output reg PortalACT, 
	output reg [3:0] PortalCMD,
	output reg [127:0] PortalParA, PortalParB, PortalParC,
	input wire PortalRDY, PortalNAN, PortalINF, PortalZERO, PortalSIGN,
	input wire [3:0] PortalDST,
	input wire [127:0] PortalR
	);
EU64X16L Core(.CLK(EXTCLK), .RESET(RST), .CLOAD(ContEUCLOAD), .TASKID(CSRBus[15:0]), .CPSR(CPSRBus), 
			// memory interface
			.NEXT(ContEUNEXT), .StreamNEXT(CoreStreamNEXT), .ACT(CoreACT), .StreamACT(CoreStreamACT), .CMD(CoreCMD), .OS(CoreOS), .ADDRESS(CoreADDRESS),
			.OFFSET(CoreOFFSET), .SELECTOR(CoreSELECTOR), .DTo(CoreDTo), .TAGo(CoreTAGo), .DRDY(CoreDRDY), .TAGi(CoreTAGi), .SZi(CoreSZi), .DTi(CoreDTi),
			// interface to the descriptor pre-loading system
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPL(CSRBus[19:18]),
			// message system interface
			.PARAM(CorePARAM), .PARREG(CorePARREG), .MSGREQ(CoreMSGREQ), .MALLOCREQ(CoreMALLOCREQ), .PARREQ(CorePARREQ),
			.ENDMSG(CoreENDMSG), .BKPT(CoreBKPT), .EMPTY(CoreEMPTY), .HALT(CoreHALT), .NPCS(CoreNPCS), .SMSGBKPT(CoreSMSGBKPT), .CEXEC(ContEURESTART),
			.ESMSG(MsgrEUCONTINUE), .CONTINUE(ContCONTINUE), .CSTOP(ContCORESTOP | IntFlag), .LIRESET(ContLIRESET),
			// context store interface
			.RA(ContRA), .CDATA(CoreCDATA), .RIP(CoreRIP),
			// error reporting
			.ESTB(CoreESTB), .ECD(CoreECD),
			// fatal error
			.FATAL(FATAL),
			// Performance monitor outputs
			.IV(CoreIV),
			.CSEL(CoreCSEL),
			// portal interface 
			.PortalACT(PortalACT), .PortalCMD(PortalCMD), .PortalParA(PortalParA), .PortalParB(PortalParB), .PortalParC(PortalParC),
			.PortalRDY(PortalRDY), .PortalNAN(PortalNAN), .PortalINF(PortalINF), .PortalZERO(PortalZERO), .PortalSIGN(PortalSIGN),
			.PortalDST(PortalDST), .PortalR(PortalR)
			);

// datapatch mux
DMuxL CoreMux(.CLK(EXTCLK), .RESET(RST),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContEUDRDY), .LocalDATA({ContEUSZi, ContEUTAGi, ContEUDTi}), .LocalRD(ContEURD),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(~StreamDFifoEMPTY), .StreamDATA(StreamDFifoDO), .StreamRD(StreamDFifoRSTB),
		// output to the EU resources
		.DRDY(CoreDRDY), .TAG({CoreSZi, CoreTAGi}), .DATA(CoreDTi));
defparam CoreMux.TagWidth=11;

// data fifo for stream datapatch
sc_fifo	StreamDFifo(.data({StreamCoreSIZEO, StreamCoreTAGO, StreamCoreDTO}), .wrreq(StreamCoreDRDY), .rdreq(StreamDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(StreamDFifoDO), .empty(StreamDFifoEMPTY));
defparam StreamDFifo.LPM_WIDTH=75, StreamDFifo.LPM_NUMWORDS=16, StreamDFifo.LPM_WIDTHU=4;

//=====================================================================================================================
//				STREAM CONTROLLER
extern module StreamControllerX16 (
	input wire CLK, RESET, TE,
	input wire [39:0] DTBASE,
	output wire INIT,
// Core interface
	output wire CoreNEXT,
	input wire CoreACT, CoreCMD, CoreADDR,
	input wire [23:0] CoreSEL,
	input wire [63:0] CoreDTI,
	input wire [7:0] CoreTAGI,
	output reg CoreDRDY,
	output reg [63:0] CoreDTO,
	output reg [7:0] CoreTAGO,
	output reg [2:0] CoreSIZEO,
// network interface
	output wire NetNEXT,
	input wire NetACT,
	input wire [23:0] NetSEL,
	input wire [63:0] NetDATA,
// memory interface
	input wire NEXT,
	output reg ACT, CMD,
	output reg [1:0] SIZEO,
	output reg [44:0] ADDR,
	output reg [63:0] DTO,
	output reg [4:0] TAGO,
	input wire DRDY,
	input wire [63:0] DTI,
	input wire [4:0] TAGI
);
StreamControllerX16 Stream(.CLK(EXTCLK), .RESET(RST), .TE(TickFlag), .DTBASE(DTBASEBus), .INIT(StreamINIT),
						// Core interface
						.CoreNEXT(StreamCoreNEXT), .CoreACT(StreamCoreACT), .CoreCMD(StreamCoreCMD), .CoreADDR(StreamCoreADDR), .CoreSEL(StreamCoreSEL), .CoreDTI(StreamCoreDTI), .CoreTAGI(StreamCoreTAGI),
						.CoreDRDY(StreamCoreDRDY), .CoreDTO(StreamCoreDTO), .CoreTAGO(StreamCoreTAGO), .CoreSIZEO(StreamCoreSIZEO),
						// network interface
						.NetNEXT(), .NetACT(1'b0), .NetSEL(24'd0), .NetDATA(64'd0),
						// local memory interface
						.NEXT(TmuxLNEXT[1]), .ACT(StreamACT), .CMD(StreamCMD), .SIZEO(StreamSIZEO), .ADDR(StreamADDR), .DTO(StreamDTO), .TAGO(StreamTAGO),
						.DRDY(TmuxLDRDY[1]), .DTI(TmuxLDATI), .TAGI(TmuxLTAGI[4:0]));

TFifoS	StreamTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreStreamACT), .NEXTH(StreamCoreNEXT), .NEXTL(CoreStreamNEXT), .ACTH(StreamCoreACT),
					.DI({CoreOFFSET[0], CoreCMD, CoreTAGo, CoreSELECTOR[23:0], CoreDTo}),
					.DO({StreamCoreADDR, StreamCoreCMD, StreamCoreTAGI, StreamCoreSEL, StreamCoreDTI}));
defparam StreamTFifo.Width=98;

//=====================================================================================================================
//				CONTEXT CONTROLLER
extern module ContextCTRL16L ( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF, PTINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	output reg  RST, READY,						// hardware reset and ready signal
	output reg [23:0] CPSR,						// current process selector register
	output reg [31:0] CSR,						// current core state register
	output reg [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] EXTDI,
	input wire [2:0] CPSRSTB,
	input wire [3:0] CSRSTB,
	input wire [36:0] RIP,						// real ip
	// 2-channel interface to memory system
	input wire [1:0] NEXT,
	output logic [1:0] ACT,CMD,
	output logic [44:0] ADDR[1:0],
	output logic [1:0] SIZE[1:0],
	output logic [7:0] TAGo[1:0],
	output logic [63:0] DTo[1:0],
	input wire [1:0] DRDY,
	input wire [63:0] DTi,
	input wire [7:0] TAGi,
	input wire [2:0] SZi,
	// low-speed memory interface from EU
	output wire EUNEXT,
	input wire EUACT, EUCMD,
	input wire [1:0] EUSZo,
	input wire [44:0] EUADDR,
	input wire [63:0] EUDTo,
	input wire [7:0] EUTAGo,
	output wire EUDRDY,
	output wire [7:0] EUTAGi,
	output wire [2:0] EUSZi,
	output wire [63:0] EUDTi,
	input wire EURD,
	// control interface to EU
	input wire MALLOCREQ,
	input wire GETPARREQ,
	input wire BKPT,
	input wire MSGREQ,
	input wire [63:0] EUPARAM,
	input wire [3:0] EUREG,
	input wire EUEMPTY,
	input wire EUENDMSG,
	input wire SMSGBKPT,
	output reg CORESTART,
	output reg CORESTOP,
	output reg CORECONT,
	output wire EUCLOAD,
	output reg LIRESET,
	output reg ESMSG,
	// interrupts and errors
	input wire ERRORREQ,
	input wire INTREQ,
	input wire [15:0] INTCODE,
	output reg INTACK,
	input logic [23:0] INTSR,			// selector IT
	input logic [15:0] INTCR,			// Length of IT
	// context load/store interface to EU
	output wire [5:0] RA,
	input wire [63:0] CDAT,
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC
	);
ContextCTRL16L Cont(.CLK(EXTCLK), .RESETn(RST), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR),
				.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .RST(ContRST), .READY(ContREADY),
				.CPSR(CPSRBus), .CSR(CSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .EXTDI(DATA), .CPSRSTB(TmuxCPSRSTB),
				.CSRSTB(TmuxCSRSTB), .RIP(CoreRIP),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT[2], TmuxLNEXT[0]}), .ACT(ContACT), .CMD(ContCMD), .ADDR(ContADDR), .SIZE(ContSIZE), .TAGo(ContTAGo), .DTo(ContDTo),
				.DRDY({TmuxLDRDY[2], TmuxLDRDY[0]}), .DTi(TmuxLDATI), .TAGi(TmuxLTAGI[7:0]), .SZi(TmuxLSIZEI),
				// low-speed memory interface from EU
				.EUNEXT(ContEUNEXT), .EUACT(CoreACT), .EUCMD(CoreCMD), .EUSZo(CoreOS), .EUADDR(CoreADDRESS), .EUDTo(CoreDTo), .EUTAGo(CoreTAGo),
				.EUDRDY(ContEUDRDY), .EUTAGi(ContEUTAGi), .EUSZi(ContEUSZi), .EUDTi(ContEUDTi), .EURD(ContEURD),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ), .GETPARREQ(CorePARREQ), .BKPT(CoreBKPT), .MSGREQ(CoreMSGREQ), .EUPARAM(CorePARAM), .EUREG(CorePARREG), .EUEMPTY(CoreEMPTY),
				.EUENDMSG(CoreENDMSG), .SMSGBKPT(CoreSMSGBKPT), .CORESTART(ContEURESTART), .CORESTOP(ContCORESTOP), .CORECONT(ContCONTINUE), .EUCLOAD(ContEUCLOAD),
				.LIRESET(ContLIRESET), .ESMSG(MsgrEUCONTINUE),
				// interrupts and errors
				.ERRORREQ(EfifoVALID & ~DEfifoVALID), .INTREQ(IntReqFlag), .INTCODE(INTCODE), .INTACK(INTACK), .INTSR(TmuxINTSEL), .INTCR(TmuxINTLIMIT),
				// context load/store interface to EU
				.RA(ContRA), .CDAT(CoreCDATA),
				// error reporting interface
				.ESTB(ContESTB), .ERC(ContERC)
				);

//=================================================================================================
//		assignments
//=================================================================================================

assign TmuxLSIZEO[2]=ContSIZE[1];
assign TmuxLSIZEO[1]=StreamSIZEO;
assign TmuxLSIZEO[0]=ContSIZE[0];

assign TmuxLADDR[2]=ContADDR[1];
assign TmuxLADDR[1]=StreamADDR;
assign TmuxLADDR[0]=ContADDR[0];

assign TmuxLDATO[2]=ContDTo[1];
assign TmuxLDATO[1]=StreamDTO;
assign TmuxLDATO[0]=ContDTo[0];

assign TmuxLTAGO[2]={5'd0, ContTAGo[1]};
assign TmuxLTAGO[1]={7'd0, StreamTAGO};
assign TmuxLTAGO[0]={5'd0, ContTAGo[0]};

//=================================================================================================
//		synchronous 
//=================================================================================================
always_ff @(posedge EXTCLK)
begin

// reset filtering
RST<=EXTRESET & ContRST;

// timing intervals for stream controller
TECntReg<=(TECntReg+8'd1) & {8{RST & ~TickFlag}};
TickFlag<=(TECntReg==(TCKScale-2)) & RST;

// delayed EFIFO flag
DEfifoVALID<=EfifoVALID & RST;

// interrupt flag
IntFlag<=(IntFlag | INTREQ) & ~INTACK & RST & TmuxINTENA;
IntReqFlag<=IntFlag & CoreEMPTY & ~CoreSMSGBKPT  & RST & ~DIntReqFlag;
DIntReqFlag<=(DIntReqFlag | IntReqFlag) & RST & IntFlag;

end

endmodule
