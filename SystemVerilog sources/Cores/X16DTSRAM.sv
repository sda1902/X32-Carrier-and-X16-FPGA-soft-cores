module X16DTSRAM #(TCKScale=20, SRAMMode=1)(
	input wire EXTCLK, EXTRESET,
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
	
	// fatal error reporting
	output wire FATAL,
	output reg [1:0] EMPTY
	);

integer i;

reg RST;

// TE counter
reg [7:0] TECntReg;
reg TickFlag, FATALFlag, IntFlag, IntReqFlag, DIntReqFlag;

// common buses
logic [7:0] CPUBus;
logic [39:0] DTBASEBus;
logic [23:0] DTLIMITBus;
logic [23:0] CPSRBus [1:0];
logic [31:0] CSRBus [1:0];
logic [39:0] FREEMEMBus, CACHEDMEMBus;
logic [1:0] CPLBus [1:0];

logic CoreFlashNEXT, CoreFlashDRDY;
logic [63:0] CoreFlashDTO;
logic [20:0] CoreFlashTAGO;

logic EfifoVALID;
reg DEfifoVALID;
logic [63:0] EfifoECD;

logic TmuxFLACT, TmuxSDACT;
logic [4:0] TmuxLNEXT, TmuxLDRDY;
logic [63:0] TmuxLDATI;
logic [12:0] TmuxLTAGI;
logic [2:0] TmuxLSIZEI;
logic [23:0] TmuxINTSEL;
logic [15:0] TmuxINTLIMIT;
logic [3:0] TmuxNENA;
logic TmuxINTRST, TmuxINTENA, TmuxESRRD, TmuxCENA, TMuxMALOCKF;
logic [1:0] TmuxPTINTR, TmuxCPINTR;
logic [2:0] TmuxCPSRSTB [1:0];
logic [3:0] TmuxCSRSTB [1:0];
logic [1:0] TmuxLSIZEO [4:0];
logic [44:0] TmuxLADDR [4:0];
logic [63:0] TmuxLDATO [4:0];
logic [12:0] TmuxLTAGO [4:0];

logic SDCacheIDRDY;
logic [63:0] SDCacheIDATo;
logic [20:0] SDCacheITAGo;

logic CoreCLOAD, CoreACT, CoreCMD, CoreDRDY, CoreStreamNEXT, CoreNetNEXT, CoreStreamACT, CoreNetACT;
logic [1:0] CoreMSGREQ, CoreMALLOCREQ, CorePARREQ, CoreENDMSG, CoreBKPT, CoreHALT, CoreEMPTY, CoreESTB, CoreFATAL, CoreSMSGBKPT;
logic CoreFFTMemACT, CoreFFTNetACT, CoreFFTMemCMD, CoreFFTESTB;
logic [15:0] CoreTASKID [1:0];
logic [1:0] CoreOS;
logic [2:0] CoreSZi;
logic [44:0] CoreADDRESS;
logic [41:0] CoreFFTMemADDR;
logic [36:0] CoreOFFSET;
logic [36:0] CoreRIP [1:0];
logic [33:0] CoreFFTMemOFFSET;
logic [31:0] CoreSELECTOR, CoreFFTMemSEL;
logic [63:0] CoreDTo, CoreDTi, CoreCDATA, CoreFFTMemDO;
logic [63:0] CorePARAM [1:0];
logic [8:0] CoreTAGo, CoreTAGi;
logic [7:0] CoreFFTMemTO;
logic [3:0] CorePARREG [1:0];
logic [28:0] CoreECD [1:0]; 
logic [28:0] CoreFFTECD;
logic [23:0] CoreFFTCPSR;
reg CEXECFlag, CEXECReg, CSTOPFlag, HFCoreHaltReg, ESMSGFlag, ESMSGReg, CONTINUEReg, CONTINUEFlag;
logic [1:0] CoreNPCS;
logic [3:0] CoreIV [1:0];
logic [23:0] CoreCSEL [1:0];

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
logic [8:0] FpuCORETAGO, FpuCORETAGI;
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
logic [8:0] StreamCoreTAGI, StreamCoreTAGO;
logic [2:0] StreamCoreSIZEO;
logic [1:0] StreamSIZEO;
logic [44:0] StreamADDR;
logic [4:0] StreamTAGO;

logic [1:0] ContACT, ContCMD;
logic [2:0] ContEUSZi;
logic [44:0] ContADDR [1:0];
logic [1:0] ContSIZE [1:0];
logic [8:0] ContTAGo [1:0];
logic [63:0] ContDTo [1:0];
logic [63:0] ContEUDTi;
logic [8:0] ContEUTAGi;
logic ContEUNEXT, ContEUDRDY, ContEURD, ContNETMSGREQ, ContRST, ContREADY, ContESTB;
logic [1:0] ContEUCLOAD, ContCORESTOP, ContCONTINUE, ContEURESTART, ContMSGACK, ContLIRESET;
logic [6:0] ContRA;
logic [31:0] ContNETMSGPAR, ContERC;

logic MsgrRST, MsgrNETREQ, MsgrNETMSGRD;
logic MsgrACT, MsgrCMD;
logic MsgrNETSEND, MsgrNETTYPE;
logic [1:0] MsgrEUHALT, MsgrContextREQ, MsgrContextCHK;
logic MsgrESTB;
logic [1:0] MsgrEUCONTINUE, MsgrEURESTART;
logic [1:0] MsgrSIZE;
logic [31:0] MsgrDATO;
logic [63:0] MsgrERRC;
logic [95:0] MsgrContextMSG [1:0];
logic [79:0] MsgrNETMSG;
logic [44:0] MsgrADDR;
logic [4:0] MsgrNETSTAT;

//=====================================================================================================================
//				Flash controller (internal buffer and external SPI)
Flash16  CoreFlash (.CLKH(EXTCLK), .RESET(RST), .NEXT(CoreFlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(CoreFlashDRDY), .DTO(CoreFlashDTO), .TAGO(CoreFlashTAGO),
				// interface to the external memory
				.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));

//=====================================================================================================================
//				ERROR FIFO system
extern module ErrorFIFODT (
	input wire CLK, RESET,
	input wire [23:0] CPSR [1:0],
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire [1:0] CoreSTB,
	input wire [28:0] CoreECD [1:0],
	// error interface from FFT coprocessor
	input wire FFTSTB,
	input wire [28:0] FFTECD,
	input wire [23:0] FFTCPSR,
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
ErrorFIFODT Efifo(.CLK(EXTCLK), .RESET(RST), .CPSR(CPSRBus),
				// read fifo interface
				.ERD(TmuxESRRD & EfifoVALID), .VALID(EfifoVALID), .ECD(EfifoECD),
				// error interface from core
				.CoreSTB(CoreESTB), .CoreECD(CoreECD),
				// error interface from FFT coprocessor
				.FFTSTB(CoreFFTESTB), .FFTECD(CoreFFTECD), .FFTCPSR(CoreFFTCPSR),
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
// 1 - network
// 2 - stream
// 3 - context controller channel (MCU)
// 4 - Message processor
extern module MUX64DT (
	input CLK, RESETn,

	output wire [4:0]	LNEXT,
	input wire [4:0]	LACT,
	input wire [4:0]	LCMD,
	input wire [1:0] LSIZEO [4:0],
	input wire [44:0] LADDR [4:0],
	input wire [63:0] LDATO [4:0],
	input wire [12:0] LTAGO [4:0],
	output reg [4:0] LDRDY,
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
	output reg [7:0] CPUNUM,
	output reg [3:0] NENA,
	output reg INTRST, INTENA, ESRRD, CENA, MALOCKF,
	output reg [1:0] PTINTR, CPINTR,
	input wire [3:0] NLE, NERR,
	input wire [31:0] CSR [1:0],
	input wire [23:0] CPSR [1:0],
	input wire [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] ESR,
	output wire [2:0] CPSRSTB [1:0],
	output wire [3:0] CSRSTB [1:0],
	input wire SINIT,
	input wire NINIT,
	input wire CINIT,
	input wire TCK,
	input wire [1:0] TCKOVR,
	input wire [1:0] HALT,
	// performance data source
	input wire [3:0] IV [1:0],
	input wire [23:0] CSEL [1:0],
	input wire [1:0] EMPTY,
	input wire [7:0] TCKScaler,
	input wire [7:0] CoreType
	);
MUX64DT Tmux(.CLK(EXTCLK), .RESETn(RST), 
			// services interface
			.LNEXT(TmuxLNEXT),
			.LACT({MsgrACT, ContACT[1], StreamACT, FpuACT, ContACT[0]}),
			.LCMD({MsgrCMD, ContCMD[1], StreamCMD, FpuCMD, ContCMD[0]}),
			.LSIZEO(TmuxLSIZEO), .LADDR(TmuxLADDR), .LDATO(TmuxLDATO),
			.LTAGO(TmuxLTAGO),
			.LDRDY(TmuxLDRDY), .LDATI(TmuxLDATI), .LTAGI(TmuxLTAGI), .LSIZEI(TmuxLSIZEI),
			// local memory interface
			.CMD(CMD), .ADDR(ADDR), .DATA(DATA), .BE(BE), .TAG(TAG),
			.FLNEXT(CoreFlashNEXT), .FLACT(TmuxFLACT), .FLDRDY(CoreFlashDRDY), .FLDAT(CoreFlashDTO), .FLTAG(CoreFlashTAGO),
			.SDNEXT(1'b1), .SDACT(TmuxSDACT), .SDDRDY(SDCacheIDRDY), .SDDAT(SDCacheIDATo), .SDTAG(SDCacheITAGo),
			.IONEXT(IONEXT), .IOACT(IOACT), .IODRDY(IODRDY), .IODAT(IODAT), .IOTAG(IOTAG),
			// status and control lines and buses
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .INTSEL(TmuxINTSEL), .INTLIMIT(TmuxINTLIMIT), .CPUNUM(CPUBus), .NENA(TmuxNENA), .INTRST(TmuxINTRST),
			.INTENA(TmuxINTENA), .ESRRD(TmuxESRRD), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR), .CPINTR(TmuxCPINTR), .NLE(4'd0), .NERR(4'd0),
			.CSR(CSRBus), .CPSR(CPSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .ESR({EfifoECD[63:56] & {8{EfifoVALID}},EfifoECD[55:0]}),
			.CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB), .SINIT(StreamINIT), .NINIT(FpuINIT), .CINIT(ContREADY), .TCK(TickFlag), .TCKOVR(CoreNPCS), .HALT(CoreHALT),
			.IV(CoreIV), .CSEL(CoreCSEL), .EMPTY(CoreEMPTY), .TCKScaler(TCKScale), .CoreType(8'd8));

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
	
//=====================================================================================================================
// 				CORE UNIT
extern module EU64V0T2 (
	input wire CLK, RESET,
	input wire [7:0] CPU,
	input wire [15:0] TASKID [1:0],
	input wire [23:0] CPSR [1:0],
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
	// FFT memory interface
	input wire FFTMemNEXT, FFTNetNEXT,
	output wire FFTMemACT, FFTNetACT, FFTMemCMD,
	output wire [41:0] FFTMemADDR,
	output wire [33:0] FFTMemOFFSET,
	output wire [31:0] FFTMemSEL,
	output wire [63:0] FFTMemDO,
	output wire [7:0] FFTMemTO,
	// interface to the descriptor pre-loading system
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [1:0] CPL [1:0],
	// interface to message control subsystem
	output wire [63:0] PARAM [1:0],
	output wire [3:0] PARREG [1:0],
	output wire [1:0] MSGREQ, MALLOCREQ, PARREQ, ENDMSG, BKPT, HALT, FATAL, NPCS, SMSGBKPT,
	output reg [1:0] EMPTY,
	input wire [1:0] CLOAD, CEXEC, ESMSG, CONTINUE, CSTOP, LIRESET,
	// context store interface
	input wire [6:0] RA,
	output reg [63:0] CDATA,
	output wire [36:0] RIP [1:0],
	// error reporting interface
	output wire [1:0] ESTB,
	output wire [28:0] ECD [1:0],
	// FFT engine error report interface
	output wire FFTESTB,
	output wire [28:0] FFTECD,
	output wire [23:0] FFTCPSR,
	// Performance monitor outputs
	output reg [3:0] IV [1:0],
	output wire [23:0] CSEL [1:0]
	);
EU64V0T2  Core(.CLK(EXTCLK), .RESET(RST), .CPU(CPUBus), .TASKID(CoreTASKID), .CPSR(CPSRBus),
				// interface to datapatch of memory subsystem
				.NEXT(ContEUNEXT), .StreamNEXT(CoreStreamNEXT), .NetNEXT(CoreNetNEXT), .ACT(CoreACT), .StreamACT(CoreStreamACT), .NetACT(CoreNetACT), .CMD(CoreCMD), 
				.OS(CoreOS), .ADDRESS(CoreADDRESS), .OFFSET(CoreOFFSET), .SELECTOR(CoreSELECTOR), .DTo(CoreDTo), .TAGo(CoreTAGo), .DRDY(CoreDRDY), .TAGi(CoreTAGi),
				.SZi(CoreSZi), .DTi(CoreDTi),
				// FFT memory interface
				.FFTMemNEXT(ContEUNEXT & ~CoreACT & ~ContEUCLOAD[1] & ~ContEUCLOAD[0]), .FFTNetNEXT(CoreNetNEXT & ~CoreNetACT), .FFTMemACT(CoreFFTMemACT), .FFTNetACT(CoreFFTNetACT),
				.FFTMemCMD(CoreFFTMemCMD), .FFTMemADDR(CoreFFTMemADDR), .FFTMemOFFSET(CoreFFTMemOFFSET), .FFTMemSEL(CoreFFTMemSEL), .FFTMemDO(CoreFFTMemDO),
				.FFTMemTO(CoreFFTMemTO),
				// interface to the descriptor pre-loading system
				.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPL(CPLBus),
				// interface to message control subsystem
				.PARAM(CorePARAM), .PARREG(CorePARREG), .MSGREQ(CoreMSGREQ), .MALLOCREQ(CoreMALLOCREQ), .PARREQ(CorePARREQ), .ENDMSG(CoreENDMSG), .BKPT(CoreBKPT),
				.HALT(CoreHALT), .FATAL(CoreFATAL), .NPCS(CoreNPCS), .SMSGBKPT(CoreSMSGBKPT), .EMPTY(CoreEMPTY), .CLOAD(ContEUCLOAD), .CEXEC(ContEURESTART | MsgrEURESTART),
				.ESMSG(MsgrEUCONTINUE), .CONTINUE(ContCONTINUE), .CSTOP({(MsgrEUHALT[1] | ContCORESTOP[1]),(MsgrEUHALT[0] | ContCORESTOP[0] | IntFlag)}), .LIRESET(ContLIRESET),
				// context store interface
				.RA(ContRA), .CDATA(CoreCDATA), .RIP(CoreRIP),
				// error reporting interface
				.ESTB(CoreESTB), .ECD(CoreECD),
				// FFT engine error report interface
				.FFTESTB(CoreFFTESTB), .FFTECD(CoreFFTECD), .FFTCPSR(CoreFFTCPSR),
				// Performance monitor outputs
				.IV(CoreIV), .CSEL(CoreCSEL)
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
sc_fifo	StreamDFifo(.data({StreamCoreSIZEO, StreamCoreTAGO, StreamCoreDTO}), .wrreq(StreamCoreDRDY), .rdreq(StreamDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(StreamDFifoDO), .empty(StreamDFifoEMPTY));
defparam StreamDFifo.LPM_WIDTH=76, StreamDFifo.LPM_NUMWORDS=16, StreamDFifo.LPM_WIDTHU=4;

// data fifo for network datapatch
sc_fifo	NetDFifo(.data({FpuCORESIZEI, FpuCORETAGI, FpuCOREDTI}), .wrreq(FpuCOREDRDY), .rdreq(NetDFifoRSTB), .clock(EXTCLK), .sclr(~RST),
					.q(NetDFifoDO), .empty(NetDFifoEMPTY));
defparam NetDFifo.LPM_WIDTH=76, NetDFifo.LPM_NUMWORDS=16, NetDFifo.LPM_WIDTHU=4;

//=====================================================================================================================
// 				NETWORK SYSTEM
extern module FPUDT (
	// global
	input wire CLK, RESETn, TCK,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [15:0] TASKID [1:0],
	input wire [23:0] CPSR [1:0],
	output wire INIT,
	// interface from core
	output wire CORENEXT,
	input wire COREACT, CORECMD,
	input wire [1:0] CORESIZE,
	input wire [1:0] CORECPL [1:0],
	input wire [36:0] COREOFFSET,
	input wire [31:0] CORESEL,
	input wire [63:0] COREDTO,
	input wire [8:0] CORETAGO,
	output reg COREDRDY,
	output reg [63:0] COREDTI,
	output reg [8:0] CORETAGI,
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
FPUDT Fpu(.CLK(EXTCLK), .RESETn(RST), .TCK(TickFlag), .DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .TASKID(CoreTASKID), .CPSR(CPSRBus), .INIT(FpuINIT),
		// interface to core
		.CORENEXT(FpuCORENEXT), .COREACT(FpuCOREACT), .CORECMD(FpuCORECMD), .CORESIZE(FpuCORESIZE), .CORECPL(CPLBus), .COREOFFSET(FpuCOREOFFSET), 
		.CORESEL(FpuCORESEL), .COREDTO(FpuCOREDTO), .CORETAGO(FpuCORETAGO), .COREDRDY(FpuCOREDRDY), .COREDTI(FpuCOREDTI), .CORETAGI(FpuCORETAGI), .CORESIZEI(FpuCORESIZEI),
		// local memory interface
		.NEXT(TmuxLNEXT[1]), .SNEXT(StreamNetNEXT), .ACT(FpuACT), .SACT(FpuSACT), .CMD(FpuCMD), .SIZEO(FpuSIZEO), .ADDR(FpuADDR), .DTO(FpuDTO), .TAGO(FpuTAGO), .SEL(FpuSEL),
		.DRDY(TmuxLDRDY[1]), .DTI(TmuxLDATI), .SIZEI(TmuxLSIZEI[1:0]), .TAGI(TmuxLTAGI),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT), .STONEW(FpuSTONEW), .STOVAL(), .STODT(FpuSTODT), .STINEXT(FpuSTINEXT), .STIVAL(RteSTIVAL), .STINEW(RteSTINEW), .STIDT(RteSTIDT),
		// messages interface
		.MSGREQ(FpuMSGREQ), .MSGRD(MsgrNETMSGRD), .MSGDATA(FpuMSGDATA), 
		.MSGNEXT(FpuMSGNEXT), .MSGSEND(MsgrNETSEND), .MSGTYPE(MsgrNETTYPE), .MSGPARAM(MsgrNETMSG), .MSGSTAT(MsgrNETSTAT),
		// error report interface
		.ESTB(FpuESTB), .ECD(FpuECD));

// Network interface TFIFO
TFifoS	FpuTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreNetACT | CoreFFTNetACT), .NEXTH(FpuCORENEXT), .NEXTL(CoreNetNEXT), .ACTH(FpuCOREACT),
					.DI(CoreNetACT ? {CoreCMD, CoreTAGo, CoreOS, CoreOFFSET, CoreSELECTOR, CoreDTo}:{CoreFFTMemCMD, CoreFFTMemTO, 2'b11, CoreFFTMemOFFSET, 3'd0, CoreFFTMemSEL, CoreFFTMemDO}),
					.DO({FpuCORECMD, FpuCORETAGO, FpuCORESIZE, FpuCOREOFFSET, FpuCORESEL, FpuCOREDTO}));
defparam FpuTFifo.Width=145;

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
extern module StreamController32 (
	input wire CLK, RESET, TE,
	input wire [39:0] DTBASE,
	output wire INIT,
// Core interface
	output wire CoreNEXT,
	input wire CoreACT, CoreCMD, CoreADDR,
	input wire [23:0] CoreSEL,
	input wire [63:0] CoreDTI,
	input wire [8:0] CoreTAGI,
	output reg CoreDRDY,
	output reg [63:0] CoreDTO,
	output reg [8:0] CoreTAGO,
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
StreamController32 Stream(.CLK(EXTCLK), .RESET(RST), .TE(TickFlag), .DTBASE(DTBASEBus), .INIT(StreamINIT),
						// Core interface
						.CoreNEXT(StreamCoreNEXT), .CoreACT(StreamCoreACT), .CoreCMD(StreamCoreCMD), .CoreADDR(StreamCoreADDR), .CoreSEL(StreamCoreSEL), .CoreDTI(StreamCoreDTI), .CoreTAGI(StreamCoreTAGI),
						.CoreDRDY(StreamCoreDRDY), .CoreDTO(StreamCoreDTO), .CoreTAGO(StreamCoreTAGO), .CoreSIZEO(StreamCoreSIZEO),
						// network interface
						.NetNEXT(StreamNetNEXT), .NetACT(FpuSACT), .NetSEL(FpuSEL), .NetDATA(FpuDTO),
						// local memory interface
						.NEXT(TmuxLNEXT[2]), .ACT(StreamACT), .CMD(StreamCMD), .SIZEO(StreamSIZEO), .ADDR(StreamADDR), .DTO(StreamDTO), .TAGO(StreamTAGO),
						.DRDY(TmuxLDRDY[2]), .DTI(TmuxLDATI), .TAGI(TmuxLTAGI[4:0]));

TFifoS	StreamTFifo(.CLK(EXTCLK), .RESET(RST), .ACTL(CoreStreamACT), .NEXTH(StreamCoreNEXT), .NEXTL(CoreStreamNEXT), .ACTH(StreamCoreACT),
					.DI({CoreOFFSET[0], CoreCMD, CoreTAGo, CoreSELECTOR[23:0], CoreDTo}),
					.DO({StreamCoreADDR, StreamCoreCMD, StreamCoreTAGI, StreamCoreSEL, StreamCoreDTI}));
defparam StreamTFifo.Width=99;

//=====================================================================================================================
//				CONTEXT CONTROLLER
extern module ContextCTRLDT ( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF,
	input wire [1:0] PTINTR, CPINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	output reg  RST, READY,						// hardware reset and ready signal
	output reg [23:0] CPSR [1:0],				// current process selector register
	output reg [31:0] CSR [1:0],				// current core state register
	output reg [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] EXTDI,
	input wire [2:0] CPSRSTB [1:0],
	input wire [3:0] CSRSTB [1:0],
	input wire [36:0] RIP [1:0],						// real ip
	// 2-channel interface to memory system
	input wire [1:0] NEXT,
	output logic [1:0] ACT,CMD,
	output logic [44:0] ADDR[1:0],
	output logic [1:0] SIZE[1:0],
	output logic [8:0] TAGo[1:0],
	output logic [63:0] DTo[1:0],
	input wire [1:0] DRDY,
	input wire [63:0] DTi,
	input wire [8:0] TAGi,
	input wire [2:0] SZi,
	// interface to messages controller
	output reg [1:0] MSGACK,
	input wire [1:0] MSGREQ, CHKREQ,
	input wire [95:0] MSGPARAM [1:0],
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
	input wire [1:0] MALLOCREQ, GETPARREQ, EUEMPTY, EUENDMSG, SMSGBKPT,
	input wire [63:0] EUPARAM [1:0],
	input wire [3:0] EUREG [1:0],
	output reg [1:0] CORESTART, CORESTOP, CORECONT, EUCLOAD, LIRESET,
	// context load/store interface to EU
	output wire [6:0] RA,
	input wire [63:0] CDAT,
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC
);
ContextCTRLDT Cont(.CLK(EXTCLK), .RESETn(RST), .CENA(TmuxCENA), .MALOCKF(TMuxMALOCKF), .PTINTR(TmuxPTINTR), .CPINTR(TmuxCPINTR),
				.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .RST(ContRST), .READY(ContREADY),
				.CPSR(CPSRBus), .CSR(CSRBus), .FREEMEM(FREEMEMBus), .CACHEDMEM(CACHEDMEMBus), .EXTDI(DATA), .CPSRSTB(TmuxCPSRSTB),
				.CSRSTB(TmuxCSRSTB), .RIP(CoreRIP),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT[3], TmuxLNEXT[0]}), .ACT(ContACT), .CMD(ContCMD), .ADDR(ContADDR), .SIZE(ContSIZE), .TAGo(ContTAGo), .DTo(ContDTo),
				.DRDY({TmuxLDRDY[3], TmuxLDRDY[0]}), .DTi(TmuxLDATI), .TAGi(TmuxLTAGI[8:0]), .SZi(TmuxLSIZEI),
				// interface to messages controller
				.MSGACK(ContMSGACK), .MSGREQ(MsgrContextREQ), .CHKREQ(MsgrContextCHK), .MSGPARAM(MsgrContextMSG),
				// low-speed memory interface from EU
				.EUNEXT(ContEUNEXT), .EUACT(CoreACT | (CoreFFTMemACT & ~(|ContEUCLOAD))), .EUCMD(CoreACT ? CoreCMD : CoreFFTMemCMD), .EUSZo(CoreACT ? CoreOS : 2'b11), 
				.EUADDR(CoreACT ? CoreADDRESS : {CoreFFTMemADDR, 3'd0}), .EUDTo(CoreACT ? CoreDTo : CoreFFTMemDO), .EUTAGo(CoreACT ? CoreTAGo : {1'b0,CoreFFTMemTO}),
				.EUDRDY(ContEUDRDY), .EUTAGi(ContEUTAGi), .EUSZi(ContEUSZi), .EUDTi(ContEUDTi), .EURD(ContEURD),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ), .GETPARREQ(CorePARREQ), .EUPARAM(CorePARAM), .EUREG(CorePARREG), .EUEMPTY(CoreEMPTY), .EUENDMSG(CoreENDMSG),
				.SMSGBKPT(CoreSMSGBKPT), .CORESTART(ContEURESTART), .CORESTOP(ContCORESTOP), .CORECONT(ContCONTINUE), .EUCLOAD(ContEUCLOAD), .LIRESET(ContLIRESET),
				// context load/store interface to EU
				.RA(ContRA), .CDAT(CoreCDATA),
				// error reporting interface
				.ESTB(ContESTB), .ERC(ContERC)
				);

//=====================================================================================================================
//				MESSAGE CONTROLLER DECLARATION
extern module MessengerDT (
	input wire CLK, RESETn,
	output reg RST,
	// message interface from EU, error system, interrupt system and network system
	input wire [1:0] EUREQ,
	input wire ERRORREQ, INTREQ, NETREQ,
	input wire [63:0] EUPARAM [1:0],		// Message index for import table in the current PSO and parameter dword
	input wire [15:0] INTPARAM,		// Interrupt index
	input wire [121:0] NETPARAM,	// BUS(msb:lsb): CPL[121:120], Target PSO[119:96], TaskID[95:80], ProcINDX[79:64], Parameter[63:32], SourcePSO[31:0]
	output reg NETMSGRD,
	output reg INTACK,
	// interface to memory system
	input wire NEXT,
	output wire ACT, CMD,
	output wire [44:0] ADDR,
	output wire [1:0] SIZE,
	output wire [31:0] DATO,
	input wire DRDY,
	input wire [31:0] DATI,
	// interface to the context controller (interrupt, error or procedure)
	input wire [1:0] ContextRDY,
	output reg [1:0] ContextREQ, ContextCHK,
	output wire [95:0] ContextMSG [1:0],
	// interface to network controller
	input wire NETRDY,
	output reg NETSEND,
	output reg NETTYPE,
	output wire [79:0] NETMSG,
	output reg [4:0] NETSTAT,
	// DTR and DTL registers
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [23:0] CPSR [1:0],
	input logic [23:0] INTSR,			// selector IT
	input logic [15:0] INTCR,			// Length of IT
	input logic [31:0] CSR [1:0],
	// core control lines 
	output reg [1:0] EUCONTINUE, EURESTART,
	output reg [1:0] EUHALT,
	input wire [1:0] BKPT, MSGBKPT, EMPTY,
	// error reporting interface
	output reg ESTB,
	output reg [63:0] ERRC
	);
MessengerDT Msgr(.CLK(EXTCLK), .RESETn(RST), .RST(MsgrRST),
			// message interface from EU, error system, interrupt system and network system
			.EUREQ(CoreMSGREQ), .ERRORREQ(EfifoVALID & ~DEfifoVALID),
			.INTREQ(IntReqFlag), .NETREQ(FpuMSGREQ), .EUPARAM(CorePARAM), .INTPARAM(INTCODE),
			.NETPARAM(FpuMSGDATA), .NETMSGRD(MsgrNETMSGRD), .INTACK(INTACK),
			// interface to memory system
			.NEXT(TmuxLNEXT[4]), .ACT(MsgrACT), .CMD(MsgrCMD), .ADDR(MsgrADDR), .SIZE(MsgrSIZE), .DATO(MsgrDATO), .DRDY(TmuxLDRDY[4]), .DATI(TmuxLDATI[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContMSGACK), .ContextREQ(MsgrContextREQ), .ContextCHK(MsgrContextCHK), .ContextMSG(MsgrContextMSG),
			// interface to network controller
			.NETRDY(FpuMSGNEXT), .NETSEND(MsgrNETSEND), .NETTYPE(MsgrNETTYPE), .NETMSG(MsgrNETMSG), .NETSTAT(MsgrNETSTAT),
			// DTR and DTL registers
			.DTBASE(DTBASEBus), .DTLIMIT(DTLIMITBus), .CPUNUM(CPUBus), .CPSR(CPSRBus), .INTSR(TmuxINTSEL), .INTCR(TmuxINTLIMIT), .CSR(CSRBus),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE), .EURESTART(MsgrEURESTART), .EUHALT(MsgrEUHALT), .BKPT(CoreBKPT), .MSGBKPT(CoreSMSGBKPT), .EMPTY(CoreEMPTY),
			// error reporting interface
			.ESTB(MsgrESTB), .ERRC(MsgrERRC)
			);

//=================================================================================================
//		assignments
//=================================================================================================

assign CoreTASKID[0]=CSRBus[0][15:0];
assign CoreTASKID[1]=CSRBus[1][15:0];

assign CPLBus[0]=CSRBus[0][19:18];
assign CPLBus[1]=CSRBus[1][19:18];

assign TmuxLSIZEO[4]=MsgrSIZE;
assign TmuxLSIZEO[3]=ContSIZE[1];
assign TmuxLSIZEO[2]=StreamSIZEO;
assign TmuxLSIZEO[1]=FpuSIZEO;
assign TmuxLSIZEO[0]=ContSIZE[0];

assign TmuxLADDR[4]=MsgrADDR;
assign TmuxLADDR[3]=ContADDR[1];
assign TmuxLADDR[2]=StreamADDR;
assign TmuxLADDR[1]=FpuADDR;
assign TmuxLADDR[0]=ContADDR[0];

assign TmuxLDATO[4]={32'd0, MsgrDATO};
assign TmuxLDATO[3]=ContDTo[1];
assign TmuxLDATO[2]=StreamDTO;
assign TmuxLDATO[1]=FpuDTO;
assign TmuxLDATO[0]=ContDTo[0];

assign TmuxLTAGO[4]=13'd0;
assign TmuxLTAGO[3]={4'd0, ContTAGo[1]};
assign TmuxLTAGO[2]={7'd0, StreamTAGO};
assign TmuxLTAGO[1]=FpuTAGO;
assign TmuxLTAGO[0]={4'd0, ContTAGo[0]};

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

assign FATAL=FATALFlag;

//=================================================================================================
//		synchronous 
//=================================================================================================
always_ff @(posedge EXTCLK)
begin

// reset filtering
RST<=EXTRESET & MsgrRST & ContRST;

// timing intervals for stream controller
TECntReg<=(TECntReg+8'd1) & {8{RST & ~TickFlag}};
TickFlag<=(TECntReg==(TCKScale-2)) & RST;

// delayed EFIFO flag
DEfifoVALID<=EfifoVALID & RST;

// interrupt flag
IntFlag<=(IntFlag | INTREQ) & ~INTACK & RST & TmuxINTENA;
IntReqFlag<=IntFlag & CoreEMPTY[0] & ~CoreSMSGBKPT[0]  & RST & ~DIntReqFlag & CoreHALT[0];
DIntReqFlag<=(DIntReqFlag | IntReqFlag) & RST & IntFlag;

// Fatal
FATALFlag<=(|CoreFATAL);

EMPTY<=CoreEMPTY;

end

endmodule
