module X32Cs_DMA_Cache4x512x1024 #(parameter SPI=1'b1)	(
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

									// network interface
									output wire [3:0] NETSTBO,
									output wire [32:0] NETDON,
									output wire [32:0] NETDOE,
									output wire [32:0] NETDOS,
									output wire [32:0] NETDOW,
									input wire [3:0] NETSTBI,
									input wire [32:0] NETDIN,
									input wire [32:0] NETDIE,
									input wire [32:0] NETDIS,
									input wire [32:0] NETDIW,

									// interrupt interface
									output wire INTACK,
									input wire INTREQ,
									input wire [15:0] INTCODE,

									// IO input channels 
									input wire [1:0] IOSIZE0, IOSIZE1, IOSIZE2, IOSIZE3,
									output wire [3:0] IOWRDY,
									input wire [3:0] IOWR, IOWLAST,
									input wire [63:0] IOWD0, IOWD1, IOWD2, IOWD3,
									// IO output channels
									input wire [3:0] IORRDY,
									output wire [3:0] IORSTB, IORSTRT, IORLAST,
									output wire [63:0] IORD0, IORD1, IORD2, IORD3
									);

integer i;

reg RST;

// TE counter
logic [1:0] TFlag;
logic [3:0] tcnt;
reg [7:0] TECntReg, TCKcnt, TCKScale;
reg TickFlag, IntFlag, IntReqFlag, DIntReqFlag;

// common buses
logic [7:0] CPUBus;
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

logic PortalMCNNEXT, PortalMCSNEXT, PortalMCLACT, PortalMCNACT, PortalMCSACT, PortalMCCMD, PortalMCESTB, PortalDIS;
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
logic [5:0] TmuxLNEXT, TmuxLDRDY;
logic [63:0] TmuxLDATI;
logic [12:0] TmuxLTAGI;
logic [2:0] TmuxLSIZEI;
logic [23:0] TmuxINTSEL;
logic [15:0] TmuxINTLIMIT;
logic [3:0] TmuxNENA;
logic TmuxINTRST, TmuxINTENA, TmuxESRRD, TmuxCENA, TMuxMALOCKF, TmuxPTINTR, DTRESET;
logic [2:0] TmuxCPSRSTB;
logic [3:0] TmuxCSRSTB;
logic [1:0] TmuxLSIZEO [5:0];
logic [44:0] TmuxLADDR [5:0];
logic [63:0] TmuxLDATO [5:0];
logic [12:0] TmuxLTAGO [5:0];

wire [1:0] IOSIZE [0:3];
wire [63:0] IOWD [0:3];
wire [63:0] IORD [0:3];

logic SDCacheINEXT, SDCacheIDRDY;
logic [63:0] SDCacheIDATo;
logic [20:0] SDCacheITAGo;

logic CoreCLOAD, CoreACT, CoreCMD, CoreDRDY, CoreMSGREQ, CoreMALLOCREQ, CorePARREQ, CoreStreamNEXT, CoreNetNEXT, CoreStreamACT, CoreNetACT;
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

logic NetDFifoEMPTY, NetDFifoRSTB;
logic [75:0] NetDFifoDO;

logic FpuCORENEXT, FpuCOREACT, FpuCORECMD, FpuCOREDRDY, FpuACT, FpuCMD, FpuSTONEW, FpuSTINEXT;
logic FpuSNEXT, FpuSACT;
logic [1:0] FpuCORESIZE, FpuSIZEO;
logic [2:0] FpuCORESIZEI;
logic [36:0] FpuCOREOFFSET;
logic [31:0] FpuCORESEL;
logic [63:0] FpuCOREDTO, FpuCOREDTI, FpuDTO, FpuSTODT;
logic [9:0] FpuCORETAGO, FpuCORETAGI;
logic [44:0] FpuADDR;
logic [12:0] FpuTAGO;
logic FpuMSGREQ, FpuMSGNEXT;
logic [121:0] FpuMSGDATA;
logic [23:0] FpuSEL;
logic FpuINIT;
logic FpuESTB;
logic [12:0] FpuECD;

logic [32:0] RteEXTDO [3:0];
logic [3:0] RteEXTSTBI, RteEXTSTBO;
logic [32:0] RteEXTDI [3:0];
logic RteSTONEXT, RteSTINEW, RteSTIVAL;
logic [63:0] RteSTIDT;

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

logic MsgrRST, MsgrNETREQ, MsgrNETMSGRD, MsgrPortalSMSGNext;
logic MsgrACT, MsgrCMD;
logic MsgrContextREQ, MsgrNETSEND, MsgrNETTYPE, MsgrContextCHK;
logic MsgrEUCONTINUE, MsgrEUHALT, MsgrESTB, MsgrEURESTART;
logic [1:0] MsgrSIZE;
logic [31:0] MsgrDATO;
logic [63:0] MsgrERRC;
logic [95:0] MsgrContextMSG;
logic [79:0] MsgrNETMSG;
logic [44:0] MsgrADDR;
logic [4:0] MsgrNETSTAT;

logic [38:0] avl_addr_cache;

//=====================================================================================================================
//				Flash controller (internal buffer and external SPI)
generate
if (SPI==1'b1)
	Flash32 CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
					.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO),
					// interface to the external memory
					.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));
	else Flash32noSPI  CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO));
endgenerate

//=====================================================================================================================
//				ERROR FIFO system
extern module ErrorFIFOCs (
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
	// error report from network
	input wire NetSTB,
	input wire [12:0] NetECD,
	// error report from messenger
	input wire MsgrSTB,
	input wire [63:0] MsgrECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);
ErrorFIFOCs Efifo(.CLK(EXTCLK), .RESET(RST), .CPSR(CPSRBus),
				// read fifo interface
				.ERD(TmuxESRRD & EfifoVALID), .VALID(EfifoVALID), .ECD(EfifoECD),
				// error interface from core
				.CoreSTB(CoreESTB), .CoreECD(CoreECD),
				// error interface from portal
				.PortalSTB(PortalMCESTB & ERFlag), .PortalECD(PortalMCECD),
				// error report from network
				.NetSTB(FpuESTB), .NetECD(FpuECD),
				// error report from messenger
				.MsgrSTB(MsgrESTB), .MsgrECD(MsgrERRC),
				// error report from context controller
				.ContSTB(ContESTB), .ContECD(ContERC)
				);

//=====================================================================================================================
// 				BUS MULTIPLEXER
// 0 - core /througth context controller
// 1 - Portal
// 2 - network
// 3 - stream
// 4 - context controller channel (MCU)
// 5 - Message processor
extern module MUX64X32CsD	(
							input CLK, RESETn,
							// transaction channels
							output wire [5:0] LNEXT,
							input wire [5:0] LACT,
							input wire [5:0] LCMD,
							input wire [1:0] LSIZEO [5:0],
							input wire [44:0] LADDR [5:0],
							input wire [63:0] LDATO [5:0],
							input wire [12:0] LTAGO [5:0],
							output reg [5:0] LDRDY,
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
							input wire SDNEXT,
							output reg SDACT,
							input wire SDDRDY,
							input wire [63:0] SDDAT,
							input wire [20:0] SDTAG,
							// IO channel
							input wire IONEXT,
							output reg IOACT,
							input wire IODRDY,
							input [63:0] IODAT,
							input [20:0] IOTAG,
							// interface to invalidate the DMA selector registers
							input wire DSELSTB,
							input wire [23:0] DSEL,
							// control and status lines
							output reg [39:0] DTBASE,
							output reg [23:0] DTLIMIT, INTSEL,
							output reg [15:0] INTLIMIT,
							output reg [7:0] CPUNUM,
							output reg [3:0] NENA,
							output reg INTRST, INTENA, ESRRD, CENA, MALOCKF, PTINTR, DTRESET,
							input wire [3:0] NLE, NERR,
							input wire [26:0] CSR,
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
MUX64X32CsD Tmux(
				.CLK(EXTCLK), .RESETn(RST), 
				// services interface
				.LNEXT(TmuxLNEXT),
				.LACT({MsgrACT, ContACT[1], StreamACT, FpuACT, PortalMCLACT, ContACT[0]}),
				.LCMD({MsgrCMD, ContCMD[1], StreamCMD, FpuCMD, PortalMCCMD, ContCMD[0]}),
				.LSIZEO(TmuxLSIZEO), .LADDR(TmuxLADDR), .LDATO(TmuxLDATO), .LTAGO(TmuxLTAGO),
				.LDRDY(TmuxLDRDY), .LDATI(TmuxLDATI), .LTAGI(TmuxLTAGI), .LSIZEI(TmuxLSIZEI),
				// local memory interface
				.CMD(CMD), .ADDR(ADDR), .DATA(DATA), .BE(BE), .TAG(TAG),
				.FLNEXT(CoreFlashNEXT), .FLACT(TmuxFLACT), .FLDRDY(CoreFlashDRDY), .FLDAT(CoreFlashDTO), .FLTAG(CoreFlashTAGO),
				.SDNEXT(SDCacheINEXT), .SDACT(TmuxSDACT), .SDDRDY(SDCacheIDRDY), .SDDAT(SDCacheIDATo), .SDTAG(SDCacheITAGo),
				.IONEXT(IONEXT), .IOACT(IOACT), .IODRDY(IODRDY), .IODAT(IODAT), .IOTAG(IOTAG),
				// DMA control channel
				.DSELSTB(CoreMALLOCREQ), .DSEL(CorePARAM[23:0]),
				// status and control lines and buses
				.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .INTSEL(TmuxINTSEL), .INTLIMIT(TmuxINTLIMIT), .CPUNUM(CPUBus), .NENA(TmuxNENA), .INTRST(TmuxINTRST),
				.INTENA(TmuxINTENA), .ESRRD(TmuxESRRD), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR), .DTRESET(DTRESET), .NLE(4'd0), .NERR(4'd0),
				.CSR(CSRBus), .CPSR(CPSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .ESR({EfifoECD[63:56] & {8{EfifoVALID}},EfifoECD[55:0]}),
				.CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB), .SINIT(StreamINIT), .NINIT(FpuINIT), .CINIT(ContREADY), .TCK(TickFlag), .TCKOVR(CoreNPCS), .HALT(CoreHALT),
				.IV(CoreIV), .CSEL(CoreCSEL), .EMPTY(CoreEMPTY), .TCKScaler(TCKScale), .CoreType(8'd11),
				// IO Input channels
				.IOSIZE(IOSIZE), .IOWRDY(IOWRDY), .IOWR(IOWR), .IOWLAST(IOWLAST), .IOWD(IOWD),
				// IO output channels
				.IORRDY(IORRDY), .IORSTB(IORSTB), .IORSTRT(IORSTRT), .IORLAST(IORLAST), .IORD(IORD)
				);
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
extern module PortalMC(
				// global control
				input wire CLK, RST, DTCLR, DIS,
				input wire [39:0] DTBASE,
				input wire [23:0] DTLIMIT,
				input wire [7:0] CPU,
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
				input wire LNEXT, NNEXT, SNEXT,
				output reg LACT, NACT, SACT, CMD,
				output reg [1:0] OS,
				output reg [44:0] ADDRESS,
				output reg [31:0] SELECTOR,
				output reg [36:0] OFFSET,
				output reg [63:0] DO,
				output reg [8:0] TO,
				input wire LDRDY, NDRDY, SDRDY,
				input wire [63:0] LDI, NDI, SDI,
				input wire [8:0] LTI,
				input wire [7:0] NTI, STI,
				input wire [1:0] LSI, NSI, SSI,
				// error report interface				
				output wire ESTB,
				output reg [63:0] ECD
				);
PortalMC	PortalMemoryChannel(
								// global control
								.CLK(EXTCLK), .RST(RST), .DTCLR(DTRESET), .DIS(PortalErrorLockFlag), .DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPU(CPUBus),
								.CFGSTB(PortalCFGSTB & (PortalCFGAddr==6'h38)), .CFG(PortalCFG[23:16]), .TASKID(PortalTaskID), .CPL(PortalCPL), .PSO(PortalPSO),
								.DSELSTB(CoreMALLOCREQ), .DSEL(CorePARAM[23:0]),
								// portal interface
								.PortalNEXT(PortalNEXT), .PortalERROR(PortalERROR), .PortalERRORTag(PortalERRORTag), .PortalACT(PortalACT), .PortalCMD(PortalCMD), 
								.PortalSelector(PortalSelector), .PortalOffset(PortalOffset), .PortalDO(PortalDO), .PortalSO(PortalSO), .PortalTO(PortalTO),
								.PortalDRDY(PortalDRDY), .PortalDI(PortalDI), .PortalSI(PortalSI), .PortalTI(PortalTI),
								// system interface
								.LNEXT(TmuxLNEXT[1]), .NNEXT(~CoreNetACT & CoreNetNEXT), .SNEXT(~CoreStreamACT & CoreStreamNEXT),
								.LACT(PortalMCLACT), .NACT(PortalMCNACT), .SACT(PortalMCSACT), .CMD(PortalMCCMD), .OS(PortalMCOS),
								.ADDRESS(PortalMCADDRESS), .SELECTOR(PortalMCSELECTOR), .OFFSET(PortalMCOFFSET), .DO(PortalMCDO),
								.TO(PortalMCTO), .LDRDY(TmuxLDRDY[1]), .NDRDY(FpuCOREDRDY & FpuCORETAGI[9]), .SDRDY(StreamCoreDRDY & StreamCoreTAGO[9]),
								.LDI(TmuxLDATI), .NDI(FpuCOREDTI), .SDI(StreamCoreDTO), .LTI(TmuxLTAGI[8:0]), .NTI(FpuCORETAGI[7:0]),
								.STI(StreamCoreTAGO[7:0]), .LSI(TmuxLSIZEI[1:0]), .NSI(FpuCORESIZEI[1:0]), .SSI(StreamCoreSIZEO[1:0]),
								// error report interface				
								.ESTB(PortalMCESTB), .ECD(PortalMCECD)
								);
			
//=====================================================================================================================
// 				CORE UNIT
extern module EU64X32Cs (
	input wire CLK, RESET, CLOAD, TCK,
	input wire [7:0] CPU,
	input wire [15:0] TASKID,
	input wire [23:0] CPSR,
	// interface to datapatch of memory subsystem
	input wire NEXT, StreamNEXT, NetNEXT,
	output reg ACT, StreamACT, NetACT, CMD, 
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
EU64X32Cs  Core(.CLK(EXTCLK), .RESET(RST), .CLOAD(ContEUCLOAD), .TCK(TickFlag), .CPU(CPUBus), .TASKID(CSRBus[15:0]),
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPL(CSRBus[19:18]), .CPSR(CPSRBus),
			// memory interface
			.NEXT(ContEUNEXT), .StreamNEXT(CoreStreamNEXT), .NetNEXT(CoreNetNEXT), .ACT(CoreACT), .StreamACT(CoreStreamACT), .NetACT(CoreNetACT),
			.CMD(CoreCMD), .OS(CoreOS), 
			.ADDRESS(CoreADDRESS), .OFFSET(CoreOFFSET), .SELECTOR(CoreSELECTOR), .DTo(CoreDTo), .TAGo(CoreTAGo), .DRDY(CoreDRDY), .TAGi(CoreTAGi),
			.SZi(CoreSZi), .DTi(CoreDTi),
			// PORTAL instruction interface
			.PortalReady(PortalReady), .PortalActivation(PortalActivation), .PortalInstruction(PortalInstruction), .PortalOpA(PortalOpA),
			.PortalOpB(PortalOpB), .PortalOpC(PortalOpC), .PortalGPRStrobe(PortalGPRStrobe), .PortalGPRIndex(PortalGPRIndex),
			.PortalGPRSize(PortalGPRSize), .PortalGPRFlags(PortalGPRFlags), .PortalGPRData(PortalGPRData),
			// message system interface
			.PARAM(CorePARAM), .PARREG(CorePARREG), .MSGREQ(CoreMSGREQ), .MALLOCREQ(CoreMALLOCREQ), .PARREQ(CorePARREQ),
			.ENDMSG(CoreENDMSG), .BKPT(CoreBKPT), .EMPTY(CoreEMPTY), .HALT(CoreHALT), .NPCS(CoreNPCS), .SMSGBKPT(CoreSMSGBKPT), .CEXEC(ContEURESTART | MsgrEURESTART),
			.ESMSG(MsgrEUCONTINUE), .CONTINUE(ContCONTINUE), .CSTOP(MsgrEUHALT | ContCORESTOP | IntFlag),
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
DMux CoreMux(.CLK(EXTCLK), .RESET(RST),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContEUDRDY), .LocalDATA({ContEUSZi, ContEUTAGi, ContEUDTi}), .LocalRD(ContEURD),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(~StreamDFifoEMPTY), .StreamDATA(StreamDFifoDO), .StreamRD(StreamDFifoRSTB),
		// datapatch from network controller (highest priority)
		.NetDRDY(~NetDFifoEMPTY), .NetDATA(NetDFifoDO), .NetRD(NetDFifoRSTB),
		// output to the EU resources
		.DRDY(CoreDRDY), .TAG({CoreSZi, CoreTAGi}), .DATA(CoreDTi));
defparam CoreMux.TagWidth=12;

// data fifo for stream datapatch
sc_fifo	StreamDFifo(.data({StreamCoreSIZEO, StreamCoreTAGO[8:0], StreamCoreDTO}), .wrreq(StreamCoreDRDY & ~StreamCoreTAGO[9]), .rdreq(StreamDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(StreamDFifoDO), .empty(StreamDFifoEMPTY));
defparam StreamDFifo.LPM_WIDTH=76, StreamDFifo.LPM_NUMWORDS=16, StreamDFifo.LPM_WIDTHU=4;

// data fifo for network datapatch
sc_fifo	NetDFifo(.data({FpuCORESIZEI, FpuCORETAGI[8:0], FpuCOREDTI}), .wrreq(FpuCOREDRDY & ~FpuCORETAGI[9]), .rdreq(NetDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(NetDFifoDO), .empty(NetDFifoEMPTY));
defparam NetDFifo.LPM_WIDTH=76, NetDFifo.LPM_NUMWORDS=16, NetDFifo.LPM_WIDTHU=4;

//=====================================================================================================================
// 				NETWORK SYSTEM
extern module FPU32Cs (
	// global
	input wire CLK, RESETn, TCK,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [15:0] TASKID,
	input wire [23:0] CPSR,
	output wire INIT,
	// interface from core
	output wire CORENEXT,
	input wire COREACT, CORECMD,
	input wire [1:0] CORESIZE, CORECPL,
	input wire [36:0] COREOFFSET,
	input wire [31:0] CORESEL,
	input wire [63:0] COREDTO,
	input wire [9:0] CORETAGO,
	output reg COREDRDY,
	output reg [63:0] COREDTI,
	output reg [9:0] CORETAGI,
	output reg [2:0] CORESIZEI,
	// local memory interface
	input wire NEXT, SNEXT,
	output reg ACT, SACT, CMD,
	output reg [1:0] SIZEO,
	output reg [44:0] ADDR,
	output reg [63:0] DTO,
	output reg [12:0] TAGO,
	output reg [23:0] SEL,
	input wire DRDY,
	input wire [63:0] DTI,
	input wire [1:0] SIZEI,
	input wire [12:0] TAGI,
	// interface to the routing system
	input wire STONEXT,
	output reg STONEW,
	output reg STOVAL,
	output reg [63:0] STODT,
	output wire STINEXT,
	input wire STIVAL,
	input wire STINEW,
	input wire [63:0] STIDT,
	// message system interface
	output reg MSGREQ,
	input wire MSGRD,
	output reg [121:0] MSGDATA,
	// messages from Messenger and context controller
	output reg MSGNEXT,
	input wire MSGSEND,
	input wire MSGTYPE,
	input wire [79:0] MSGPARAM,
	input wire [4:0] MSGSTAT,
	// error report interface
	output reg ESTB,
	output reg [12:0] ECD
	);
FPU32Cs Fpu(.CLK(EXTCLK), .RESETn(RST), .TCK(TickFlag), .DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .TASKID(CSRBus[15:0]), .CPSR(CPSRBus), .INIT(FpuINIT),
		// interface to core
		.CORENEXT(FpuCORENEXT), .COREACT(FpuCOREACT), .CORECMD(FpuCORECMD), .CORESIZE(FpuCORESIZE), .CORECPL(CSRBus[19:18]), .COREOFFSET(FpuCOREOFFSET), 
		.CORESEL(FpuCORESEL), .COREDTO(FpuCOREDTO), .CORETAGO(FpuCORETAGO), .COREDRDY(FpuCOREDRDY), .COREDTI(FpuCOREDTI), .CORETAGI(FpuCORETAGI), .CORESIZEI(FpuCORESIZEI),
		// local memory interface
		.NEXT(TmuxLNEXT[2]), .SNEXT(StreamNetNEXT), .ACT(FpuACT), .SACT(FpuSACT), .CMD(FpuCMD), .SIZEO(FpuSIZEO), .ADDR(FpuADDR), .DTO(FpuDTO), .TAGO(FpuTAGO), .SEL(FpuSEL),
		.DRDY(TmuxLDRDY[2]), .DTI(TmuxLDATI), .SIZEI(TmuxLSIZEI[1:0]), .TAGI(TmuxLTAGI),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT), .STONEW(FpuSTONEW), .STOVAL(), .STODT(FpuSTODT), .STINEXT(FpuSTINEXT), .STIVAL(RteSTIVAL), .STINEW(RteSTINEW), .STIDT(RteSTIDT),
		// messages interface
		.MSGREQ(FpuMSGREQ), .MSGRD(MsgrNETMSGRD), .MSGDATA(FpuMSGDATA), 
		.MSGNEXT(FpuMSGNEXT), .MSGSEND(MsgrNETSEND), .MSGTYPE(MsgrNETTYPE), .MSGPARAM(MsgrNETMSG), .MSGSTAT(MsgrNETSTAT),
		// error report interface
		.ESTB(FpuESTB), .ECD(FpuECD));

// Network interface TFIFO
TFifoS	FpuTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreNetACT | PortalMCNACT), .NEXTH(FpuCORENEXT), .NEXTL(CoreNetNEXT), .ACTH(FpuCOREACT),
					.DI(CoreNetACT ? {CoreCMD,1'b0,CoreTAGo,CoreOS,CoreOFFSET,CoreSELECTOR,CoreDTo}:{PortalMCCMD,1'b1,PortalMCTO,PortalMCOS,PortalMCOFFSET,PortalMCSELECTOR,PortalMCDO}),
					.DO({FpuCORECMD, FpuCORETAGO, FpuCORESIZE, FpuCOREOFFSET, FpuCORESEL, FpuCOREDTO}));
defparam FpuTFifo.Width=146;

// Routing engine
extern module RTE (
	// global control
	input wire CLK, RESET,
	input wire [7:0] CPUNUM,
	// external interfaces
	output reg [3:0] EXTSTBO,
	output reg [32:0]EXTDO[3:0],
	input wire [3:0] EXTSTBI,
	input wire [32:0]EXTDI[3:0],
	// core interface
	output reg STONEXT,
	input wire STONEW,
	//input wire STOVAL,
	input wire [63:0] STODT,
	input wire STINEXT,
	output wire STINEW,
	output wire STIVAL,
	output wire [63:0] STIDT
);
RTE Rte(.CLK(EXTCLK), .RESET(RST), .CPUNUM(CPUBus), .EXTDO(RteEXTDO), .EXTSTBO(RteEXTSTBO), .EXTSTBI(RteEXTSTBI), .EXTDI(RteEXTDI),
			.STONEXT(RteSTONEXT), .STONEW(FpuSTONEW), .STODT(FpuSTODT), .STINEXT(FpuSTINEXT), .STINEW(RteSTINEW), .STIVAL(RteSTIVAL), .STIDT(RteSTIDT));

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
						.CoreNEXT(StreamCoreNEXT), .CoreACT(StreamCoreACT), .CoreCMD(StreamCoreCMD), .CoreADDR(StreamCoreADDR),
						.CoreSEL(StreamCoreSEL), .CoreDTI(StreamCoreDTI), .CoreTAGI(StreamCoreTAGI),
						.CoreDRDY(StreamCoreDRDY), .CoreDTO(StreamCoreDTO), .CoreTAGO(StreamCoreTAGO), .CoreSIZEO(StreamCoreSIZEO),
						// network interface
						.NetNEXT(StreamNetNEXT), .NetACT(FpuSACT), .NetSEL(FpuSEL), .NetDATA(FpuDTO),
						// local memory interface
						.NEXT(TmuxLNEXT[3]), .ACT(StreamACT), .CMD(StreamCMD), .SIZEO(StreamSIZEO), .ADDR(StreamADDR), .DTO(StreamDTO), .TAGO(StreamTAGO),
						.DRDY(TmuxLDRDY[3]), .DTI(TmuxLDATI), .TAGI(TmuxLTAGI[4:0]));

TFifoS	StreamTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreStreamACT | PortalMCSACT), .NEXTH(StreamCoreNEXT), .NEXTL(CoreStreamNEXT), .ACTH(StreamCoreACT),
					.DI(CoreStreamACT ? {CoreOFFSET[0],CoreCMD,1'b0,CoreTAGo,CoreSELECTOR[23:0],CoreDTo}:{PortalMCOFFSET[0],PortalMCCMD,1'b1,PortalMCTO,PortalMCSELECTOR[23:0],PortalMCDO}),
					.DO({StreamCoreADDR, StreamCoreCMD, StreamCoreTAGI, StreamCoreSEL, StreamCoreDTI}));
defparam StreamTFifo.Width=100;

//=====================================================================================================================
//				CONTEXT CONTROLLER
extern module ContextCTRL32Cs ( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF, PTINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
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
	// interface to messages controller
	output reg MSGACK,
	input wire MSGREQ, CHKREQ,
	input wire [95:0] MSGPARAM,
	// low-speed memory interface from EU
	output reg EUNEXT,
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
	input wire [63:0] EUPARAM,
	input wire [4:0] EUREG,
	input wire EUEMPTY,
	input wire EUENDMSG,
	input wire SMSGBKPT,
	output reg CORESTART,
	output reg CORESTOP,
	output reg CORECONT,
	output wire EUCLOAD,
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
	// reconfiguration channel
	output reg PortalCFGSTB, PortalCFGRST,
	output reg [5:0] PortalCFGAddr,
	output wire [31:0] PortalCFG,
	input wire [31:0] PortalState,
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC
);
ContextCTRL32Cs Cont(.CLK(EXTCLK), .RESETn(RST), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR),
					.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .RST(ContRST), .READY(ContREADY),
				.CPSR(CPSRBus), .CSR(CSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .EXTDI(DATA), .CPSRSTB(TmuxCPSRSTB),
				.CSRSTB(TmuxCSRSTB), .RIP(CoreRIP),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT[4], TmuxLNEXT[0]}), .ACT(ContACT), .CMD(ContCMD), .ADDR(ContADDR), .SIZE(ContSIZE), .TAGo(ContTAGo), .DTo(ContDTo),
				.DRDY({TmuxLDRDY[4], TmuxLDRDY[0]}), .DTi(TmuxLDATI), .TAGi(TmuxLTAGI[9:0]), .SZi(TmuxLSIZEI),
				// interface to messages controller
				.MSGACK(ContMSGACK), .MSGREQ(MsgrContextREQ), .CHKREQ(MsgrContextCHK), .MSGPARAM(MsgrContextMSG),
				// low-speed memory interface from EU
				.EUNEXT(ContEUNEXT), .EUACT(CoreACT), .EUCMD(CoreCMD), .EUSZo(CoreOS), .EUADDR(CoreADDRESS), .EUDTo(CoreDTo), .EUTAGo(CoreTAGo),
				.EUDRDY(ContEUDRDY), .EUTAGi(ContEUTAGi), .EUSZi(ContEUSZi), .EUDTi(ContEUDTi), .EURD(ContEURD),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ), .GETPARREQ(CorePARREQ), .EUPARAM(CorePARAM), .EUREG(CorePARREG), .EUEMPTY(CoreEMPTY), .EUENDMSG(CoreENDMSG),
				.SMSGBKPT(CoreSMSGBKPT), .CORESTART(ContEURESTART), .CORESTOP(ContCORESTOP), .CORECONT(ContCONTINUE), .EUCLOAD(ContEUCLOAD),
				// context load/store interface to EU
				.RA(ContRA), .CDAT(CoreCDATA),
				// PORTAL context interface
				.PortalSTOP(PortalSTOP), .PortalRUN(PortalRUN), .PortalDIS(PortalDIS), .PortalEMPTY(PortalEMPTY), .PortalContextSTB(PortalContextSTB),
				.PortalContextAddress(PortalContextAddress), .PortalContextDI(PortalContextDI), .PortalContextDO(PortalContextDO),
				// reconfiguration channel
				.PortalCFGSTB(PortalCFGSTB), .PortalCFGRST(PortalCFGRST), .PortalCFGAddr(PortalCFGAddr), .PortalCFG(PortalCFG), .PortalState(PortalState),
				// error reporting interface
				.ESTB(ContESTB), .ERC(ContERC)
				);

//=====================================================================================================================
//				MESSAGE CONTROLLER DECLARATION
extern module Messenger32Cs (
	input wire CLK, RESETn,
	output reg RST,
	// message interface from EU, error system, interrupt system and network system
	input wire EUREQ, ERRORREQ, INTREQ, NETREQ,
	input wire [63:0] EUPARAM,		// Message index for import table in the current PSO and parameter dword
	input wire [15:0] INTPARAM,		// Interrupt index
	input wire [121:0] NETPARAM,	// BUS(msb:lsb): CPL[121:120], Target PSO[119:96], TaskID[95:80], ProcINDX[79:64], Parameter[63:32], SourcePSO[31:0]
	output reg NETMSGRD,
	output reg INTACK,
	// PORTAL message interface
	input wire PortalSMSG,
	input wire [63:0] PortalMSG,
	output reg PortalSMSGNext,
	input wire [1:0] PortalCPL,
	input wire [23:0] PortalPSO,
	input wire [15:0] PortalTaskID,
	// interface to memory system
	input wire NEXT,
	output wire ACT, CMD,
	output wire [44:0] ADDR,
	output wire [1:0] SIZE,
	output wire [31:0] DATO,
	input wire DRDY,
	input wire [31:0] DATI,
	// interface to the context controller (interrupt, error or procedure)
	input wire ContextRDY,
	output reg ContextREQ, ContextCHK,
	output reg [95:0] ContextMSG,
	// interface to network controller
	input wire NETRDY,
	output reg NETSEND,
	output reg NETTYPE,
	output reg [79:0] NETMSG,
	output reg [4:0] NETSTAT,
	// DTR and DTL registers
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [23:0] CPSR,
	input logic [23:0] INTSR,			// selector IT
	input logic [15:0] INTCR,			// Length of IT
	input logic [26:0] CSR,
	// core control lines 
	output reg EUCONTINUE, EURESTART,
	output reg EUHALT,
	input wire BKPT,
	// error reporting interface
	output reg ESTB,
	output reg [63:0] ERRC
	);
Messenger32Cs Msgr(.CLK(EXTCLK), .RESETn(RST), .RST(MsgrRST),
			// message interface from EU, error system, interrupt system and network system
			.EUREQ(CoreMSGREQ), .ERRORREQ(EfifoVALID & ~DEfifoVALID),
			.INTREQ(IntReqFlag), .NETREQ(FpuMSGREQ), .EUPARAM(CorePARAM), .INTPARAM(INTCODE),
			.NETPARAM(FpuMSGDATA), .NETMSGRD(MsgrNETMSGRD), .INTACK(INTACK),
			// PORTAL message interface
			.PortalSMSG(RST & PortalSMSG & PortalMsgEnable & |PortalMsgCntr), .PortalMSG(PortalMSG), .PortalSMSGNext(MsgrPortalSMSGNext),
			.PortalCPL(PortalCPL), .PortalPSO(PortalPSO), .PortalTaskID(PortalTaskID),
			// interface to memory system
			.NEXT(TmuxLNEXT[5]), .ACT(MsgrACT), .CMD(MsgrCMD), .ADDR(MsgrADDR), .SIZE(MsgrSIZE), .DATO(MsgrDATO), .DRDY(TmuxLDRDY[5]), .DATI(TmuxLDATI[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContMSGACK), .ContextREQ(MsgrContextREQ), .ContextCHK(MsgrContextCHK), .ContextMSG(MsgrContextMSG),
			// interface to network controller
			.NETRDY(FpuMSGNEXT), .NETSEND(MsgrNETSEND), .NETTYPE(MsgrNETTYPE), .NETMSG(MsgrNETMSG), .NETSTAT(MsgrNETSTAT),
			// DTR and DTL registers
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .CPSR(CPSRBus), .INTSR(TmuxINTSEL), .INTCR(TmuxINTLIMIT), .CSR(CSRBus),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE), .EURESTART(MsgrEURESTART), .EUHALT(MsgrEUHALT), .BKPT(CoreBKPT),
			// error reporting interface
			.ESTB(MsgrESTB), .ERRC(MsgrERRC)
			);

//=================================================================================================
//		assignments
//=================================================================================================

assign TmuxLSIZEO[5]=MsgrSIZE;
assign TmuxLSIZEO[4]=ContSIZE[1];
assign TmuxLSIZEO[3]=StreamSIZEO;
assign TmuxLSIZEO[2]=FpuSIZEO;
assign TmuxLSIZEO[1]=PortalMCOS;
assign TmuxLSIZEO[0]=ContSIZE[0];

assign TmuxLADDR[5]=MsgrADDR;
assign TmuxLADDR[4]=ContADDR[1];
assign TmuxLADDR[3]=StreamADDR;
assign TmuxLADDR[2]=FpuADDR;
assign TmuxLADDR[1]=PortalMCADDRESS;
assign TmuxLADDR[0]=ContADDR[0];

assign TmuxLDATO[5]={32'd0, MsgrDATO};
assign TmuxLDATO[4]=ContDTo[1];
assign TmuxLDATO[3]=StreamDTO;
assign TmuxLDATO[2]=FpuDTO;
assign TmuxLDATO[1]=PortalMCDO;
assign TmuxLDATO[0]=ContDTo[0];

assign TmuxLTAGO[5]=13'd0;
assign TmuxLTAGO[4]={3'd0, ContTAGo[1]};
assign TmuxLTAGO[3]={8'd0, StreamTAGO};
assign TmuxLTAGO[2]=FpuTAGO;
assign TmuxLTAGO[1]={4'd0,PortalMCTO};
assign TmuxLTAGO[0]={3'd0, ContTAGo[0]};

assign NETSTBO=RteEXTSTBO;
assign NETDON=RteEXTDO[0];
assign NETDOE=RteEXTDO[1];
assign NETDOS=RteEXTDO[2];
assign NETDOW=RteEXTDO[3];
assign RteEXTSTBI=NETSTBI;
assign RteEXTDI[0]=NETDIN;
assign RteEXTDI[1]=NETDIE;
assign RteEXTDI[2]=NETDIS;
assign RteEXTDI[3]=NETDIW;

assign avl_addr=avl_addr_cache-39'h1000000;

assign PortalSMSGNext=MsgrPortalSMSGNext;

assign TCK=TickFlag;

assign IOSIZE[0]=IOSIZE0, IOSIZE[1]=IOSIZE1, IOSIZE[2]=IOSIZE2, IOSIZE[3]=IOSIZE3;
assign IOWD[0]=IOWD0, IOWD[1]=IOWD1, IOWD[2]=IOWD2, IOWD[3]=IOWD3;
assign IORD0=IORD[0], IORD1=IORD[1], IORD2=IORD[2], IORD3=IORD[3];

//=================================================================================================
//		synchronous 
//=================================================================================================
always_ff @(posedge CLK50) tcnt<={tcnt[3]^tcnt[2], (tcnt[2:0]+1'b1) & {3{~tcnt[2]}}};

always_ff @(posedge EXTCLK)
begin

TFlag<={TFlag[0],tcnt[3]};
TCKcnt<=(TCKcnt+1'b1) & {8{TFlag!=2'd1}};
if (TFlag==2'd1) TCKScale<=TCKcnt+1'b1;

// reset filtering
RST<=EXTRESET & MsgrRST & ContRST;

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
		else if (|PortalMsgCntr & PortalSMSG) PortalMsgCntr<=PortalMsgCntr-8'd1;
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
if ((PortalReady & PortalActivation)|(PortalCFGSTB & (PortalCFGAddr==6'h3B)))
	begin
	PortalCPL<=PortalCFGSTB ? PortalCFG[19:18]:CSRBus[19:18];
	PortalTaskID<=PortalCFGSTB ? PortalCFG[15:0]:CSRBus[15:0];
	end
if ((PortalReady & PortalActivation)|(PortalCFGSTB & (PortalCFGAddr==6'h3C))) PortalPSO<=PortalCFGSTB ? PortalCFG[23:0]:CPSRBus;

// lock portal datapath on error
PortalErrorLockFlag<=(PortalErrorLockFlag | PortalDIS | (PortalMCESTB & SoEFlag)) & RST & ~PortalRUN;

// Stop_on_Error flag
if (~RST) SoEFlag<=0;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h38)) SoEFlag<=PortalCFG[21];

// error reporting flag
if (~RST) ERFlag<=1'b1;
	else if (PortalCFGSTB & (PortalCFGAddr==6'h38)) ERFlag<=PortalCFG[20];
	
// reset portal
PortalRST<=RST & (~PortalMCESTB | ~SoEFlag);

// portal configuration register 38h
if (PortalCFGSTB & (PortalCFGAddr==6'h38)) PortalCFGReg38<=PortalCFG[15:0];

// portal state for to context controller
if (PortalCFGAddr==6'h3C) PortalState<={8'd0,PortalPSO};
	else if (PortalCFGAddr==6'h3B) PortalState<={12'd0,PortalCPL,2'd0,PortalTaskID};
		else PortalState<={16'd0,PortalCFGReg38};

end

endmodule
