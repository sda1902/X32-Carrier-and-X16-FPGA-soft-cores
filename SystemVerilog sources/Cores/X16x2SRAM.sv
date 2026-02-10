module X16x2SRAM #(TCKScale=20, SRAMMode_A=1, SRAMMode_B=1)(
	input wire CLK, RESET,

	// internal memory interface
	output wire CMD_A, CMD_B,
	output wire [44:0] ADDR_A, ADDR_B,
	output wire [63:0] DATA_A, DATA_B,
	output wire [7:0] BE_A, BE_B,
	output wire [20:0] TAG_A, TAG_B,
	
	input wire IONEXT_A, IONEXT_B,
	output wire IOACT_A, IOACT_B,
	input wire IODRDY_A, IODRDY_B,
	input wire [63:0] IODAT_A, IODAT_B,
	input wire [20:0] IOTAG_A, IOTAG_B,

	// SPI Flash interface
	output wire SPICK,
	output wire SPIRST,
	output wire SPICS,
	output wire SPISO,
	input wire SPISI,

	// network interface
	output wire STBO_NW, STBO_NE,
	output wire [32:0] NETDO_NW, NETDO_NE,
	output wire STBO_E,
	output wire [32:0] NETDO_E,
	output wire STBO_SW, STBO_SE,
	output wire [32:0] NETDO_SW, NETDO_SE,
	output wire STBO_W,
	output wire [32:0] NETDO_W,
	input wire STBI_NW, STBI_NE,
	input wire [32:0] NETDI_NW, NETDI_NE,
	input wire STBI_E,
	input wire [32:0] NETDI_E,
	input wire STBI_SW, STBI_SE,
	input wire [32:0] NETDI_SW, NETDI_SE,
	input wire STBI_W,
	input wire [32:0] NETDI_W,
	
	// interrupt interface
	output wire INTACK_A, INTACK_B,
	input wire INTREQ_A, INTREQ_B,
	input wire [15:0] INTCODE_A, INTCODE_B
);

logic [7:0] CPUBus_A, CPUBus_B;
reg EXTRESET, RST_A, RST_B, TickFlag, DEfifoVALID_A, DEfifoVALID_B;
reg [7:0] TECntReg;
reg IntFlag_A, IntFlag_B, IntReqFlag_A, IntReqFlag_B, DIntReqFlag_A, DIntReqFlag_B;

//-----------------------------------------------
//				Core unit resources
logic CoreACT_A, CoreStreamACT_A, CoreNetACT_A, CoreACTH_A, CoreCMD_A, CoreStreamACTH_A, CoreNPCS_A;
logic [1:0] CoreOS_A;
logic [44:0] CoreADDRESS_A;
logic [36:0] CoreOFFSET_A;
logic [31:0] CoreSELECTOR_A;
logic [63:0] CoreDTo_A;
logic [7:0] CoreTAGo_A;
logic CoreFFTMemACT_A, CoreFFTMemCMD_A;
logic [41:0] CoreFFTMemADDR_A;
logic [63:0] CoreFFTMemDO_A;
logic [7:0] CoreFFTMemTO_A;
logic [63:0] CorePARAM_A;
logic [3:0] CorePARREG_A;
logic CoreMSGREQ_A, CoreMALLOCREQ_A, CorePARREQ_A, CoreENDMSG_A, CoreBKPT_A, CoreEMPTY_A, CoreHALT_A, CoreSMSGBKPT_A;
logic [63:0] CoreCDATA_A;
logic [36:0] CoreRIP_A;
logic CoreESTB_A;
logic [28:0] CoreECD_A;
logic CoreMuxDRDY_A, CoreMuxLocalRD_A;
logic [2:0] CoreMuxSZi_A;
logic [7:0] CoreMuxTAGi_A;
logic [63:0] CoreMuxDTi_A;
logic CoreFATAL_A;
logic CoreFFTESTB_A;
logic [28:0] CoreFFTECD_A;
logic [23:0] CoreFFTCPSR_A;
logic [3:0] CoreIV_A;
logic [23:0] CoreCSEL_A;

logic CoreACT_B, CoreStreamACT_B, CoreNetACT_B, CoreACTH_B, CoreCMD_B, CoreStreamACTH_B, CoreNPCS_B;
logic [1:0] CoreOS_B;
logic [44:0] CoreADDRESS_B;
logic [36:0] CoreOFFSET_B;
logic [31:0] CoreSELECTOR_B;
logic [63:0] CoreDTo_B;
logic [7:0] CoreTAGo_B;
logic CoreFFTMemACT_B, CoreFFTMemCMD_B;
logic [41:0] CoreFFTMemADDR_B;
logic [63:0] CoreFFTMemDO_B;
logic [7:0] CoreFFTMemTO_B;
logic [63:0] CorePARAM_B;
logic [3:0] CorePARREG_B;
logic CoreMSGREQ_B, CoreMALLOCREQ_B, CorePARREQ_B, CoreENDMSG_B, CoreBKPT_B, CoreEMPTY_B, CoreHALT_B, CoreSMSGBKPT_B;
logic [63:0] CoreCDATA_B;
logic [36:0] CoreRIP_B;
logic CoreESTB_B;
logic [28:0] CoreECD_B;
logic CoreMuxDRDY_B, CoreMuxLocalRD_B;
logic [2:0] CoreMuxSZi_B;
logic [7:0] CoreMuxTAGi_B;
logic [63:0] CoreMuxDTi_B;
logic CoreFATAL_B;
logic CoreFFTESTB_B;
logic [28:0] CoreFFTECD_B;
logic [23:0] CoreFFTCPSR_B;
logic [3:0] CoreIV_B;
logic [23:0] CoreCSEL_B;

//-----------------------------------------------
//				ErrorFIFO resources
logic EfifoVALID_A;
logic [63:0] EfifoECD_A;

logic EfifoVALID_B;
logic [63:0] EfifoECD_B;

//-----------------------------------------------
//				Bus MUX resources
logic [4:0] TmuxLNEXT_A, TmuxLDRDY_A;
logic [1:0] TmuxLSIZEO_A [4:0]; 
logic [44:0] TmuxLADDR_A [4:0];
logic [63:0] TmuxLDATO_A [4:0];
logic [12:0] TmuxLTAGO_A [4:0];
logic [63:0] TmuxLDATI_A;
logic [12:0] TmuxLTAGI_A;
logic [2:0] TmuxLSIZEI_A;
logic TmuxCoreNEXTH_A, TmuxCoreDRDYH_A, TmuxESTBH_A;
logic [36:0] TmuxECD_A;
logic TmuxFLACT_A;
logic [39:0] TmuxDTBASE_A;
logic [23:0] TmuxDTLIMIT_A, TmuxINTSEL_A;
logic [15:0] TmuxINTLIMIT_A;
logic [7:0] TmuxCPUNUM_A;
logic [3:0] TmuxNENA_A;
logic TmuxINTRST_A, TmuxINTENA_A, TmuxESRRD_A, TmuxCENA_A, TMuxMALOCKF_A, TmuxPTINTR_A, TmuxDTRESET_A, TmuxSDACT_A;
logic [2:0] TmuxCPSRSTB_A;
logic [3:0] TmuxCSRSTB_A;
logic [2:0] TmuxCPUSIZEO_A;
logic [7:0] TmuxCPUTAGO_A;
logic TmuxSACT_A;
logic [23:0] TmuxSSEL_A;
logic [63:0] TmuxSDATA_A;

logic [4:0] TmuxLNEXT_B, TmuxLDRDY_B;
logic [1:0] TmuxLSIZEO_B [4:0]; 
logic [44:0] TmuxLADDR_B [4:0];
logic [63:0] TmuxLDATO_B [4:0];
logic [12:0] TmuxLTAGO_B [4:0];
logic [63:0] TmuxLDATI_B;
logic [12:0] TmuxLTAGI_B;
logic [2:0] TmuxLSIZEI_B;
logic TmuxCoreNEXTH_B, TmuxCoreDRDYH_B, TmuxESTBH_B;
logic [36:0] TmuxECD_B;
logic TmuxFLACT_B;
logic [39:0] TmuxDTBASE_B;
logic [23:0] TmuxDTLIMIT_B, TmuxINTSEL_B;
logic [15:0] TmuxINTLIMIT_B;
logic [7:0] TmuxCPUNUM_B;
logic [3:0] TmuxNENA_B;
logic TmuxINTRST_B, TmuxINTENA_B, TmuxESRRD_B, TmuxCENA_B, TMuxMALOCKF_B, TmuxPTINTR_B, TmuxDTRESET_B, TmuxSDACT_B;
logic [2:0] TmuxCPSRSTB_B;
logic [3:0] TmuxCSRSTB_B;
logic [2:0] TmuxCPUSIZEO_B;
logic [7:0] TmuxCPUTAGO_B;
logic TmuxSACT_B;
logic [23:0] TmuxSSEL_B;
logic [63:0] TmuxSDATA_B;

//-----------------------------------------------
//				Cache resources
logic SDCacheINEXT_A, SDCacheIDRDY_A;
logic [63:0] SDCacheIDATo_A;
logic [20:0] SDCacheITAGo_A;

logic SDCacheINEXT_B, SDCacheIDRDY_B;
logic [63:0] SDCacheIDATo_B;
logic [20:0] SDCacheITAGo_B;


//-----------------------------------------------
//				Flash unit resources
logic FlashNEXT_A, FlashDRDY_A;
logic [63:0] FlashDTO_A;
logic [20:0] FlashTAGO_A;

logic FlashNEXT_B, FlashDRDY_B;
logic [63:0] FlashDTO_B;
logic [20:0] FlashTAGO_B;

//-----------------------------------------------
//			Context controller resources
logic ContextRST_A, ContextREADY_A;
logic [23:0] ContextCPSR_A;
logic [31:0] ContextCSR_A;
logic [39:0] ContextFREEMEM_A, ContextCACHEDMEM_A;
logic [1:0] ContextACT_A, ContextCMD_A;
logic [44:0] ContextADDR_A [1:0];
logic [1:0] ContextSIZE_A [1:0];
logic [7:0] ContextTAGo_A [1:0];
logic [63:0] ContextDTo_A [1:0];
logic ContextMSGACK_A, ContextEUNEXT_A, ContextEUDRDY_A;
logic [7:0] ContextEUTAGi_A;
logic [2:0] ContextEUSZi_A;
logic [63:0] ContextEUDTi_A;
logic ContextEURESTART_A, ContextCORESTOP_A, ContextCONTINUE_A, ContextEUCLOAD_A, ContextLIRESET_A;
logic [5:0] ContextRA_A;
logic ContextESTB_A;
logic [31:0] ContextERC_A;

logic ContextRST_B, ContextREADY_B;
logic [23:0] ContextCPSR_B;
logic [31:0] ContextCSR_B;
logic [39:0] ContextFREEMEM_B, ContextCACHEDMEM_B;
logic [1:0] ContextACT_B, ContextCMD_B;
logic [44:0] ContextADDR_B [1:0];
logic [1:0] ContextSIZE_B [1:0];
logic [7:0] ContextTAGo_B [1:0];
logic [63:0] ContextDTo_B [1:0];
logic ContextMSGACK_B, ContextEUNEXT_B, ContextEUDRDY_B;
logic [7:0] ContextEUTAGi_B;
logic [2:0] ContextEUSZi_B;
logic [63:0] ContextEUDTi_B;
logic ContextEURESTART_B, ContextCORESTOP_B, ContextCONTINUE_B, ContextEUCLOAD_B, ContextLIRESET_B;
logic [5:0] ContextRA_B;
logic ContextESTB_B;
logic [31:0] ContextERC_B;

//-----------------------------------------------
//				Messenger resources
logic MsgrRST_A, MsgrNETMSGRD_A, MsgrACT_A, MsgrCMD_A;
logic [44:0] MsgrADDR_A;
logic [1:0] MsgrSIZE_A;
logic [31:0] MsgrDATO_A;
logic MsgrContextREQ_A, MsgrContextCHK_A, MsgrNETSEND_A, MsgrNETTYPE_A;
logic [95:0] MsgrContextMSG_A;
logic [79:0] MsgrNETMSG_A;
logic [4:0] MsgrNETSTAT_A;
logic MsgrEUCONTINUE_A, MsgrEUHALT_A, MsgrESTB_A, MsgrEURESTART_A;
logic [63:0] MsgrERRC_A;

logic MsgrRST_B, MsgrNETMSGRD_B, MsgrACT_B, MsgrCMD_B;
logic [44:0] MsgrADDR_B;
logic [1:0] MsgrSIZE_B;
logic [31:0] MsgrDATO_B;
logic MsgrContextREQ_B, MsgrContextCHK_B, MsgrNETSEND_B, MsgrNETTYPE_B;
logic [95:0] MsgrContextMSG_B;
logic [79:0] MsgrNETMSG_B;
logic [4:0] MsgrNETSTAT_B;
logic MsgrEUCONTINUE_B, MsgrEUHALT_B, MsgrESTB_B, MsgrEURESTART_B;
logic [63:0] MsgrERRC_B;

//-----------------------------------------------
//				Stream controller resources
logic StreamINIT_A, StreamCoreNEXT_A, StreamCoreDRDY_A, StreamNetNEXT_A, StreamACT_A, StreamCMD_A;
logic StreamNEXTH_A;
logic [63:0] StreamCoreDTO_A, StreamDTO_A;
logic [7:0] StreamCoreTAGO_A;
logic [2:0] StreamCoreSIZEO_A;
logic [1:0] StreamSIZEO_A;
logic [44:0] StreamADDR_A;
logic [4:0] StreamTAGO_A;

logic StreamINIT_B, StreamCoreNEXT_B, StreamCoreDRDY_B, StreamNetNEXT_B, StreamACT_B, StreamCMD_B;
logic StreamNEXTH_B;
logic [63:0] StreamCoreDTO_B, StreamDTO_B;
logic [7:0] StreamCoreTAGO_B;
logic [2:0] StreamCoreSIZEO_B;
logic [1:0] StreamSIZEO_B;
logic [44:0] StreamADDR_B;
logic [4:0] StreamTAGO_B;

//-----------------------------------------------
//			FPU's resources
logic FPUCoreNEXT_A, FpuACT_A, FpuSACT_A, FpuCMD_A, FpuINIT_A, FpuSTINEXT_A, FpuSTONEW_A;
logic FpuCOREDRDY_A, FpuSTOSTB_A;
logic [63:0] FpuDTO_A;
logic [23:0] FpuSEL_A;
logic [63:0] FpuCOREDTI_A;
logic [7:0] FpuCORETAGI_A;
logic [2:0] FpuCORESIZEI_A;
logic FpuESTB_A;
logic [12:0] FpuECD_A;
logic FpuMSGREQ_A, FpuMSGNEXT_A;
logic [121:0] FpuMSGDATA_A;
logic [1:0] FpuSIZEO_A;
logic [44:0] FpuADDR_A;
logic [12:0] FpuTAGO_A;
logic [63:0] FpuSTODT_A;

logic FPUCoreNEXT_B, FpuACT_B, FpuSACT_B, FpuCMD_B, FpuINIT_B;
logic FpuCOREDRDY_B;
logic [63:0] FpuDTO_B;
logic [23:0] FpuSEL_B;
logic [63:0] FpuCOREDTI_B;
logic [7:0] FpuCORETAGI_B;
logic [2:0] FpuCORESIZEI_B;
logic FpuESTB_B;
logic [12:0] FpuECD_B;
logic FpuMSGREQ_B, FpuMSGNEXT_B;
logic [121:0] FpuMSGDATA_B;
logic [1:0] FpuSIZEO_B;
logic [44:0] FpuADDR_B;
logic [12:0] FpuTAGO_B;
logic FpuSTOSTB_B, FpuSTINEXT_B, FpuSTONEW_B;
logic [63:0] FpuSTODT_B;

//-----------------------------------------------
//				RTE resources
logic [3:0] RteEXTSTBO_A;
logic [32:0] RteEXTDO_A [3:0];
logic [3:0] RteEXTSTBI_A;
logic [32:0] RteEXTDI_A [3:0];
logic RteSTONEXT_A, RteSTINEW_A, RteSTIVAL_A;
logic [63:0] RteSTIDT_A;

logic [3:0] RteEXTSTBO_B;
logic [32:0] RteEXTDO_B [3:0];
logic [3:0] RteEXTSTBI_B;
logic [32:0] RteEXTDI_B [3:0];
logic RteSTONEXT_B, RteSTINEW_B, RteSTIVAL_B;
logic [63:0] RteSTIDT_B;

//=====================================================================================================================
//
// 				CORE UNITs
//
//=====================================================================================================================
extern module EU64S2 (
	input wire CLK, RESET, CLOAD,
	input wire [7:0] CPU,
	input wire [15:0] TASKID,
	input wire [23:0] CPSR,
	// interface to the descriptor pre-loading system
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire DTRESET,
	input wire [1:0] CPL,
	// descriptor tables for neighbourhood
	input wire [39:0] DTBASEH,
	input wire [23:0] DTLIMITH,
	input wire DTRESETH,
	// interface to datapatch of memory subsystem
	input wire NEXT, StreamNEXT, StreamNEXTH, NetNEXT, NEXTH,
	output reg ACT, StreamACT, StreamACTH, NetACT, ACTH, CMD, 
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
	// FFT memory interface
	input wire FFTMemNEXT,
	output wire FFTMemACT, FFTMemCMD,
	output wire [41:0] FFTMemADDR,
	output wire [63:0] FFTMemDO,
	output wire [7:0] FFTMemTO,
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
	// FFT engine error report interface
	output wire FFTESTB,
	output wire [28:0] FFTECD,
	output wire [23:0] FFTCPSR,
	// test purpose pins
	output wire FATAL,
	// Performance monitor outputs
	output reg [3:0] IV,
	output wire [23:0] CSEL
	);

// CORE A (North-West)
EU64S2  Core_A(.CLK(CLK), .RESET(RST_A), .CLOAD(ContextEUCLOAD_A), .CPU(CPUBus_A), .TASKID(ContextCSR_A[15:0]), .CPSR(ContextCPSR_A),
			.DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .DTRESET(TmuxDTRESET_A), .CPL(ContextCSR_A[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_B), .DTLIMITH(TmuxDTLIMIT_B), .DTRESETH(TmuxDTRESET_B),
			// memory, stream and network interfaces
			.NEXT(ContextEUNEXT_A), .StreamNEXT(StreamCoreNEXT_A), .StreamNEXTH(StreamNEXTH_B),
			.NetNEXT(FPUCoreNEXT_A), .NEXTH(TmuxCoreNEXTH_B),
			.ACT(CoreACT_A), .StreamACT(CoreStreamACT_A), .StreamACTH(CoreStreamACTH_A),
			.NetACT(CoreNetACT_A), .ACTH(CoreACTH_A),
			.CMD(CoreCMD_A), .OS(CoreOS_A), .ADDRESS(CoreADDRESS_A), .OFFSET(CoreOFFSET_A), .SELECTOR(CoreSELECTOR_A), .DTo(CoreDTo_A), .TAGo(CoreTAGo_A),
			.DRDY(CoreMuxDRDY_A), .TAGi(CoreMuxTAGi_A), .SZi(CoreMuxSZi_A), .DTi(CoreMuxDTi_A),
			// FFT memory interface
			.FFTMemNEXT(ContextEUNEXT_A & ~CoreACT_A & ~ContextEUCLOAD_A), .FFTMemACT(CoreFFTMemACT_A), .FFTMemCMD(CoreFFTMemCMD_A),
			.FFTMemADDR(CoreFFTMemADDR_A), .FFTMemDO(CoreFFTMemDO_A), .FFTMemTO(CoreFFTMemTO_A),
			// message system interface
			.PARAM(CorePARAM_A), .PARREG(CorePARREG_A), .MSGREQ(CoreMSGREQ_A), .MALLOCREQ(CoreMALLOCREQ_A), .PARREQ(CorePARREQ_A),
			.ENDMSG(CoreENDMSG_A), .BKPT(CoreBKPT_A), .EMPTY(CoreEMPTY_A), .HALT(CoreHALT_A), .NPCS(CoreNPCS_A), .SMSGBKPT(CoreSMSGBKPT_A), .CEXEC(ContextEURESTART_A | MsgrEURESTART_A),
			.ESMSG(MsgrEUCONTINUE_A), .CONTINUE(ContextCONTINUE_A), .CSTOP(MsgrEUHALT_A | ContextCORESTOP_A | IntFlag_A), .LIRESET(ContextLIRESET_A),
			// context store interface
			.RA(ContextRA_A), .CDATA(CoreCDATA_A), .RIP(CoreRIP_A),
			// error reporting
			.ESTB(CoreESTB_A), .ECD(CoreECD_A),
			// FFT engine error report interface
			.FFTESTB(CoreFFTESTB_A), .FFTECD(CoreFFTECD_A), .FFTCPSR(CoreFFTCPSR_A),
			.FATAL(CoreFATAL_A),
			// Performance monitor outputs
			.IV(CoreIV_A),
			.CSEL(CoreCSEL_A)
			);

// DataMux A
DMux	CoreMux_A(.CLK(CLK), .RESET(RST_A),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_A), .LocalDATA({ContextEUSZi_A, ContextEUTAGi_A, ContextEUDTi_A}), .LocalRD(CoreMuxLocalRD_A),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_A), .StreamDATA({StreamCoreSIZEO_A, StreamCoreTAGO_A, StreamCoreDTO_A}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_A), .NetDATA({FpuCORESIZEI_A, FpuCORETAGI_A, FpuCOREDTI_A}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_B), .DATAH({TmuxLSIZEI_B, TmuxLTAGI_B[7:0], TmuxLDATI_B}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_A), .TAG({CoreMuxSZi_A, CoreMuxTAGi_A}), .DATA(CoreMuxDTi_A)
		);
defparam CoreMux_A.TagWidth=11;

// CORE B (North-East)
EU64S2  Core_B(.CLK(CLK), .RESET(RST_B), .CLOAD(ContextEUCLOAD_B), .CPU(CPUBus_B), .TASKID(ContextCSR_B[15:0]), .CPSR(ContextCPSR_B),
			.DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .DTRESET(TmuxDTRESET_B), .CPL(ContextCSR_B[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_A), .DTLIMITH(TmuxDTLIMIT_A), .DTRESETH(TmuxDTRESET_A),
			// memory, stream and network interface
			.NEXT(ContextEUNEXT_B), .StreamNEXT(StreamCoreNEXT_B), .StreamNEXTH(StreamNEXTH_A),
			.NetNEXT(FPUCoreNEXT_B), .NEXTH(TmuxCoreNEXTH_A),
			.ACT(CoreACT_B), .StreamACT(CoreStreamACT_B), .StreamACTH(CoreStreamACTH_B),
			.NetACT(CoreNetACT_B), .ACTH(CoreACTH_B), 
			.CMD(CoreCMD_B), .OS(CoreOS_B), .ADDRESS(CoreADDRESS_B), .OFFSET(CoreOFFSET_B), .SELECTOR(CoreSELECTOR_B), .DTo(CoreDTo_B), .TAGo(CoreTAGo_B),
			.DRDY(CoreMuxDRDY_B), .TAGi(CoreMuxTAGi_B), .SZi(CoreMuxSZi_B), .DTi(CoreMuxDTi_B),
			// FFT memory interface
			.FFTMemNEXT(ContextEUNEXT_B & ~CoreACT_B & ~ContextEUCLOAD_B), .FFTMemACT(CoreFFTMemACT_B), .FFTMemCMD(CoreFFTMemCMD_B),
			.FFTMemADDR(CoreFFTMemADDR_B), .FFTMemDO(CoreFFTMemDO_B), .FFTMemTO(CoreFFTMemTO_B),
			// message system interface
			.PARAM(CorePARAM_B), .PARREG(CorePARREG_B), .MSGREQ(CoreMSGREQ_B), .MALLOCREQ(CoreMALLOCREQ_B), .PARREQ(CorePARREQ_B),
			.ENDMSG(CoreENDMSG_B), .BKPT(CoreBKPT_B), .EMPTY(CoreEMPTY_B), .HALT(CoreHALT_B), .NPCS(CoreNPCS_B), .SMSGBKPT(CoreSMSGBKPT_B), .CEXEC(ContextEURESTART_B | MsgrEURESTART_B),
			.ESMSG(MsgrEUCONTINUE_B), .CONTINUE(ContextCONTINUE_B), .CSTOP(MsgrEUHALT_B | ContextCORESTOP_B | IntFlag_B), .LIRESET(ContextLIRESET_B),
			// context store interface
			.RA(ContextRA_B), .CDATA(CoreCDATA_B), .RIP(CoreRIP_B),
			// error reporting
			.ESTB(CoreESTB_B), .ECD(CoreECD_B),
			// FFT engine error report interface
			.FFTESTB(CoreFFTESTB_B), .FFTECD(CoreFFTECD_B), .FFTCPSR(CoreFFTCPSR_B),
			.FATAL(CoreFATAL_B),
			// Performance monitor outputs
			.IV(CoreIV_B),
			.CSEL(CoreCSEL_B)
			);

// DataMux B
DMux	CoreMux_B(.CLK(CLK), .RESET(RST_B),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_B), .LocalDATA({ContextEUSZi_B, ContextEUTAGi_B, ContextEUDTi_B}), .LocalRD(CoreMuxLocalRD_B),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_B), .StreamDATA({StreamCoreSIZEO_B, StreamCoreTAGO_B, StreamCoreDTO_B}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_B), .NetDATA({FpuCORESIZEI_B, FpuCORETAGI_B, FpuCOREDTI_B}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_A), .DATAH({TmuxLSIZEI_A, TmuxLTAGI_A[7:0], TmuxLDATI_A}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_B), .TAG({CoreMuxSZi_B, CoreMuxTAGi_B}), .DATA(CoreMuxDTi_B)
		);
defparam CoreMux_B.TagWidth=11;

//=====================================================================================================================
//
// 				ErrorFIFO UNITs
//
//=====================================================================================================================
ErrorFIFO EFifo_A(.CLK(CLK), .RESET(RST_A), .CPSR(ContextCPSR_A),
				// read fifo interface
				.ERD(TmuxESRRD_A & EfifoVALID_A), .VALID(EfifoVALID_A), .ECD(EfifoECD_A),
				// error interface from core
				.CoreSTB(CoreESTB_A), .CoreECD(CoreECD_A),
				// error interface from FFT coprocessor
				.FFTSTB(CoreFFTESTB_A), .FFTECD(CoreFFTECD_A), .FFTCPSR(CoreFFTCPSR_A),
				// error report from outer network
				.NetSTB(FpuESTB_A), .NetECD(FpuECD_A),
				// error report from messenger
				.MsgrSTB(MsgrESTB_A), .MsgrECD(MsgrERRC_A),
				// error report from context controller
				.ContSTB(ContextESTB_A), .ContECD(ContextERC_A)
				);

ErrorFIFO EFifo_B(.CLK(CLK), .RESET(RST_B), .CPSR(ContextCPSR_B),
				// read fifo interface
				.ERD(TmuxESRRD_B & EfifoVALID_B), .VALID(EfifoVALID_B), .ECD(EfifoECD_B),
				// error interface from core
				.CoreSTB(CoreESTB_B), .CoreECD(CoreECD_B),
				// error interface from FFT coprocessor
				.FFTSTB(CoreFFTESTB_B), .FFTECD(CoreFFTECD_B), .FFTCPSR(CoreFFTCPSR_B),
				// error report from outer network
				.NetSTB(FpuESTB_B), .NetECD(FpuECD_B),
				// error report from messenger
				.MsgrSTB(MsgrESTB_B), .MsgrECD(MsgrERRC_B),
				// error report from context controller
				.ContSTB(ContextESTB_B), .ContECD(ContextERC_B)
				);

//=====================================================================================================================
//
// 				BUS MULTIPLEXER UNITs
//
//=====================================================================================================================
extern module MUX64S2 (
	input wire CLK, RESETn,

	output wire [4:0] LNEXT,
	input wire [4:0] LACT,
	input wire [4:0] LCMD,
	input wire [1:0] LSIZEO [4:0],
	input wire [44:0] LADDR [4:0],
	input wire [63:0] LDATO [4:0],
	input wire [12:0] LTAGO [4:0],
	output reg [4:0] LDRDY,
	output reg [63:0] LDATI,
	output reg [12:0] LTAGI,
	output reg [2:0] LSIZEI,
	// neighbourhood interface
	output wire CoreNEXTH,
	input wire CoreACTH, CoreCMDH,
	input wire [1:0] CoreSIZEH,
	input wire [44:0] CoreADDRH,
	input wire [63:0] CoreDATAH,
	input wire [7:0] CoreTAGH,
	output reg CoreDRDYH,
	// local memory interface
	output reg CMD,
	output reg [44:0] ADDR,
	output wire [63:0] DATA,
	output reg [7:0] BE,
	output reg [20:0] TAG,
	// Flash
	input wire FLNEXT,
	output reg FLACT,
	input wire FLDRDY,
	input wire [63:0] FLDAT,
	input wire [20:0] FLTAG,
	// SDRAM
	input SDNEXT,
	output reg SDACT,
	input SDDRDY,
	input [63:0] SDDAT,
	input [20:0] SDTAG,
	// IO
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
	output reg INTRST, INTENA, ESRRD, CENA, MALOCKF, PTINTR, DTRESET,
	input wire [3:0] NLE, NERR,
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

extern module MUX64S2SL (
	input wire CLK, RESETn,

	output wire [4:0] LNEXT,
	input wire [4:0] LACT,
	input wire [4:0] LCMD,
	input wire [1:0] LSIZEO [4:0],
	input wire [44:0] LADDR [4:0],
	input wire [63:0] LDATO [4:0],
	input wire [12:0] LTAGO [4:0],
	output reg [4:0] LDRDY,
	output reg [63:0] LDATI,
	output reg [12:0] LTAGI,
	output reg [2:0] LSIZEI,
	// neighbourhood interface
	output wire CoreNEXTH,
	input wire CoreACTH, CoreCMDH,
	input wire [1:0] CoreSIZEH,
	input wire [44:0] CoreADDRH,
	input wire [63:0] CoreDATAH,
	input wire [7:0] CoreTAGH,
	output reg CoreDRDYH,
	// local memory interface
	output reg CMD,
	output reg [44:0] ADDR,
	output wire [63:0] DATA,
	output reg [7:0] BE,
	output reg [20:0] TAG,
	// Flash
	input wire FLNEXT,
	output reg FLACT,
	input wire FLDRDY,
	input wire [63:0] FLDAT,
	input wire [20:0] FLTAG,
	// SDRAM
	input SDNEXT,
	output reg SDACT,
	input SDDRDY,
	input [63:0] SDDAT,
	input [20:0] SDTAG,
	// IO
	input IONEXT,
	output reg IOACT,
	input IODRDY,
	input [63:0] IODAT,
	input [20:0] IOTAG,
	// control and status lines
	output reg [39:0] DTBASE,
	output reg [23:0] DTLIMIT, INTSEL,
	output reg [15:0] INTLIMIT,
	input wire [7:0] CPUNUM,
	output reg [3:0] NENA,
	output reg INTRST, INTENA, ESRRD, CENA, MALOCKF, PTINTR, DTRESET,
	input wire [3:0] NLE, NERR,
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

// West
MUX64S2 Tmux_A(.CLK(CLK), .RESETn(RST_A), 
			// services interface
			.LNEXT(TmuxLNEXT_A),
			.LACT({MsgrACT_A, ContextACT_A[1], StreamACT_A, FpuACT_A, ContextACT_A[0]}),
			.LCMD({MsgrCMD_A, ContextCMD_A[1], StreamCMD_A, FpuCMD_A, ContextCMD_A[0]}),
			.LSIZEO(TmuxLSIZEO_A), .LADDR(TmuxLADDR_A), .LDATO(TmuxLDATO_A), .LTAGO(TmuxLTAGO_A),
			.LDRDY(TmuxLDRDY_A), .LDATI(TmuxLDATI_A), .LTAGI(TmuxLTAGI_A), .LSIZEI(TmuxLSIZEI_A),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_A), .CoreACTH(CoreACTH_B), .CoreCMDH(CoreCMD_B), .CoreSIZEH(CoreOS_B),
			.CoreADDRH(CoreADDRESS_B), .CoreDATAH(CoreDTo_B), .CoreTAGH(CoreTAGo_B), .CoreDRDYH(TmuxCoreDRDYH_A),
			// local memory interface
			.CMD(CMD_A), .ADDR(ADDR_A), .DATA(DATA_A), .BE(BE_A), .TAG(TAG_A),
			.FLNEXT(FlashNEXT_A), .FLACT(TmuxFLACT_A), .FLDRDY(FlashDRDY_A), .FLDAT(FlashDTO_A), .FLTAG(FlashTAGO_A),
			.SDNEXT(SDCacheINEXT_A), .SDACT(TmuxSDACT_A), .SDDRDY(SDCacheIDRDY_A), .SDDAT(SDCacheIDATo_A), .SDTAG(SDCacheITAGo_A),
			.IONEXT(IONEXT_A), .IOACT(IOACT_A), .IODRDY(IODRDY_A), .IODAT(IODAT_A), .IOTAG(IOTAG_A),
			// status and control lines and buses
			.DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .INTSEL(TmuxINTSEL_A), .INTLIMIT(TmuxINTLIMIT_A), .CPUNUM(TmuxCPUNUM_A), .NENA(TmuxNENA_A), .INTRST(TmuxINTRST_A),
			.INTENA(TmuxINTENA_A), .ESRRD(TmuxESRRD_A), .CENA(TmuxCENA_A), .MALOCKF(TMuxMALOCKF_A), .PTINTR(TmuxPTINTR_A), .NLE(4'd0), .NERR(4'd0),
			.CSR(ContextCSR_A), .CPSR(ContextCPSR_A), .FREEMEM(ContextFREEMEM_A), .CACHEDMEM(ContextCACHEDMEM_A), .ESR({EfifoECD_A[63:56] & {8{EfifoVALID_A}},EfifoECD_A[55:0]}),
			.CPSRSTB(TmuxCPSRSTB_A), .CSRSTB(TmuxCSRSTB_A), .SINIT(StreamINIT_A), .NINIT(FpuINIT_A), .CINIT(ContextREADY_A), .TCK(TickFlag), .TCKOVR(CoreNPCS_A), .HALT(CoreHALT_A),
			.DTRESET(TmuxDTRESET_A),
			.IV(CoreIV_A), .CSEL(CoreCSEL_A), .EMPTY(CoreEMPTY_A), .TCKScaler(TCKScale), .CoreType(8'd2)
			);

// East
MUX64S2SL Tmux_B(.CLK(CLK), .RESETn(RST_B), 
			// services interface
			.LNEXT(TmuxLNEXT_B),
			.LACT({MsgrACT_B, ContextACT_B[1], StreamACT_B, FpuACT_B, ContextACT_B[0]}),
			.LCMD({MsgrCMD_B, ContextCMD_B[1], StreamCMD_B, FpuCMD_B, ContextCMD_B[0]}),
			.LSIZEO(TmuxLSIZEO_B), .LADDR(TmuxLADDR_B), .LDATO(TmuxLDATO_B), .LTAGO(TmuxLTAGO_B),
			.LDRDY(TmuxLDRDY_B), .LDATI(TmuxLDATI_B), .LTAGI(TmuxLTAGI_B), .LSIZEI(TmuxLSIZEI_B),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_B), .CoreACTH(CoreACTH_A), .CoreCMDH(CoreCMD_A), .CoreSIZEH(CoreOS_A),
			.CoreADDRH(CoreADDRESS_A), .CoreDATAH(CoreDTo_A), .CoreTAGH(CoreTAGo_A), .CoreDRDYH(TmuxCoreDRDYH_B),
			// local memory interface
			.CMD(CMD_B), .ADDR(ADDR_B), .DATA(DATA_B), .BE(BE_B), .TAG(TAG_B),
			.FLNEXT(FlashNEXT_B), .FLACT(TmuxFLACT_B), .FLDRDY(FlashDRDY_B), .FLDAT(FlashDTO_B), .FLTAG(FlashTAGO_B),
			.SDNEXT(SDCacheINEXT_B), .SDACT(TmuxSDACT_B), .SDDRDY(SDCacheIDRDY_B), .SDDAT(SDCacheIDATo_B), .SDTAG(SDCacheITAGo_B),
			.IONEXT(IONEXT_B), .IOACT(IOACT_B), .IODRDY(IODRDY_B), .IODAT(IODAT_B), .IOTAG(IOTAG_B),
			// status and control lines and buses
			.DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .INTSEL(TmuxINTSEL_B), .INTLIMIT(TmuxINTLIMIT_B), .CPUNUM(CPUBus_B), .NENA(TmuxNENA_B), .INTRST(TmuxINTRST_B),
			.INTENA(TmuxINTENA_B), .ESRRD(TmuxESRRD_B), .CENA(TmuxCENA_B), .MALOCKF(TMuxMALOCKF_B), .PTINTR(TmuxPTINTR_B), .NLE(4'd0), .NERR(4'd0),
			.CSR(ContextCSR_B), .CPSR(ContextCPSR_B), .FREEMEM(ContextFREEMEM_B), .CACHEDMEM(ContextCACHEDMEM_B), .ESR({EfifoECD_B[63:56] & {8{EfifoVALID_B}},EfifoECD_B[55:0]}),
			.CPSRSTB(TmuxCPSRSTB_B), .CSRSTB(TmuxCSRSTB_B), .SINIT(StreamINIT_B), .NINIT(FpuINIT_B), .CINIT(ContextREADY_B), .TCK(TickFlag), .TCKOVR(CoreNPCS_B), .HALT(CoreHALT_B),
			.DTRESET(TmuxDTRESET_B),
			.IV(CoreIV_B), .CSEL(CoreCSEL_B), .EMPTY(CoreEMPTY_B), .TCKScaler(TCKScale), .CoreType(8'd2)
			);

//=====================================================================================================================
//
// 				SRAM UNITs
//
//=====================================================================================================================
// West
generate

case (SRAMMode_A[1:0])
	2'd0: InternalMemory256K #(.TagWidth(21))SSRAM_A(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[17:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd1: InternalMemory512K #(.TagWidth(21))SSRAM_A(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[18:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd2: InternalMemory1M #(.TagWidth(21))SSRAM_A(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[19:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd3: InternalMemory2M #(.TagWidth(21))SSRAM_A(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[20:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	endcase

case (SRAMMode_B[1:0])
	2'd0: InternalMemory256K #(.TagWidth(21))SSRAM_B(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[17:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd1: InternalMemory512K #(.TagWidth(21))SSRAM_B(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[18:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd2: InternalMemory1M #(.TagWidth(21))SSRAM_B(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[19:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	2'd3: InternalMemory2M #(.TagWidth(21))SSRAM_B(.CLK(EXTCLK), .ACT(TmuxSDACT), .CMD(CMD), .ADDR(ADDR[20:3]), .BE(BE), .DI(DATA), .TI(TAG), .DRDY(SDCacheIDRDY), .DO(SDCacheIDATo), .TO(SDCacheITAGo));
	endcase

endgenerate

assign SDCacheINEXT_A=1'b1;
assign SDCacheINEXT_B=1'b1;

//=====================================================================================================================
//
// 				FLASH UNITs
//
//=====================================================================================================================
// West
Flash16  Flash_A(.CLKH(CLK), .RESET(RST_A), .NEXT(FlashNEXT_A), .ACT(TmuxFLACT_A), .CMD(CMD_A), .ADDR(ADDR_A[31:0]),
				.BE(BE_A), .DTI(DATA_A), .TAGI(TAG_A), .DRDY(FlashDRDY_A), .DTO(FlashDTO_A), .TAGO(FlashTAGO_A),
				// interface to the external memory
				.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));

// East
Flash16  Flash_B(.CLKH(CLK), .RESET(RST_B), .NEXT(FlashNEXT_B), .ACT(TmuxFLACT_B), .CMD(CMD_B), .ADDR(ADDR_B[31:0]),
				.BE(BE_B), .DTI(DATA_B), .TAGI(TAG_B), .DRDY(FlashDRDY_B), .DTO(FlashDTO_B), .TAGO(FlashTAGO_B),
				// interface to the external memory
				.FLCK(), .FLRST(), .FLCS(), .FLSO(), .FLSI(1'b1));

//=====================================================================================================================
//
// 				CONTEXT CONTROLLERS
//
//=====================================================================================================================
extern module ContextCTRL16 ( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF, PTINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
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
	// interface to messages controller
	output reg MSGACK,
	input wire MSGREQ, CHKREQ,
	input wire [95:0] MSGPARAM,
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
	// context load/store interface to EU
	output wire [5:0] RA,
	input wire [63:0] CDAT,
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC
);

// West
ContextCTRL16 Context_A(.CLK(CLK), .RESETn(RST_A), .CENA(TmuxCENA_A), .MALOCKF(TMuxMALOCKF_A), .PTINTR(TmuxPTINTR_A),
				.DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .CPUNUM(CPUBus_A), .RST(ContextRST_A), .READY(ContextREADY_A),
				.CPSR(ContextCPSR_A), .CSR(ContextCSR_A), .FREEMEM(ContextFREEMEM_A), .CACHEDMEM(ContextCACHEDMEM_A), .EXTDI(DATA_A), .CPSRSTB(TmuxCPSRSTB_A),
				.CSRSTB(TmuxCSRSTB_A), .RIP(CoreRIP_A),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT_A[3], TmuxLNEXT_A[0]}), .ACT(ContextACT_A), .CMD(ContextCMD_A), .ADDR(ContextADDR_A), .SIZE(ContextSIZE_A),
				.TAGo(ContextTAGo_A), .DTo(ContextDTo_A),
				.DRDY({TmuxLDRDY_A[3], TmuxLDRDY_A[0]}), .DTi(TmuxLDATI_A), .TAGi(TmuxLTAGI_A[7:0]), .SZi(TmuxLSIZEI_A),
				// interface to messages controller
				.MSGACK(ContextMSGACK_A), .MSGREQ(MsgrContextREQ_A), .CHKREQ(MsgrContextCHK_A), .MSGPARAM(MsgrContextMSG_A),
				// low-speed memory interface from EU
				.EUNEXT(ContextEUNEXT_A), .EUACT(CoreACT_A | (CoreFFTMemACT_A & ~ContextEUCLOAD_A)), .EUCMD(CoreACT_A ? CoreCMD_A : CoreFFTMemCMD_A),
				.EUSZo(CoreACT_A ? CoreOS_A : 2'b11), .EUADDR(CoreACT_A ? CoreADDRESS_A : {CoreFFTMemADDR_A, 3'd0}), .EUDTo(CoreACT_A ? CoreDTo_A : CoreFFTMemDO_A),
				.EUTAGo(CoreACT_A ? CoreTAGo_A : CoreFFTMemTO_A),
				.EUDRDY(ContextEUDRDY_A), .EUTAGi(ContextEUTAGi_A), .EUSZi(ContextEUSZi_A), .EUDTi(ContextEUDTi_A), .EURD(CoreMuxLocalRD_A),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ_A), .GETPARREQ(CorePARREQ_A), .EUPARAM(CorePARAM_A), .EUREG(CorePARREG_A), .EUEMPTY(CoreEMPTY_A), .EUENDMSG(CoreENDMSG_A),
				.SMSGBKPT(CoreSMSGBKPT_A), .CORESTART(ContextEURESTART_A), .CORESTOP(ContextCORESTOP_A), .CORECONT(ContextCONTINUE_A), .EUCLOAD(ContextEUCLOAD_A), .LIRESET(ContextLIRESET_A),
				// context load/store interface to EU
				.RA(ContextRA_A), .CDAT(CoreCDATA_A),
				// error reporting interface
				.ESTB(ContextESTB_A), .ERC(ContextERC_A));

// East
ContextCTRL16 Context_B(.CLK(CLK), .RESETn(RST_B), .CENA(TmuxCENA_B), .MALOCKF(TMuxMALOCKF_B), .PTINTR(TmuxPTINTR_B),
				.DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .CPUNUM(CPUBus_B), .RST(ContextRST_B), .READY(ContextREADY_B),
				.CPSR(ContextCPSR_B), .CSR(ContextCSR_B), .FREEMEM(ContextFREEMEM_B), .CACHEDMEM(ContextCACHEDMEM_B), .EXTDI(DATA_B), .CPSRSTB(TmuxCPSRSTB_B),
				.CSRSTB(TmuxCSRSTB_B), .RIP(CoreRIP_B),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT_B[3], TmuxLNEXT_B[0]}), .ACT(ContextACT_B), .CMD(ContextCMD_B), .ADDR(ContextADDR_B), .SIZE(ContextSIZE_B),
				.TAGo(ContextTAGo_B), .DTo(ContextDTo_B),
				.DRDY({TmuxLDRDY_B[3], TmuxLDRDY_B[0]}), .DTi(TmuxLDATI_B), .TAGi(TmuxLTAGI_B[7:0]), .SZi(TmuxLSIZEI_B),
				// interface to messages controller
				.MSGACK(ContextMSGACK_B), .MSGREQ(MsgrContextREQ_B), .CHKREQ(MsgrContextCHK_B), .MSGPARAM(MsgrContextMSG_B),
				// low-speed memory interface from EU
				.EUNEXT(ContextEUNEXT_B), .EUACT(CoreACT_B | (CoreFFTMemACT_B & ~ContextEUCLOAD_B)), .EUCMD(CoreACT_B ? CoreCMD_B : CoreFFTMemCMD_B),
				.EUSZo(CoreACT_B ? CoreOS_B : 2'b11), .EUADDR(CoreACT_B ? CoreADDRESS_B : {CoreFFTMemADDR_B, 3'd0}), .EUDTo(CoreACT_B ? CoreDTo_B : CoreFFTMemDO_B),
				.EUTAGo(CoreACT_B ? CoreTAGo_B : CoreFFTMemTO_B),
				.EUDRDY(ContextEUDRDY_B), .EUTAGi(ContextEUTAGi_B), .EUSZi(ContextEUSZi_B), .EUDTi(ContextEUDTi_B), .EURD(CoreMuxLocalRD_B),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ_B), .GETPARREQ(CorePARREQ_B), .EUPARAM(CorePARAM_B), .EUREG(CorePARREG_B), .EUEMPTY(CoreEMPTY_B), .EUENDMSG(CoreENDMSG_B),
				.SMSGBKPT(CoreSMSGBKPT_B), .CORESTART(ContextEURESTART_B), .CORESTOP(ContextCORESTOP_B), .CORECONT(ContextCONTINUE_B), .EUCLOAD(ContextEUCLOAD_B), .LIRESET(ContextLIRESET_B),
				// context load/store interface to EU
				.RA(ContextRA_B), .CDAT(CoreCDATA_B),
				// error reporting interface
				.ESTB(ContextESTB_B), .ERC(ContextERC_B)
				);

//=====================================================================================================================
//
// 				 MESSENGERS
//
//=====================================================================================================================
// West
Messenger16 Msgr_A(.CLK(CLK), .RESETn(RST_A), .RST(MsgrRST_A),
			// message interface from EU, error system, interrupt system, network system and neighbourhood processors
			.EUREQ(CoreMSGREQ_A), .ERRORREQ(EfifoVALID_A & ~DEfifoVALID_A),
			.INTREQ(IntReqFlag_A), .NETREQ(FpuMSGREQ_A), .EUPARAM(CorePARAM_A), .INTPARAM(INTCODE_A),
			.NETPARAM(FpuMSGDATA_A), .NETMSGRD(MsgrNETMSGRD_A), .INTACK(INTACK_A),
			// interface to memory system
			.NEXT(TmuxLNEXT_A[4]), .ACT(MsgrACT_A), .CMD(MsgrCMD_A), .ADDR(MsgrADDR_A), .SIZE(MsgrSIZE_A), .DATO(MsgrDATO_A),
			.DRDY(TmuxLDRDY_A[4]), .DATI(TmuxLDATI_A[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContextMSGACK_A), .ContextREQ(MsgrContextREQ_A), .ContextCHK(MsgrContextCHK_A), .ContextMSG(MsgrContextMSG_A),
			// interface to network controller
			.NETRDY(FpuMSGNEXT_A), .NETSEND(MsgrNETSEND_A), .NETTYPE(MsgrNETTYPE_A), .NETMSG(MsgrNETMSG_A), .NETSTAT(MsgrNETSTAT_A),
			// DTR and DTL registers
			.DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .CPUNUM(CPUBus_A), .CPSR(ContextCPSR_A), .INTSR(TmuxINTSEL_A), .INTCR(TmuxINTLIMIT_A), .CSR(ContextCSR_A),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE_A), .EURESTART(MsgrEURESTART_A), .EUHALT(MsgrEUHALT_A), .BKPT(CoreBKPT_A),
			// error reporting interface
			.ESTB(MsgrESTB_A), .ERRC(MsgrERRC_A)
			);

// East
Messenger16 Msgr_B(.CLK(CLK), .RESETn(RST_B), .RST(MsgrRST_B),
			// message interface from EU, error system, interrupt system, network system and neighbourhood processors
			.EUREQ(CoreMSGREQ_B), .ERRORREQ(EfifoVALID_B & ~DEfifoVALID_B),
			.INTREQ(IntReqFlag_B), .NETREQ(FpuMSGREQ_B), .EUPARAM(CorePARAM_B), .INTPARAM(INTCODE_B),
			.NETPARAM(FpuMSGDATA_B), .NETMSGRD(MsgrNETMSGRD_B), .INTACK(INTACK_B),
			// interface to memory system
			.NEXT(TmuxLNEXT_B[4]), .ACT(MsgrACT_B), .CMD(MsgrCMD_B), .ADDR(MsgrADDR_B), .SIZE(MsgrSIZE_B), .DATO(MsgrDATO_B),
			.DRDY(TmuxLDRDY_B[4]), .DATI(TmuxLDATI_B[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContextMSGACK_B), .ContextREQ(MsgrContextREQ_B), .ContextCHK(MsgrContextCHK_B), .ContextMSG(MsgrContextMSG_B),
			// interface to network controller
			.NETRDY(FpuMSGNEXT_B), .NETSEND(MsgrNETSEND_B), .NETTYPE(MsgrNETTYPE_B), .NETMSG(MsgrNETMSG_B), .NETSTAT(MsgrNETSTAT_B),
			// DTR and DTL registers
			.DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .CPUNUM(CPUBus_B), .CPSR(ContextCPSR_B), .INTSR(TmuxINTSEL_B), .INTCR(TmuxINTLIMIT_B), .CSR(ContextCSR_B),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE_B), .EURESTART(MsgrEURESTART_B), .EUHALT(MsgrEUHALT_B), .BKPT(CoreBKPT_B),
			// error reporting interface
			.ESTB(MsgrESTB_B), .ERRC(MsgrERRC_B)
			);

//=====================================================================================================================
//
// 				 STREAM CONTROLLERS
//
//=====================================================================================================================
// West
StreamControllerS2 Stream_A(.CLK(CLK), .RESET(RST_A), .TE(TickFlag), .DTBASE(TmuxDTBASE_A), .INIT(StreamINIT_A),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_A), .CoreACT(CoreStreamACT_A), .CoreCMD(CoreCMD_A), .CoreADDR(CoreADDRESS_A[0]), .CoreSEL(CoreSELECTOR_A[23:0]), 
						.CoreDTI(CoreDTo_A), .CoreTAGI(CoreTAGo_A),
						.CoreDRDY(StreamCoreDRDY_A), .CoreDTO(StreamCoreDTO_A), .CoreTAGO(StreamCoreTAGO_A), .CoreSIZEO(StreamCoreSIZEO_A),
						// network interface
						.NetNEXT(StreamNetNEXT_A), .NetACT(FpuSACT_A), .NetSEL(FpuSEL_A), .NetDATA(FpuDTO_A),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_A),
						.ACTH(CoreStreamACTH_B),
						.SELH(CoreSELECTOR_B[23:0]),
						.DATAH(CoreDTo_B),
						// local memory interface
						.NEXT(TmuxLNEXT_A[2]), .ACT(StreamACT_A), .CMD(StreamCMD_A), .SIZEO(StreamSIZEO_A), .ADDR(StreamADDR_A), .DTO(StreamDTO_A), .TAGO(StreamTAGO_A),
						.DRDY(TmuxLDRDY_A[2]), .DTI(TmuxLDATI_A), .TAGI(TmuxLTAGI_A[4:0]));

// East
StreamControllerS2 Stream_B(.CLK(CLK), .RESET(RST_B), .TE(TickFlag), .DTBASE(TmuxDTBASE_B), .INIT(StreamINIT_B),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_B), .CoreACT(CoreStreamACT_B), .CoreCMD(CoreCMD_B), .CoreADDR(CoreADDRESS_B[0]), .CoreSEL(CoreSELECTOR_B[23:0]), 
						.CoreDTI(CoreDTo_B), .CoreTAGI(CoreTAGo_B),
						.CoreDRDY(StreamCoreDRDY_B), .CoreDTO(StreamCoreDTO_B), .CoreTAGO(StreamCoreTAGO_B), .CoreSIZEO(StreamCoreSIZEO_B),
						// network interface
						.NetNEXT(StreamNetNEXT_B), .NetACT(FpuSACT_B), .NetSEL(FpuSEL_B), .NetDATA(FpuDTO_B),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_B),
						.ACTH(CoreStreamACTH_A),
						.SELH(CoreSELECTOR_A[23:0]),
						.DATAH(CoreDTo_A),
						// local memory interface
						.NEXT(TmuxLNEXT_B[2]), .ACT(StreamACT_B), .CMD(StreamCMD_B), .SIZEO(StreamSIZEO_B), .ADDR(StreamADDR_B), .DTO(StreamDTO_B), .TAGO(StreamTAGO_B),
						.DRDY(TmuxLDRDY_B[2]), .DTI(TmuxLDATI_B), .TAGI(TmuxLTAGI_B[4:0]));

//=====================================================================================================================
//
// 				 Frame Processing Units
//
//=====================================================================================================================
// West
FPU16 Fpu_A(.CLK(CLK), .RESETn(RST_A), .TCK(TickFlag), .DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .CPUNUM(CPUBus_A), .TASKID(ContextCSR_A[15:0]), .CPSR(ContextCPSR_A), .INIT(FpuINIT_A),
		// interface to core
		.CORENEXT(FPUCoreNEXT_A), .COREACT(CoreNetACT_A), .CORECMD(CoreCMD_A), .CORESIZE(CoreOS_A), .CORECPL(ContextCSR_A[19:18]),
		.COREOFFSET(CoreOFFSET_A), .CORESEL(CoreSELECTOR_A), .COREDTO(CoreDTo_A), .CORETAGO(CoreTAGo_A),
		.COREDRDY(FpuCOREDRDY_A), .COREDTI(FpuCOREDTI_A), .CORETAGI(FpuCORETAGI_A), .CORESIZEI(FpuCORESIZEI_A),
		// local memory interface
		.NEXT(TmuxLNEXT_A[1]), .SNEXT(StreamNetNEXT_A), .ACT(FpuACT_A), .SACT(FpuSACT_A), .CMD(FpuCMD_A), .SIZEO(FpuSIZEO_A), .ADDR(FpuADDR_A), 
		.DTO(FpuDTO_A), .TAGO(FpuTAGO_A), .SEL(FpuSEL_A),
		.DRDY(TmuxLDRDY_A[1]), .DTI(TmuxLDATI_A), .SIZEI(TmuxLSIZEI_A[1:0]), .TAGI(TmuxLTAGI_A),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT_A), .STONEW(FpuSTONEW_A), .STODT(FpuSTODT_A), .STINEXT(FpuSTINEXT_A), .STIVAL(RteSTIVAL_A), .STINEW(RteSTINEW_A), .STIDT(RteSTIDT_A),
		// messages interface
		.MSGREQ(FpuMSGREQ_A), .MSGRD(MsgrNETMSGRD_A), .MSGDATA(FpuMSGDATA_A), 
		.MSGNEXT(FpuMSGNEXT_A), .MSGSEND(MsgrNETSEND_A), .MSGTYPE(MsgrNETTYPE_A), .MSGPARAM(MsgrNETMSG_A), .MSGSTAT(MsgrNETSTAT_A),
		// error report interface
		.ESTB(FpuESTB_A), .ECD(FpuECD_A));

// East
FPU16 Fpu_B(.CLK(CLK), .RESETn(RST_B), .TCK(TickFlag), .DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .CPUNUM(CPUBus_B), .TASKID(ContextCSR_B[15:0]), .CPSR(ContextCPSR_B), .INIT(FpuINIT_B),
		// interface to core
		.CORENEXT(FPUCoreNEXT_B), .COREACT(CoreNetACT_B), .CORECMD(CoreCMD_B), .CORESIZE(CoreOS_B), .CORECPL(ContextCSR_B[19:18]),
		.COREOFFSET(CoreOFFSET_B), .CORESEL(CoreSELECTOR_B), .COREDTO(CoreDTo_B), .CORETAGO(CoreTAGo_B),
		.COREDRDY(FpuCOREDRDY_B), .COREDTI(FpuCOREDTI_B), .CORETAGI(FpuCORETAGI_B), .CORESIZEI(FpuCORESIZEI_B),
		// local memory interface
		.NEXT(TmuxLNEXT_B[1]), .SNEXT(StreamNetNEXT_B), .ACT(FpuACT_B), .SACT(FpuSACT_B), .CMD(FpuCMD_B), .SIZEO(FpuSIZEO_B), .ADDR(FpuADDR_B),
		.DTO(FpuDTO_B), .TAGO(FpuTAGO_B), .SEL(FpuSEL_B),
		.DRDY(TmuxLDRDY_B[1]), .DTI(TmuxLDATI_B), .SIZEI(TmuxLSIZEI_B[1:0]), .TAGI(TmuxLTAGI_B),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT_B), .STONEW(FpuSTONEW_B), .STODT(FpuSTODT_B), .STINEXT(FpuSTINEXT_B), .STIVAL(RteSTIVAL_B), .STINEW(RteSTINEW_B), .STIDT(RteSTIDT_B),
		// messages interface
		.MSGREQ(FpuMSGREQ_B), .MSGRD(MsgrNETMSGRD_B), .MSGDATA(FpuMSGDATA_B), 
		.MSGNEXT(FpuMSGNEXT_B), .MSGSEND(MsgrNETSEND_B), .MSGTYPE(MsgrNETTYPE_B), .MSGPARAM(MsgrNETMSG_B), .MSGSTAT(MsgrNETSTAT_B),
		// error report interface
		.ESTB(FpuESTB_B), .ECD(FpuECD_B));

//=====================================================================================================================
//
//					Routing Engine
//
//=====================================================================================================================
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
	input wire [63:0] STODT,
	input wire STINEXT,
	output wire STINEW,
	output wire STIVAL,
	output wire [63:0] STIDT
);
// West
RTE Rte_A(.CLK(CLK), .RESET(RST_A), .CPUNUM(CPUBus_A),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_A), .EXTDO(RteEXTDO_A), .EXTSTBI(RteEXTSTBI_A), .EXTDI(RteEXTDI_A),
			// core interface
			.STONEXT(RteSTONEXT_A), .STONEW(FpuSTONEW_A), .STODT(FpuSTODT_A), .STINEXT(FpuSTINEXT_A),
			.STINEW(RteSTINEW_A), .STIVAL(RteSTIVAL_A), .STIDT(RteSTIDT_A));

// East
RTE Rte_B(.CLK(CLK), .RESET(RST_B), .CPUNUM(CPUBus_B),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_B), .EXTDO(RteEXTDO_B), .EXTSTBI(RteEXTSTBI_B), .EXTDI(RteEXTDI_B),
			// core interface
			.STONEXT(RteSTONEXT_B), .STONEW(FpuSTONEW_B), .STODT(FpuSTODT_B), .STINEXT(FpuSTINEXT_B),
			.STINEW(RteSTINEW_B), .STIVAL(RteSTIVAL_B), .STIDT(RteSTIDT_B));

//=====================================================================================================================
//					Assignments
//=====================================================================================================================
assign TmuxLSIZEO_A[4]=MsgrSIZE_A;
assign TmuxLSIZEO_A[3]=ContextSIZE_A[1];
assign TmuxLSIZEO_A[2]=StreamSIZEO_A;
assign TmuxLSIZEO_A[1]=FpuSIZEO_A;
assign TmuxLSIZEO_A[0]=ContextSIZE_A[0];

assign TmuxLADDR_A[4]=MsgrADDR_A;
assign TmuxLADDR_A[3]=ContextADDR_A[1];
assign TmuxLADDR_A[2]=StreamADDR_A;
assign TmuxLADDR_A[1]=FpuADDR_A;
assign TmuxLADDR_A[0]=ContextADDR_A[0];

assign TmuxLDATO_A[4]={32'd0, MsgrDATO_A};
assign TmuxLDATO_A[3]=ContextDTo_A[1];
assign TmuxLDATO_A[2]=StreamDTO_A;
assign TmuxLDATO_A[1]=FpuDTO_A;
assign TmuxLDATO_A[0]=ContextDTo_A[0];

assign TmuxLTAGO_A[4]=13'd0;
assign TmuxLTAGO_A[3]={5'd0, ContextTAGo_A[1]};
assign TmuxLTAGO_A[2]={7'd0, StreamTAGO_A};
assign TmuxLTAGO_A[1]=FpuTAGO_A;
assign TmuxLTAGO_A[0]={5'd0, ContextTAGo_A[0]};

assign TmuxLSIZEO_B[4]=MsgrSIZE_B;
assign TmuxLSIZEO_B[3]=ContextSIZE_B[1];
assign TmuxLSIZEO_B[2]=StreamSIZEO_B;
assign TmuxLSIZEO_B[1]=FpuSIZEO_B;
assign TmuxLSIZEO_B[0]=ContextSIZE_B[0];

assign TmuxLADDR_B[4]=MsgrADDR_B;
assign TmuxLADDR_B[3]=ContextADDR_B[1];
assign TmuxLADDR_B[2]=StreamADDR_B;
assign TmuxLADDR_B[1]=FpuADDR_B;
assign TmuxLADDR_B[0]=ContextADDR_B[0];

assign TmuxLDATO_B[4]={32'd0, MsgrDATO_B};
assign TmuxLDATO_B[3]=ContextDTo_B[1];
assign TmuxLDATO_B[2]=StreamDTO_B;
assign TmuxLDATO_B[1]=FpuDTO_B;
assign TmuxLDATO_B[0]=ContextDTo_B[0];

assign TmuxLTAGO_B[4]=13'd0;
assign TmuxLTAGO_B[3]={5'd0, ContextTAGo_B[1]};
assign TmuxLTAGO_B[2]={7'd0, StreamTAGO_B};
assign TmuxLTAGO_B[1]=FpuTAGO_B;
assign TmuxLTAGO_B[0]={5'd0, ContextTAGo_B[0]};

assign STBO_NW=RteEXTSTBO_A[0];
assign NETDO_NW=RteEXTDO_A[0];
assign STBO_NE=RteEXTSTBO_B[0];
assign NETDO_NE=RteEXTDO_B[0];
assign STBO_E=RteEXTSTBO_B[1];
assign NETDO_E=RteEXTDO_B[1];
assign STBO_SW=RteEXTSTBO_A[2];
assign NETDO_SW=RteEXTDO_A[2];
assign STBO_SE=RteEXTSTBO_B[2];
assign NETDO_SE=RteEXTDO_B[2];
assign STBO_W=RteEXTSTBO_A[3];
assign NETDO_W=RteEXTDO_A[3];

assign RteEXTSTBI_A={STBI_W, STBI_SW, RteEXTSTBO_B[3], STBI_NW};
assign RteEXTDI_A[3]=NETDI_W, RteEXTDI_A[2]=NETDI_SW, RteEXTDI_A[1]=RteEXTDO_B[3], RteEXTDI_A[0]=NETDI_NW;

assign RteEXTSTBI_B={RteEXTSTBO_A[1], STBI_SE, STBI_E, STBI_NE};
assign RteEXTDI_B[3]=RteEXTDO_A[1], RteEXTDI_B[2]=NETDI_SE, RteEXTDI_B[1]=NETDI_E, RteEXTDI_B[0]=NETDI_NE;

//=====================================================================================================================
//					Combinatorical
//=====================================================================================================================
//
always_comb begin
// cpu buses
CPUBus_A={TmuxCPUNUM_A[7:4],TmuxCPUNUM_A[3:1],1'b0};
CPUBus_B={TmuxCPUNUM_A[7:4],TmuxCPUNUM_A[3:1],1'b1};
end

//=================================================================================================
//					synchronous 
//=================================================================================================
//
always_ff @(posedge CLK)
begin

// reset filtering
EXTRESET<=RESET;

RST_A<=EXTRESET & MsgrRST_A & ContextRST_A;
RST_B<=EXTRESET & MsgrRST_B & ContextRST_B;

// timing intervals for stream controller
TECntReg<=(TECntReg+8'd1) & {8{EXTRESET & ~TickFlag}};
TickFlag<=(TECntReg==(TCKScale-2)) & EXTRESET;

// delayed EFIFO flag
DEfifoVALID_A<=EfifoVALID_A & RST_A;
DEfifoVALID_B<=EfifoVALID_B & RST_B;

// interrupt flag A
IntFlag_A<=(IntFlag_A | INTREQ_A) & ~INTACK_A & RST_A & TmuxINTENA_A;
IntReqFlag_A<=IntFlag_A & CoreEMPTY_A & ~CoreSMSGBKPT_A  & RST_A & ~DIntReqFlag_A;
DIntReqFlag_A<=(DIntReqFlag_A | IntReqFlag_A) & RST_A & IntFlag_A;

// interrupt flag B
IntFlag_B<=(IntFlag_B | INTREQ_B) & ~INTACK_B & RST_B & TmuxINTENA_B;
IntReqFlag_B<=IntFlag_B & CoreEMPTY_B & ~CoreSMSGBKPT_B  & RST_B & ~DIntReqFlag_B;
DIntReqFlag_B<=(DIntReqFlag_B | IntReqFlag_B) & RST_B & IntFlag_B;

end

endmodule
