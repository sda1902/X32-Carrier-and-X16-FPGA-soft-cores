module T2X16T2X32Cache4x64x2048 #(parameter TCKScale=20)(
	input wire CLK, EXTRESET,
	output reg FATAL,
	output reg [3:0] EMPTY,

	// internal memory interface
	output wire CMD,
	output wire [44:0] ADDR,
	output wire [63:0] DATA,
	output wire [7:0] BE,
	output wire [20:0] TAG,

	// SDRAM controller channel
	input wire SDNEXT,
	output wire SDACT, SDCMD,
	output wire [41:0] SDADDR,
	output wire [7:0] SDBE,
	output wire [63:0] SDDI,
	output wire [1:0] SDTI,
	input wire SDDRDY,
	input wire [63:0] SDDO,
	input wire [1:0] SDTO,
	
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
	input wire [15:0] INTCODE
);

/*
===================================================================================================
										Variables
===================================================================================================
*/

logic [3:0] ContextEUNEXT, ContextCORESTART, ContextCONTINUE, ContextCORESTOP, ContextEUDRDY, ContextLIRESET;
logic ContextESTB, ContextREADY, ContextRST, ContextMSGACK, ContextMSGCHKACK, ContextPTACK;
logic [31:0] ContextCSR [3:0];
logic [23:0] ContextCPSR [3:0];
logic [6:0] ContextRA;
logic [8:0] ContextEUTAGi;
logic [2:0] ContextEUSZi;
logic [63:0] ContextEUDTi;
logic [31:0] ContextERC;
logic [1:0] ContextACT, ContextCMD;
logic [39:0] ContextFREEMEM, ContextCACHEDMEM;
logic [44:0] ContextADDR[1:0];
logic [1:0] ContextSIZE[1:0];
logic [10:0] ContextTAGo[1:0];
logic [63:0] ContextDTo[1:0];
logic [1:0] ContextEUSZo [3:0];
logic [44:0] ContextEUADDR [3:0];
logic [63:0] ContextEUDTo [3:0];
logic [8:0] ContextEUTAGo [3:0];
logic [3:0] ContextEUCLOAD;

logic [1:0] CPLBus [3:0];

logic DMuxADRDY, DMuxBDRDY, DMuxCDRDY, DMuxDDRDY, DMuxALocalRD, DMuxBLocalRD, DMuxCLocalRD, DMuxDLocalRD;
logic [10:0] DMuxATAG, DMuxBTAG;
logic [11:0] DMuxCTAG, DMuxDTAG;
logic [63:0] DMuxADATA, DMuxBDATA, DMuxCDATA, DMuxDDATA;

logic EfifoVALID;
reg DEfifoVALID;
logic [63:0] EfifoECD;

logic [3:0] EUACT, EUStreamACT, EUNetACT, EUCMD, EUFFTMemACT, EUFFTMemCMD, EUMSGREQ, EUMALLOCREQ;
logic [3:0] EUPARREQ, EUENDMSG, EUBKPT, EUEMPTY, EUHALT, EUNPCS, EUESTB, EUFFTESTB, EUFATAL, EUSMSGBKPT;
logic [1:0] EUOS [3:0];
logic [44:0] EUADDRESS [3:0];
logic [36:0] EUOFFSET [3:0];
logic [31:0] EUSELECTOR [3:0];
logic [63:0] EUDTo [3:0];
logic [8:0] EUTAGo [3:0];
logic [41:0] EUFFTMemADDR [3:0];
logic [63:0] EUFFTMemDO [3:0];
logic [8:0] EUFFTMemTO [3:0];
logic [63:0] EUPARAM [3:0];
logic [4:0] EUPARREG [3:0];
logic [63:0] EUCDATA [3:0];
logic [36:0] EURIP [3:0];
logic [28:0] EUECD [3:0];
logic [28:0] EUFFTECD [3:0];
logic [23:0] EUFFTCPSR [3:0];

logic FlashNEXT, FlashDRDY;
logic [63:0] FlashDTO;
logic [20:0] FlashTAGO;

logic [3:0] FpuEUNEXT, FpuCOREDRDY;
logic FpuESTB, FpuACT, FpuCMD, FpuINIT, FpuMSGREQ, FpuMSGNEXT, FpuSACT, FpuSTONEW, FpuSTINEXT;
logic [12:0] FpuECD;
logic [121:0] FpuMSGDATA;
logic [23:0] FpuSEL;
logic [63:0] FpuCOREDTI;
logic [8:0] FpuCORETAGI;
logic [2:0] FpuCORESIZEI;
logic [1:0] FpuSIZEO, FpuCPSRSel;
logic [44:0] FpuADDR;
logic [63:0] FpuDTO, FpuSTODT;
logic [12:0] FpuTAGO;

logic [3:0] MsgrEUCONTINUE, MsgrEUHALT;
logic MsgrESTB, MsgrACT, MsgrCMD, MsgrContextREQ, MsgrContextCHK, MsgrNETMSGRD, MsgrNETSEND, MsgrNETTYPE, MsgrRST, MsgrContextTT, MsgrEINTR;
logic [63:0] MsgrERRC;
logic [95:0] MsgrContextMSG;
logic [44:0] MsgrADDR;
logic [1:0] MsgrSIZE, MsgrContextCHAN, MsgrNETCPL;
logic [31:0] MsgrDATO;
logic [79:0] MsgrNETMSG;
logic [4:0] MsgrNETSTAT;
logic [15:0] MsgrNETTASKID;
logic [23:0] MsgrNETCPSR;

reg RST;

logic RteSTONEXT, RteSTIVAL, RteSTINEW;
logic [63:0] RteSTIDT;
logic [32:0] RteEXTDO [3:0];
logic [3:0] RteEXTSTBO, RteEXTSTBI;
logic [32:0] RteEXTDI [3:0];

logic SDCacheINEXT, SDCacheIDRDY;
logic [63:0] SDCacheIDATo;
logic [20:0] SDCacheITAGo;
logic [41:0] SDCacheEADDR;

logic StreamACT, StreamCMD, StreamINIT, StreamNetNEXT;
logic [3:0] StreamEUNEXT, StreamCoreDRDY;
logic [23:0] StreamCoreSEL [3:0];
logic [63:0] StreamCoreDTO;
logic [8:0] StreamCoreTAGO;
logic [2:0] StreamCoreSIZEO;
logic [1:0] StreamSIZEO;
logic [44:0] StreamADDR;
logic [63:0] StreamDTO;
logic [4:0] StreamTAGO;

logic StreamDFifoAempty, StreamDFifoBempty, StreamDFifoCempty, StreamDFifoDempty;
logic [74:0] StreamDFifoAq, StreamDFifoBq;
logic [75:0] StreamDFifoCq, StreamDFifoDq;

logic [15:0] TASKIDBus [3:0];

reg TickFlag, IntFlag, IntReqFlag, DIntReqFlag;
reg [7:0] TECntReg;

logic TmuxESRRD, TmuxFLACT, TmuxINTRST, TmuxINTENA, TmuxCENA, TmuxMALOCKF, TmuxSDACT;
logic [7:0] TmuxCPU;
logic [39:0] TmuxDTBASE;
logic [23:0] TmuxDTLIMIT, TmuxINTSEL;
logic [4:0] TmuxLNEXT, TmuxLDRDY;
logic [1:0] TmuxLSIZEO [4:0];
logic [44:0] TmuxLADDR [4:0];
logic [63:0] TmuxLDATO [4:0];
logic [12:0] TmuxLTAGO [4:0];
logic [63:0] TmuxLDATI;
logic [12:0] TmuxLTAGI;
logic [2:0] TmuxLSIZEI;
logic [3:0] TmuxNENA, TmuxPTINTR, TmuxCPINTR;
logic [2:0] TmuxCPSRSTB [3:0];
logic [3:0] TmuxCSRSTB [3:0];
logic [3:0] TmuxIV [3:0];
logic [23:0] TmuxCSEL [3:0];
logic [15:0] TmuxINTLIMIT;

/*
===================================================================================================
										Assignments
===================================================================================================
*/

assign TASKIDBus[0]=ContextCSR[0][15:0], TASKIDBus[1]=ContextCSR[1][15:0], TASKIDBus[2]=ContextCSR[2][15:0], TASKIDBus[3]=ContextCSR[3][15:0];

assign CPLBus[0]=ContextCSR[0][19:18], CPLBus[1]=ContextCSR[1][19:18], CPLBus[2]=ContextCSR[2][19:18], CPLBus[3]=ContextCSR[3][19:18];

assign TmuxLSIZEO[0]=ContextSIZE[0], TmuxLSIZEO[1]=FpuSIZEO, TmuxLSIZEO[2]=StreamSIZEO, TmuxLSIZEO[3]=ContextSIZE[1], TmuxLSIZEO[4]=MsgrSIZE;
assign TmuxLADDR[0]=ContextADDR[0], TmuxLADDR[1]=FpuADDR, TmuxLADDR[2]=StreamADDR, TmuxLADDR[3]=ContextADDR[1], TmuxLADDR[4]=MsgrADDR;
assign TmuxLDATO[0]=ContextDTo[0], TmuxLDATO[1]=FpuDTO, TmuxLDATO[2]=StreamDTO, TmuxLDATO[3]=ContextDTo[1], TmuxLDATO[4]={32'd0, MsgrDATO};
assign TmuxLTAGO[0]={2'd0, ContextTAGo[0]}, TmuxLTAGO[1]=FpuTAGO, TmuxLTAGO[2]={7'd0, StreamTAGO}, TmuxLTAGO[3]={2'd0, ContextTAGo[1]}, TmuxLTAGO[4]=13'd0;
assign ContextEUSZo[0]=EUACT[0] ? EUOS[0] : 2'b11, ContextEUSZo[1]=EUACT[1] ? EUOS[1] : 2'b11;
assign ContextEUSZo[2]=EUACT[2] ? EUOS[2] : 2'b11, ContextEUSZo[3]=EUACT[3] ? EUOS[3] : 2'b11;
assign ContextEUADDR[0]=EUACT[0] ? EUADDRESS[0] : {EUFFTMemADDR[0], 3'd0}, ContextEUADDR[1]=EUACT[1] ? EUADDRESS[1] : {EUFFTMemADDR[1], 3'd0};
assign ContextEUADDR[2]=EUACT[2] ? EUADDRESS[2] : {EUFFTMemADDR[2], 3'd0}, ContextEUADDR[3]=EUACT[3] ? EUADDRESS[3] : {EUFFTMemADDR[3], 3'd0};
assign ContextEUDTo[0]=EUACT[0] ? EUDTo[0] : EUFFTMemDO[0], ContextEUDTo[1]=EUACT[1] ? EUDTo[1] : EUFFTMemDO[1];
assign ContextEUDTo[2]=EUACT[2] ? EUDTo[2] : EUFFTMemDO[2], ContextEUDTo[3]=EUACT[3] ? EUDTo[3] : EUFFTMemDO[3];
assign ContextEUTAGo[0]=EUACT[0] ? EUTAGo[0] : EUFFTMemTO[0], ContextEUTAGo[1]=EUACT[1] ? EUTAGo[1] : EUFFTMemTO[1];
assign ContextEUTAGo[2]=EUACT[2] ? EUTAGo[2] : EUFFTMemTO[2], ContextEUTAGo[3]=EUACT[3] ? EUTAGo[3] : EUFFTMemTO[3];
assign StreamCoreSEL[0]=EUSELECTOR[0][23:0], StreamCoreSEL[1]=EUSELECTOR[1][23:0], StreamCoreSEL[2]=EUSELECTOR[2][23:0], StreamCoreSEL[3]=EUSELECTOR[3][23:0];

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

assign EUTAGo[0][8]=1'b0, EUTAGo[1][8]=1'b0, EUFFTMemTO[0][8]=1'b0, EUFFTMemTO[1][8]=1'b0, EUPARREG[0][4]=1'b0, EUPARREG[1][4]=1'b0;

assign SDADDR=SDCacheEADDR-42'h008000000;


/*
===================================================================================================
										EU X16 and X32
===================================================================================================
*/
extern module EU64x16MT #(parameter Mode=0)(
	input wire CLK, RESET, CLOAD,
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

extern module EU64x32MT #(parameter Mode=0)(
	input wire CLK, RESET, CLOAD,
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
	// FFT memory interface
	input wire FFTMemNEXT,
	output wire FFTMemACT, FFTMemCMD,
	output wire [41:0] FFTMemADDR,
	output wire [63:0] FFTMemDO,
	output wire [8:0] FFTMemTO,
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

EU64x16MT	EU_A(.CLK(CLK), .RESET(RST), .CLOAD(ContextEUCLOAD[0]), .CPU(TmuxCPU), .TASKID(ContextCSR[0][15:0]), .CPSR(ContextCPSR[0]),
				// interface to datapatch of memory subsystem
				.NEXT(ContextEUNEXT[0]), .StreamNEXT(StreamEUNEXT[0]), .NetNEXT(FpuEUNEXT[0]),
				.ACT(EUACT[0]), .StreamACT(EUStreamACT[0]), .NetACT(EUNetACT[0]), .CMD(EUCMD[0]), .OS(EUOS[0]),
				.ADDRESS(EUADDRESS[0]), .OFFSET(EUOFFSET[0]), .SELECTOR(EUSELECTOR[0]), .DTo(EUDTo[0]), .TAGo(EUTAGo[0][7:0]),
				.DRDY(DMuxADRDY), .TAGi(DMuxATAG[7:0]), .SZi(DMuxATAG[10:8]), .DTi(DMuxADATA),
				// FFT memory interface
				.FFTMemNEXT(ContextEUNEXT[0] & ~EUACT[0] & ~ContextEUCLOAD[0]), .FFTMemACT(EUFFTMemACT[0]), .FFTMemCMD(EUFFTMemCMD[0]),
				.FFTMemADDR(EUFFTMemADDR[0]), .FFTMemDO(EUFFTMemDO[0]), .FFTMemTO(EUFFTMemTO[0][7:0]),
				// interface to the descriptor pre-loading system
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPL(ContextCSR[0][19:18]),
				// interface to message control subsystem
				.PARAM(EUPARAM[0]), .PARREG(EUPARREG[0][3:0]), .MSGREQ(EUMSGREQ[0]), .MALLOCREQ(EUMALLOCREQ[0]), .PARREQ(EUPARREQ[0]),
				.ENDMSG(EUENDMSG[0]), .BKPT(EUBKPT[0]), .EMPTY(EUEMPTY[0]), .HALT(EUHALT[0]), .NPCS(EUNPCS[0]), .SMSGBKPT(EUSMSGBKPT[0]),
				.CEXEC(ContextCORESTART[0]), .ESMSG(MsgrEUCONTINUE[0]), .CONTINUE(ContextCONTINUE[0]),
				.CSTOP(MsgrEUHALT[0] | ContextCORESTOP[0]), .LIRESET(ContextLIRESET[0]),
				// context store interface
				.RA(ContextRA[5:0]), .CDATA(EUCDATA[0]), .RIP(EURIP[0]),
				// error reporting interface
				.ESTB(EUESTB[0]), .ECD(EUECD[0]),
				// FFT engine error report interface
				.FFTESTB(EUFFTESTB[0]), .FFTECD(EUFFTECD[0]), .FFTCPSR(EUFFTCPSR[0]),
				// test purpose pins
				.FATAL(EUFATAL[0]),
				// Performance monitor outputs
				.IV(TmuxIV[0]), .CSEL(TmuxCSEL[0])
				);
defparam EU_A.Mode=0;

DMux	DMuxA(.CLK(CLK), .RESET(RST),
				// datapatch from local memory (lowest priority)
				.LocalDRDY(ContextEUDRDY[0]), .LocalDATA({ContextEUSZi, ContextEUTAGi[7:0], ContextEUDTi}), .LocalRD(DMuxALocalRD),
				// datapatch form stream controller (middle priority)
				.StreamDRDY(~StreamDFifoAempty), .StreamDATA(StreamDFifoAq),
				// datapatch from network controller (highest priority)
				.NetDRDY(FpuCOREDRDY[0]), .NetDATA({FpuCORESIZEI, FpuCORETAGI[7:0], FpuCOREDTI}),
				// output to the EU resources
				.DRDY(DMuxADRDY), .TAG(DMuxATAG), .DATA(DMuxADATA)
				);
defparam DMuxA.TagWidth=11;

// data fifo for stream datapatch
sc_fifo	StreamDFifoA(.data({StreamCoreSIZEO, StreamCoreTAGO[7:0], StreamCoreDTO}), .wrreq(StreamCoreDRDY[0]), .rdreq(~FpuCOREDRDY[0] & ~StreamDFifoAempty), 
				.clock(CLK), .sclr(~RST), .q(StreamDFifoAq), .empty(StreamDFifoAempty));
defparam StreamDFifoA.LPM_WIDTH=75, StreamDFifoA.LPM_NUMWORDS=16, StreamDFifoA.LPM_WIDTHU=4;

EU64x16MT	EU_B(.CLK(CLK), .RESET(RST), .CLOAD(ContextEUCLOAD[1]), .CPU(TmuxCPU), .TASKID(ContextCSR[1][15:0]), .CPSR(ContextCPSR[1]),
				// interface to datapatch of memory subsystem
				.NEXT(ContextEUNEXT[1]), .StreamNEXT(StreamEUNEXT[1]), .NetNEXT(FpuEUNEXT[1]),
				.ACT(EUACT[1]), .StreamACT(EUStreamACT[1]), .NetACT(EUNetACT[1]), .CMD(EUCMD[1]), .OS(EUOS[1]),
				.ADDRESS(EUADDRESS[1]), .OFFSET(EUOFFSET[1]), .SELECTOR(EUSELECTOR[1]), .DTo(EUDTo[1]), .TAGo(EUTAGo[1][7:0]),
				.DRDY(DMuxBDRDY), .TAGi(DMuxBTAG[7:0]), .SZi(DMuxBTAG[10:8]), .DTi(DMuxBDATA),
				// FFT memory interface
				.FFTMemNEXT(ContextEUNEXT[1] & ~EUACT[1] & ~ContextEUCLOAD[1]), .FFTMemACT(EUFFTMemACT[1]), .FFTMemCMD(EUFFTMemCMD[1]),
				.FFTMemADDR(EUFFTMemADDR[1]), .FFTMemDO(EUFFTMemDO[1]), .FFTMemTO(EUFFTMemTO[1][7:0]),
				// interface to the descriptor pre-loading system
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPL(ContextCSR[1][19:18]),
				// interface to message control subsystem
				.PARAM(EUPARAM[1]), .PARREG(EUPARREG[1][3:0]), .MSGREQ(EUMSGREQ[1]), .MALLOCREQ(EUMALLOCREQ[1]), .PARREQ(EUPARREQ[1]),
				.ENDMSG(EUENDMSG[1]), .BKPT(EUBKPT[1]), .EMPTY(EUEMPTY[1]), .HALT(EUHALT[1]), .NPCS(EUNPCS[1]), .SMSGBKPT(EUSMSGBKPT[1]),
				.CEXEC(ContextCORESTART[1]), .ESMSG(MsgrEUCONTINUE[1]), .CONTINUE(ContextCONTINUE[1]),
				.CSTOP(MsgrEUHALT[1] | ContextCORESTOP[1]), .LIRESET(ContextLIRESET[1]),
				// context store interface
				.RA(ContextRA[5:0]), .CDATA(EUCDATA[1]), .RIP(EURIP[1]),
				// error reporting interface
				.ESTB(EUESTB[1]), .ECD(EUECD[1]),
				// FFT engine error report interface
				.FFTESTB(EUFFTESTB[1]), .FFTECD(EUFFTECD[1]), .FFTCPSR(EUFFTCPSR[1]),
				// test purpose pins
				.FATAL(EUFATAL[1]),
				// Performance monitor outputs
				.IV(TmuxIV[1]), .CSEL(TmuxCSEL[1])
				);
defparam EU_B.Mode=1;

DMux	DMuxB(.CLK(CLK), .RESET(RST),
				// datapatch from local memory (lowest priority)
				.LocalDRDY(ContextEUDRDY[1]), .LocalDATA({ContextEUSZi, ContextEUTAGi[7:0], ContextEUDTi}), .LocalRD(DMuxBLocalRD),
				// datapatch form stream controller (middle priority)
				.StreamDRDY(~StreamDFifoBempty), .StreamDATA(StreamDFifoBq),
				// datapatch from network controller (highest priority)
				.NetDRDY(FpuCOREDRDY[1]), .NetDATA({FpuCORESIZEI, FpuCORETAGI[7:0], FpuCOREDTI}),
				// output to the EU resources
				.DRDY(DMuxBDRDY), .TAG(DMuxBTAG), .DATA(DMuxBDATA)
				);
defparam DMuxB.TagWidth=11;

// data fifo for stream datapatch
sc_fifo	StreamDFifoB(.data({StreamCoreSIZEO, StreamCoreTAGO[7:0], StreamCoreDTO}), .wrreq(StreamCoreDRDY[1]), 
				.rdreq(~FpuCOREDRDY[1] & ~StreamDFifoBempty), .clock(CLK), .sclr(~RST), .q(StreamDFifoBq), .empty(StreamDFifoBempty));
defparam StreamDFifoB.LPM_WIDTH=75, StreamDFifoB.LPM_NUMWORDS=16, StreamDFifoB.LPM_WIDTHU=4;

EU64x32MT	EU_C(.CLK(CLK), .RESET(RST), .CLOAD(ContextEUCLOAD[2]), .CPU(TmuxCPU), .TASKID(ContextCSR[2][15:0]), .CPSR(ContextCPSR[2]),
				// interface to datapatch of memory subsystem
				.NEXT(ContextEUNEXT[2]), .StreamNEXT(StreamEUNEXT[2]), .NetNEXT(FpuEUNEXT[2]),
				.ACT(EUACT[2]), .StreamACT(EUStreamACT[2]), .NetACT(EUNetACT[2]), .CMD(EUCMD[2]), .OS(EUOS[2]),
				.ADDRESS(EUADDRESS[2]), .OFFSET(EUOFFSET[2]), .SELECTOR(EUSELECTOR[2]), .DTo(EUDTo[2]), .TAGo(EUTAGo[2]),
				.DRDY(DMuxCDRDY), .TAGi(DMuxCTAG[8:0]), .SZi(DMuxCTAG[11:9]), .DTi(DMuxCDATA),
				// FFT memory interface
				.FFTMemNEXT(ContextEUNEXT[2] & ~EUACT[2] & ~ContextEUCLOAD[2]), .FFTMemACT(EUFFTMemACT[2]), .FFTMemCMD(EUFFTMemCMD[2]),
				.FFTMemADDR(EUFFTMemADDR[2]), .FFTMemDO(EUFFTMemDO[2]), .FFTMemTO(EUFFTMemTO[2]),
				// interface to the descriptor pre-loading system
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPL(ContextCSR[2][19:18]),
				// interface to message control subsystem
				.PARAM(EUPARAM[2]), .PARREG(EUPARREG[2]), .MSGREQ(EUMSGREQ[2]), .MALLOCREQ(EUMALLOCREQ[2]), .PARREQ(EUPARREQ[2]),
				.ENDMSG(EUENDMSG[2]), .BKPT(EUBKPT[2]), .EMPTY(EUEMPTY[2]), .HALT(EUHALT[2]), .NPCS(EUNPCS[2]), .SMSGBKPT(EUSMSGBKPT[2]),
				.CEXEC(ContextCORESTART[2]), .ESMSG(MsgrEUCONTINUE[2]), .CONTINUE(ContextCONTINUE[2]),
				.CSTOP(MsgrEUHALT[2] | ContextCORESTOP[2]),
				// context store interface
				.RA(ContextRA), .CDATA(EUCDATA[2]), .RIP(EURIP[2]),
				// error reporting interface
				.ESTB(EUESTB[2]), .ECD(EUECD[2]),
				// FFT engine error report interface
				.FFTESTB(EUFFTESTB[2]), .FFTECD(EUFFTECD[2]), .FFTCPSR(EUFFTCPSR[2]),
				// test purpose pins
				.FATAL(EUFATAL[2]),
				// Performance monitor outputs
				.IV(TmuxIV[2]), .CSEL(TmuxCSEL[2])
				);
defparam EU_C.Mode=1;

DMux	DMuxC(.CLK(CLK), .RESET(RST),
				// datapatch from local memory (lowest priority)
				.LocalDRDY(ContextEUDRDY[2]), .LocalDATA({ContextEUSZi, ContextEUTAGi, ContextEUDTi}), .LocalRD(DMuxCLocalRD),
				// datapatch form stream controller (middle priority)
				.StreamDRDY(~StreamDFifoCempty), .StreamDATA(StreamDFifoCq),
				// datapatch from network controller (highest priority)
				.NetDRDY(FpuCOREDRDY[2]), .NetDATA({FpuCORESIZEI, FpuCORETAGI, FpuCOREDTI}),
				// output to the EU resources
				.DRDY(DMuxCDRDY), .TAG(DMuxCTAG), .DATA(DMuxCDATA)
				);
defparam DMuxC.TagWidth=12;

// data fifo for stream datapatch
sc_fifo	StreamDFifoC(.data({StreamCoreSIZEO, StreamCoreTAGO, StreamCoreDTO}), .wrreq(StreamCoreDRDY[2]), .rdreq(~FpuCOREDRDY[2] & ~StreamDFifoCempty), 
				.clock(CLK), .sclr(~RST), .q(StreamDFifoCq), .empty(StreamDFifoCempty));
defparam StreamDFifoC.LPM_WIDTH=76, StreamDFifoC.LPM_NUMWORDS=16, StreamDFifoC.LPM_WIDTHU=4;

EU64x32MT	EU_D(.CLK(CLK), .RESET(RST), .CLOAD(ContextEUCLOAD[3]), .CPU(TmuxCPU), .TASKID(ContextCSR[3][15:0]), .CPSR(ContextCPSR[3]),
				// interface to datapatch of memory subsystem
				.NEXT(ContextEUNEXT[3]), .StreamNEXT(StreamEUNEXT[3]), .NetNEXT(FpuEUNEXT[3]),
				.ACT(EUACT[3]), .StreamACT(EUStreamACT[3]), .NetACT(EUNetACT[3]), .CMD(EUCMD[3]), .OS(EUOS[3]),
				.ADDRESS(EUADDRESS[3]), .OFFSET(EUOFFSET[3]), .SELECTOR(EUSELECTOR[3]), .DTo(EUDTo[3]), .TAGo(EUTAGo[3]),
				.DRDY(DMuxDDRDY), .TAGi(DMuxDTAG[8:0]), .SZi(DMuxDTAG[11:9]), .DTi(DMuxDDATA),
				// FFT memory interface
				.FFTMemNEXT(ContextEUNEXT[3] & ~EUACT[3] & ~ContextEUCLOAD[3]), .FFTMemACT(EUFFTMemACT[3]), .FFTMemCMD(EUFFTMemCMD[3]),
				.FFTMemADDR(EUFFTMemADDR[3]), .FFTMemDO(EUFFTMemDO[3]), .FFTMemTO(EUFFTMemTO[3]),
				// interface to the descriptor pre-loading system
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPL(ContextCSR[3][19:18]),
				// interface to message control subsystem
				.PARAM(EUPARAM[3]), .PARREG(EUPARREG[3]), .MSGREQ(EUMSGREQ[3]), .MALLOCREQ(EUMALLOCREQ[3]), .PARREQ(EUPARREQ[3]),
				.ENDMSG(EUENDMSG[3]), .BKPT(EUBKPT[3]), .EMPTY(EUEMPTY[3]), .HALT(EUHALT[3]), .NPCS(EUNPCS[3]), .SMSGBKPT(EUSMSGBKPT[3]),
				.CEXEC(ContextCORESTART[3]), .ESMSG(MsgrEUCONTINUE[3]), .CONTINUE(ContextCONTINUE[3]),
				.CSTOP(MsgrEUHALT[3] | ContextCORESTOP[3]),
				// context store interface
				.RA(ContextRA), .CDATA(EUCDATA[3]), .RIP(EURIP[3]),
				// error reporting interface
				.ESTB(EUESTB[3]), .ECD(EUECD[3]),
				// FFT engine error report interface
				.FFTESTB(EUFFTESTB[3]), .FFTECD(EUFFTECD[3]), .FFTCPSR(EUFFTCPSR[3]),
				// test purpose pins
				.FATAL(EUFATAL[3]),
				// Performance monitor outputs
				.IV(TmuxIV[3]), .CSEL(TmuxCSEL[3])
				);
defparam EU_D.Mode=1;

DMux	DMuxD(.CLK(CLK), .RESET(RST),
				// datapatch from local memory (lowest priority)
				.LocalDRDY(ContextEUDRDY[3]), .LocalDATA({ContextEUSZi, ContextEUTAGi, ContextEUDTi}), .LocalRD(DMuxDLocalRD),
				// datapatch form stream controller (middle priority)
				.StreamDRDY(~StreamDFifoDempty), .StreamDATA(StreamDFifoDq),
				// datapatch from network controller (highest priority)
				.NetDRDY(FpuCOREDRDY[3]), .NetDATA({FpuCORESIZEI, FpuCORETAGI, FpuCOREDTI}),
				// output to the EU resources
				.DRDY(DMuxDDRDY), .TAG(DMuxDTAG), .DATA(DMuxDDATA)
				);
defparam DMuxD.TagWidth=12;

// data fifo for stream datapatch
sc_fifo	StreamDFifoD(.data({StreamCoreSIZEO, StreamCoreTAGO, StreamCoreDTO}), .wrreq(StreamCoreDRDY[3]), .rdreq(~FpuCOREDRDY[3] & ~StreamDFifoDempty), 
				.clock(CLK), .sclr(~RST), .q(StreamDFifoDq), .empty(StreamDFifoDempty));
defparam StreamDFifoD.LPM_WIDTH=76, StreamDFifoD.LPM_NUMWORDS=16, StreamDFifoD.LPM_WIDTHU=4;


/*
===================================================================================================
										ErrorFIFO
===================================================================================================
*/
ErrorFIFOQT EFifo(.CLK(CLK), .RESET(RST), .CPSR(ContextCPSR),
				// read fifo interface
				.ERD(TmuxESRRD & EfifoVALID), .VALID(EfifoVALID), .ECD(EfifoECD),
				// error interface from cores
				.CoreSTB(EUESTB), .CoreECD(EUECD),
				// error interface from FFT coprocessors
				.FFTSTB(EUFFTESTB), .FFTECD(EUFFTECD), .FFTCPSR(EUFFTCPSR),
				// error report from outer network
				.NetSTB(FpuESTB), .NetECD(FpuECD), .NetCPSRSel(FpuCPSRSel),
				// error report from messenger
				.MsgrSTB(MsgrESTB), .MsgrECD(MsgrERRC),
				// error report from context controller
				.ContSTB(ContextESTB), .ContECD(ContextERC)
				);

/*
===================================================================================================
										Bus multiplexer
===================================================================================================
*/
extern module MUX64T4 (
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
	output reg [3:0] PTINTR, CPINTR,
	input wire PTACK,
	input wire [3:0] NLE, NERR,
	input wire [31:0] CSR [3:0],
	input wire [23:0] CPSR [3:0],
	input wire [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] ESR,
	output wire [2:0] CPSRSTB [3:0],
	output wire [3:0] CSRSTB [3:0],
	input wire SINIT,
	input wire NINIT,
	input wire CINIT,
	input wire TCK,
	input wire [3:0] TCKOVR,
	input wire [3:0] HALT,
	// performance data source
	input wire [3:0] IV [3:0],
	input wire [23:0] CSEL [3:0],
	input wire [3:0] EMPTY,
	input wire [7:0] TCKScaler,
	input wire [7:0] CoreType
	);
MUX64T4		Tmux(
				.CLK(CLK), .RESETn(RST),
				// services interface
				.LNEXT(TmuxLNEXT),
				.LACT({MsgrACT, ContextACT[1], StreamACT, FpuACT, ContextACT[0]}),
				.LCMD({MsgrCMD, ContextCMD[1], StreamCMD, FpuCMD, ContextCMD[0]}),
				.LSIZEO(TmuxLSIZEO), .LADDR(TmuxLADDR), .LDATO(TmuxLDATO), .LTAGO(TmuxLTAGO),
				.LDRDY(TmuxLDRDY), .LDATI(TmuxLDATI), .LTAGI(TmuxLTAGI), .LSIZEI(TmuxLSIZEI),
				// local memory interface
				.CMD(CMD), .ADDR(ADDR), .DATA(DATA), .BE(BE), .TAG(TAG),
				.FLNEXT(FlashNEXT), .FLACT(TmuxFLACT), .FLDRDY(FlashDRDY), .FLDAT(FlashDTO), .FLTAG(FlashTAGO),
				.SDNEXT(SDCacheINEXT), .SDACT(TmuxSDACT), .SDDRDY(SDCacheIDRDY), .SDDAT(SDCacheIDATo), .SDTAG(SDCacheITAGo),
				.IONEXT(IONEXT), .IOACT(IOACT), .IODRDY(IODRDY), .IODAT(IODAT), .IOTAG(IOTAG),
				// status and control lines and buses
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .INTSEL(TmuxINTSEL), .INTLIMIT(TmuxINTLIMIT), .CPUNUM(TmuxCPU),
				.NENA(TmuxNENA), .INTRST(TmuxINTRST), .INTENA(TmuxINTENA), .ESRRD(TmuxESRRD), 
				.CENA(TmuxCENA), .MALOCKF(TmuxMALOCKF), .PTINTR(TmuxPTINTR), .CPINTR(TmuxCPINTR), .PTACK(ContextPTACK), .NLE(4'd0), .NERR(4'd0),
				.CSR(ContextCSR), .CPSR(ContextCPSR), .FREEMEM(ContextFREEMEM), .CACHEDMEM(ContextCACHEDMEM),
				.ESR({EfifoECD[63:56] & {8{EfifoVALID}},EfifoECD[55:0]}), .CPSRSTB(TmuxCPSRSTB), .CSRSTB(TmuxCSRSTB),
				.SINIT(StreamINIT), .NINIT(FpuINIT), .CINIT(ContextREADY), .TCK(TickFlag), .TCKOVR(EUNPCS), .HALT(EUHALT),
				.IV(TmuxIV), .CSEL(TmuxCSEL), .EMPTY(EUEMPTY), .TCKScaler(TCKScale), .CoreType(8'd9)
				);

/*
===================================================================================================
				SDRAM Cache unit
===================================================================================================
*/
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
Cache4x64x2048 SDCache(.RESET(RST), .CLK(CLK),
				// internal ISI
				.INEXT(SDCacheINEXT), .IACT(TmuxSDACT), .ICMD(CMD), .IADDR(ADDR[44:3]), .IDATi(DATA), .IBE(BE), .ITAGi(TAG),
				.IDRDY(SDCacheIDRDY), .IDATo(SDCacheIDATo), .ITAGo(SDCacheITAGo),
				// external ISI
				.ENEXT(SDNEXT), .EACT(SDACT), .ECMD(SDCMD), .EADDR(SDCacheEADDR), .EDATo(SDDI), .EBE(SDBE), .ETAGo(SDTI),
				.EDRDY(SDDRDY), .EDATi(SDDO), .ETAGi(SDTO)
				);

/*
===================================================================================================
 										FLASH UNITs
===================================================================================================
*/
Flash16  Flash(.CLKH(CLK), .RESET(RST), .NEXT(FlashNEXT), .ACT(TmuxFLACT), .CMD(CMD), .ADDR(ADDR[31:0]),
				.BE(BE), .DTI(DATA), .TAGI(TAG), .DRDY(FlashDRDY), .DTO(FlashDTO), .TAGO(FlashTAGO),
				// interface to the external memory
				.FLCK(SPICK), .FLRST(SPIRST), .FLCS(SPICS), .FLSO(SPISO), .FLSI(SPISI)
				);
				
/*
===================================================================================================
										Context controller
===================================================================================================
*/
extern module ContextCTRL4T( 
	// global control
	input wire CLK, RESETn, CENA, MALOCKF,
	input wire [3:0] PTINTR, CPINTR,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	output reg  RST, READY, PTACK,						// hardware reset and ready signal
	output reg [23:0] CPSR [3:0],						// current process selector register
	output reg [31:0] CSR [3:0],						// current core state register
	output reg [39:0] FREEMEM, CACHEDMEM,
	input wire [63:0] EXTDI,
	input wire [2:0] CPSRSTB [3:0],
	input wire [3:0] CSRSTB [3:0],
	input wire [36:0] RIP [3:0],						// real ip
	// 2-channel interface to memory system
	input wire [1:0] NEXT,
	output logic [1:0] ACT,CMD,
	output logic [44:0] ADDR[1:0],
	output logic [1:0] SIZE[1:0],
	output logic [10:0] TAGo[1:0],
	output logic [63:0] DTo[1:0],
	input wire [1:0] DRDY,
	input wire [63:0] DTi,
	input wire [10:0] TAGi,
	input wire [2:0] SZi,
	// interface to messages controller
	output reg MSGACK, CHKACK,
	input wire MSGREQ, CHKREQ, MSGTT, MSGERR,
	input wire [95:0] MSGPARAM,
	input wire [1:0] MSGCHAN,
	// interface from EU
	output wire [3:0] EUNEXT,
	input wire [3:0] EUACT, EUCMD,
	input wire [1:0] EUSZo [3:0],
	input wire [44:0] EUADDR [3:0],
	input wire [63:0] EUDTo [3:0],
	input wire [8:0] EUTAGo [3:0],
	output wire [3:0] EUDRDY,
	output wire [8:0] EUTAGi,
	output wire [2:0] EUSZi,
	output wire [63:0] EUDTi,
	input wire EURD,
	// control interface to EU
	input wire [3:0] MALLOCREQ,
	input wire [3:0] GETPARREQ,
	input wire [63:0] EUPARAM [3:0],
	input wire [4:0] EUREG [3:0],
	input wire [3:0] EUEMPTY, EUENDMSG, EUERROR, EUSMSGBKPT,
	output reg [3:0] CORESTART, CORESTOP, CORECONT, EUCLOAD, LIRESET,
	// context load/store interface to EU
	output wire [6:0] RA,
	input wire [63:0] CDAT [3:0],
	// error reporting interface
	output reg ESTB,
	output reg [31:0] ERC
	);

ContextCTRL4T	Context(
				.CLK(CLK), .RESETn(RST), .CENA(TmuxCENA), .MALOCKF(TmuxMALOCKF), .PTINTR(TmuxPTINTR), .CPINTR(TmuxCPINTR),
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPUNUM(TmuxCPU), .RST(ContextRST), .READY(ContextREADY), .PTACK(ContextPTACK),
				.CPSR(ContextCPSR), .CSR(ContextCSR), .FREEMEM(ContextFREEMEM), .CACHEDMEM(ContextCACHEDMEM), .EXTDI(DATA), .CPSRSTB(TmuxCPSRSTB),
				.CSRSTB(TmuxCSRSTB), .RIP(EURIP),
				// 2-channel interface to memory system
				.NEXT({TmuxLNEXT[3], TmuxLNEXT[0]}), .ACT(ContextACT), .CMD(ContextCMD), .ADDR(ContextADDR), .SIZE(ContextSIZE), .TAGo(ContextTAGo),
				.DTo(ContextDTo), .DRDY({TmuxLDRDY[3], TmuxLDRDY[0]}), .DTi(TmuxLDATI), .TAGi(TmuxLTAGI[10:0]), .SZi(TmuxLSIZEI),
				// interface to messages controller
				.MSGACK(ContextMSGACK), .CHKACK(ContextMSGCHKACK), .MSGREQ(MsgrContextREQ), .CHKREQ(MsgrContextCHK),
				.MSGTT(MsgrContextTT), .MSGERR(MsgrEINTR), .MSGPARAM(MsgrContextMSG), .MSGCHAN(MsgrContextCHAN),
				// interface from EU
				.EUNEXT(ContextEUNEXT), .EUACT({EUACT[3] | (EUFFTMemACT[3] & ~(|ContextEUCLOAD[3])),EUACT[2] | (EUFFTMemACT[2] & ~(|ContextEUCLOAD[2])),EUACT[1] | (EUFFTMemACT[1] & ~(|ContextEUCLOAD[1])),EUACT[0] | (EUFFTMemACT[0] & ~(|ContextEUCLOAD[0]))}),
				.EUCMD({EUACT[3] ? EUCMD[3] : EUFFTMemCMD[3],EUACT[2] ? EUCMD[2] : EUFFTMemCMD[2],EUACT[1] ? EUCMD[1] : EUFFTMemCMD[1],EUACT[0] ? EUCMD[0] : EUFFTMemCMD[0]}),
				.EUSZo(ContextEUSZo), .EUADDR(ContextEUADDR), .EUDTo(ContextEUDTo), .EUTAGo(ContextEUTAGo),
				.EUDRDY(ContextEUDRDY), .EUTAGi(ContextEUTAGi), .EUSZi(ContextEUSZi), .EUDTi(ContextEUDTi),
				.EURD(DMuxALocalRD | DMuxBLocalRD | DMuxCLocalRD | DMuxDLocalRD),
				// control interface to EU
				.MALLOCREQ(EUMALLOCREQ), .GETPARREQ(EUPARREQ), .EUPARAM(EUPARAM), .EUREG(EUPARREG), .EUEMPTY(EUEMPTY), .EUENDMSG(EUENDMSG),
				.EUERROR(EUESTB), .EUSMSGBKPT(EUSMSGBKPT),
				.CORESTART(ContextCORESTART), .CORESTOP(ContextCORESTOP), .CORECONT(ContextCONTINUE), .EUCLOAD(ContextEUCLOAD), .LIRESET(ContextLIRESET),
				// context load/store interface to EU
				.RA(ContextRA), .CDAT(EUCDATA),
				// error reporting interface
				.ESTB(ContextESTB), .ERC(ContextERC)
				);
				
/*
===================================================================================================
										Messenger
===================================================================================================
*/
extern module Messenger4T (
	input wire CLK, RESETn,
	output reg RST,
	// message interface from EU, error system, interrupt system and network system
	input wire [3:0] EUREQ,
	input wire ERRORREQ, INTREQ, NETREQ,
	input wire [63:0] EUPARAM [3:0],		// Message index for import table in the current PSO and parameter dword
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
	input wire ContextRDY, ContextCHKRDY,
	output reg ContextREQ, ContextCHK, ContextTT, ContextEINTR,
	output wire [95:0] ContextMSG,
	output reg [1:0] ContextCHAN,
	// interface to network controller
	input wire NETRDY,
	output reg NETSEND,
	output reg NETTYPE,
	output wire [79:0] NETMSG,
	output reg [4:0] NETSTAT,
	output reg [1:0] NETCPL,
	output reg [15:0] NETTASKID,
	output reg [23:0] NETCPSR,
	// DTR and DTL registers
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [23:0] CPSR [3:0],
	input logic [23:0] INTSR,			// selector IT
	input logic [15:0] INTCR,			// Length of IT
	input logic [31:0] CSR [3:0],
	// core control lines 
	output reg [3:0] EUCONTINUE,
	output reg [3:0] EUHALT,
	input wire [3:0] BKPT,
	input wire [3:0] MSGBKPT,
	input wire [3:0] EUEMPTY,
	// error reporting interface
	output reg ESTB,
	output reg [63:0] ERRC
	);
	
Messenger4T Msgr(
				.CLK(CLK), .RESETn(RST), .RST(MsgrRST),
				// message interface from EU, error system, interrupt system and network system
				.EUREQ(EUMSGREQ), .ERRORREQ(EfifoVALID & ~DEfifoVALID), .INTREQ(IntReqFlag), .NETREQ(FpuMSGREQ),
				.EUPARAM(EUPARAM), .INTPARAM(INTCODE), .NETPARAM(FpuMSGDATA), .NETMSGRD(MsgrNETMSGRD), .INTACK(INTACK),
				// interface to memory system
				.NEXT(TmuxLNEXT[4]), .ACT(MsgrACT), .CMD(MsgrCMD), .ADDR(MsgrADDR), .SIZE(MsgrSIZE), .DATO(MsgrDATO),
				.DRDY(TmuxLDRDY[4]), .DATI(TmuxLDATI[31:0]),
				// interface to the context controller (interrupt, error or procedure)
				.ContextRDY(ContextMSGACK), .ContextCHKRDY(ContextMSGCHKACK), .ContextREQ(MsgrContextREQ), .ContextCHK(MsgrContextCHK),
				.ContextTT(MsgrContextTT), .ContextEINTR(MsgrEINTR), .ContextMSG(MsgrContextMSG), .ContextCHAN(MsgrContextCHAN),
				// interface to network controller
				.NETRDY(FpuMSGNEXT), .NETSEND(MsgrNETSEND), .NETTYPE(MsgrNETTYPE), .NETMSG(MsgrNETMSG),
				.NETSTAT(MsgrNETSTAT), .NETCPL(MsgrNETCPL), .NETTASKID(MsgrNETTASKID), .NETCPSR(MsgrNETCPSR),
				// DTR and DTL registers
				.DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPUNUM(TmuxCPU), .CPSR(ContextCPSR), .INTSR(TmuxINTSEL),
				.INTCR(TmuxINTLIMIT), .CSR(ContextCSR),
				// core control lines 
				.EUCONTINUE(MsgrEUCONTINUE), .EUHALT(MsgrEUHALT), .BKPT(EUBKPT), .MSGBKPT(EUSMSGBKPT), .EUEMPTY(EUEMPTY),
				// error reporting interface
				.ESTB(MsgrESTB), .ERRC(MsgrERRC)
				);
				
/*
===================================================================================================
										Stream controller
===================================================================================================
*/
extern module StreamController4T (
	input wire CLK, RESET, TE,
	input wire [39:0] DTBASE,
	output wire INIT,
// Core interface
	output wire [3:0] EUNEXT,
	input wire [3:0] EUACT, EUCMD, EUADDR,
	input wire [23:0] EUSELECTOR [3:0],
	input wire [63:0] EUDTI [3:0],
	input wire [8:0] EUTAGI [3:0],
	output reg [3:0] EUDRDY,
	output reg [63:0] EUDTO,
	output reg [8:0] EUTAGO,
	output reg [2:0] EUSIZEO,
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

StreamController4T Stream(
				.CLK(CLK), .RESET(RST), .TE(TickFlag), .DTBASE(TmuxDTBASE), .INIT(StreamINIT),
				// Core interface
				.EUNEXT(StreamEUNEXT), .EUACT(EUStreamACT), .EUCMD(EUCMD),
				.EUADDR({EUOFFSET[3][0],EUOFFSET[2][0],EUOFFSET[1][0],EUOFFSET[0][0]}),
				.EUSELECTOR(StreamCoreSEL), .EUDTI(EUDTo), .EUTAGI(EUTAGo), .EUDRDY(StreamCoreDRDY),
				.EUDTO(StreamCoreDTO), .EUTAGO(StreamCoreTAGO), .EUSIZEO(StreamCoreSIZEO),
				// network interface
				.NetNEXT(StreamNetNEXT), .NetACT(FpuSACT), .NetSEL(FpuSEL), .NetDATA(FpuDTO),
				// memory interface
				.NEXT(TmuxLNEXT[2]), .ACT(StreamACT), .CMD(StreamCMD), .SIZEO(StreamSIZEO), .ADDR(StreamADDR),
				.DTO(StreamDTO), .TAGO(StreamTAGO), .DRDY(TmuxLDRDY[2]), .DTI(TmuxLDATI), .TAGI(TmuxLTAGI[4:0])
				);

/*				
===================================================================================================
										NETWORK SYSTEM
===================================================================================================
*/
extern module FPU4T (
	// global
	input wire CLK, RESETn, TCK,
	input wire [39:0] DTBASE,
	input wire [23:0] DTLIMIT,
	input wire [7:0] CPUNUM,
	input wire [15:0] TASKID [3:0],
	output wire INIT,
	// interface from core
	output wire [3:0] CORENEXT,
	input wire [3:0] COREACT, CORECMD,
	input wire [1:0] CORESIZE [3:0],
	input wire [1:0] CORECPL [3:0],
	input wire [36:0] COREOFFSET [3:0],
	input wire [31:0] CORESEL [3:0],
	input wire [63:0] COREDTO [3:0],
	input wire [8:0] CORETAGO [3:0],
	output reg [3:0] COREDRDY,
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
	input wire [1:0] MSGCPL,
	input wire [15:0] MSGTASKID,
	input wire [23:0] MSGCPSR,
	// error report interface
	output reg ESTB,
	output reg [12:0] ECD,
	output reg [1:0] CPSRSel
	);
FPU4T Fpu(
				.CLK(CLK), .RESETn(RST), .TCK(TickFlag), .DTBASE(TmuxDTBASE), .DTLIMIT(TmuxDTLIMIT), .CPUNUM(TmuxCPU), 
				.TASKID(TASKIDBus), .INIT(FpuINIT),
				// interface to core
				.CORENEXT(FpuEUNEXT), .COREACT(EUNetACT), .CORECMD(EUCMD), .CORESIZE(EUOS), .CORECPL(CPLBus), .COREOFFSET(EUOFFSET), 
				.CORESEL(EUSELECTOR), .COREDTO(EUDTo), .CORETAGO(EUTAGo), .COREDRDY(FpuCOREDRDY), .COREDTI(FpuCOREDTI), .CORETAGI(FpuCORETAGI), .CORESIZEI(FpuCORESIZEI),
				// local memory interface
				.NEXT(TmuxLNEXT[1]), .SNEXT(StreamNetNEXT), .ACT(FpuACT), .SACT(FpuSACT), .CMD(FpuCMD), .SIZEO(FpuSIZEO), .ADDR(FpuADDR), .DTO(FpuDTO),
				.TAGO(FpuTAGO), .SEL(FpuSEL), .DRDY(TmuxLDRDY[1]), .DTI(TmuxLDATI), .SIZEI(TmuxLSIZEI[1:0]), .TAGI(TmuxLTAGI),
				// interface to the routing subsystem
				.STONEXT(RteSTONEXT), .STONEW(FpuSTONEW), .STOVAL(), .STODT(FpuSTODT), .STINEXT(FpuSTINEXT), .STIVAL(RteSTIVAL), 
				.STINEW(RteSTINEW), .STIDT(RteSTIDT),
				// messages interface
				.MSGREQ(FpuMSGREQ), .MSGRD(MsgrNETMSGRD), .MSGDATA(FpuMSGDATA), .MSGNEXT(FpuMSGNEXT), .MSGSEND(MsgrNETSEND), 
				.MSGTYPE(MsgrNETTYPE), .MSGPARAM(MsgrNETMSG), .MSGSTAT(MsgrNETSTAT), .MSGCPL(MsgrNETCPL), .MSGTASKID(MsgrNETTASKID),
				.MSGCPSR(MsgrNETCPSR),
				// error report interface
				.ESTB(FpuESTB), .ECD(FpuECD), .CPSRSel(FpuCPSRSel)
				);

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
RTE Rte(.CLK(CLK), .RESET(RST), .CPUNUM(TmuxCPU), .EXTDO(RteEXTDO), .EXTSTBO(RteEXTSTBO), .EXTSTBI(RteEXTSTBI), .EXTDI(RteEXTDI),
			.STONEXT(RteSTONEXT), .STONEW(FpuSTONEW), .STODT(FpuSTODT), .STINEXT(FpuSTINEXT), .STINEW(RteSTINEW), .STIVAL(RteSTIVAL), 
			.STIDT(RteSTIDT)
			);

/*
===================================================================================================
										synchronous 
===================================================================================================
*/
always_ff @(posedge CLK)
begin

// reset filtering
RST<=EXTRESET & MsgrRST & ContextRST;

// timing intervals for stream controller
TECntReg<=(TECntReg+8'd1) & {8{RST & ~TickFlag}};
TickFlag<=(TECntReg==TCKScale) & RST;

// delayed EFIFO flag
DEfifoVALID<=EfifoVALID & RST;

// interrupt flag
IntFlag<=(IntFlag | INTREQ) & ~INTACK & RST & TmuxINTENA;
IntReqFlag<=IntFlag & RST & ~DIntReqFlag;
DIntReqFlag<=(DIntReqFlag | IntReqFlag) & RST & IntFlag;

// Fatal
FATAL<=(|EUFATAL);

EMPTY<=EUEMPTY;

end

endmodule
