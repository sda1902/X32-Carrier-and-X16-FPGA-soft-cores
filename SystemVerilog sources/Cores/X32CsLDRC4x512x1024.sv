module X32CsLDRC4x512x1024 #(SPI=1'b1)(
	input wire EXTCLK, CLK50, EXTRESET,
	output wire FATAL, TCK,
	// internal memory interface
	output wire CMD,
	output wire [44:0] ADDR,
	output wire [63:0] DATA,
	output wire [7:0] BE,
	output wire [20:0] TAG,

	// SDRAM controller channel
	input wire avl_ready,
	output wire avl_burstbegin,
	output wire [38:0] avl_addr,
	input wire avl_rdata_valid,
	input wire [511:0] avl_rdata,
	output wire [511:0] avl_wdata,
	output wire [63:0] avl_be,
	output wire avl_read_req,
	output wire avl_write_req,
	output wire [2:0] avl_size,

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
	
	// PORTAL instruction interface
	input wire PortalReady,
	output wire PortalActivation,
	output wire [31:0] PortalInstruction,
	output wire [127:0] PortalOpA, PortalOpB, PortalOpC,
	input wire PortalGPRStrobe,
	input wire [4:0] PortalGPRIndex,
	input wire [2:0] PortalGPRSize,
	input wire [6:0] PortalGPRFlags,
	input wire [127:0] PortalGPRData,
	// PORTAL context interface
	output reg PortalRST,
	output wire PortalSTOP,
	output wire PortalRUN,
	input wire PortalEMPTY,
	output wire PortalContextSTB,
	output wire [7:0] PortalContextAddress,
	output wire [63:0] PortalContextDI,
	input wire [63:0] PortalContextDO,
	// PORTAL message interface
	input wire PortalSMSG,
	input wire [63:0] PortalMSG,
	output wire PortalSMSGNext,
	// PORTAL memory DMA interface
	output wire PortalNEXT, PortalERROR,
	output wire [7:0] PortalERRORTag,
	input wire PortalACT, PortalCMD,
	input wire [31:0] PortalSelector,
	input wire [36:0] PortalOffset,
	input wire [63:0] PortalDO,
	input wire [7:0] PortalTO,
	input wire [1:0] PortalSO,
	output wire PortalDRDY,
	output wire [63:0] PortalDI,
	output wire [7:0] PortalTI,
	output wire [1:0] PortalSI,
	
	// interrupt interface
	output wire INTACK,
	input wire INTREQ,
	input wire [15:0] INTCODE,
	
	// Dynamic reconfiguration interface
	input wire DRCLK, 
	output reg DRStart,
	input wire DRFreeze, 
	input wire [2:0] DRStatus, 
	input wire DRReady,
	output wire DRValid, 
	output wire [31:0] DRData
	);

integer i;

reg RST;

// TE counter
logic [1:0] TFlag;
logic [3:0] tcnt;
reg [7:0] TECntReg, TCKcnt, TCKScale;
reg TickFlag, IntFlag, IntReqFlag, DIntReqFlag;

// common buses
logic [39:0] DTBASEBus;
logic [23:0] DTLIMITBus, CPSRBus;
logic [26:0] CSRBus;
logic [39:0] FREEMEMBus, CACHEDMEMBus;

logic CoreFlashNEXT, CoreFlashDRDY;
logic [63:0] CoreFlashDTO;
logic [20:0] CoreFlashTAGO;

logic EfifoVALID;
reg DEfifoVALID;
logic [63:0] EfifoECD;

logic PortalMCLACT, PortalMCSACT, PortalMCCMD, PortalMCESTB, PortalDIS;
logic [1:0] PortalMCOS;
logic [44:0] PortalMCADDRESS;
logic [31:0] PortalMCSELECTOR;
logic [36:0] PortalMCOFFSET;
logic [63:0] PortalMCDO;
logic [8:0] PortalMCTO;
logic [63:0] PortalMCECD;
logic PortalCFGSTB, PortalCFGRST;
logic [5:0] PortalCFGAddr;
logic [31:0] PortalCFG;
reg [31:0] PortalState;
reg [7:0] PortalMsgCntr, PortalMsgCntrBase;
reg [15:0] PortalMsgTimer, PortalMsgTimerBase, PortalCFGReg38;
reg PortalMsgEnable, PortalErrorLockFlag, ERFlag, SoEFlag;
reg [1:0] PortalCPL;
reg [23:0] PortalPSO;
reg [15:0] PortalTaskID;

logic TmuxFLACT, TmuxSDACT;
logic [3:0] TmuxLNEXT, TmuxLDRDY;
logic [63:0] TmuxLDATI;
logic [12:0] TmuxLTAGI;
logic [2:0] TmuxLSIZEI;
logic [23:0] TmuxINTSEL;
logic [15:0] TmuxINTLIMIT;
logic TmuxINTRST, TmuxINTENA, TmuxESRRD, TmuxCENA, TMuxMALOCKF, TmuxPTINTR, DTRESET;
logic [2:0] TmuxCPSRSTB;
logic [3:0] TmuxCSRSTB;
logic [1:0] TmuxLSIZEO [3:0];
logic [44:0] TmuxLADDR [3:0];
logic [63:0] TmuxLDATO [3:0];
logic [12:0] TmuxLTAGO [3:0];

logic SDCacheINEXT, SDCacheIDRDY;
logic [63:0] SDCacheIDATo;
logic [20:0] SDCacheITAGo;

logic CoreCLOAD, CoreACT, CoreCMD, CoreDRDY, CoreMSGREQ, CoreMALLOCREQ, CorePARREQ, CoreStreamNEXT, CoreStreamACT;
logic CoreEMPTY, CoreENDMSG, CoreBKPT, CoreESTB, CoreHALT, CoreNPCS, CoreSMSGBKPT;
logic [1:0] CoreOS;
logic [2:0] CoreSZi;
logic [44:0] CoreADDRESS;
logic [36:0] CoreOFFSET, CoreRIP;
logic [31:0] CoreSELECTOR;
logic [63:0] CoreDTo, CoreDTi, CorePARAM, CoreCDATA;
logic [8:0] CoreTAGo, CoreTAGi;
logic [4:0] CorePARREG;
logic [28:0] CoreECD;
logic [3:0] CoreIV;
logic [23:0] CoreCSEL;
reg CEXECFlag, CEXECReg, CSTOPFlag, HFCoreHaltReg, ESMSGFlag, ESMSGReg, CONTINUEReg, CONTINUEFlag;

logic StreamDFifoEMPTY, StreamDFifoRSTB;
logic [75:0] StreamDFifoDO;

logic StreamCoreNEXT, StreamCoreACT, StreamCoreCMD, StreamCoreDRDY, StreamNetNEXT, StreamACT, StreamCMD, StreamINIT, StreamCoreADDR;
logic [23:0] StreamCoreSEL;
logic [63:0] StreamCoreDTI, StreamCoreDTO, StreamNetDATA, StreamDTO;
logic [9:0] StreamCoreTAGI, StreamCoreTAGO;
logic [2:0] StreamCoreSIZEO;
logic [1:0] StreamSIZEO;
logic [44:0] StreamADDR;
logic [4:0] StreamTAGO;

logic [1:0] ContACT, ContCMD;
logic [2:0] ContEUSZi;
logic [44:0] ContADDR [1:0];
logic [1:0] ContSIZE [1:0];
logic [9:0] ContTAGo [1:0];
logic [63:0] ContDTo [1:0];
logic [63:0] ContEUDTi;
logic [8:0] ContEUTAGi;
logic ContEUNEXT, ContEUDRDY, ContEURESTART, ContEURD, ContNETMSGREQ, ContMSGACK, ContRST, ContREADY, ContESTB;
logic ContEUCLOAD, ContCORESTOP, ContCONTINUE;
logic [6:0] ContRA;
logic [31:0] ContNETMSGPAR, ContERC;

logic [38:0] avl_addr_cache;

logic MsgrEUCONTINUE;

logic [3:0] DRwrused, DRrdused;
logic [9:0] CfgInitCnt='0;
logic CfgFreeze='0, DRFifoReset='0, CfgReset, CfgSTB, CfgRequest;
logic [2:0] CfgStatus='0, CfgFinishReg='0;
logic [31:0] CfgData;

//=====================================================================================================================
//				Flash controller (internal buffer and external SPI)
generate
if (SPI==1'b1)
	Flash32 CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
					.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO),
					// interface to the external memory
					.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));
	else begin
	Flash32noSPI  CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO));
	assign {SPICK, SPIRST, SPICS, SPISO}='Z;
	end
endgenerate

//=====================================================================================================================
//				ERROR FIFO system
extern module ErrorFIFOCsL (
	input wire CLK, RESET,
	input wire [23:0] CPSR,
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire CoreSTB,
	input wire [28:0] CoreECD,
	// error interface from portal
	input wire PortalSTB,
	input wire [63:0] PortalECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);
ErrorFIFOCsL Efifo(.CLK(EXTCLK), .RESET(RST), .CPSR(CPSRBus),
				// read fifo interface
				.ERD(TmuxESRRD & EfifoVALID), .VALID(EfifoVALID), .ECD(EfifoECD),
				// error interface from core
				.CoreSTB(CoreESTB), .CoreECD(CoreECD),
				// error interface from portal
				.PortalSTB(PortalMCESTB & ERFlag), .PortalECD(PortalMCECD),
				// error report from context controller
				.ContSTB(ContESTB), .ContECD(ContERC)
				);

//=====================================================================================================================
// 				BUS MULTIPLEXER
// 0 - core /througth context controller
// 1 - portal
// 2 - stream
// 3 - context controller channel (MCU)
extern module MUX64X32CsL (
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
MUX64X32CsL Tmux(.CLK(EXTCLK), .RESETn(RST), 
			// services interface
			.LNEXT(TmuxLNEXT),
			.LACT({ContACT[1], StreamACT, PortalMCLACT, ContACT[0]}),
			.LCMD({ContCMD[1], StreamCMD, PortalMCCMD, ContCMD[0]}),
			.LSIZEO(TmuxLSIZEO), .LADDR(TmuxLADDR), .LDATO(TmuxLDATO), .LTAGO(TmuxLTAGO),
			.LDRDY(TmuxLDRDY), .LDATI(TmuxLDATI), .LTAGI(TmuxLTAGI), .LSIZEI(TmuxLSIZEI),
			// local memory interface
			.CMD(CMD), .ADDR(ADDR), .DATA(DATA), .BE(BE), .TAG(TAG),
			.FLNEXT(CoreFlashNEXT), .FLACT(TmuxFLACT), .FLDRDY(CoreFlashDRDY), .FLDAT(CoreFlashDTO), .FLTAG(CoreFlashTAGO),
			.SDNEXT(SDCacheINEXT), .SDACT(TmuxSDACT), .SDDRDY(SDCacheIDRDY), .SDDAT(SDCacheIDATo), .SDTAG(SDCacheITAGo),
			.IONEXT(IONEXT), .IOACT(IOACT), .IODRDY(IODRDY), .IODAT(IODAT), .IOTAG(IOTAG),
			// status and control lines and buses
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .INTSEL(TmuxINTSEL), .INTLIMIT(TmuxINTLIMIT), .INTRST(TmuxINTRST),
			.INTENA(TmuxINTENA), .ESRRD(TmuxESRRD), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR), .DTRESET(DTRESET),
			.CSR(CSRBus), .CPSR(CPSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .ESR({EfifoECD[63:56] & {8{EfifoVALID}},EfifoECD[55:0]}),
			.CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB), .SINIT(StreamINIT), .CINIT(ContREADY), .TCK(TickFlag), .TCKOVR(CoreNPCS), .HALT(CoreHALT),
			.IV(CoreIV), .CSEL(CoreCSEL), .EMPTY(CoreEMPTY), .TCKScaler(TCKScale), .CoreType(8'd12));
//=====================================================================================================================
//				SDRAM Cache unit
extern module Cache4x512x1024DDR3 #(parameter TagWidth=21)(
			input wire RESET, CLK,
			// internal interface
			output wire INEXT,
			input wire IACT, ICMD,
			input wire [41:0] IADDR,
			input wire [63:0] IDATi,
			input wire [7:0] IBE,
			input wire [TagWidth-1:0] ITAGi,
			output reg IDRDY,
			output reg [63:0] IDATo,
			output reg [TagWidth-1:0] ITAGo,
			// interface to the DDR3 memory controller
			input wire avl_ready,
			output reg avl_burstbegin,
			output reg [38:0] avl_addr,
			input wire avl_rdata_valid,
			input wire [511:0] avl_rdata,
			output reg [511:0] avl_wdata,
			output reg [63:0] avl_be,
			output reg avl_read_req,
			output reg avl_write_req,
			output reg [2:0] avl_size
			);
Cache4x512x1024DDR3 #(.TagWidth(21)) SDCache(.RESET(RST), .CLK(EXTCLK),
				// internal ISI
				.INEXT(SDCacheINEXT), .IACT(TmuxSDACT), .ICMD(CMD), .IADDR(ADDR[44:3]), .IDATi(DATA), .IBE(BE), .ITAGi(TAG),
				.IDRDY(SDCacheIDRDY), .IDATo(SDCacheIDATo), .ITAGo(SDCacheITAGo),
				// Avalon-MM DDR3 controller interface
				.avl_ready(avl_ready), .avl_burstbegin(avl_burstbegin), .avl_addr(avl_addr_cache), .avl_rdata_valid(avl_rdata_valid), .avl_rdata(avl_rdata),
				.avl_wdata(avl_wdata), .avl_be(avl_be), .avl_read_req(avl_read_req), .avl_write_req(avl_write_req), .avl_size(avl_size)
				);

//=====================================================================================================================
//				Portal Memory channel
extern module PortalMCL(
				// global control
				input wire CLK, RST, DTCLR, DIS,
				input wire [39:0] DTBASE,
				input wire [23:0] DTLIMIT,
				input wire CFGSTB,
				input wire [7:0] CFG,
				input wire [15:0] TASKID,
				input wire [1:0] CPL,
				input wire [23:0] PSO,
				input wire DSELSTB,
				input wire [23:0] DSEL,
				// portal interface
				output reg PortalNEXT,
				output wire PortalERROR,
				output wire [7:0] PortalERRORTag,
				input wire PortalACT, PortalCMD,
				input wire [31:0] PortalSelector,
				input wire [36:0] PortalOffset,
				input wire [63:0] PortalDO,
				input wire [1:0] PortalSO,
				input wire [7:0] PortalTO,
				output reg PortalDRDY,
				output reg [63:0] PortalDI,
				output reg [1:0] PortalSI,
				output reg [7:0] PortalTI,
				// system interface
				input wire LNEXT, SNEXT,
				output reg LACT, SACT, CMD,
				output reg [1:0] OS,
				output reg [44:0] ADDRESS,
				output reg [31:0] SELECTOR,
				output reg [36:0] OFFSET,
				output reg [63:0] DO,
				output reg [8:0] TO,
				input wire LDRDY, SDRDY,
				input wire [63:0] LDI, SDI,
				input wire [8:0] LTI,
				input wire [7:0] STI,
				input wire [1:0] LSI, SSI,
				// error report interface				
				output wire ESTB,
				output reg [63:0] ECD
				);
PortalMCL	PortalMemoryChannel(
								// global control
								.CLK(EXTCLK), .RST(RST), .DTCLR(DTRESET), .DIS(PortalErrorLockFlag), .DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus),
								.CFGSTB(PortalCFGSTB & (PortalCFGAddr==6'h38)), .CFG(PortalCFG[23:16]), .TASKID(PortalTaskID), .CPL(PortalCPL), .PSO(PortalPSO),
								.DSELSTB(CoreMALLOCREQ), .DSEL(CorePARAM[23:0]),
								// portal interface
								.PortalNEXT(PortalNEXT), .PortalERROR(PortalERROR), .PortalERRORTag(PortalERRORTag), .PortalACT(CfgFreeze ? 1'b0 : PortalACT), .PortalCMD(PortalCMD), 
								.PortalSelector(PortalSelector), .PortalOffset(PortalOffset), .PortalDO(PortalDO), .PortalSO(PortalSO), .PortalTO(PortalTO),
								.PortalDRDY(PortalDRDY), .PortalDI(PortalDI), .PortalSI(PortalSI), .PortalTI(PortalTI),
								// system interface
								.LNEXT(TmuxLNEXT[1]), .SNEXT(~CoreStreamACT & CoreStreamNEXT), .LACT(PortalMCLACT), .SACT(PortalMCSACT), .CMD(PortalMCCMD), .OS(PortalMCOS),
								.ADDRESS(PortalMCADDRESS), .SELECTOR(PortalMCSELECTOR), .OFFSET(PortalMCOFFSET), .DO(PortalMCDO),
								.TO(PortalMCTO), .LDRDY(TmuxLDRDY[1]), .SDRDY(StreamCoreDRDY & StreamCoreTAGO[9]), .LDI(TmuxLDATI), .SDI(StreamCoreDTO), .LTI(TmuxLTAGI[8:0]),
								.STI(StreamCoreTAGO[7:0]), .LSI(TmuxLSIZEI[1:0]), .SSI(StreamCoreSIZEO[1:0]),
								// error report interface				
								.ESTB(PortalMCESTB), .ECD(PortalMCECD)
								);
			
//=====================================================================================================================
// 				CORE UNIT
extern module EU64X32CsL (
	input wire CLK, RESET, CLOAD, TCK,
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
	output reg [8:0] TAGo,
	input wire DRDY,
	input wire [8:0] TAGi,
	input wire [2:0] SZi,
	input wire [63:0] DTi,
	// PORTAL instruction interface
	input wire PortalReady,
	output reg PortalActivation,
	output reg [31:0] PortalInstruction,
	output reg [127:0] PortalOpA, PortalOpB, PortalOpC,
	input wire PortalGPRStrobe,
	input wire [4:0] PortalGPRIndex,
	input wire [2:0] PortalGPRSize,
	input wire [6:0] PortalGPRFlags,
	input wire [127:0] PortalGPRData,
	// interface to the descriptor pre-loading system
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [1:0] CPL,
	// interface to message control subsystem
	output wire [63:0] PARAM,
	output wire [4:0] PARREG,
	output wire MSGREQ, MALLOCREQ, PARREQ, ENDMSG, BKPT,
	output reg EMPTY,
	output wire HALT,
	output wire NPCS,
	output wire SMSGBKPT,
	input wire CEXEC, ESMSG, CONTINUE,
	input wire CSTOP,
	// context store interface
	input wire [6:0] RA,
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
	// configuration interface
	input wire CFGSTB, CFGRST,
	input wire [5:0] CFGADDR,
	input wire [31:0] CFGDATA
	);
EU64X32CsL  Core(.CLK(EXTCLK), .RESET(RST), .CLOAD(ContEUCLOAD), .TCK(TickFlag), .TASKID(CSRBus[15:0]),
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPL(CSRBus[19:18]), .CPSR(CPSRBus),
			// memory interface
			.NEXT(ContEUNEXT), .StreamNEXT(CoreStreamNEXT), .ACT(CoreACT), .StreamACT(CoreStreamACT), .CMD(CoreCMD), .OS(CoreOS), 
			.ADDRESS(CoreADDRESS), .OFFSET(CoreOFFSET), .SELECTOR(CoreSELECTOR), .DTo(CoreDTo), .TAGo(CoreTAGo), .DRDY(CoreDRDY), .TAGi(CoreTAGi),
			.SZi(CoreSZi), .DTi(CoreDTi),
			// PORTAL instruction interface
			.PortalReady(CfgFreeze ? 1'b1 : PortalReady), .PortalActivation(PortalActivation), .PortalInstruction(PortalInstruction), .PortalOpA(PortalOpA),
			.PortalOpB(PortalOpB), .PortalOpC(PortalOpC), .PortalGPRStrobe(CfgFreeze ? 1'b0 : PortalGPRStrobe), .PortalGPRIndex(PortalGPRIndex),
			.PortalGPRSize(PortalGPRSize), .PortalGPRFlags(PortalGPRFlags), .PortalGPRData(PortalGPRData),
			// message system interface
			.PARAM(CorePARAM), .PARREG(CorePARREG), .MSGREQ(CoreMSGREQ), .MALLOCREQ(CoreMALLOCREQ), .PARREQ(CorePARREQ),
			.ENDMSG(CoreENDMSG), .BKPT(CoreBKPT), .EMPTY(CoreEMPTY), .HALT(CoreHALT), .NPCS(CoreNPCS), .SMSGBKPT(CoreSMSGBKPT), .CEXEC(ContEURESTART),
			.ESMSG(MsgrEUCONTINUE), .CONTINUE(ContCONTINUE), .CSTOP(ContCORESTOP | IntFlag),
			// context store interface
			.RA(ContRA), .CDATA(CoreCDATA), .RIP(CoreRIP),
			// error reporting
			.ESTB(CoreESTB), .ECD(CoreECD),
			// fatal error
			.FATAL(FATAL),
			// Performance monitor outputs
			.IV(CoreIV),
			.CSEL(CoreCSEL),
			// configuration interface
			.CFGSTB(PortalCFGSTB), .CFGRST(PortalCFGRST), .CFGADDR(PortalCFGAddr), .CFGDATA(PortalCFG)
			);

// datapatch mux
DMuxL CoreMux(.CLK(EXTCLK), .RESET(RST),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContEUDRDY), .LocalDATA({ContEUSZi, ContEUTAGi, ContEUDTi}), .LocalRD(ContEURD),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(~StreamDFifoEMPTY), .StreamDATA(StreamDFifoDO), .StreamRD(StreamDFifoRSTB),
		// output to the EU resources
		.DRDY(CoreDRDY), .TAG({CoreSZi, CoreTAGi}), .DATA(CoreDTi));
defparam CoreMux.TagWidth=12;

// data fifo for stream datapatch
sc_fifo	StreamDFifo(.data({StreamCoreSIZEO, StreamCoreTAGO[8:0], StreamCoreDTO}), .wrreq(StreamCoreDRDY & ~StreamCoreTAGO[9]), .rdreq(StreamDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(StreamDFifoDO), .empty(StreamDFifoEMPTY));
defparam StreamDFifo.LPM_WIDTH=76, StreamDFifo.LPM_NUMWORDS=16, StreamDFifo.LPM_WIDTHU=4;

//=====================================================================================================================
//				STREAM CONTROLLER
extern module StreamController32Cs (
	input wire CLK, RESET, TE,
	input wire [39:0] DTBASE,
	output wire INIT,
// Core interface
	output wire CoreNEXT,
	input wire CoreACT, CoreCMD, CoreADDR,
	input wire [23:0] CoreSEL,
	input wire [63:0] CoreDTI,
	input wire [9:0] CoreTAGI,
	output reg CoreDRDY,
	output reg [63:0] CoreDTO,
	output reg [9:0] CoreTAGO,
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
StreamController32Cs Stream(.CLK(EXTCLK), .RESET(RST), .TE(TickFlag), .DTBASE(DTBASEBus), .INIT(StreamINIT),
						// Core interface
						.CoreNEXT(StreamCoreNEXT), .CoreACT(StreamCoreACT), .CoreCMD(StreamCoreCMD), .CoreADDR(StreamCoreADDR), .CoreSEL(StreamCoreSEL), .CoreDTI(StreamCoreDTI), .CoreTAGI(StreamCoreTAGI),
						.CoreDRDY(StreamCoreDRDY), .CoreDTO(StreamCoreDTO), .CoreTAGO(StreamCoreTAGO), .CoreSIZEO(StreamCoreSIZEO),
						// network interface
						.NetNEXT(), .NetACT(1'b0), .NetSEL(24'd0), .NetDATA(64'd0),
						// local memory interface
						.NEXT(TmuxLNEXT[2]), .ACT(StreamACT), .CMD(StreamCMD), .SIZEO(StreamSIZEO), .ADDR(StreamADDR), .DTO(StreamDTO), .TAGO(StreamTAGO),
						.DRDY(TmuxLDRDY[2]), .DTI(TmuxLDATI), .TAGI(TmuxLTAGI[4:0]));

TFifoS	StreamTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreStreamACT | PortalMCSACT), .NEXTH(StreamCoreNEXT), .NEXTL(CoreStreamNEXT), .ACTH(StreamCoreACT),
					.DI(CoreStreamACT ? {CoreOFFSET[0],CoreCMD,1'b0,CoreTAGo,CoreSELECTOR[23:0],CoreDTo}:{PortalMCOFFSET[0],PortalMCCMD,1'b1,PortalMCTO,PortalMCSELECTOR[23:0],PortalMCDO}),
					.DO({StreamCoreADDR, StreamCoreCMD, StreamCoreTAGI, StreamCoreSEL, StreamCoreDTI}));
defparam StreamTFifo.Width=100;

//=====================================================================================================================
//				CONTEXT CONTROLLER
extern module ContextCTRL32CsLDR ( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF, PTINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	output reg  RST, READY,						// hardware reset and ready signal
	output reg [23:0] CPSR,						// current process selector register
	output reg [26:0] CSR,						// current core state register
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
	output logic [9:0] TAGo[1:0],
	output logic [63:0] DTo[1:0],
	input wire [1:0] DRDY,
	input wire [63:0] DTi,
	input wire [9:0] TAGi,
	input wire [2:0] SZi,
	// low-speed memory interface from EU
	output wire EUNEXT,
	input wire EUACT, EUCMD,
	input wire [1:0] EUSZo,
	input wire [44:0] EUADDR,
	input wire [63:0] EUDTo,
	input wire [8:0] EUTAGo,
	output wire EUDRDY,
	output wire [8:0] EUTAGi,
	output wire [2:0] EUSZi,
	output wire [63:0] EUDTi,
	input wire EURD,
	// control interface to EU
	input wire MALLOCREQ,
	input wire GETPARREQ,
	input wire BKPT,
	input wire MSGREQ,
	input wire [63:0] EUPARAM,
	input wire [4:0] EUREG,
	input wire EUEMPTY,
	input wire EUENDMSG,
	input wire SMSGBKPT,
	output reg CORESTART,
	output reg CORESTOP,
	output reg CORECONT,
	output wire EUCLOAD,
	output reg ESMSG,
	// interrupts and errors
	input wire ERRORREQ,
	input wire INTREQ,
	input wire [15:0] INTCODE,
	output reg INTACK,
	input logic [23:0] INTSR,			// selector IT
	input logic [15:0] INTCR,			// Length of IT
	// context load/store interface to EU
	output wire [6:0] RA,
	input wire [63:0] CDAT,
	// PORTAL context interface
	output reg PortalSTOP,
	output reg PortalRUN,
	output reg PortalDIS,
	input wire PortalEMPTY,
	output reg PortalContextSTB,
	output reg [7:0] PortalContextAddress,
	output reg [63:0] PortalContextDI,
	input wire [63:0] PortalContextDO,
	// PORTAL message interface
	input wire PortalSMSG, 
	input wire [63:0] PortalMSG, 
	output reg PortalSMSGNext,
	input wire [1:0] PortalCPL,
	input wire [23:0] PortalPSO,
	input wire [15:0] PortalTaskID,
	// reconfiguration channel
	output reg PortalCFGSTB, PortalCFGRST,
	output reg [5:0] PortalCFGAddr,
	output wire [31:0] PortalCFG,
	input wire [31:0] PortalState,
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC,
	// reconfiguration interface
	output reg CfgReset,
	input wire CfgFreeze,
	input wire [3:0] CfgStatus,
	output reg CfgSTB,
	output reg [31:0] CfgData
	);
ContextCTRL32CsLDR Cont(.CLK(EXTCLK), .RESETn(RST), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR), .DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .RST(ContRST), .READY(ContREADY),
				.CPSR(CPSRBus), .CSR(CSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .EXTDI(DATA), .CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB), .RIP(CoreRIP),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT[3], TmuxLNEXT[0]}), .ACT(ContACT), .CMD(ContCMD), .ADDR(ContADDR), .SIZE(ContSIZE), .TAGo(ContTAGo), .DTo(ContDTo),
				.DRDY({TmuxLDRDY[3], TmuxLDRDY[0]}), .DTi(TmuxLDATI), .TAGi(TmuxLTAGI[9:0]), .SZi(TmuxLSIZEI),
				// low-speed memory interface from EU
				.EUNEXT(ContEUNEXT), .EUACT(CoreACT), .EUCMD(CoreCMD), .EUSZo(CoreOS), .EUADDR(CoreADDRESS), .EUDTo(CoreDTo), .EUTAGo(CoreTAGo),
				.EUDRDY(ContEUDRDY), .EUTAGi(ContEUTAGi), .EUSZi(ContEUSZi), .EUDTi(ContEUDTi), .EURD(ContEURD),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ), .GETPARREQ(CorePARREQ), .BKPT(CoreBKPT), .MSGREQ(CoreMSGREQ), .EUPARAM(CorePARAM), .EUREG(CorePARREG), .EUEMPTY(CoreEMPTY),
				.EUENDMSG(CoreENDMSG), .SMSGBKPT(CoreSMSGBKPT), .CORESTART(ContEURESTART), .CORESTOP(ContCORESTOP), .CORECONT(ContCONTINUE), .EUCLOAD(ContEUCLOAD), .ESMSG(MsgrEUCONTINUE),
				// interrupts and errors
				.ERRORREQ(EfifoVALID & ~DEfifoVALID), .INTREQ(IntReqFlag), .INTCODE(INTCODE), .INTACK(INTACK), .INTSR(TmuxINTSEL), .INTCR(TmuxINTLIMIT),
				// context load/store interface to EU
				.RA(ContRA), .CDAT(CoreCDATA),
				// PORTAL context interface
				.PortalSTOP(PortalSTOP), .PortalRUN(PortalRUN), .PortalDIS(PortalDIS), .PortalEMPTY(CfgFreeze ? 1'b1 : PortalEMPTY), .PortalContextSTB(PortalContextSTB),
				.PortalContextAddress(PortalContextAddress), .PortalContextDI(PortalContextDI), .PortalContextDO(PortalContextDO),
				// PORTAL message interface
				.PortalSMSG(CfgFreeze ? 1'b0 : (RST & PortalSMSG & PortalMsgEnable & |PortalMsgCntr)), .PortalMSG(PortalMSG), .PortalSMSGNext(PortalSMSGNext),
				.PortalCPL(PortalCPL), .PortalPSO(PortalPSO), .PortalTaskID(PortalTaskID),
				// reconfiguration channel
				.PortalCFGSTB(PortalCFGSTB), .PortalCFGRST(PortalCFGRST), .PortalCFGAddr(PortalCFGAddr), .PortalCFG(PortalCFG), .PortalState(PortalState),
				// error reporting interface
				.ESTB(ContESTB), .ERC(ContERC),
				// reconfiguration interface
				 .CfgReset(CfgReset), .CfgRequest(CfgRequest), .CfgFreeze(CfgFreeze), .CfgStatus({DRwrused[3], CfgStatus}), .CfgSTB(CfgSTB), .CfgData(CfgData)
				);

//=====================================================================================================================
//			Dynamic reconfiguration FIFO

dc_fifo #(.WIDTH(32), .NUMWORDS(16), .WIDTHU(4)) DRFifo (
																.resetn(DRFifoReset), .wrclk(EXTCLK), .wren(CfgSTB), .data(CfgData), .wrused(DRwrused),
																.rdclk(DRCLK), .rden(DRReady & |DRrdused), .q(DRData), .rdused(DRrdused)
																);

//=================================================================================================
//		assignments
//=================================================================================================

assign TmuxLSIZEO[3]=ContSIZE[1];
assign TmuxLSIZEO[2]=StreamSIZEO;
assign TmuxLSIZEO[1]=PortalMCOS;
assign TmuxLSIZEO[0]=ContSIZE[0];

assign TmuxLADDR[3]=ContADDR[1];
assign TmuxLADDR[2]=StreamADDR;
assign TmuxLADDR[1]=PortalMCADDRESS;
assign TmuxLADDR[0]=ContADDR[0];

assign TmuxLDATO[3]=ContDTo[1];
assign TmuxLDATO[2]=StreamDTO;
assign TmuxLDATO[1]=PortalMCDO;
assign TmuxLDATO[0]=ContDTo[0];

assign TmuxLTAGO[3]={3'd0, ContTAGo[1]};
assign TmuxLTAGO[2]={8'd0, StreamTAGO};
assign TmuxLTAGO[1]={4'd0,PortalMCTO};
assign TmuxLTAGO[0]={3'd0, ContTAGo[0]};

assign avl_addr=avl_addr_cache-39'h1000000;

assign TCK=TickFlag;

assign DRValid=|DRrdused;

//=================================================================================================
//		synchronous 
//=================================================================================================
always_ff @(posedge CLK50) tcnt<={tcnt[3]^tcnt[2], (tcnt[2:0]+1'b1) & {3{~tcnt[2]}}};



// DRC clocking
always_ff @(posedge DRCLK or negedge DRFifoReset)
if (~DRFifoReset) DRStart<='0;
	else DRStart<=CfgRequest;

// system clock domain
always_ff @(posedge EXTCLK)
begin

// end of reconfig
CfgFinishReg<={CfgFinishReg[1:0],DRFreeze} & {3{RST}};

// initialization counter
if (~RST) CfgInitCnt<='0;
	else if (|CfgInitCnt | (CfgFinishReg[2] & ~CfgFinishReg[1])) CfgInitCnt<=CfgInitCnt+1'b1;

// reconfig resources
CfgFreeze<=(CfgFreeze | CfgSTB) & RST & ~&CfgInitCnt;
CfgStatus<=DRStatus & {3{RST}};
DRFifoReset<=RST & CfgReset;

// Tick counter
TFlag<={TFlag[0],tcnt[3]};
TCKcnt<=(TCKcnt+1'b1) & {8{TFlag!=2'd1}};
if (TFlag==2'd1) TCKScale<=TCKcnt+1'b1;

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

//
//			portal message control system
//
// message counter
if (~RST | PortalCFGRST) PortalMsgCntr<=0;
	else if (~|PortalMsgTimer) PortalMsgCntr<=PortalMsgCntrBase;
		else if (|PortalMsgCntr & PortalSMSG & ~CfgFreeze) PortalMsgCntr<=PortalMsgCntr-8'd1;
// message counter base
if (~RST | PortalCFGRST) PortalMsgCntrBase<=0;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h39)) PortalMsgCntrBase<=PortalCFG[23:16];
// timer
if (~RST | PortalCFGRST) PortalMsgTimer<=0;
	else if (~|PortalMsgTimer) PortalMsgTimer<=PortalMsgTimerBase;
		else if ((PortalMsgCntr!=PortalMsgCntrBase) & TickFlag) PortalMsgTimer<=PortalMsgTimer-16'd1;
// timer base
if (~RST | PortalCFGRST) PortalMsgTimerBase<=0;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h39)) PortalMsgTimerBase<=PortalCFG[15:0];
// next message enable
PortalMsgEnable<=RST & |PortalMsgCntr;

// portal parameters
if (((CfgFreeze ? 1'b1 : PortalReady) & PortalActivation)|(PortalCFGSTB & (PortalCFGAddr==6'h3B)))
	begin
	PortalCPL<=PortalCFGSTB ? PortalCFG[19:18]:CSRBus[19:18];
	PortalTaskID<=PortalCFGSTB ? PortalCFG[15:0]:CSRBus[15:0];
	end
if (((CfgFreeze ? 1'b1 : PortalReady) & PortalActivation)|(PortalCFGSTB & (PortalCFGAddr==6'h3C))) PortalPSO<=PortalCFGSTB ? PortalCFG[23:0]:CPSRBus;

// lock portal datapath on error
PortalErrorLockFlag<=(PortalErrorLockFlag | PortalDIS | (PortalMCESTB & SoEFlag)) & RST & ~PortalRUN;

// Stop_on_Error flag
if (~RST) SoEFlag<=0;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h38)) SoEFlag<=PortalCFG[21];

// error reporting flag
if (~RST) ERFlag<=1'b1;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h38)) ERFlag<=PortalCFG[20];
	
// reset portal
PortalRST<=RST & (~PortalMCESTB | ~SoEFlag) & ~CfgFreeze;

// portal configuration register 38h
if (PortalCFGSTB & (PortalCFGAddr==6'h38)) PortalCFGReg38<=PortalCFG[15:0];

// portal state for to context controller
if (PortalCFGAddr==6'h3C) PortalState<={8'd0,PortalPSO};
	else if (PortalCFGAddr==6'h3B) PortalState<={12'd0,PortalCPL,2'd0,PortalTaskID};
		else PortalState<={16'd0,PortalCFGReg38};

end

endmodule
