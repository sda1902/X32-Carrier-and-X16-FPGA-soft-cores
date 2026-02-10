module X16x4Cache4x64x2048 #(parameter TCKScale=20)(
	input wire CLK, RESET,

	// internal memory interface
	output wire CMD_A, CMD_B, CMD_C, CMD_D,
	output wire [44:0] ADDR_A, ADDR_B, ADDR_C, ADDR_D,
	output wire [63:0] DATA_A, DATA_B, DATA_C, DATA_D,
	output wire [7:0] BE_A, BE_B, BE_C, BE_D,
	output wire [20:0] TAG_A, TAG_B, TAG_C, TAG_D,
	
	// SDRAM controller channel
	input wire SDNEXT_A, SDNEXT_B, SDNEXT_C, SDNEXT_D,
	output wire SDACT_A, SDACT_B, SDACT_C, SDACT_D,
	output wire SDCMD_A, SDCMD_B, SDCMD_C, SDCMD_D,
	output wire [41:0] SDADDR_A, SDADDR_B, SDADDR_C, SDADDR_D,
	output wire [7:0] SDBE_A, SDBE_B, SDBE_C, SDBE_D,
	output wire [63:0] SDDI_A, SDDI_B, SDDI_C, SDDI_D,
	output wire [1:0] SDTI_A, SDTI_B, SDTI_C, SDTI_D,
	input wire SDDRDY_A, SDDRDY_B, SDDRDY_C, SDDRDY_D,
	input wire [63:0] SDDO_A, SDDO_B, SDDO_C, SDDO_D,
	input wire [1:0] SDTO_A, SDTO_B, SDTO_C, SDTO_D,
	
	input wire IONEXT_A, IONEXT_B, IONEXT_C, IONEXT_D,
	output wire IOACT_A, IOACT_B, IOACT_C, IOACT_D,
	input wire IODRDY_A, IODRDY_B, IODRDY_C, IODRDY_D,
	input wire [63:0] IODAT_A, IODAT_B, IODAT_C, IODAT_D,
	input wire [20:0] IOTAG_A, IOTAG_B, IOTAG_C, IOTAG_D,

	// SPI Flash interface
	output wire SPICK,
	output wire SPIRST,
	output wire SPICS,
	output wire SPISO,
	input wire SPISI,

	// network interface
	output wire STBO_NW, STBO_NE,
	output wire [32:0] NETDO_NW, NETDO_NE,
	output wire STBO_EN, STBO_ES,
	output wire [32:0] NETDO_EN, NETDO_ES,
	output wire STBO_SW, STBO_SE,
	output wire [32:0] NETDO_SW, NETDO_SE,
	output wire STBO_WN, STBO_WS,
	output wire [32:0] NETDO_WN, NETDO_WS,
	input wire STBI_NW, STBI_NE,
	input wire [32:0] NETDI_NW, NETDI_NE,
	input wire STBI_EN, STBI_ES,
	input wire [32:0] NETDI_EN, NETDI_ES,
	input wire STBI_SW, STBI_SE,
	input wire [32:0] NETDI_SW, NETDI_SE,
	input wire STBI_WN, STBI_WS,
	input wire [32:0] NETDI_WN, NETDI_WS,
	
	// interrupt interface
	output wire INTACK_A, INTACK_B, INTACK_C, INTACK_D,
	input wire INTREQ_A, INTREQ_B, INTREQ_C, INTREQ_D,
	input wire [15:0] INTCODE_A, INTCODE_B, INTCODE_C, INTCODE_D
);

logic [7:0] CPUBus_A, CPUBus_B, CPUBus_C, CPUBus_D;
reg EXTRESET, RST_A, RST_B, RST_C, RST_D, DEfifoVALID_A, DEfifoVALID_B, DEfifoVALID_C, DEfifoVALID_D;

// TE counter
reg [7:0] TECntReg;
reg TickFlag, IntFlag_A, IntFlag_B, IntFlag_C, IntFlag_D, IntReqFlag_A, IntReqFlag_B, IntReqFlag_C, IntReqFlag_D;
reg DIntReqFlag_A, DIntReqFlag_B, DIntReqFlag_C, DIntReqFlag_D;

logic [41:0] SDCacheEADDR_A, SDCacheEADDR_B, SDCacheEADDR_C, SDCacheEADDR_D;

//-----------------------------------------------
//				Core unit resources
logic CoreACT_A, CoreStreamACT_A, CoreNetACT_A, CoreACTH_A, CoreACTV_A, CoreACTD_A, CoreCMD_A, CoreStreamACTH_A, CoreStreamACTV_A, CoreStreamACTD_A, CoreNPCS_A;
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

logic CoreACT_B, CoreStreamACT_B, CoreNetACT_B, CoreACTH_B, CoreACTV_B, CoreACTD_B, CoreCMD_B, CoreStreamACTH_B, CoreStreamACTV_B, CoreStreamACTD_B, CoreNPCS_B;
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

logic CoreACT_C, CoreStreamACT_C, CoreNetACT_C, CoreACTH_C, CoreACTV_C, CoreACTD_C, CoreCMD_C, CoreStreamACTH_C, CoreStreamACTV_C, CoreStreamACTD_C, CoreNPCS_C;
logic [1:0] CoreOS_C;
logic [44:0] CoreADDRESS_C;
logic [36:0] CoreOFFSET_C;
logic [31:0] CoreSELECTOR_C;
logic [63:0] CoreDTo_C;
logic [7:0] CoreTAGo_C;
logic CoreFFTMemACT_C, CoreFFTMemCMD_C;
logic [41:0] CoreFFTMemADDR_C;
logic [63:0] CoreFFTMemDO_C;
logic [7:0] CoreFFTMemTO_C;
logic [63:0] CorePARAM_C;
logic [3:0] CorePARREG_C;
logic CoreMSGREQ_C, CoreMALLOCREQ_C, CorePARREQ_C, CoreENDMSG_C, CoreBKPT_C, CoreEMPTY_C, CoreHALT_C, CoreSMSGBKPT_C;
logic [63:0] CoreCDATA_C;
logic [36:0] CoreRIP_C;
logic CoreESTB_C;
logic [28:0] CoreECD_C;
logic CoreMuxDRDY_C, CoreMuxLocalRD_C;
logic [2:0] CoreMuxSZi_C;
logic [7:0] CoreMuxTAGi_C;
logic [63:0] CoreMuxDTi_C;
logic CoreFATAL_C;
logic CoreFFTESTB_C;
logic [28:0] CoreFFTECD_C;
logic [23:0] CoreFFTCPSR_C;
logic [3:0] CoreIV_C;
logic [23:0] CoreCSEL_C;

logic CoreACT_D, CoreStreamACT_D, CoreNetACT_D, CoreACTH_D, CoreACTV_D, CoreACTD_D, CoreCMD_D, CoreStreamACTH_D, CoreStreamACTV_D, CoreStreamACTD_D, CoreNPCS_D;
logic [1:0] CoreOS_D;
logic [44:0] CoreADDRESS_D;
logic [36:0] CoreOFFSET_D;
logic [31:0] CoreSELECTOR_D;
logic [63:0] CoreDTo_D;
logic [7:0] CoreTAGo_D;
logic CoreFFTMemACT_D, CoreFFTMemCMD_D;
logic [41:0] CoreFFTMemADDR_D;
logic [63:0] CoreFFTMemDO_D;
logic [7:0] CoreFFTMemTO_D;
logic [63:0] CorePARAM_D;
logic [3:0] CorePARREG_D;
logic CoreMSGREQ_D, CoreMALLOCREQ_D, CorePARREQ_D, CoreENDMSG_D, CoreBKPT_D, CoreEMPTY_D, CoreHALT_D, CoreSMSGBKPT_D;
logic [63:0] CoreCDATA_D;
logic [36:0] CoreRIP_D;
logic CoreESTB_D;
logic [28:0] CoreECD_D;
logic CoreMuxDRDY_D, CoreMuxLocalRD_D;
logic [2:0] CoreMuxSZi_D;
logic [7:0] CoreMuxTAGi_D;
logic [63:0] CoreMuxDTi_D;
logic CoreFATAL_D;
logic CoreFFTESTB_D;
logic [28:0] CoreFFTECD_D;
logic [23:0] CoreFFTCPSR_D;
logic [3:0] CoreIV_D;
logic [23:0] CoreCSEL_D;

//-----------------------------------------------
//				ErrorFIFO resources
logic EfifoVALID_A;
logic [63:0] EfifoECD_A;

logic EfifoVALID_B;
logic [63:0] EfifoECD_B;

logic EfifoVALID_C;
logic [63:0] EfifoECD_C;

logic EfifoVALID_D;
logic [63:0] EfifoECD_D;

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
logic TmuxCoreNEXTH_A, TmuxCoreNEXTV_A, TmuxCoreNEXTD_A, TmuxCoreDRDYH_A, TmuxCoreDRDYV_A, TmuxCoreDRDYD_A, TmuxESTBH_A, TmuxESTBV_A, TmuxESTBD_A;
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
logic TmuxCoreNEXTH_B, TmuxCoreNEXTV_B, TmuxCoreNEXTD_B, TmuxCoreDRDYH_B, TmuxCoreDRDYV_B, TmuxCoreDRDYD_B, TmuxESTBH_B, TmuxESTBV_B, TmuxESTBD_B;
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

logic [4:0] TmuxLNEXT_C, TmuxLDRDY_C;
logic [1:0] TmuxLSIZEO_C [4:0]; 
logic [44:0] TmuxLADDR_C [4:0];
logic [63:0] TmuxLDATO_C [4:0];
logic [12:0] TmuxLTAGO_C [4:0];
logic [63:0] TmuxLDATI_C;
logic [12:0] TmuxLTAGI_C;
logic [2:0] TmuxLSIZEI_C;
logic TmuxCoreNEXTH_C, TmuxCoreNEXTV_C, TmuxCoreNEXTD_C, TmuxCoreDRDYH_C, TmuxCoreDRDYV_C, TmuxCoreDRDYD_C, TmuxESTBH_C, TmuxESTBV_C, TmuxESTBD_C;
logic [36:0] TmuxECD_C;
logic TmuxFLACT_C;
logic [39:0] TmuxDTBASE_C;
logic [23:0] TmuxDTLIMIT_C, TmuxINTSEL_C;
logic [15:0] TmuxINTLIMIT_C;
logic [7:0] TmuxCPUNUM_C;
logic [3:0] TmuxNENA_C;
logic TmuxINTRST_C, TmuxINTENA_C, TmuxESRRD_C, TmuxCENA_C, TMuxMALOCKF_C, TmuxPTINTR_C, TmuxDTRESET_C, TmuxSDACT_C;
logic [2:0] TmuxCPSRSTB_C;
logic [3:0] TmuxCSRSTB_C;
logic [2:0] TmuxCPUSIZEO_C;
logic [7:0] TmuxCPUTAGO_C;
logic TmuxSACT_C;
logic [23:0] TmuxSSEL_C;
logic [63:0] TmuxSDATA_C;

logic [4:0] TmuxLNEXT_D, TmuxLDRDY_D;
logic [1:0] TmuxLSIZEO_D [4:0]; 
logic [44:0] TmuxLADDR_D [4:0];
logic [63:0] TmuxLDATO_D [4:0];
logic [12:0] TmuxLTAGO_D [4:0];
logic [63:0] TmuxLDATI_D;
logic [12:0] TmuxLTAGI_D;
logic [2:0] TmuxLSIZEI_D;
logic TmuxCoreNEXTH_D, TmuxCoreNEXTV_D, TmuxCoreNEXTD_D, TmuxCoreDRDYH_D, TmuxCoreDRDYV_D, TmuxCoreDRDYD_D, TmuxESTBH_D, TmuxESTBV_D, TmuxESTBD_D;
logic [36:0] TmuxECD_D;
logic TmuxFLACT_D;
logic [39:0] TmuxDTBASE_D;
logic [23:0] TmuxDTLIMIT_D, TmuxINTSEL_D;
logic [15:0] TmuxINTLIMIT_D;
logic [7:0] TmuxCPUNUM_D;
logic [3:0] TmuxNENA_D;
logic TmuxINTRST_D, TmuxINTENA_D, TmuxESRRD_D, TmuxCENA_D, TMuxMALOCKF_D, TmuxPTINTR_D, TmuxDTRESET_D, TmuxSDACT_D;
logic [2:0] TmuxCPSRSTB_D;
logic [3:0] TmuxCSRSTB_D;
logic [2:0] TmuxCPUSIZEO_D;
logic [7:0] TmuxCPUTAGO_D;
logic TmuxSACT_D;
logic [23:0] TmuxSSEL_D;
logic [63:0] TmuxSDATA_D;

//-----------------------------------------------
//				Cache resources
logic SDCacheINEXT_A, SDCacheIDRDY_A;
logic [63:0] SDCacheIDATo_A;
logic [20:0] SDCacheITAGo_A;

logic SDCacheINEXT_B, SDCacheIDRDY_B;
logic [63:0] SDCacheIDATo_B;
logic [20:0] SDCacheITAGo_B;

logic SDCacheINEXT_C, SDCacheIDRDY_C;
logic [63:0] SDCacheIDATo_C;
logic [20:0] SDCacheITAGo_C;


logic SDCacheINEXT_D, SDCacheIDRDY_D;
logic [63:0] SDCacheIDATo_D;
logic [20:0] SDCacheITAGo_D;

//-----------------------------------------------
//				Flash unit resources
logic FlashNEXT_A, FlashDRDY_A;
logic [63:0] FlashDTO_A;
logic [20:0] FlashTAGO_A;

logic FlashNEXT_B, FlashDRDY_B;
logic [63:0] FlashDTO_B;
logic [20:0] FlashTAGO_B;

logic FlashNEXT_C, FlashDRDY_C;
logic [63:0] FlashDTO_C;
logic [20:0] FlashTAGO_C;

logic FlashNEXT_D, FlashDRDY_D;
logic [63:0] FlashDTO_D;
logic [20:0] FlashTAGO_D;

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

logic ContextRST_C, ContextREADY_C;
logic [23:0] ContextCPSR_C;
logic [31:0] ContextCSR_C;
logic [39:0] ContextFREEMEM_C, ContextCACHEDMEM_C;
logic [1:0] ContextACT_C, ContextCMD_C;
logic [44:0] ContextADDR_C [1:0];
logic [1:0] ContextSIZE_C [1:0];
logic [7:0] ContextTAGo_C [1:0];
logic [63:0] ContextDTo_C [1:0];
logic ContextMSGACK_C, ContextEUNEXT_C, ContextEUDRDY_C;
logic [7:0] ContextEUTAGi_C;
logic [2:0] ContextEUSZi_C;
logic [63:0] ContextEUDTi_C;
logic ContextEURESTART_C, ContextCORESTOP_C, ContextCONTINUE_C, ContextEUCLOAD_C, ContextLIRESET_C;
logic [5:0] ContextRA_C;
logic ContextESTB_C;
logic [31:0] ContextERC_C;

logic ContextRST_D, ContextREADY_D;
logic [23:0] ContextCPSR_D;
logic [31:0] ContextCSR_D;
logic [39:0] ContextFREEMEM_D, ContextCACHEDMEM_D;
logic [1:0] ContextACT_D, ContextCMD_D;
logic [44:0] ContextADDR_D [1:0];
logic [1:0] ContextSIZE_D [1:0];
logic [7:0] ContextTAGo_D [1:0];
logic [63:0] ContextDTo_D [1:0];
logic ContextMSGACK_D, ContextEUNEXT_D, ContextEUDRDY_D;
logic [7:0] ContextEUTAGi_D;
logic [2:0] ContextEUSZi_D;
logic [63:0] ContextEUDTi_D;
logic ContextEURESTART_D, ContextCORESTOP_D, ContextCONTINUE_D, ContextEUCLOAD_D, ContextLIRESET_D;
logic [5:0] ContextRA_D;
logic ContextESTB_D;
logic [31:0] ContextERC_D;

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

logic MsgrRST_C, MsgrNETMSGRD_C, MsgrACT_C, MsgrCMD_C;
logic [44:0] MsgrADDR_C;
logic [1:0] MsgrSIZE_C;
logic [31:0] MsgrDATO_C;
logic MsgrContextREQ_C, MsgrContextCHK_C, MsgrNETSEND_C, MsgrNETTYPE_C;
logic [79:0] MsgrNETMSG_C;
logic [95:0] MsgrContextMSG_C;
logic [4:0] MsgrNETSTAT_C;
logic MsgrEUCONTINUE_C, MsgrEUHALT_C, MsgrESTB_C, MsgrEURESTART_C;
logic [63:0] MsgrERRC_C;

logic MsgrRST_D, MsgrNETMSGRD_D, MsgrACT_D, MsgrCMD_D;
logic [44:0] MsgrADDR_D;
logic [1:0] MsgrSIZE_D;
logic [31:0] MsgrDATO_D;
logic MsgrContextREQ_D, MsgrContextCHK_D, MsgrNETSEND_D, MsgrNETTYPE_D;
logic [95:0] MsgrContextMSG_D;
logic [79:0] MsgrNETMSG_D;
logic [4:0] MsgrNETSTAT_D;
logic MsgrEUCONTINUE_D, MsgrEUHALT_D, MsgrESTB_D, MsgrEURESTART_D;
logic [63:0] MsgrERRC_D;

//-----------------------------------------------
//				Stream controller resources
logic StreamINIT_A, StreamCoreNEXT_A, StreamCoreDRDY_A, StreamNetNEXT_A, StreamACT_A, StreamCMD_A;
logic StreamNEXTH_A, StreamNEXTV_A, StreamNEXTD_A;
logic [63:0] StreamCoreDTO_A, StreamDTO_A;
logic [7:0] StreamCoreTAGO_A;
logic [2:0] StreamCoreSIZEO_A;
logic [1:0] StreamSIZEO_A;
logic [44:0] StreamADDR_A;
logic [4:0] StreamTAGO_A;

logic StreamINIT_B, StreamCoreNEXT_B, StreamCoreDRDY_B, StreamNetNEXT_B, StreamACT_B, StreamCMD_B;
logic StreamNEXTH_B, StreamNEXTV_B, StreamNEXTD_B;
logic [63:0] StreamCoreDTO_B, StreamDTO_B;
logic [7:0] StreamCoreTAGO_B;
logic [2:0] StreamCoreSIZEO_B;
logic [1:0] StreamSIZEO_B;
logic [44:0] StreamADDR_B;
logic [4:0] StreamTAGO_B;

logic StreamINIT_C, StreamCoreNEXT_C, StreamCoreDRDY_C, StreamNetNEXT_C, StreamNBNEXT_C, StreamACT_C, StreamCMD_C;
logic StreamNEXTH_C, StreamNEXTV_C, StreamNEXTD_C;
logic [63:0] StreamCoreDTO_C, StreamDTO_C;
logic [7:0] StreamCoreTAGO_C;
logic [2:0] StreamCoreSIZEO_C;
logic [1:0] StreamSIZEO_C;
logic [44:0] StreamADDR_C;
logic [4:0] StreamTAGO_C;

logic StreamINIT_D, StreamCoreNEXT_D, StreamCoreDRDY_D, StreamNetNEXT_D, StreamNBNEXT_D, StreamACT_D, StreamCMD_D;
logic StreamNEXTH_D, StreamNEXTV_D, StreamNEXTD_D;
logic [63:0] StreamCoreDTO_D, StreamDTO_D;
logic [7:0] StreamCoreTAGO_D;
logic [2:0] StreamCoreSIZEO_D;
logic [1:0] StreamSIZEO_D;
logic [44:0] StreamADDR_D;
logic [4:0] StreamTAGO_D;

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

logic FPUCoreNEXT_C, FpuACT_C, FpuSACT_C, FpuCMD_C, FpuINIT_C;
logic FpuCOREDRDY_C;
logic [63:0] FpuDTO_C;
logic [23:0] FpuSEL_C;
logic [63:0] FpuCOREDTI_C;
logic [7:0] FpuCORETAGI_C;
logic [2:0] FpuCORESIZEI_C;
logic FpuESTB_C;
logic [12:0] FpuECD_C;
logic FpuMSGREQ_C, FpuMSGNEXT_C;
logic [121:0] FpuMSGDATA_C;
logic [1:0] FpuSIZEO_C;
logic [44:0] FpuADDR_C;
logic [12:0] FpuTAGO_C;
logic FpuSTOSTB_C, FpuSTINEXT_C, FpuSTONEW_C;
logic [63:0] FpuSTODT_C;

logic FPUCoreNEXT_D, FpuACT_D, FpuSACT_D, FpuCMD_D, FpuINIT_D;
logic [63:0] FpuDTO_D;
logic [23:0] FpuSEL_D;
logic FpuCOREDRDY_D;
logic [63:0] FpuCOREDTI_D;
logic [7:0] FpuCORETAGI_D;
logic [2:0] FpuCORESIZEI_D;
logic FpuESTB_D;
logic [12:0] FpuECD_D;
logic FpuMSGREQ_D, FpuMSGNEXT_D;
logic [121:0] FpuMSGDATA_D;
logic [1:0] FpuSIZEO_D;
logic [44:0] FpuADDR_D;
logic [12:0] FpuTAGO_D;
logic FpuSTOSTB_D, FpuSTINEXT_D, FpuSTONEW_D;
logic [63:0] FpuSTODT_D;

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

logic [3:0] RteEXTSTBO_C;
logic [32:0] RteEXTDO_C [3:0];
logic [3:0] RteEXTSTBI_C;
logic [32:0] RteEXTDI_C [3:0];
logic RteSTONEXT_C, RteSTINEW_C, RteSTIVAL_C;
logic [63:0] RteSTIDT_C;

logic [3:0] RteEXTSTBO_D;
logic [32:0] RteEXTDO_D [3:0];
logic [3:0] RteEXTSTBI_D;
logic [32:0] RteEXTDI_D [3:0];
logic RteSTONEXT_D, RteSTINEW_D, RteSTIVAL_D;
logic [63:0] RteSTIDT_D;

//=====================================================================================================================
//
// 				CORE UNITs
//
//=====================================================================================================================
extern module EU64S4 (
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
	input wire [39:0] DTBASEH, DTBASEV, DTBASED,
	input wire [23:0] DTLIMITH, DTLIMITV, DTLIMITD,
	input wire DTRESETH, DTRESETV, DTRESETD,
	// interface to datapatch of memory subsystem
	input wire NEXT, StreamNEXT, StreamNEXTH, StreamNEXTV, StreamNEXTD, NetNEXT, NEXTH, NEXTV, NEXTD,
	output reg ACT, StreamACT, StreamACTH, StreamACTV, StreamACTD, NetACT, ACTH, ACTV, ACTD, CMD, 
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
EU64S4  Core_A(.CLK(CLK), .RESET(RST_A), .CLOAD(ContextEUCLOAD_A), .CPU(CPUBus_A), .TASKID(ContextCSR_A[15:0]), .CPSR(ContextCPSR_A),
			.DTBASE(TmuxDTBASE_A), .DTLIMIT(TmuxDTLIMIT_A), .DTRESET(TmuxDTRESET_A), .CPL(ContextCSR_A[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_B), .DTLIMITH(TmuxDTLIMIT_B), .DTRESETH(TmuxDTRESET_B),
			.DTBASEV(TmuxDTBASE_C), .DTLIMITV(TmuxDTLIMIT_C), .DTRESETV(TmuxDTRESET_C),
			.DTBASED(TmuxDTBASE_D), .DTLIMITD(TmuxDTLIMIT_D), .DTRESETD(TmuxDTRESET_D),
			// memory, stream and network interfaces
			.NEXT(ContextEUNEXT_A), .StreamNEXT(StreamCoreNEXT_A), .StreamNEXTH(StreamNEXTH_B), .StreamNEXTV(StreamNEXTV_C), .StreamNEXTD(StreamNEXTD_D),
			.NetNEXT(FPUCoreNEXT_A), .NEXTH(TmuxCoreNEXTH_B), .NEXTV(TmuxCoreNEXTV_C), .NEXTD(TmuxCoreNEXTD_D),
			.ACT(CoreACT_A), .StreamACT(CoreStreamACT_A), .StreamACTH(CoreStreamACTH_A), .StreamACTV(CoreStreamACTV_A), .StreamACTD(CoreStreamACTD_A),
			.NetACT(CoreNetACT_A), .ACTH(CoreACTH_A), .ACTV(CoreACTV_A), .ACTD(CoreACTD_A),
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
DMuxS4	CoreMux_A(.CLK(CLK), .RESET(RST_A),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_A), .LocalDATA({ContextEUSZi_A, ContextEUTAGi_A, ContextEUDTi_A}), .LocalRD(CoreMuxLocalRD_A),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_A), .StreamDATA({StreamCoreSIZEO_A, StreamCoreTAGO_A, StreamCoreDTO_A}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_A), .NetDATA({FpuCORESIZEI_A, FpuCORETAGI_A, FpuCOREDTI_A}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_B), .DATAH({TmuxLSIZEI_B, TmuxLTAGI_B[7:0], TmuxLDATI_B}), 
		.DRDYV(TmuxCoreDRDYV_C), .DATAV({TmuxLSIZEI_C, TmuxLTAGI_C[7:0], TmuxLDATI_C}), 
		.DRDYD(TmuxCoreDRDYD_D), .DATAD({TmuxLSIZEI_D, TmuxLTAGI_D[7:0], TmuxLDATI_D}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_A), .TAG({CoreMuxSZi_A, CoreMuxTAGi_A}), .DATA(CoreMuxDTi_A)
		);
defparam CoreMux_A.TagWidth=11;

// CORE B (North-East)
EU64S4  Core_B(.CLK(CLK), .RESET(RST_B), .CLOAD(ContextEUCLOAD_B), .CPU(CPUBus_B), .TASKID(ContextCSR_B[15:0]), .CPSR(ContextCPSR_B),
			.DTBASE(TmuxDTBASE_B), .DTLIMIT(TmuxDTLIMIT_B), .DTRESET(TmuxDTRESET_B), .CPL(ContextCSR_B[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_A), .DTLIMITH(TmuxDTLIMIT_A), .DTRESETH(TmuxDTRESET_A),
			.DTBASEV(TmuxDTBASE_D), .DTLIMITV(TmuxDTLIMIT_D), .DTRESETV(TmuxDTRESET_D),
			.DTBASED(TmuxDTBASE_C), .DTLIMITD(TmuxDTLIMIT_C), .DTRESETD(TmuxDTRESET_C),
			// memory, stream and network interface
			.NEXT(ContextEUNEXT_B), .StreamNEXT(StreamCoreNEXT_B), .StreamNEXTH(StreamNEXTH_A), .StreamNEXTV(StreamNEXTV_D), .StreamNEXTD(StreamNEXTD_C),
			.NetNEXT(FPUCoreNEXT_B), .NEXTH(TmuxCoreNEXTH_A), .NEXTV(TmuxCoreNEXTV_D), .NEXTD(TmuxCoreNEXTD_C),
			.ACT(CoreACT_B), .StreamACT(CoreStreamACT_B), .StreamACTH(CoreStreamACTH_B), .StreamACTV(CoreStreamACTV_B), .StreamACTD(CoreStreamACTD_B),
			.NetACT(CoreNetACT_B), .ACTH(CoreACTH_B), .ACTV(CoreACTV_B), .ACTD(CoreACTD_B),
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
DMuxS4	CoreMux_B(.CLK(CLK), .RESET(RST_B),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_B), .LocalDATA({ContextEUSZi_B, ContextEUTAGi_B, ContextEUDTi_B}), .LocalRD(CoreMuxLocalRD_B),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_B), .StreamDATA({StreamCoreSIZEO_B, StreamCoreTAGO_B, StreamCoreDTO_B}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_B), .NetDATA({FpuCORESIZEI_B, FpuCORETAGI_B, FpuCOREDTI_B}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_A), .DATAH({TmuxLSIZEI_A, TmuxLTAGI_A[7:0], TmuxLDATI_A}), 
		.DRDYV(TmuxCoreDRDYV_D), .DATAV({TmuxLSIZEI_D, TmuxLTAGI_D[7:0], TmuxLDATI_D}), 
		.DRDYD(TmuxCoreDRDYD_C), .DATAD({TmuxLSIZEI_C, TmuxLTAGI_C[7:0], TmuxLDATI_C}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_B), .TAG({CoreMuxSZi_B, CoreMuxTAGi_B}), .DATA(CoreMuxDTi_B)
		);
defparam CoreMux_B.TagWidth=11;

// CORE C (South-West)
EU64S4  Core_C(.CLK(CLK), .RESET(RST_C), .CLOAD(ContextEUCLOAD_C), .CPU(CPUBus_C), .TASKID(ContextCSR_C[15:0]), .CPSR(ContextCPSR_C),
			.DTBASE(TmuxDTBASE_C), .DTLIMIT(TmuxDTLIMIT_C), .DTRESET(TmuxDTRESET_C), .CPL(ContextCSR_C[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_D), .DTLIMITH(TmuxDTLIMIT_D), .DTRESETH(TmuxDTRESET_D),
			.DTBASEV(TmuxDTBASE_A), .DTLIMITV(TmuxDTLIMIT_A), .DTRESETV(TmuxDTRESET_A),
			.DTBASED(TmuxDTBASE_B), .DTLIMITD(TmuxDTLIMIT_B), .DTRESETD(TmuxDTRESET_B),
			// memory, stream and network interface
			.NEXT(ContextEUNEXT_C), .StreamNEXT(StreamCoreNEXT_C), .StreamNEXTH(StreamNEXTH_D), .StreamNEXTV(StreamNEXTV_A), .StreamNEXTD(StreamNEXTD_B),
			.NetNEXT(FPUCoreNEXT_C), .NEXTH(TmuxCoreNEXTH_D), .NEXTV(TmuxCoreNEXTV_A), .NEXTD(TmuxCoreNEXTD_B),
			.ACT(CoreACT_C), .StreamACT(CoreStreamACT_C), .StreamACTH(CoreStreamACTH_C), .StreamACTV(CoreStreamACTV_C), .StreamACTD(CoreStreamACTD_C),
			.NetACT(CoreNetACT_C), .ACTH(CoreACTH_C), .ACTV(CoreACTV_C), .ACTD(CoreACTD_C),
			.CMD(CoreCMD_C), .OS(CoreOS_C), .ADDRESS(CoreADDRESS_C), .OFFSET(CoreOFFSET_C), .SELECTOR(CoreSELECTOR_C), .DTo(CoreDTo_C), .TAGo(CoreTAGo_C),
			.DRDY(CoreMuxDRDY_C), .TAGi(CoreMuxTAGi_C), .SZi(CoreMuxSZi_C), .DTi(CoreMuxDTi_C),
			// FFT memory interface
			.FFTMemNEXT(ContextEUNEXT_C & ~CoreACT_C & ~ContextEUCLOAD_C), .FFTMemACT(CoreFFTMemACT_C), .FFTMemCMD(CoreFFTMemCMD_C),
			.FFTMemADDR(CoreFFTMemADDR_C), .FFTMemDO(CoreFFTMemDO_C), .FFTMemTO(CoreFFTMemTO_C),
			// message system interface
			.PARAM(CorePARAM_C), .PARREG(CorePARREG_C), .MSGREQ(CoreMSGREQ_C), .MALLOCREQ(CoreMALLOCREQ_C), .PARREQ(CorePARREQ_C),
			.ENDMSG(CoreENDMSG_C), .BKPT(CoreBKPT_C), .EMPTY(CoreEMPTY_C), .HALT(CoreHALT_C), .NPCS(CoreNPCS_C), .SMSGBKPT(CoreSMSGBKPT_C), .CEXEC(ContextEURESTART_C | MsgrEURESTART_C),
			.ESMSG(MsgrEUCONTINUE_C), .CONTINUE(ContextCONTINUE_C), .CSTOP(MsgrEUHALT_C | ContextCORESTOP_C | IntFlag_C), .LIRESET(ContextLIRESET_C),
			// context store interface
			.RA(ContextRA_C), .CDATA(CoreCDATA_C), .RIP(CoreRIP_C),
			// error reporting
			.ESTB(CoreESTB_C), .ECD(CoreECD_C),
			// FFT engine error report interface
			.FFTESTB(CoreFFTESTB_C), .FFTECD(CoreFFTECD_C), .FFTCPSR(CoreFFTCPSR_C),
			.FATAL(CoreFATAL_C),
			// Performance monitor outputs
			.IV(CoreIV_C),
			.CSEL(CoreCSEL_C)
			);

// DataMux C
DMuxS4	CoreMux_C(.CLK(CLK), .RESET(RST_C),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_C), .LocalDATA({ContextEUSZi_C, ContextEUTAGi_C, ContextEUDTi_C}), .LocalRD(CoreMuxLocalRD_C),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_C), .StreamDATA({StreamCoreSIZEO_C, StreamCoreTAGO_C, StreamCoreDTO_C}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_C), .NetDATA({FpuCORESIZEI_C, FpuCORETAGI_C, FpuCOREDTI_C}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_D), .DATAH({TmuxLSIZEI_D, TmuxLTAGI_D[7:0], TmuxLDATI_D}), 
		.DRDYV(TmuxCoreDRDYV_A), .DATAV({TmuxLSIZEI_A, TmuxLTAGI_A[7:0], TmuxLDATI_A}), 
		.DRDYD(TmuxCoreDRDYD_B), .DATAD({TmuxLSIZEI_B, TmuxLTAGI_B[7:0], TmuxLDATI_B}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_C), .TAG({CoreMuxSZi_C, CoreMuxTAGi_C}), .DATA(CoreMuxDTi_C)
		);
defparam CoreMux_C.TagWidth=11;

// CORE D (South-East)
EU64S4  Core_D(.CLK(CLK), .RESET(RST_D), .CLOAD(ContextEUCLOAD_D), .CPU(CPUBus_D), .TASKID(ContextCSR_D[15:0]), .CPSR(ContextCPSR_D),
			.DTBASE(TmuxDTBASE_D), .DTLIMIT(TmuxDTLIMIT_D), .DTRESET(TmuxDTRESET_D), .CPL(ContextCSR_D[19:18]),
			// descriptor tables for neighbourhood
			.DTBASEH(TmuxDTBASE_C), .DTLIMITH(TmuxDTLIMIT_C), .DTRESETH(TmuxDTRESET_C),
			.DTBASEV(TmuxDTBASE_B), .DTLIMITV(TmuxDTLIMIT_B), .DTRESETV(TmuxDTRESET_B),
			.DTBASED(TmuxDTBASE_A), .DTLIMITD(TmuxDTLIMIT_A), .DTRESETD(TmuxDTRESET_A),
			// memory, stream and network interface
			.NEXT(ContextEUNEXT_D), .StreamNEXT(StreamCoreNEXT_D), .StreamNEXTH(StreamNEXTH_C), .StreamNEXTV(StreamNEXTV_B), .StreamNEXTD(StreamNEXTD_A),
			.NetNEXT(FPUCoreNEXT_D), .NEXTH(TmuxCoreNEXTH_C), .NEXTV(TmuxCoreNEXTV_B), .NEXTD(TmuxCoreNEXTD_A),
			.ACT(CoreACT_D), .StreamACT(CoreStreamACT_D), .StreamACTH(CoreStreamACTH_D), .StreamACTV(CoreStreamACTV_D), .StreamACTD(CoreStreamACTD_D),
			.NetACT(CoreNetACT_D), .ACTH(CoreACTH_D), .ACTV(CoreACTV_D), .ACTD(CoreACTD_D),
			.CMD(CoreCMD_D), .OS(CoreOS_D), .ADDRESS(CoreADDRESS_D), .OFFSET(CoreOFFSET_D), .SELECTOR(CoreSELECTOR_D), .DTo(CoreDTo_D), .TAGo(CoreTAGo_D),
			.DRDY(CoreMuxDRDY_D), .TAGi(CoreMuxTAGi_D), .SZi(CoreMuxSZi_D), .DTi(CoreMuxDTi_D),
			// FFT memory interface
			.FFTMemNEXT(ContextEUNEXT_D & ~CoreACT_D & ~ContextEUCLOAD_D), .FFTMemACT(CoreFFTMemACT_D), .FFTMemCMD(CoreFFTMemCMD_D), 
			.FFTMemADDR(CoreFFTMemADDR_D), .FFTMemDO(CoreFFTMemDO_D), .FFTMemTO(CoreFFTMemTO_D),
			// message system interface
			.PARAM(CorePARAM_D), .PARREG(CorePARREG_D), .MSGREQ(CoreMSGREQ_D), .MALLOCREQ(CoreMALLOCREQ_D), .PARREQ(CorePARREQ_D),
			.ENDMSG(CoreENDMSG_D), .BKPT(CoreBKPT_D), .EMPTY(CoreEMPTY_D), .HALT(CoreHALT_D), .NPCS(CoreNPCS_D), .SMSGBKPT(CoreSMSGBKPT_D), .CEXEC(ContextEURESTART_D | MsgrEURESTART_D),
			.ESMSG(MsgrEUCONTINUE_D), .CONTINUE(ContextCONTINUE_D), .CSTOP(MsgrEUHALT_D | ContextCORESTOP_D | IntFlag_D), .LIRESET(ContextLIRESET_D),
			// context store interface
			.RA(ContextRA_D), .CDATA(CoreCDATA_D), .RIP(CoreRIP_D),
			// error reporting
			.ESTB(CoreESTB_D), .ECD(CoreECD_D),
			// FFT engine error report interface
			.FFTESTB(CoreFFTESTB_D), .FFTECD(CoreFFTECD_D), .FFTCPSR(CoreFFTCPSR_D),
			.FATAL(CoreFATAL_D),
			// Performance monitor outputs
			.IV(CoreIV_D),
			.CSEL(CoreCSEL_D)
			);

// DataMux D
DMuxS4	CoreMux_D(.CLK(CLK), .RESET(RST_D),
		// datapatch from local memory (lowest priority)
		.LocalDRDY(ContextEUDRDY_D), .LocalDATA({ContextEUSZi_D, ContextEUTAGi_D, ContextEUDTi_D}), .LocalRD(CoreMuxLocalRD_D),
		// datapatch form stream controller (middle priority)
		.StreamDRDY(StreamCoreDRDY_D), .StreamDATA({StreamCoreSIZEO_D, StreamCoreTAGO_D, StreamCoreDTO_D}),
		// datapatch from network controller (highest priority)
		.NetDRDY(FpuCOREDRDY_D), .NetDATA({FpuCORESIZEI_D, FpuCORETAGI_D, FpuCOREDTI_D}),
		// data patches from neighbourhood
		.DRDYH(TmuxCoreDRDYH_C), .DATAH({TmuxLSIZEI_C, TmuxLTAGI_C[7:0], TmuxLDATI_C}), 
		.DRDYV(TmuxCoreDRDYV_B), .DATAV({TmuxLSIZEI_B, TmuxLTAGI_B[7:0], TmuxLDATI_B}), 
		.DRDYD(TmuxCoreDRDYD_A), .DATAD({TmuxLSIZEI_A, TmuxLTAGI_A[7:0], TmuxLDATI_A}), 
		// output to the EU resources
		.DRDY(CoreMuxDRDY_D), .TAG({CoreMuxSZi_D, CoreMuxTAGi_D}), .DATA(CoreMuxDTi_D)
		);
defparam CoreMux_D.TagWidth=11;

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

ErrorFIFO EFifo_C(.CLK(CLK), .RESET(RST_C), .CPSR(ContextCPSR_C),
				// read fifo interface
				.ERD(TmuxESRRD_C & EfifoVALID_C), .VALID(EfifoVALID_C), .ECD(EfifoECD_C),
				// error interface from core
				.CoreSTB(CoreESTB_C), .CoreECD(CoreECD_C),
				// error interface from FFT coprocessor
				.FFTSTB(CoreFFTESTB_C), .FFTECD(CoreFFTECD_C), .FFTCPSR(CoreFFTCPSR_C),
				// error report from outer network
				.NetSTB(FpuESTB_C), .NetECD(FpuECD_C),
				// error report from messenger
				.MsgrSTB(MsgrESTB_C), .MsgrECD(MsgrERRC_C),
				// error report from context controller
				.ContSTB(ContextESTB_C), .ContECD(ContextERC_C)
				);

ErrorFIFO EFifo_D(.CLK(CLK), .RESET(RST_D), .CPSR(ContextCPSR_D),
				// read fifo interface
				.ERD(TmuxESRRD_D & EfifoVALID_D), .VALID(EfifoVALID_D), .ECD(EfifoECD_D),
				// error interface from core
				.CoreSTB(CoreESTB_D), .CoreECD(CoreECD_D),
				// error interface from FFT coprocessor
				.FFTSTB(CoreFFTESTB_D), .FFTECD(CoreFFTECD_D), .FFTCPSR(CoreFFTCPSR_D),
				// error report from outer network
				.NetSTB(FpuESTB_D), .NetECD(FpuECD_D),
				// error report from messenger
				.MsgrSTB(MsgrESTB_D), .MsgrECD(MsgrERRC_D),
				// error report from context controller
				.ContSTB(ContextESTB_D), .ContECD(ContextERC_D)
				);

//=====================================================================================================================
//
// 				BUS MULTIPLEXER UNITs
//
//=====================================================================================================================
extern module MUX64S4 (
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
	output wire CoreNEXTH, CoreNEXTV, CoreNEXTD,
	input wire CoreACTH, CoreACTV, CoreACTD, CoreCMDH, CoreCMDV, CoreCMDD,
	input wire [1:0] CoreSIZEH, CoreSIZEV, CoreSIZED,
	input wire [44:0] CoreADDRH, CoreADDRV, CoreADDRD,
	input wire [63:0] CoreDATAH, CoreDATAV, CoreDATAD,
	input wire [7:0] CoreTAGH, CoreTAGV, CoreTAGD,
	output reg CoreDRDYH, CoreDRDYV, CoreDRDYD,
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

extern module MUX64S4SL (
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
	output wire CoreNEXTH, CoreNEXTV, CoreNEXTD,
	input wire CoreACTH, CoreACTV, CoreACTD, CoreCMDH, CoreCMDV, CoreCMDD,
	input wire [1:0] CoreSIZEH, CoreSIZEV, CoreSIZED,
	input wire [44:0] CoreADDRH, CoreADDRV, CoreADDRD,
	input wire [63:0] CoreDATAH, CoreDATAV, CoreDATAD,
	input wire [7:0] CoreTAGH, CoreTAGV, CoreTAGD,
	output reg CoreDRDYH, CoreDRDYV, CoreDRDYD,
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

// North-West
MUX64S4 Tmux_A(.CLK(CLK), .RESETn(RST_A), 
			// services interface
			.LNEXT(TmuxLNEXT_A),
			.LACT({MsgrACT_A, ContextACT_A[1], StreamACT_A, FpuACT_A, ContextACT_A[0]}),
			.LCMD({MsgrCMD_A, ContextCMD_A[1], StreamCMD_A, FpuCMD_A, ContextCMD_A[0]}),
			.LSIZEO(TmuxLSIZEO_A), .LADDR(TmuxLADDR_A), .LDATO(TmuxLDATO_A), .LTAGO(TmuxLTAGO_A),
			.LDRDY(TmuxLDRDY_A), .LDATI(TmuxLDATI_A), .LTAGI(TmuxLTAGI_A), .LSIZEI(TmuxLSIZEI_A),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_A), .CoreNEXTV(TmuxCoreNEXTV_A), .CoreNEXTD(TmuxCoreNEXTD_A),
			.CoreACTH(CoreACTH_B), .CoreACTV(CoreACTV_C), .CoreACTD(CoreACTD_D), .CoreCMDH(CoreCMD_B), .CoreCMDV(CoreCMD_C), .CoreCMDD(CoreCMD_D),
			.CoreSIZEH(CoreOS_B), .CoreSIZEV(CoreOS_C), .CoreSIZED(CoreOS_D), .CoreADDRH(CoreADDRESS_B), .CoreADDRV(CoreADDRESS_C), .CoreADDRD(CoreADDRESS_D),
			.CoreDATAH(CoreDTo_B), .CoreDATAV(CoreDTo_C), .CoreDATAD(CoreDTo_D), .CoreTAGH(CoreTAGo_B), .CoreTAGV(CoreTAGo_C), .CoreTAGD(CoreTAGo_D),
			.CoreDRDYH(TmuxCoreDRDYH_A), .CoreDRDYV(TmuxCoreDRDYV_A), .CoreDRDYD(TmuxCoreDRDYD_A),
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
			.IV(CoreIV_A), .CSEL(CoreCSEL_A), .EMPTY(CoreEMPTY_A), .TCKScaler(TCKScale), .CoreType(8'd4)
			);

// North_East
MUX64S4SL Tmux_B(.CLK(CLK), .RESETn(RST_B), 
			// services interface
			.LNEXT(TmuxLNEXT_B),
			.LACT({MsgrACT_B, ContextACT_B[1], StreamACT_B, FpuACT_B, ContextACT_B[0]}),
			.LCMD({MsgrCMD_B, ContextCMD_B[1], StreamCMD_B, FpuCMD_B, ContextCMD_B[0]}),
			.LSIZEO(TmuxLSIZEO_B), .LADDR(TmuxLADDR_B), .LDATO(TmuxLDATO_B), .LTAGO(TmuxLTAGO_B),
			.LDRDY(TmuxLDRDY_B), .LDATI(TmuxLDATI_B), .LTAGI(TmuxLTAGI_B), .LSIZEI(TmuxLSIZEI_B),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_B), .CoreNEXTV(TmuxCoreNEXTV_B), .CoreNEXTD(TmuxCoreNEXTD_B),
			.CoreACTH(CoreACTH_A), .CoreACTV(CoreACTV_D), .CoreACTD(CoreACTD_C), .CoreCMDH(CoreCMD_A), .CoreCMDV(CoreCMD_D), .CoreCMDD(CoreCMD_C),
			.CoreSIZEH(CoreOS_A), .CoreSIZEV(CoreOS_D), .CoreSIZED(CoreOS_C), .CoreADDRH(CoreADDRESS_A), .CoreADDRV(CoreADDRESS_D), .CoreADDRD(CoreADDRESS_C),
			.CoreDATAH(CoreDTo_A), .CoreDATAV(CoreDTo_D), .CoreDATAD(CoreDTo_C), .CoreTAGH(CoreTAGo_A), .CoreTAGV(CoreTAGo_D), .CoreTAGD(CoreTAGo_C),
			.CoreDRDYH(TmuxCoreDRDYH_B), .CoreDRDYV(TmuxCoreDRDYV_B), .CoreDRDYD(TmuxCoreDRDYD_B),
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
			.IV(CoreIV_B), .CSEL(CoreCSEL_B), .EMPTY(CoreEMPTY_B), .TCKScaler(TCKScale), .CoreType(8'd4)
			);

// South-West
MUX64S4SL Tmux_C(.CLK(CLK), .RESETn(RST_C), 
			// services interface
			.LNEXT(TmuxLNEXT_C),
			.LACT({MsgrACT_C, ContextACT_C[1], StreamACT_C, FpuACT_C, ContextACT_C[0]}),
			.LCMD({MsgrCMD_C, ContextCMD_C[1], StreamCMD_C, FpuCMD_C, ContextCMD_C[0]}),
			.LSIZEO(TmuxLSIZEO_C), .LADDR(TmuxLADDR_C), .LDATO(TmuxLDATO_C), .LTAGO(TmuxLTAGO_C),
			.LDRDY(TmuxLDRDY_C), .LDATI(TmuxLDATI_C), .LTAGI(TmuxLTAGI_C), .LSIZEI(TmuxLSIZEI_C),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_C), .CoreNEXTV(TmuxCoreNEXTV_C), .CoreNEXTD(TmuxCoreNEXTD_C),
			.CoreACTH(CoreACTH_D), .CoreACTV(CoreACTV_A), .CoreACTD(CoreACTD_B), .CoreCMDH(CoreCMD_D), .CoreCMDV(CoreCMD_A), .CoreCMDD(CoreCMD_B),
			.CoreSIZEH(CoreOS_D), .CoreSIZEV(CoreOS_A), .CoreSIZED(CoreOS_B), .CoreADDRH(CoreADDRESS_D), .CoreADDRV(CoreADDRESS_A), .CoreADDRD(CoreADDRESS_B),
			.CoreDATAH(CoreDTo_D), .CoreDATAV(CoreDTo_A), .CoreDATAD(CoreDTo_B), .CoreTAGH(CoreTAGo_D), .CoreTAGV(CoreTAGo_A), .CoreTAGD(CoreTAGo_B),
			.CoreDRDYH(TmuxCoreDRDYH_C), .CoreDRDYV(TmuxCoreDRDYV_C), .CoreDRDYD(TmuxCoreDRDYD_C),
			// local memory interface
			.CMD(CMD_C), .ADDR(ADDR_C), .DATA(DATA_C), .BE(BE_C), .TAG(TAG_C),
			.FLNEXT(FlashNEXT_C), .FLACT(TmuxFLACT_C), .FLDRDY(FlashDRDY_C), .FLDAT(FlashDTO_C), .FLTAG(FlashTAGO_C),
			.SDNEXT(SDCacheINEXT_C), .SDACT(TmuxSDACT_C), .SDDRDY(SDCacheIDRDY_C), .SDDAT(SDCacheIDATo_C), .SDTAG(SDCacheITAGo_C),
			.IONEXT(IONEXT_C), .IOACT(IOACT_C), .IODRDY(IODRDY_C), .IODAT(IODAT_C), .IOTAG(IOTAG_C),
			// status and control lines and buses
			.DTBASE(TmuxDTBASE_C), .DTLIMIT(TmuxDTLIMIT_C), .INTSEL(TmuxINTSEL_C), .INTLIMIT(TmuxINTLIMIT_C), .CPUNUM(CPUBus_C), .NENA(TmuxNENA_C), .INTRST(TmuxINTRST_C),
			.INTENA(TmuxINTENA_C), .ESRRD(TmuxESRRD_C), .CENA(TmuxCENA_C), .MALOCKF(TMuxMALOCKF_C), .PTINTR(TmuxPTINTR_C), .NLE(4'd0), .NERR(4'd0),
			.CSR(ContextCSR_C), .CPSR(ContextCPSR_C), .FREEMEM(ContextFREEMEM_C), .CACHEDMEM(ContextCACHEDMEM_C), .ESR({EfifoECD_C[63:56] & {8{EfifoVALID_C}},EfifoECD_C[55:0]}),
			.CPSRSTB(TmuxCPSRSTB_C), .CSRSTB(TmuxCSRSTB_C), .SINIT(StreamINIT_C), .NINIT(FpuINIT_C), .CINIT(ContextREADY_C), .TCK(TickFlag), .TCKOVR(CoreNPCS_C), .HALT(CoreHALT_C),
			.DTRESET(TmuxDTRESET_C),
			.IV(CoreIV_C), .CSEL(CoreCSEL_C), .EMPTY(CoreEMPTY_C), .TCKScaler(TCKScale), .CoreType(8'd4)
			);

// South_East
MUX64S4SL Tmux_D(.CLK(CLK), .RESETn(RST_D), 
			// services interface
			.LNEXT(TmuxLNEXT_D),
			.LACT({MsgrACT_D, ContextACT_D[1], StreamACT_D, FpuACT_D, ContextACT_D[0]}),
			.LCMD({MsgrCMD_D, ContextCMD_D[1], StreamCMD_D, FpuCMD_D, ContextCMD_D[0]}),
			.LSIZEO(TmuxLSIZEO_D), .LADDR(TmuxLADDR_D), .LDATO(TmuxLDATO_D), .LTAGO(TmuxLTAGO_D),
			.LDRDY(TmuxLDRDY_D), .LDATI(TmuxLDATI_D), .LTAGI(TmuxLTAGI_D), .LSIZEI(TmuxLSIZEI_D),
			// neighbourhood interface
			.CoreNEXTH(TmuxCoreNEXTH_D), .CoreNEXTV(TmuxCoreNEXTV_D), .CoreNEXTD(TmuxCoreNEXTD_D),
			.CoreACTH(CoreACTH_C), .CoreACTV(CoreACTV_B), .CoreACTD(CoreACTD_A), .CoreCMDH(CoreCMD_C), .CoreCMDV(CoreCMD_B), .CoreCMDD(CoreCMD_A),
			.CoreSIZEH(CoreOS_C), .CoreSIZEV(CoreOS_B), .CoreSIZED(CoreOS_A), .CoreADDRH(CoreADDRESS_C), .CoreADDRV(CoreADDRESS_B), .CoreADDRD(CoreADDRESS_A),
			.CoreDATAH(CoreDTo_C), .CoreDATAV(CoreDTo_B), .CoreDATAD(CoreDTo_A), .CoreTAGH(CoreTAGo_C), .CoreTAGV(CoreTAGo_B), .CoreTAGD(CoreTAGo_A),
			.CoreDRDYH(TmuxCoreDRDYH_D), .CoreDRDYV(TmuxCoreDRDYV_D), .CoreDRDYD(TmuxCoreDRDYD_D),
			// local memory interface
			.CMD(CMD_D), .ADDR(ADDR_D), .DATA(DATA_D), .BE(BE_D), .TAG(TAG_D),
			.FLNEXT(FlashNEXT_D), .FLACT(TmuxFLACT_D), .FLDRDY(FlashDRDY_D), .FLDAT(FlashDTO_D), .FLTAG(FlashTAGO_D),
			.SDNEXT(SDCacheINEXT_D), .SDACT(TmuxSDACT_D), .SDDRDY(SDCacheIDRDY_D), .SDDAT(SDCacheIDATo_D), .SDTAG(SDCacheITAGo_D),
			.IONEXT(IONEXT_D), .IOACT(IOACT_D), .IODRDY(IODRDY_D), .IODAT(IODAT_D), .IOTAG(IOTAG_D),
			// status and control lines and buses
			.DTBASE(TmuxDTBASE_D), .DTLIMIT(TmuxDTLIMIT_D), .INTSEL(TmuxINTSEL_D), .INTLIMIT(TmuxINTLIMIT_D), .CPUNUM(CPUBus_D), .NENA(TmuxNENA_D), .INTRST(TmuxINTRST_D),
			.INTENA(TmuxINTENA_D), .ESRRD(TmuxESRRD_D), .CENA(TmuxCENA_D), .MALOCKF(TMuxMALOCKF_D), .PTINTR(TmuxPTINTR_D), .NLE(4'd0), .NERR(4'd0),
			.CSR(ContextCSR_D), .CPSR(ContextCPSR_D), .FREEMEM(ContextFREEMEM_D), .CACHEDMEM(ContextCACHEDMEM_D), .ESR({EfifoECD_D[63:56] & {8{EfifoVALID_D}},EfifoECD_D[55:0]}),
			.CPSRSTB(TmuxCPSRSTB_D), .CSRSTB(TmuxCSRSTB_D), .SINIT(StreamINIT_D), .NINIT(FpuINIT_D), .CINIT(ContextREADY_D), .TCK(TickFlag), .TCKOVR(CoreNPCS_D), .HALT(CoreHALT_D),
			.DTRESET(TmuxDTRESET_D),
			.IV(CoreIV_D), .CSEL(CoreCSEL_D), .EMPTY(CoreEMPTY_D), .TCKScaler(TCKScale), .CoreType(8'd4)
			);

//=====================================================================================================================
//
// 				Cache UNITs
//
//=====================================================================================================================
// North-West
extern module Cache4x64x2048(
	input wire RESET, CLK,
	// internal ISI
	output wire INEXT,
	input wire IACT, ICMD,
	input wire [41:0] IADDR,
	input wire [63:0] IDATi,
	input wire [7:0] IBE,
	input wire [20:0] ITAGi,
	output reg IDRDY,
	output reg [63:0] IDATo,
	output reg [20:0] ITAGo,
	// external ISI
	input wire ENEXT,
	output reg EACT, ECMD,
	output reg [41:0] EADDR,
	output reg [63:0] EDATo,
	output reg [7:0] EBE,
	output reg [1:0] ETAGo,
	input wire EDRDY,
	input wire [63:0] EDATi,
	input wire [1:0] ETAGi
	);
Cache4x64x2048 SDCache_A(.RESET(RST_A), .CLK(CLK),
				// internal ISI
				.INEXT(SDCacheINEXT_A), .IACT(TmuxSDACT_A), .ICMD(CMD_A), .IADDR(ADDR_A[44:3]), .IDATi(DATA_A), .IBE(BE_A), .ITAGi(TAG_A),
				.IDRDY(SDCacheIDRDY_A), .IDATo(SDCacheIDATo_A), .ITAGo(SDCacheITAGo_A),
				// external ISI
				.ENEXT(SDNEXT_A), .EACT(SDACT_A), .ECMD(SDCMD_A), .EADDR(SDCacheEADDR_A), .EDATo(SDDI_A), .EBE(SDBE_A), .ETAGo(SDTI_A),
				.EDRDY(SDDRDY_A), .EDATi(SDDO_A), .ETAGi(SDTO_A)
				);

// North-East
Cache4x64x2048 SDCache_B(.RESET(RST_B), .CLK(CLK),
				// internal ISI
				.INEXT(SDCacheINEXT_B), .IACT(TmuxSDACT_B), .ICMD(CMD_B), .IADDR(ADDR_B[44:3]), .IDATi(DATA_B), .IBE(BE_B), .ITAGi(TAG_B),
				.IDRDY(SDCacheIDRDY_B), .IDATo(SDCacheIDATo_B), .ITAGo(SDCacheITAGo_B),
				// external ISI
				.ENEXT(SDNEXT_B), .EACT(SDACT_B), .ECMD(SDCMD_B), .EADDR(SDCacheEADDR_B), .EDATo(SDDI_B), .EBE(SDBE_B), .ETAGo(SDTI_B),
				.EDRDY(SDDRDY_B), .EDATi(SDDO_B), .ETAGi(SDTO_B)
				);

// South-West
Cache4x64x2048 SDCache_C(.RESET(RST_C), .CLK(CLK),
				// internal ISI
				.INEXT(SDCacheINEXT_C), .IACT(TmuxSDACT_C), .ICMD(CMD_C), .IADDR(ADDR_C[44:3]), .IDATi(DATA_C), .IBE(BE_C), .ITAGi(TAG_C),
				.IDRDY(SDCacheIDRDY_C), .IDATo(SDCacheIDATo_C), .ITAGo(SDCacheITAGo_C),
				// external ISI
				.ENEXT(SDNEXT_C), .EACT(SDACT_C), .ECMD(SDCMD_C), .EADDR(SDCacheEADDR_C), .EDATo(SDDI_C), .EBE(SDBE_C), .ETAGo(SDTI_C),
				.EDRDY(SDDRDY_C), .EDATi(SDDO_C), .ETAGi(SDTO_C)
				);

// South-East
Cache4x64x2048 SDCache_D(.RESET(RST_D), .CLK(CLK),
				// internal ISI
				.INEXT(SDCacheINEXT_D), .IACT(TmuxSDACT_D), .ICMD(CMD_D), .IADDR(ADDR_D[44:3]), .IDATi(DATA_D), .IBE(BE_D), .ITAGi(TAG_D),
				.IDRDY(SDCacheIDRDY_D), .IDATo(SDCacheIDATo_D), .ITAGo(SDCacheITAGo_D),
				// external ISI
				.ENEXT(SDNEXT_D), .EACT(SDACT_D), .ECMD(SDCMD_D), .EADDR(SDCacheEADDR_D), .EDATo(SDDI_D), .EBE(SDBE_D), .ETAGo(SDTI_D),
				.EDRDY(SDDRDY_D), .EDATi(SDDO_D), .ETAGi(SDTO_D)
				);

//=====================================================================================================================
//
// 				FLASH UNITs
//
//=====================================================================================================================
// Notrh-West
Flash16  Flash_A(.CLKH(CLK), .RESET(RST_A), .NEXT(FlashNEXT_A), .ACT(TmuxFLACT_A), .CMD(CMD_A), .ADDR(ADDR_A[31:0]),
				.BE(BE_A), .DTI(DATA_A), .TAGI(TAG_A), .DRDY(FlashDRDY_A), .DTO(FlashDTO_A), .TAGO(FlashTAGO_A),
				// interface to the external memory
				.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI));

// Notrh-East
Flash16  Flash_B(.CLKH(CLK), .RESET(RST_B), .NEXT(FlashNEXT_B), .ACT(TmuxFLACT_B), .CMD(CMD_B), .ADDR(ADDR_B[31:0]),
				.BE(BE_B), .DTI(DATA_B), .TAGI(TAG_B), .DRDY(FlashDRDY_B), .DTO(FlashDTO_B), .TAGO(FlashTAGO_B),
				// interface to the external memory
				.FLCK(), .FLRST(), .FLCS(), .FLSO(), .FLSI(1'b1));

// South-West
Flash16  Flash_C(.CLKH(CLK), .RESET(RST_C), .NEXT(FlashNEXT_C), .ACT(TmuxFLACT_C), .CMD(CMD_C), .ADDR(ADDR_C[31:0]),
				.BE(BE_C), .DTI(DATA_C), .TAGI(TAG_C), .DRDY(FlashDRDY_C), .DTO(FlashDTO_C), .TAGO(FlashTAGO_C),
				// interface to the external memory
				.FLCK(), .FLRST(), .FLCS(), .FLSO(), .FLSI(1'b1));

// South-East
Flash16  Flash_D(.CLKH(CLK), .RESET(RST_D), .NEXT(FlashNEXT_D), .ACT(TmuxFLACT_D), .CMD(CMD_D), .ADDR(ADDR_D[31:0]),
				.BE(BE_D), .DTI(DATA_D), .TAGI(TAG_D), .DRDY(FlashDRDY_D), .DTO(FlashDTO_D), .TAGO(FlashTAGO_D),
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

// Notrh-West
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

// North-East
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

// South-West
ContextCTRL16 Context_C(.CLK(CLK), .RESETn(RST_C), .CENA(TmuxCENA_C), .MALOCKF(TMuxMALOCKF_C), .PTINTR(TmuxPTINTR_C),
				.DTBASE(TmuxDTBASE_C), .DTLIMIT(TmuxDTLIMIT_C), .CPUNUM(CPUBus_C), .RST(ContextRST_C), .READY(ContextREADY_C),
				.CPSR(ContextCPSR_C), .CSR(ContextCSR_C), .FREEMEM(ContextFREEMEM_C), .CACHEDMEM(ContextCACHEDMEM_C), .EXTDI(DATA_C), .CPSRSTB(TmuxCPSRSTB_C),
				.CSRSTB(TmuxCSRSTB_C), .RIP(CoreRIP_C),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT_C[3], TmuxLNEXT_C[0]}), .ACT(ContextACT_C), .CMD(ContextCMD_C), .ADDR(ContextADDR_C), .SIZE(ContextSIZE_C),
				.TAGo(ContextTAGo_C), .DTo(ContextDTo_C),
				.DRDY({TmuxLDRDY_C[3], TmuxLDRDY_C[0]}), .DTi(TmuxLDATI_C), .TAGi(TmuxLTAGI_C[7:0]), .SZi(TmuxLSIZEI_C),
				// interface to messages controller
				.MSGACK(ContextMSGACK_C), .MSGREQ(MsgrContextREQ_C), .CHKREQ(MsgrContextCHK_C), .MSGPARAM(MsgrContextMSG_C),
				// low-speed memory interface from EU
				.EUNEXT(ContextEUNEXT_C), .EUACT(CoreACT_C | (CoreFFTMemACT_C & ~ContextEUCLOAD_C)), .EUCMD(CoreACT_C ? CoreCMD_C : CoreFFTMemCMD_C),
				.EUSZo(CoreACT_C ? CoreOS_C : 2'b11), .EUADDR(CoreACT_C ? CoreADDRESS_C : {CoreFFTMemADDR_C, 3'd0}), .EUDTo(CoreACT_C ? CoreDTo_C : CoreFFTMemDO_C),
				.EUTAGo(CoreACT_C ? CoreTAGo_C : CoreFFTMemTO_C),
				.EUDRDY(ContextEUDRDY_C), .EUTAGi(ContextEUTAGi_C), .EUSZi(ContextEUSZi_C), .EUDTi(ContextEUDTi_C), .EURD(CoreMuxLocalRD_C),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ_C), .GETPARREQ(CorePARREQ_C), .EUPARAM(CorePARAM_C), .EUREG(CorePARREG_C), .EUEMPTY(CoreEMPTY_C), .EUENDMSG(CoreENDMSG_C),
				.SMSGBKPT(CoreSMSGBKPT_C), .CORESTART(ContextEURESTART_C), .CORESTOP(ContextCORESTOP_C), .CORECONT(ContextCONTINUE_C), .EUCLOAD(ContextEUCLOAD_C), .LIRESET(ContextLIRESET_C),
				// context load/store interface to EU
				.RA(ContextRA_C), .CDAT(CoreCDATA_C),
				// error reporting interface
				.ESTB(ContextESTB_C), .ERC(ContextERC_C)
				);

// South-East
ContextCTRL16 Context_D(.CLK(CLK), .RESETn(RST_D), .CENA(TmuxCENA_D), .MALOCKF(TMuxMALOCKF_D), .PTINTR(TmuxPTINTR_D),
				.DTBASE(TmuxDTBASE_D), .DTLIMIT(TmuxDTLIMIT_D), .CPUNUM(CPUBus_D), .RST(ContextRST_D), .READY(ContextREADY_D),
				.CPSR(ContextCPSR_D), .CSR(ContextCSR_D), .FREEMEM(ContextFREEMEM_D), .CACHEDMEM(ContextCACHEDMEM_D), .EXTDI(DATA_D), .CPSRSTB(TmuxCPSRSTB_D),
				.CSRSTB(TmuxCSRSTB_D), .RIP(CoreRIP_D),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT_D[3], TmuxLNEXT_D[0]}), .ACT(ContextACT_D), .CMD(ContextCMD_D), .ADDR(ContextADDR_D), .SIZE(ContextSIZE_D),
				.TAGo(ContextTAGo_D), .DTo(ContextDTo_D),
				.DRDY({TmuxLDRDY_D[3], TmuxLDRDY_D[0]}), .DTi(TmuxLDATI_D), .TAGi(TmuxLTAGI_D[7:0]), .SZi(TmuxLSIZEI_D),
				// interface to messages controller
				.MSGACK(ContextMSGACK_D), .MSGREQ(MsgrContextREQ_D), .CHKREQ(MsgrContextCHK_D), .MSGPARAM(MsgrContextMSG_D),
				// low-speed memory interface from EU
				.EUNEXT(ContextEUNEXT_D), .EUACT(CoreACT_D | (CoreFFTMemACT_D & ~ContextEUCLOAD_D)), .EUCMD(CoreACT_D ? CoreCMD_D : CoreFFTMemCMD_D),
				.EUSZo(CoreACT_D ? CoreOS_D : 2'b11), .EUADDR(CoreACT_D ? CoreADDRESS_D : {CoreFFTMemADDR_D, 3'd0}), .EUDTo(CoreACT_D ? CoreDTo_D : CoreFFTMemDO_D),
				.EUTAGo(CoreACT_D ? CoreTAGo_D : CoreFFTMemTO_D),
				.EUDRDY(ContextEUDRDY_D), .EUTAGi(ContextEUTAGi_D), .EUSZi(ContextEUSZi_D), .EUDTi(ContextEUDTi_D), .EURD(CoreMuxLocalRD_D),
				// control interface to EU
				.MALLOCREQ(CoreMALLOCREQ_D), .GETPARREQ(CorePARREQ_D), .EUPARAM(CorePARAM_D), .EUREG(CorePARREG_D), .EUEMPTY(CoreEMPTY_D), .EUENDMSG(CoreENDMSG_D),
				.SMSGBKPT(CoreSMSGBKPT_D), .CORESTART(ContextEURESTART_D), .CORESTOP(ContextCORESTOP_D), .CORECONT(ContextCONTINUE_D), .EUCLOAD(ContextEUCLOAD_D), .LIRESET(ContextLIRESET_D),
				// context load/store interface to EU
				.RA(ContextRA_D), .CDAT(CoreCDATA_D),
				// error reporting interface
				.ESTB(ContextESTB_D), .ERC(ContextERC_D)
				);

//=====================================================================================================================
//
// 				 MESSENGERS
//
//=====================================================================================================================
// North-West
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

// North_East
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

// South-West
Messenger16 Msgr_C(.CLK(CLK), .RESETn(RST_C), .RST(MsgrRST_C),
			// message interface from EU, error system, interrupt system, network system and neighbourhood processors
			.EUREQ(CoreMSGREQ_C), .ERRORREQ(EfifoVALID_C & ~DEfifoVALID_C),
			.INTREQ(IntReqFlag_C), .NETREQ(FpuMSGREQ_C), .EUPARAM(CorePARAM_C), .INTPARAM(INTCODE_C),
			.NETPARAM(FpuMSGDATA_C), .NETMSGRD(MsgrNETMSGRD_C), .INTACK(INTACK_C),
			// interface to memory system
			.NEXT(TmuxLNEXT_C[4]), .ACT(MsgrACT_C), .CMD(MsgrCMD_C), .ADDR(MsgrADDR_C), .SIZE(MsgrSIZE_C), .DATO(MsgrDATO_C),
			.DRDY(TmuxLDRDY_C[4]), .DATI(TmuxLDATI_C[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContextMSGACK_C), .ContextREQ(MsgrContextREQ_C), .ContextCHK(MsgrContextCHK_C), .ContextMSG(MsgrContextMSG_C),
			// interface to network controller
			.NETRDY(FpuMSGNEXT_C), .NETSEND(MsgrNETSEND_C), .NETTYPE(MsgrNETTYPE_C), .NETMSG(MsgrNETMSG_C), .NETSTAT(MsgrNETSTAT_C),
			// DTR and DTL registers
			.DTBASE(TmuxDTBASE_C), .DTLIMIT(TmuxDTLIMIT_C), .CPUNUM(CPUBus_C), .CPSR(ContextCPSR_C), .INTSR(TmuxINTSEL_C), .INTCR(TmuxINTLIMIT_C), .CSR(ContextCSR_C),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE_C), .EURESTART(MsgrEURESTART_C), .EUHALT(MsgrEUHALT_C), .BKPT(CoreBKPT_C),
			// error reporting interface
			.ESTB(MsgrESTB_C), .ERRC(MsgrERRC_C)
			);

// South-East
Messenger16 Msgr_D(.CLK(CLK), .RESETn(RST_D), .RST(MsgrRST_D),
			// message interface from EU, error system, interrupt system, network system and neighbourhood processors
			.EUREQ(CoreMSGREQ_D), .ERRORREQ(EfifoVALID_D & ~DEfifoVALID_D),
			.INTREQ(IntReqFlag_D), .NETREQ(FpuMSGREQ_D), .EUPARAM(CorePARAM_D), .INTPARAM(INTCODE_D),
			.NETPARAM(FpuMSGDATA_D), .NETMSGRD(MsgrNETMSGRD_D), .INTACK(INTACK_D),
			// interface to memory system
			.NEXT(TmuxLNEXT_D[4]), .ACT(MsgrACT_D), .CMD(MsgrCMD_D), .ADDR(MsgrADDR_D), .SIZE(MsgrSIZE_D), .DATO(MsgrDATO_D),
			.DRDY(TmuxLDRDY_D[4]), .DATI(TmuxLDATI_D[31:0]),
			// interface to the context controller (interrupt or error)
			.ContextRDY(ContextMSGACK_D), .ContextREQ(MsgrContextREQ_D), .ContextCHK(MsgrContextCHK_D), .ContextMSG(MsgrContextMSG_D),
			// interface to network controller
			.NETRDY(FpuMSGNEXT_D), .NETSEND(MsgrNETSEND_D), .NETTYPE(MsgrNETTYPE_D), .NETMSG(MsgrNETMSG_D), .NETSTAT(MsgrNETSTAT_D),
			// DTR and DTL registers
			.DTBASE(TmuxDTBASE_D), .DTLIMIT(TmuxDTLIMIT_D), .CPUNUM(CPUBus_D), .CPSR(ContextCPSR_D), .INTSR(TmuxINTSEL_D), .INTCR(TmuxINTLIMIT_D), .CSR(ContextCSR_D),
			// control lines
			.EUCONTINUE(MsgrEUCONTINUE_D), .EURESTART(MsgrEURESTART_D), .EUHALT(MsgrEUHALT_D), .BKPT(CoreBKPT_D),
			// error reporting interface
			.ESTB(MsgrESTB_D), .ERRC(MsgrERRC_D)
			);

//=====================================================================================================================
//
// 				 STREAM CONTROLLERS
//
//=====================================================================================================================
// North-West
StreamControllerS4 Stream_A(.CLK(CLK), .RESET(RST_A), .TE(TickFlag), .DTBASE(TmuxDTBASE_A), .INIT(StreamINIT_A),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_A), .CoreACT(CoreStreamACT_A), .CoreCMD(CoreCMD_A), .CoreADDR(CoreADDRESS_A[0]), .CoreSEL(CoreSELECTOR_A[23:0]), 
						.CoreDTI(CoreDTo_A), .CoreTAGI(CoreTAGo_A),
						.CoreDRDY(StreamCoreDRDY_A), .CoreDTO(StreamCoreDTO_A), .CoreTAGO(StreamCoreTAGO_A), .CoreSIZEO(StreamCoreSIZEO_A),
						// network interface
						.NetNEXT(StreamNetNEXT_A), .NetACT(FpuSACT_A), .NetSEL(FpuSEL_A), .NetDATA(FpuDTO_A),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_A), .NEXTV(StreamNEXTV_A), .NEXTD(StreamNEXTD_A),
						.ACTH(CoreStreamACTH_B), .ACTV(CoreStreamACTV_C), .ACTD(CoreStreamACTD_D),
						.SELH(CoreSELECTOR_B[23:0]), .SELV(CoreSELECTOR_C[23:0]), .SELD(CoreSELECTOR_D[23:0]),
						.DATAH(CoreDTo_B), .DATAV(CoreDTo_C), .DATAD(CoreDTo_D),
						// local memory interface
						.NEXT(TmuxLNEXT_A[2]), .ACT(StreamACT_A), .CMD(StreamCMD_A), .SIZEO(StreamSIZEO_A), .ADDR(StreamADDR_A), .DTO(StreamDTO_A), .TAGO(StreamTAGO_A),
						.DRDY(TmuxLDRDY_A[2]), .DTI(TmuxLDATI_A), .TAGI(TmuxLTAGI_A[4:0]));

// North-East
StreamControllerS4 Stream_B(.CLK(CLK), .RESET(RST_B), .TE(TickFlag), .DTBASE(TmuxDTBASE_B), .INIT(StreamINIT_B),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_B), .CoreACT(CoreStreamACT_B), .CoreCMD(CoreCMD_B), .CoreADDR(CoreADDRESS_B[0]), .CoreSEL(CoreSELECTOR_B[23:0]), 
						.CoreDTI(CoreDTo_B), .CoreTAGI(CoreTAGo_B),
						.CoreDRDY(StreamCoreDRDY_B), .CoreDTO(StreamCoreDTO_B), .CoreTAGO(StreamCoreTAGO_B), .CoreSIZEO(StreamCoreSIZEO_B),
						// network interface
						.NetNEXT(StreamNetNEXT_B), .NetACT(FpuSACT_B), .NetSEL(FpuSEL_B), .NetDATA(FpuDTO_B),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_B), .NEXTV(StreamNEXTV_B), .NEXTD(StreamNEXTD_B),
						.ACTH(CoreStreamACTH_A), .ACTV(CoreStreamACTV_D), .ACTD(CoreStreamACTD_C),
						.SELH(CoreSELECTOR_A[23:0]), .SELV(CoreSELECTOR_D[23:0]), .SELD(CoreSELECTOR_C[23:0]),
						.DATAH(CoreDTo_A), .DATAV(CoreDTo_D), .DATAD(CoreDTo_C),
						// local memory interface
						.NEXT(TmuxLNEXT_B[2]), .ACT(StreamACT_B), .CMD(StreamCMD_B), .SIZEO(StreamSIZEO_B), .ADDR(StreamADDR_B), .DTO(StreamDTO_B), .TAGO(StreamTAGO_B),
						.DRDY(TmuxLDRDY_B[2]), .DTI(TmuxLDATI_B), .TAGI(TmuxLTAGI_B[4:0]));

// South-West
StreamControllerS4 Stream_C(.CLK(CLK), .RESET(RST_C), .TE(TickFlag), .DTBASE(TmuxDTBASE_C), .INIT(StreamINIT_C),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_C), .CoreACT(CoreStreamACT_C), .CoreCMD(CoreCMD_C), .CoreADDR(CoreADDRESS_C[0]), .CoreSEL(CoreSELECTOR_C[23:0]), 
						.CoreDTI(CoreDTo_C), .CoreTAGI(CoreTAGo_C),
						.CoreDRDY(StreamCoreDRDY_C), .CoreDTO(StreamCoreDTO_C), .CoreTAGO(StreamCoreTAGO_C), .CoreSIZEO(StreamCoreSIZEO_C),
						// network interface
						.NetNEXT(StreamNetNEXT_C), .NetACT(FpuSACT_C), .NetSEL(FpuSEL_C), .NetDATA(FpuDTO_C),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_C), .NEXTV(StreamNEXTV_C), .NEXTD(StreamNEXTD_C),
						.ACTH(CoreStreamACTH_D), .ACTV(CoreStreamACTV_A), .ACTD(CoreStreamACTD_B),
						.SELH(CoreSELECTOR_D[23:0]), .SELV(CoreSELECTOR_A[23:0]), .SELD(CoreSELECTOR_B[23:0]),
						.DATAH(CoreDTo_D), .DATAV(CoreDTo_A), .DATAD(CoreDTo_B),
						// local memory interface
						.NEXT(TmuxLNEXT_C[2]), .ACT(StreamACT_C), .CMD(StreamCMD_C), .SIZEO(StreamSIZEO_C), .ADDR(StreamADDR_C), .DTO(StreamDTO_C), .TAGO(StreamTAGO_C),
						.DRDY(TmuxLDRDY_C[2]), .DTI(TmuxLDATI_C), .TAGI(TmuxLTAGI_C[4:0]));

// South-East
StreamControllerS4 Stream_D(.CLK(CLK), .RESET(RST_D), .TE(TickFlag), .DTBASE(TmuxDTBASE_D), .INIT(StreamINIT_D),
						// Core interface
						.CoreNEXT(StreamCoreNEXT_D), .CoreACT(CoreStreamACT_D), .CoreCMD(CoreCMD_D), .CoreADDR(CoreADDRESS_D[0]), .CoreSEL(CoreSELECTOR_D[23:0]), 
						.CoreDTI(CoreDTo_D), .CoreTAGI(CoreTAGo_D),
						.CoreDRDY(StreamCoreDRDY_D), .CoreDTO(StreamCoreDTO_D), .CoreTAGO(StreamCoreTAGO_D), .CoreSIZEO(StreamCoreSIZEO_D),
						// network interface
						.NetNEXT(StreamNetNEXT_D), .NetACT(FpuSACT_D), .NetSEL(FpuSEL_D), .NetDATA(FpuDTO_D),
						// neighbourhood interface
						.NEXTH(StreamNEXTH_D), .NEXTV(StreamNEXTV_D), .NEXTD(StreamNEXTD_D),
						.ACTH(CoreStreamACTH_C), .ACTV(CoreStreamACTV_B), .ACTD(CoreStreamACTD_A),
						.SELH(CoreSELECTOR_C[23:0]), .SELV(CoreSELECTOR_B[23:0]), .SELD(CoreSELECTOR_A[23:0]),
						.DATAH(CoreDTo_C), .DATAV(CoreDTo_B), .DATAD(CoreDTo_A),
						// local memory interface
						.NEXT(TmuxLNEXT_D[2]), .ACT(StreamACT_D), .CMD(StreamCMD_D), .SIZEO(StreamSIZEO_D), .ADDR(StreamADDR_D), .DTO(StreamDTO_D), .TAGO(StreamTAGO_D),
						.DRDY(TmuxLDRDY_D[2]), .DTI(TmuxLDATI_D), .TAGI(TmuxLTAGI_D[4:0]));

//=====================================================================================================================
//
// 				 Frame Processing Units
//
//=====================================================================================================================
// North-West
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

// North-East
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

// South-West
FPU16 Fpu_C(.CLK(CLK), .RESETn(RST_C), .TCK(TickFlag), .DTBASE(TmuxDTBASE_C), .DTLIMIT(TmuxDTLIMIT_C), .CPUNUM(CPUBus_C), .TASKID(ContextCSR_C[15:0]), .CPSR(ContextCPSR_C), .INIT(FpuINIT_C),
		// interface to core
		.CORENEXT(FPUCoreNEXT_C), .COREACT(CoreNetACT_C), .CORECMD(CoreCMD_C), .CORESIZE(CoreOS_C), .CORECPL(ContextCSR_C[19:18]),
		.COREOFFSET(CoreOFFSET_C), .CORESEL(CoreSELECTOR_C), .COREDTO(CoreDTo_C), .CORETAGO(CoreTAGo_C),
		.COREDRDY(FpuCOREDRDY_C), .COREDTI(FpuCOREDTI_C), .CORETAGI(FpuCORETAGI_C), .CORESIZEI(FpuCORESIZEI_C),
		// local memory interface
		.NEXT(TmuxLNEXT_C[1]), .SNEXT(StreamNetNEXT_C), .ACT(FpuACT_C), .SACT(FpuSACT_C), .CMD(FpuCMD_C), .SIZEO(FpuSIZEO_C), .ADDR(FpuADDR_C),
		.DTO(FpuDTO_C), .TAGO(FpuTAGO_C), .SEL(FpuSEL_C),
		.DRDY(TmuxLDRDY_C[1]), .DTI(TmuxLDATI_C), .SIZEI(TmuxLSIZEI_C[1:0]), .TAGI(TmuxLTAGI_C),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT_C), .STONEW(FpuSTONEW_C), .STODT(FpuSTODT_C), .STINEXT(FpuSTINEXT_C), .STIVAL(RteSTIVAL_C), .STINEW(RteSTINEW_C), .STIDT(RteSTIDT_C),
		// messages interface
		.MSGREQ(FpuMSGREQ_C), .MSGRD(MsgrNETMSGRD_C), .MSGDATA(FpuMSGDATA_C), 
		.MSGNEXT(FpuMSGNEXT_C), .MSGSEND(MsgrNETSEND_C), .MSGTYPE(MsgrNETTYPE_C), .MSGPARAM(MsgrNETMSG_C), .MSGSTAT(MsgrNETSTAT_C),
		// error report interface
		.ESTB(FpuESTB_C), .ECD(FpuECD_C));

// South-East
FPU16 Fpu_D(.CLK(CLK), .RESETn(RST_D), .TCK(TickFlag), .DTBASE(TmuxDTBASE_D), .DTLIMIT(TmuxDTLIMIT_D), .CPUNUM(CPUBus_D), .TASKID(ContextCSR_D[15:0]), .CPSR(ContextCPSR_D), .INIT(FpuINIT_D),
		// interface to core
		.CORENEXT(FPUCoreNEXT_D), .COREACT(CoreNetACT_D), .CORECMD(CoreCMD_D), .CORESIZE(CoreOS_D), .CORECPL(ContextCSR_D[19:18]),
		.COREOFFSET(CoreOFFSET_D), .CORESEL(CoreSELECTOR_D), .COREDTO(CoreDTo_D), .CORETAGO(CoreTAGo_D),
		.COREDRDY(FpuCOREDRDY_D), .COREDTI(FpuCOREDTI_D), .CORETAGI(FpuCORETAGI_D), .CORESIZEI(FpuCORESIZEI_D),
		// local memory interface
		.NEXT(TmuxLNEXT_D[1]), .SNEXT(StreamNetNEXT_D), .ACT(FpuACT_D), .SACT(FpuSACT_D), .CMD(FpuCMD_D), .SIZEO(FpuSIZEO_D), .ADDR(FpuADDR_D),
		.DTO(FpuDTO_D), .TAGO(FpuTAGO_D), .SEL(FpuSEL_D),
		.DRDY(TmuxLDRDY_D[1]), .DTI(TmuxLDATI_D), .SIZEI(TmuxLSIZEI_D[1:0]), .TAGI(TmuxLTAGI_D),
		// interface to the routing subsystem
		.STONEXT(RteSTONEXT_D), .STONEW(FpuSTONEW_D), .STOVAL(), .STODT(FpuSTODT_D), .STINEXT(FpuSTINEXT_D), .STIVAL(RteSTIVAL_D), .STINEW(RteSTINEW_D), .STIDT(RteSTIDT_D),
		// messages interface
		.MSGREQ(FpuMSGREQ_D), .MSGRD(MsgrNETMSGRD_D), .MSGDATA(FpuMSGDATA_D), 
		.MSGNEXT(FpuMSGNEXT_D), .MSGSEND(MsgrNETSEND_D), .MSGTYPE(MsgrNETTYPE_D), .MSGPARAM(MsgrNETMSG_D), .MSGSTAT(MsgrNETSTAT_D),
		// error report interface
		.ESTB(FpuESTB_D), .ECD(FpuECD_D));

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
// North-West
RTE Rte_A(.CLK(CLK), .RESET(RST_A), .CPUNUM(CPUBus_A),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_A), .EXTDO(RteEXTDO_A), .EXTSTBI(RteEXTSTBI_A), .EXTDI(RteEXTDI_A),
			// core interface
			.STONEXT(RteSTONEXT_A), .STONEW(FpuSTONEW_A), .STODT(FpuSTODT_A), .STINEXT(FpuSTINEXT_A),
			.STINEW(RteSTINEW_A), .STIVAL(RteSTIVAL_A), .STIDT(RteSTIDT_A));

// North-East
RTE Rte_B(.CLK(CLK), .RESET(RST_B), .CPUNUM(CPUBus_B),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_B), .EXTDO(RteEXTDO_B), .EXTSTBI(RteEXTSTBI_B), .EXTDI(RteEXTDI_B),
			// core interface
			.STONEXT(RteSTONEXT_B), .STONEW(FpuSTONEW_B), .STODT(FpuSTODT_B), .STINEXT(FpuSTINEXT_B),
			.STINEW(RteSTINEW_B), .STIVAL(RteSTIVAL_B), .STIDT(RteSTIDT_B));

// South-West
RTE Rte_C(.CLK(CLK), .RESET(RST_C), .CPUNUM(CPUBus_C),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_C), .EXTDO(RteEXTDO_C), .EXTSTBI(RteEXTSTBI_C), .EXTDI(RteEXTDI_C),
			// core interface
			.STONEXT(RteSTONEXT_C), .STONEW(FpuSTONEW_C), .STODT(FpuSTODT_C), .STINEXT(FpuSTINEXT_C),
			.STINEW(RteSTINEW_C), .STIVAL(RteSTIVAL_C), .STIDT(RteSTIDT_C));

// South-East
RTE Rte_D(.CLK(CLK), .RESET(RST_D), .CPUNUM(CPUBus_D),
			// external interfaces
			.EXTSTBO(RteEXTSTBO_D), .EXTDO(RteEXTDO_D), .EXTSTBI(RteEXTSTBI_D), .EXTDI(RteEXTDI_D),
			// core interface
			.STONEXT(RteSTONEXT_D), .STONEW(FpuSTONEW_D), .STODT(FpuSTODT_D), .STINEXT(FpuSTINEXT_D),
			.STINEW(RteSTINEW_D), .STIVAL(RteSTIVAL_D), .STIDT(RteSTIDT_D));

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

assign TmuxLSIZEO_C[4]=MsgrSIZE_C;
assign TmuxLSIZEO_C[3]=ContextSIZE_C[1];
assign TmuxLSIZEO_C[2]=StreamSIZEO_C;
assign TmuxLSIZEO_C[1]=FpuSIZEO_C;
assign TmuxLSIZEO_C[0]=ContextSIZE_C[0];

assign TmuxLADDR_C[4]=MsgrADDR_C;
assign TmuxLADDR_C[3]=ContextADDR_C[1];
assign TmuxLADDR_C[2]=StreamADDR_C;
assign TmuxLADDR_C[1]=FpuADDR_C;
assign TmuxLADDR_C[0]=ContextADDR_C[0];

assign TmuxLDATO_C[4]={32'd0, MsgrDATO_C};
assign TmuxLDATO_C[3]=ContextDTo_C[1];
assign TmuxLDATO_C[2]=StreamDTO_C;
assign TmuxLDATO_C[1]=FpuDTO_C;
assign TmuxLDATO_C[0]=ContextDTo_C[0];

assign TmuxLTAGO_C[4]=13'd0;
assign TmuxLTAGO_C[3]={5'd0, ContextTAGo_C[1]};
assign TmuxLTAGO_C[2]={7'd0, StreamTAGO_C};
assign TmuxLTAGO_C[1]=FpuTAGO_C;
assign TmuxLTAGO_C[0]={5'd0, ContextTAGo_C[0]};

assign TmuxLSIZEO_D[4]=MsgrSIZE_D;
assign TmuxLSIZEO_D[3]=ContextSIZE_D[1];
assign TmuxLSIZEO_D[2]=StreamSIZEO_D;
assign TmuxLSIZEO_D[1]=FpuSIZEO_D;
assign TmuxLSIZEO_D[0]=ContextSIZE_D[0];

assign TmuxLADDR_D[4]=MsgrADDR_D;
assign TmuxLADDR_D[3]=ContextADDR_D[1];
assign TmuxLADDR_D[2]=StreamADDR_D;
assign TmuxLADDR_D[1]=FpuADDR_D;
assign TmuxLADDR_D[0]=ContextADDR_D[0];

assign TmuxLDATO_D[4]={32'd0, MsgrDATO_D};
assign TmuxLDATO_D[3]=ContextDTo_D[1];
assign TmuxLDATO_D[2]=StreamDTO_D;
assign TmuxLDATO_D[1]=FpuDTO_D;
assign TmuxLDATO_D[0]=ContextDTo_D[0];

assign TmuxLTAGO_D[4]=13'd0;
assign TmuxLTAGO_D[3]={5'd0, ContextTAGo_D[1]};
assign TmuxLTAGO_D[2]={7'd0, StreamTAGO_D};
assign TmuxLTAGO_D[1]=FpuTAGO_D;
assign TmuxLTAGO_D[0]={5'd0, ContextTAGo_D[0]};

assign STBO_NW=RteEXTSTBO_A[0];
assign NETDO_NW=RteEXTDO_A[0];
assign STBO_NE=RteEXTSTBO_B[0];
assign NETDO_NE=RteEXTDO_B[0];
assign STBO_EN=RteEXTSTBO_B[1];
assign NETDO_EN=RteEXTDO_B[1];
assign STBO_ES=RteEXTSTBO_D[1];
assign NETDO_ES=RteEXTDO_D[1];
assign STBO_SW=RteEXTSTBO_C[2];
assign NETDO_SW=RteEXTDO_C[2];
assign STBO_SE=RteEXTSTBO_D[2];
assign NETDO_SE=RteEXTDO_D[2];
assign STBO_WN=RteEXTSTBO_A[3];
assign NETDO_WN=RteEXTDO_A[3];
assign STBO_WS=RteEXTSTBO_C[3];
assign NETDO_WS=RteEXTDO_C[3];

assign RteEXTSTBI_A={STBI_WN, RteEXTSTBO_C[0], RteEXTSTBO_B[3], STBI_NW};
assign RteEXTDI_A[3]=NETDI_WN, RteEXTDI_A[2]=RteEXTDO_C[0], RteEXTDI_A[1]=RteEXTDO_B[3], RteEXTDI_A[0]=NETDI_NW;

assign RteEXTSTBI_B={RteEXTSTBO_A[1], RteEXTSTBO_D[0], STBI_EN, STBI_NE};
assign RteEXTDI_B[3]=RteEXTDO_A[1], RteEXTDI_B[2]=RteEXTDO_D[0], RteEXTDI_B[1]=NETDI_EN, RteEXTDI_B[0]=NETDI_NE;

assign RteEXTSTBI_C={STBI_WS, STBI_SW, RteEXTSTBO_D[3], RteEXTSTBO_A[2]};
assign RteEXTDI_C[3]=NETDI_WS, RteEXTDI_C[2]=NETDI_SW, RteEXTDI_C[1]=RteEXTDO_D[3], RteEXTDI_C[0]=RteEXTDO_A[2];

assign RteEXTSTBI_D={RteEXTSTBO_C[1], STBI_SE, STBI_ES, RteEXTSTBO_B[2]};
assign RteEXTDI_D[3]=RteEXTDO_C[1], RteEXTDI_D[2]=NETDI_SE, RteEXTDI_D[1]=NETDI_ES, RteEXTDI_D[0]=RteEXTDO_B[2];

assign SDADDR_A=SDCacheEADDR_A-42'h008000000;
assign SDADDR_B=SDCacheEADDR_B-42'h008000000;
assign SDADDR_C=SDCacheEADDR_C-42'h008000000;
assign SDADDR_D=SDCacheEADDR_D-42'h008000000;

//=====================================================================================================================
//					Combinatorical
//=====================================================================================================================
//
always_comb begin
// cpu buses
CPUBus_A={TmuxCPUNUM_A[7:5],1'b0,TmuxCPUNUM_A[3:1],1'b0};
CPUBus_B={TmuxCPUNUM_A[7:5],1'b0,TmuxCPUNUM_A[3:1],1'b1};
CPUBus_C={TmuxCPUNUM_A[7:5],1'b1,TmuxCPUNUM_A[3:1],1'b0};
CPUBus_D={TmuxCPUNUM_A[7:5],1'b1,TmuxCPUNUM_A[3:1],1'b1};
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
RST_C<=EXTRESET & MsgrRST_C & ContextRST_C;
RST_D<=EXTRESET & MsgrRST_D & ContextRST_D;

// timing intervals for stream controller
TECntReg<=(TECntReg+8'd1) & {8{EXTRESET & ~TickFlag}};
TickFlag<=(TECntReg==(TCKScale-2)) & EXTRESET;

// delayed EFIFO flag
DEfifoVALID_A<=EfifoVALID_A & RST_A;
DEfifoVALID_B<=EfifoVALID_B & RST_B;
DEfifoVALID_C<=EfifoVALID_C & RST_C;
DEfifoVALID_D<=EfifoVALID_D & RST_D;

// interrupt flag A
IntFlag_A<=(IntFlag_A | INTREQ_A) & ~INTACK_A & RST_A & TmuxINTENA_A;
IntReqFlag_A<=IntFlag_A & CoreEMPTY_A & ~CoreSMSGBKPT_A  & RST_A & ~DIntReqFlag_A;
DIntReqFlag_A<=(DIntReqFlag_A | IntReqFlag_A) & RST_A & IntFlag_A;

// interrupt flag B
IntFlag_B<=(IntFlag_B | INTREQ_B) & ~INTACK_B & RST_B & TmuxINTENA_B;
IntReqFlag_B<=IntFlag_B & CoreEMPTY_B & ~CoreSMSGBKPT_B  & RST_B & ~DIntReqFlag_B;
DIntReqFlag_B<=(DIntReqFlag_B | IntReqFlag_B) & RST_B & IntFlag_B;

// interrupt flag C
IntFlag_C<=(IntFlag_C | INTREQ_C) & ~INTACK_C & RST_C & TmuxINTENA_C;
IntReqFlag_C<=IntFlag_C & CoreEMPTY_C & ~CoreSMSGBKPT_C & RST_C & ~DIntReqFlag_C;
DIntReqFlag_C<=(DIntReqFlag_C | IntReqFlag_C) & RST_C & IntFlag_C;

// interrupt flag D
IntFlag_D<=(IntFlag_D | INTREQ_D) & ~INTACK_D & RST_D & TmuxINTENA_D;
IntReqFlag_D<=IntFlag_D & CoreEMPTY_D & ~CoreSMSGBKPT_D & RST_D & ~DIntReqFlag_D;
DIntReqFlag_D<=(DIntReqFlag_D | IntReqFlag_D) & RST_D & IntFlag_D;

end

endmodule
