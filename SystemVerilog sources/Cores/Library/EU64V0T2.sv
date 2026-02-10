module EU64V0T2 (
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

integer i0,i1,i2,i3,i4,i5,i6,i7,i8,i9,i10,i11;

// general purpose register file
reg [127:0] GPR_A [15:0];
reg [127:0] GPR_B [15:0];
// arithmetic flags
reg [31:0] AFR_A [15:0];
reg [31:0] AFR_B [15:0];
reg [15:0] FlagWrite [1:0];
reg [1:0] ContextLoadFlag;
// address register file
reg [36:0] ADR_A [15:0];
reg [36:0] ADR_B [15:0];
// GPR valid flags
reg [15:0] GPVFReg [1:0];
wire [15:0] GPVFINVD [1:0];

// FACC unit resources
wire [19:0] FMULACCBus [1:0];
reg [19:0] FMULACCReg; //0 - ACT, 3:1 - ctrlSel, 7:4 - DST, 11:8 - CtrlOffsetReg, 15:12 - DataOffsetReg, 18:16 - DataSel, 19-CMD
reg FMULACCACTReg, FMULACCCMDReg, FFT32NEXTReg, FMULACCSelFlag, FMULACCSelReg;
wire FMULACCNEXT;
reg [4:0] FMULACCDSTReg;
reg [3:0] FMULACCDataSelReg, FMULACCCtrlSelReg;
reg [34:0] FMULACCDataOffsetReg;
reg [33:0] FMULACCCtrlOffsetReg;
wire FMULACCRDY, FMULACCSIGN, FMULACCZERO, FMULACCINF, FMULACCNAN;
logic FMULACCSel;
wire [31:0] FMULACCR;
wire [4:0] FMULACCDST;
wire FMULACCMemACT, FMULACCSIZE, FMULACCTAGo;
wire [2:0] FMULACCMemSEL;
wire [34:0] FMULACCMemOffset;
reg FMULACCDRDYFlag;
reg [6:0] FMULACCBypassControlOffsetReg, FMULACCBypassDataOffsetReg, FFTBypassReg;
wire SkipFifoData, SkipFifoFlag;
reg [4:0] FFTParReg;

// FFT resources
wire FFT32NEXT;
reg [31:0] FFTDataSelReg, FFTCtrlSelReg;
reg [33:0] FFTDataBaseReg, FFTCtrlBaseReg;
reg [18:0] FFTIndexReg;

// FADD unit resources
wire [13:0] FADDInstBus [1:0];
reg [13:0] FADDInstReg;
reg [127:0] FADDAReg, FADDBReg;
reg [2:0] FADDSAReg, FADDSBReg;
reg [4:0] FADDDSTReg, FADDDSTR;
reg [6:0] FADDBypassAReg, FADDBypassBReg;
reg FADDACTReg, FADDCMDReg, FADDRDYR, FADDSelFlag;
wire [127:0] FADDR;
wire [4:0] FADDDST;
wire [2:0] FADDSR;
wire FADDRDY, FADDZero, FADDSign, FADDInf, FADDNaN;
logic FADDSel;

// FMUL resources
wire [12:0] FMULInstBus [1:0];
reg [12:0] FMULInstReg;
reg [127:0] FMULAReg, FMULBReg;
reg FMULACTReg, FMULSelFlag;
reg [2:0] FMULSAReg, FMULSBReg;
reg [4:0] FMULDSTReg;
reg [6:0] FMULBypassAReg, FMULBypassBReg;
wire [63:0] FMULR;
wire [127:0] FMULRQ;
wire [4:0] FMULDST [1:0];
wire FMULSR;
logic FMULSel;
wire [1:0] FMULRDY, FMULZero, FMULSign, FMULInf, FMULNaN;
reg [1:0] FMULRDYR;
reg [4:0] FMULDSTR [1:0];

// FDIV unit resources
wire [13:0] FDIVInstBus [1:0];
reg [13:0] FDIVInstReg;
reg [127:0] FDIVAReg, FDIVBReg;
reg FDIVACTReg, FDIVCMDReg, FDIVSelFlag;
reg [2:0] FDIVSAReg, FDIVSBReg, FDIVSRReg;
reg [4:0] FDIVDSTReg;
reg [6:0] FDIVBypassAReg, FDIVBypassBReg;
wire [127:0] FDIVR;
wire [4:0] FDIVDST;
wire [2:0] FDIVSR;
wire FDIVRDY, FDIVZero, FDIVInf, FDIVNaN, FDIVSign, FDIVNEXT;
logic FDIVSel;

// Integer ALU Resources
wire [24:0] ALUInstBus [1:0];
reg [24:0] ALUInstReg;
reg ALUACTReg, ALURDYR, ALUSelFlag;
reg [63:0] ALUAReg, ALUBReg, ALUCReg, ALUDReg;
reg [1:0] ALUSAReg, ALUSBReg, ALUSRReg, ALUSCReg, ALUSDReg;
reg [2:0] ALUOpCODEReg;
reg [4:0] ALUDSTReg, ALUDSTR;
reg [6:0] ALUBypassAReg, ALUBypassBReg, ALUBypassCReg, ALUBypassDReg;
wire [63:0] ALUR;
wire [4:0] ALUDST;
wire ALURDY, ALUOVR, ALUSign, ALUZero;
logic ALUSel;
wire [15:0] ALUCOUT;
wire [1:0] ALUSR;

// Parallel shifter resources
wire [12:0] ShiftInstBus [1:0];
reg [12:0] ShiftInstReg;
reg [63:0] ShiftAReg;
reg [5:0] ShiftBReg;
reg [6:0] ShiftBypassAReg, ShiftBypassBReg;
reg [4:0] ShiftDSTReg, ShiftDSTR;
reg [2:0] ShiftOPRReg;
reg [1:0] ShiftSAReg, ShiftSRReg;
reg ShiftACTReg, ShiftRDYR, ShiftSelFlag;
wire [63:0] ShiftR;
wire [4:0] ShiftDST;
wire ShiftRDY, ShiftOVR, ShiftZERO, ShiftCOUT, ShiftSign;
logic ShiftSel;
wire [1:0] ShiftSR;

// miscellaneous unit resources
wire [11:0] MiscInstBus [1:0];
reg [11:0] MiscInstReg [1:0];
reg [2:0] MiscOPRReg [1:0];
reg [1:0] MiscACTReg, MiscRDYR;
reg [127:0] MiscAReg [1:0];
reg [3:0] MiscDSTReg [1:0];
reg [3:0] MiscDSTR [1:0];
reg [2:0] MiscSAReg [1:0];
reg [2:0] MiscSDReg [1:0];
reg [2:0] MiscSRReg [1:0];
reg [15:0] MiscCINReg [1:0];
reg [5:0] MiscBypassAReg [1:0];
reg [5:0] MiscBypassBReg [1:0];
wire [127:0] MiscR [1:0];
wire [3:0] MiscDST [1:0];
wire [2:0] MiscSR [1:0];
wire [1:0] MiscRDY, MiscCOUT, MiscOVR, MiscSign, MiscZero, MiscNaN;

// data movement resources
reg [14:0] MovInstReg [1:0];
wire [14:0] MovInstBus [1:0];
reg [127:0] MovReg [1:0];
reg [2:0] MovSR [1:0];
reg [15:0] LIResetFlag [1:0];
reg [15:0] LIFlag [1:0];
reg [5:0] CopyBypassReg [1:0];

// loop instruction bus
reg [15:0] LoopInstReg [1:0];
wire [15:0] LoopInstBus [1:0];
reg LoopInstFlag [1:0];
reg [5:0] LoopBypassReg [1:0];

// prefetch control resources
reg [16:0] PrefInstReg [1:0];
wire [16:0] PrefInstBus [1:0];
reg [5:0] PrefBypassReg [1:0];
reg [5:0] PrefCCBypassReg [1:0];
wire [1:0] IFetch, InsRDY, PrefACT, PrefCall, PrefRet, PrefEMPTY, PrefERST, CodeError;
wire [3:0] IVF [1:0];
wire [63:0] INST [1:0];
wire [36:0] PrefOffset [1:0];
wire [35:0] PrefRealIP [1:0];
reg [35:0] PrefRealIPReg [1:0];
wire [2:0] PrefTag [1:0];
reg [1:0] PrefCC, PrefCallReg, PrefRetReg;
wire [1:0] SeqEMPTY, MFlag;

// memory read/write resources
reg [15:0] MemInstReg [1:0];
wire [15:0] MemInstBus [1:0];
reg [1:0] MemDelayFlag, MemFifoFullFlag;
wire [216:0] MemFifoBus [1:0];
wire [1:0] MemFifoEmpty;
wire [5:0] MemFifoUsedW [1:0];
reg [1:0] MemBusy, MemReq, MemLoadSel, MemOpr, MemADRPushPop, MemPUSH, MemPOP, MemLDST, MemLDO, MemLoadOffset, MemSecondCycle, MemReadAR, MemLSelNode, MemNext;
reg [2:0] MemSEL [1:0];
reg [2:0] MemSize [1:0];
reg [2:0] MemAMode [1:0];
reg [31:0] MemAFR [1:0];
reg [36:0] ARData [1:0];
reg [36:0] MemGPROffset [1:0];
reg [127:0] MemGPR [1:0];
reg [3:0] MemDST [1:0];
reg [3:0] MemOFF [1:0];
reg [4:0] MemoryOSValue [1:0];
reg [15:0] MemASelNode [1:0];
reg [15:0] MemFSelNode [1:0];
reg [1:0] MemCNT [1:0];
reg [2:0] SZiReg;
reg [8:0] TAGiReg;
logic MemChannelSel;

// check memory access stage
reg [1:0] CheckACT, CheckCMD, CheckNetwork, CheckNext, CheckPref;
reg [1:0] CheckOS [1:0];
reg [36:0] CheckOffset [1:0];
reg [31:0] CheckLL [1:0];
reg [31:0] CheckUL [1:0];
reg [31:0] CheckSelector [1:0];
reg [3:0] CheckAR [1:0];
reg [39:0] CheckBase [1:0];
reg [23:0] CheckLowerSel [1:0];
reg [23:0] CheckUpperSel [1:0];
reg [63:0] CheckData [1:0];
reg [7:0] CheckTag [1:0];
reg [2:0] CheckSEL [1:0];
logic [1:0] CheckNode, CheckStreamNode, CheckNetNode;

/*
descriptor registers
39:0	- base address		40
71:40	- lower limit		32
103:72	- upper limit		32
127:104	- lower selector	24
151:128 - upper selector	24
154:152 - access rights		4
155 	- valid bit
*/
reg [155:0] DTR_A [7:0];
reg [155:0] DTR_B [7:0];
reg [8:0] DTRWriteFlag [1:0];
reg [1:0] DTRLoadedFlag, DescriptorLoadState, ValidDescriptor, LoadNewDSC, LoadLowerDSC, LoadUpperDSC, RetryTransactionFlag;
reg [23:0] DLSelector [1:0];
// state machine for descriptor loading
reg [3:0] DLMachine_A;
reg [3:0] DLMachine_B;
parameter WS=4'd0, CSS=4'd1, ZSS=4'd2, INVSS=4'd3, LBS=4'd4, LLSS=4'd5, LSLS=4'd6, RWS=4'd7, INVOBS=4'd8, STS=4'd9, AERSS=4'd10;
reg [1:0] SkipDataRead, InvalidType, InvalidCPL, InvalidTaskID, AccessError;
reg [3:0] STAGReg [1:0];
reg [23:0] InvalidSelector [1:0];


// wire result flags
reg [15:0] GPRByteNode [1:0];
reg [15:0] GPRWordNode [1:0];
reg [15:0] GPRDwordNode [1:0];
reg [15:0] GPRQwordNode [1:0];
reg [15:0] GPROwordNode [1:0];
reg [15:0] FADDSelNode [1:0];
reg [15:0] FMULSelNode [1:0];
reg [15:0] FMULQSelNode [1:0];
reg [15:0] FMULACCSelNode [1:0];
reg [15:0] FDIVSelNode [1:0];
reg [15:0] ALUSelNode [1:0];
reg [15:0] ShiftSelNode [1:0];
reg [15:0] MiscSelNode [1:0];
reg [15:0] MovSelNode [1:0];
reg [15:0] MemSelNode [1:0];
reg [15:0] MemARSelNode [1:0];
reg [15:0] FFTSelNode [1:0];

/*
===========================================================================================================
				Modules
===========================================================================================================
*/
// memory operations queue
sc_fifo MemFIFO_A (.data({PrefRet[0], PrefCall[0], AFR_A[MemInstReg[0][15:12]], PrefCall[0] ? {91'd0,PrefRealIP[0],1'b0}:GPR_A[MemInstReg[0][15:12]], AFR_A[MemInstReg[0][11:8]][27:25], GPR_A[MemInstReg[0][11:8]][36:0], MemInstReg[0][15:1]}),
				.wrreq((MemInstReg[0][0] & ~MemDelayFlag[0]) | PrefCall[0] | PrefRet[0]),
				.rdreq((~MemBusy[0] | (MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) | MemLoadOffset[0] | (MemLoadSel[0] & (MemDST[0]!={CheckSEL[0],CheckACT[0]})) | MemReadAR[0]) & ~MemCNT[0][1] & ~MemCNT[0][0]), 
				.clock(CLK), .sclr(~RESET), .q(MemFifoBus[0]), .empty(MemFifoEmpty[0]), .almost_empty(), .usedw(MemFifoUsedW[0]));
defparam MemFIFO_A.LPM_WIDTH=217, MemFIFO_A.LPM_NUMWORDS=64, MemFIFO_A.LPM_WIDTHU=6;

sc_fifo MemFIFO_B (.data({PrefRet[1], PrefCall[1], AFR_B[MemInstReg[1][15:12]], PrefCall[1] ? {91'd0,PrefRealIP[1],1'b0}:GPR_B[MemInstReg[1][15:12]], AFR_B[MemInstReg[1][11:8]][27:25], GPR_B[MemInstReg[1][11:8]][36:0], MemInstReg[1][15:1]}),
				.wrreq((MemInstReg[1][0] & ~MemDelayFlag[1]) | PrefCall[1] | PrefRet[1]),
				.rdreq((~MemBusy[1] | (MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])) | MemLoadOffset[1] | (MemLoadSel[1] & (MemDST[1]!={CheckSEL[1],CheckACT[1]})) | MemReadAR[1]) & ~MemCNT[1][1] & ~MemCNT[1][0]), 
				.clock(CLK), .sclr(~RESET), .q(MemFifoBus[1]), .empty(MemFifoEmpty[1]), .almost_empty(), .usedw(MemFifoUsedW[1]));
defparam MemFIFO_B.LPM_WIDTH=217, MemFIFO_B.LPM_NUMWORDS=64, MemFIFO_B.LPM_WIDTHU=6;

// Instruction prefetcher
PrefetcherX16 Pref_A (.CLK(CLK), .RESET(RESET), .CSELCHG(MemASelNode[0][13]), .DRDY(DRDY & ~TAGi[8]), .TAGi(TAGi[7:0]), .DTi(DTi), .IFETCH(IFetch[0]), .IRDY(InsRDY[0]),
				.VF(IVF[0]), .IBUS(INST[0]), .NEXT(~MemReq[0] & MemNext[0] & ~PrefCallReg[0] & ~PrefRetReg[0] & (~FMULACCMemACT | FMULACCDSTReg[4])), .ACT(PrefACT[0]),
				.OFFSET(PrefOffset[0]), .TAGo(PrefTag[0]),
				// instruction for prefetcher
				.CBUS(LoopInstFlag[0] ? {LoopInstReg[0], 1'b1} : PrefInstReg[0]),
				.GPRBUS(LoopInstFlag[0] ? ((GPR_A[LoopInstReg[0][15:12]][63:0] & {64{~(|LoopBypassReg[0])}}) | (FADDR[63:0] & {64{LoopBypassReg[0][0]}}) |
										(FMULR & {64{LoopBypassReg[0][1]}}) | (FMULRQ[63:0] & {64{LoopBypassReg[0][2]}}) |
										(ALUR & {64{LoopBypassReg[0][3]}}) | (ShiftR & {64{LoopBypassReg[0][4]}}) | (MiscR[0][63:0] & {64{LoopBypassReg[0][5]}})) :
									   ((GPR_A[PrefInstReg[0][16:13]][63:0] & {64{~(|PrefBypassReg[0])}}) | (FADDR[63:0] & {64{PrefBypassReg[0][0]}}) |
										(FMULR & {64{PrefBypassReg[0][1]}}) | (FMULRQ[63:0] & {64{PrefBypassReg[0][2]}}) |
										(ALUR & {64{PrefBypassReg[0][3]}}) | (ShiftR & {64{PrefBypassReg[0][4]}}) | (MiscR[0][63:0] & {64{PrefBypassReg[0][5]}}))),
				// flags
				.CC(PrefCC[0]), .MOVFLAG(MFlag[0] | MemInstReg[0][0]), .CALL(PrefCall[0]), .RET(PrefRet[0]), .ERST(PrefERST[0]), .RIP(PrefRealIP[0]), .CEXEC(CEXEC[0]),
				.ESMSG(ESMSG[0]), .CONTINUE(CONTINUE[0]), .STOP(CSTOP[0] | ESTB[0]),
				// interface to message and memory control system
				.GPINDX(PARREG[0]),
				.SMSG(MSGREQ[0]), .MALLOC(MALLOCREQ[0]), .GPAR(PARREQ[0]), .EMSG(ENDMSG[0]), .BKPT(BKPT[0]), .EMPTY(PrefEMPTY[0]), .HALT(HALT[0]), .PARAM(PARAM[0]),
				.SLEEP(NPCS[0]), .SMSGBKPT(SMSGBKPT[0]),
				// code fetch error
				.CFERROR(CodeError[0]),
				// Fatal error reporting
				.FATAL(FATAL[0])
				);
defparam Pref_A.Mode=0;

PrefetcherX16 Pref_B (.CLK(CLK), .RESET(RESET), .CSELCHG(MemASelNode[1][13]), .DRDY(DRDY & TAGi[8]), .TAGi(TAGi[7:0]), .DTi(DTi), .IFETCH(IFetch[1]), .IRDY(InsRDY[1]),
				.VF(IVF[1]), .IBUS(INST[1]), .NEXT(~MemReq[1] & MemNext[1] & ~PrefCallReg[1] & ~PrefRetReg[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])), .ACT(PrefACT[1]),
				.OFFSET(PrefOffset[1]), .TAGo(PrefTag[1]),
				// instruction for prefetcher
				.CBUS(LoopInstFlag[1] ? {LoopInstReg[1], 1'b1} : PrefInstReg[1]),
				.GPRBUS(LoopInstFlag[1] ? ((GPR_B[LoopInstReg[1][15:12]][63:0] & {64{~(|LoopBypassReg[1])}}) | (FADDR[63:0] & {64{LoopBypassReg[1][0]}}) |
										(FMULR & {64{LoopBypassReg[1][1]}}) | (FMULRQ[63:0] & {64{LoopBypassReg[1][2]}}) |
										(ALUR & {64{LoopBypassReg[1][3]}}) | (ShiftR & {64{LoopBypassReg[1][4]}}) | (MiscR[1][63:0] & {64{LoopBypassReg[1][5]}})) :
									   ((GPR_B[PrefInstReg[1][16:13]][63:0] & {64{~(|PrefBypassReg[1])}}) | (FADDR[63:0] & {64{PrefBypassReg[1][0]}}) |
										(FMULR & {64{PrefBypassReg[1][1]}}) | (FMULRQ[63:0] & {64{PrefBypassReg[1][2]}}) |
										(ALUR & {64{PrefBypassReg[1][3]}}) | (ShiftR & {64{PrefBypassReg[1][4]}}) | (MiscR[1][63:0] & {64{PrefBypassReg[1][5]}}))),
				// flags
				.CC(PrefCC[1]), .MOVFLAG(MFlag[1] | MemInstReg[1][0]), .CALL(PrefCall[1]), .RET(PrefRet[1]), .ERST(PrefERST[1]), .RIP(PrefRealIP[1]), .CEXEC(CEXEC[1]),
				.ESMSG(ESMSG[1]), .CONTINUE(CONTINUE[1]), .STOP(CSTOP[1] | ESTB[1]),
				// interface to message and memory control system
				.GPINDX(PARREG[1]),
				.SMSG(MSGREQ[1]), .MALLOC(MALLOCREQ[1]), .GPAR(PARREQ[1]), .EMSG(ENDMSG[1]), .BKPT(BKPT[1]), .EMPTY(PrefEMPTY[1]), .HALT(HALT[1]), .PARAM(PARAM[1]),
				.SLEEP(NPCS[1]), .SMSGBKPT(SMSGBKPT[1]),
				// code fetch error
				.CFERROR(CodeError[1]),
				// Fatal error reporting
				.FATAL(FATAL[1])
				);
defparam Pref_B.Mode=1;

// Instruction sequencer
SequencerDT Seq_A (.CLK(CLK), .RESET(RESET), .IRDY(InsRDY[0]), .VF(IVF[0]), .IBUS(INST[0]),
				.IRD(IFetch[0]), .GPRVF(GPVFReg[0]), .GPRINVD(GPVFINVD[0]), .EMPTY(SeqEMPTY[0]), .MOVFLAG(MFlag[0]),
				.FDIVRDY(~FDIVInstReg[0] & ~FDIVSel), .FMULACCRDY(~FMULACCReg[0] & ~FMULACCSel),
				.MEMRDY(~MemDelayFlag[0]), .FADDBus(FADDInstBus[0]), .FADDRDY(~FADDSel), .FMULBus(FMULInstBus[0]), .FMULRDY(~FMULSel),
				.FMULACCBus(FMULACCBus[0]), .FDIVBus(FDIVInstBus[0]), .ALUBus(ALUInstBus[0]), .ALURDY(~ALUSel), .ShiftBus(ShiftInstBus[0]), .ShiftRDY(~ShiftSel),
				.MiscBus(MiscInstBus[0]), .LoopBus(LoopInstBus[0]), .MovBus(MovInstBus[0]), .MemBus(MemInstBus[0]), .CtrlBus(PrefInstBus[0]));

SequencerDT Seq_B (.CLK(CLK), .RESET(RESET), .IRDY(InsRDY[1]), .VF(IVF[1]), .IBUS(INST[1]),
				.IRD(IFetch[1]), .GPRVF(GPVFReg[1]), .GPRINVD(GPVFINVD[1]), .EMPTY(SeqEMPTY[1]), .MOVFLAG(MFlag[1]),
				.FDIVRDY(~FDIVInstReg[0] & FDIVSel), .FMULACCRDY(~FMULACCReg[0] & FMULACCSel),
				.MEMRDY(~MemDelayFlag[1]), .FADDBus(FADDInstBus[1]), .FADDRDY(FADDSel), .FMULBus(FMULInstBus[1]), .FMULRDY(FMULSel),
				.FMULACCBus(FMULACCBus[1]), .FDIVBus(FDIVInstBus[1]), .ALUBus(ALUInstBus[1]), .ALURDY(ALUSel), .ShiftBus(ShiftInstBus[1]), .ShiftRDY(ShiftSel),
				.MiscBus(MiscInstBus[1]), .LoopBus(LoopInstBus[1]), .MovBus(MovInstBus[1]), .MemBus(MemInstBus[1]), .CtrlBus(PrefInstBus[1]));

// 32-bit multiplier/accumulator
Neuro32 FMULACC (.CLK(CLK), .RESET(RESET), .ACT(FMULACCACTReg & ~FMULACCCMDReg),
				.MAERR((CheckACT[0] & CheckCMD[0] & (DLMachine_A==STS) & (CheckTag[0][7:1]==7'b1100000)) |
						(CheckACT[1] & CheckCMD[1] & (DLMachine_B==STS) & (CheckTag[1][7:1]==7'b1100000))),
				.NEXT(FMULACCNEXT), .DSTi(FMULACCDSTReg), .DataSEL(FMULACCDataSelReg), .CtrlSEL(FMULACCCtrlSelReg), .DataOffset(FMULACCDataOffsetReg),
				.CtrlOffset(FMULACCCtrlOffsetReg), .RDY(FMULACCRDY), .SIGN(FMULACCSIGN), .ZERO(FMULACCZERO), .INF(FMULACCINF), .NAN(FMULACCNAN),
				.R(FMULACCR), .DSTo(FMULACCDST),
				// memory interface
				.MemNEXT((MemNext[0] & ~FMULACCSelReg)|(MemNext[1] & FMULACCSelReg)), .MemACT(FMULACCMemACT), .MemSEL(FMULACCMemSEL),
				.MemOffset(FMULACCMemOffset), .SIZE(FMULACCSIZE),
				.TAGo(FMULACCTAGo), .DRDY(FMULACCDRDYFlag | SkipFifoFlag),
				.TAGi((TAGiReg[0] & FMULACCDRDYFlag) | (SkipFifoData & ~FMULACCDRDYFlag)), .DTi(DTi));

SFifo SkipFifo(.CLK(CLK), .RST(RESET), .D(CheckTag[0]),
				.WR((CheckACT[0] & CheckCMD[0] & (DLMachine_A==STS) & (CheckTag[0][7:1]==7'b1100000)) |
					(CheckACT[1] & CheckCMD[1] & (DLMachine_B==STS) & (CheckTag[1][7:1]==7'b1100000))),
				.Q(SkipFifoData), .VALID(SkipFifoFlag), .RD(~FMULACCDRDYFlag));


// 32-bit FFT processor
fftX16 FFT32(.CLK(CLK), .RESET(RESET), .CPU(CPU), .DTBASE(DTBASE), .DTLIMIT(DTLIMIT), .CPL(FMULACCSelReg ? CPL[1] : CPL[0]),
				.TASKID(FMULACCSelReg ? TASKID[1] : TASKID[0]), .CPSR(FMULACCSelReg ? CPSR[1] : CPSR[0]),
				// command interface
				.NEXT(FFT32NEXT), .ACT(FMULACCACTReg & FMULACCCMDReg), .DataObject(FFTDataSelReg), .ControlObject(FFTCtrlSelReg),
				.DataOffset(FFTDataBaseReg+FMULACCDataOffsetReg[34:1]), .ControlOffset(FFTCtrlBaseReg+FMULACCCtrlOffsetReg),
				.PAR(FFTParReg), .INDEX(FFTIndexReg),
				// memory interface
				.MemNEXT(FFTMemNEXT), .NetNEXT(FFTNetNEXT), .MemACT(FFTMemACT), .NetACT(FFTNetACT), .MemCMD(FFTMemCMD), .MemADDR(FFTMemADDR),
				.MemOFFSET(FFTMemOFFSET), .MemSEL(FFTMemSEL), .MemDO(FFTMemDO), .MemTO(FFTMemTO), .MemDRDY(DRDY), .MemDI(DTi), .MemTI(TAGi[7:0]),
				// error report interface
				.ESTB(FFTESTB), .ECD(FFTECD), .ECPSR(FFTCPSR));

// 128-bit adder module
FPADD128 #(.DSTWidth(5)) FPAdder(.CLK(CLK), .RESET(RESET), .ACT(FADDACTReg), .CMD(FADDCMDReg), .A(FADDAReg), .B(FADDBReg),
		.SA(FADDSAReg), .SB(FADDSBReg), .DSTI(FADDDSTReg), .RDY(FADDRDY), .SIGN(FADDSign), .ZERO(FADDZero), .INF(FADDInf),
		.NAN(FADDNaN), .SR(FADDSR), .DSTO(FADDDST), .R(FADDR));

// 128-bit FP multiplier
FPMUL128 #(.DSTWidth(5)) FPMult (.CLK(CLK), .RESET(RESET), .ACT(FMULACTReg), .DSTI(FMULDSTReg), .A(FMULAReg), .B(FMULBReg),
				.SA(FMULSAReg), .SB(FMULSBReg), .RDYSD(FMULRDY[0]), .RDYQ(FMULRDY[1]), .ZEROSD(FMULZero[0]), .SIGNSD(FMULSign[0]),
				.INFSD(FMULInf[0]), .NANSD(FMULNaN[0]), .ZEROQ(FMULZero[1]), .SIGNQ(FMULSign[1]), .INFQ(FMULInf[1]),
				.NANQ(FMULNaN[1]), .SR(FMULSR), .DSTSD(FMULDST[0]), .DSTQ(FMULDST[1]), .RSD(FMULR), .RQ(FMULRQ));

// FP 64-bit divisor
FPDIV128 #(.DSTWidth(5)) FDIV (.CLK(CLK), .ACT(FDIVACTReg), .CMD(FDIVCMDReg), .SA(FDIVSAReg), .SB(FDIVSBReg), .RST(RESET), .A(FDIVAReg), .B(FDIVBReg),
				.DSTi(FDIVDSTReg), .R(FDIVR), .DSTo(FDIVDST), .RDY(FDIVRDY), .Zero(FDIVZero), .Inf(FDIVInf),
				.NaN(FDIVNaN), .Sign(FDIVSign), .SR(FDIVSR), .NEXT(FDIVNEXT));

// integer ALU
ALU64X16 #(.DSTWidth(5)) IntALU (.CLK(CLK), .ACT(ALUACTReg), .CIN(1'b0), .DSTi(ALUDSTReg), .A(ALUAReg), .B(ALUBReg), .C(ALUCReg), .D(ALUDReg),
				.OpCODE(ALUOpCODEReg), .SA(ALUSAReg), .SB(ALUSBReg), .SC(ALUSCReg), .SD(ALUSDReg), .R(ALUR), .COUT(ALUCOUT),
				.DSTo(ALUDST), .SR(ALUSR), .RDY(ALURDY), .OVR(ALUOVR), .Zero(ALUZero), .Sign(ALUSign));

// shifter
Shifter64X16 #(.DSTWidth(5)) Sht (.CLK(CLK), .ACT(ShiftACTReg), .CIN(1'b0), .A(ShiftAReg), .B(ShiftBReg), .DSTi(ShiftDSTReg),
				.SA(ShiftSAReg), .OPR(ShiftOPRReg), .R(ShiftR), .DSTo(ShiftDST), .RDY(ShiftRDY), .OVR(ShiftOVR),
				.ZERO(ShiftZERO), .SIGN(ShiftSign), .COUT(ShiftCOUT), .SR(ShiftSR));

// misc unit
Misc64X16 Misc_A (.CLK(CLK), .ACT(MiscACTReg[0]), .OpCODE(MiscOPRReg[0]), .SA(MiscSAReg[0]), .SD(MiscSDReg[0]), .DSTi(MiscDSTReg[0]),
				.CIN(MiscCINReg[0]), .A(MiscAReg[0]), .RDY(MiscRDY[0]), .ZERO(MiscZero[0]), .NaN(MiscNaN[0]), .SIGN(MiscSign[0]),
				.OVR(MiscOVR[0]), .COUT(MiscCOUT[0]), .SR(MiscSR[0]), .DSTo(MiscDST[0]), .R(MiscR[0]));

Misc64X16 Misc_B (.CLK(CLK), .ACT(MiscACTReg[1]), .OpCODE(MiscOPRReg[1]), .SA(MiscSAReg[1]), .SD(MiscSDReg[1]), .DSTi(MiscDSTReg[1]),
				.CIN(MiscCINReg[1]), .A(MiscAReg[1]), .RDY(MiscRDY[1]), .ZERO(MiscZero[1]), .NaN(MiscNaN[1]), .SIGN(MiscSign[1]),
				.OVR(MiscOVR[1]), .COUT(MiscCOUT[1]), .SR(MiscSR[1]), .DSTo(MiscDST[1]), .R(MiscR[1]));

/*
===========================================================================================================
				Assignments part
===========================================================================================================
*/
assign RIP[0]={PrefRealIP[0], 1'b0};
assign RIP[1]={PrefRealIP[1], 1'b0};

// error reporting
assign ESTB[0]=(((DLMachine_A==ZSS) | (DLMachine_A==INVSS) | (DLMachine_A==AERSS)) & ~CheckTag[0][6] & ~CheckTag[0][5]) | CodeError[0] | (DLMachine_A==INVOBS);
assign ESTB[1]=(((DLMachine_B==ZSS) | (DLMachine_B==INVSS) | (DLMachine_B==AERSS)) & ~CheckTag[1][6] & ~CheckTag[1][5]) | CodeError[1] | (DLMachine_B==INVOBS);
assign ECD[0][23:0]=CodeError[0] ? ADR_A[13][23:0] : ((DLMachine_A==INVOBS) ? InvalidSelector[0] : CheckSelector[0][23:0]);
assign ECD[1][23:0]=CodeError[1] ? ADR_B[13][23:0] : ((DLMachine_B==INVOBS) ? InvalidSelector[1] : CheckSelector[1][23:0]);
assign ECD[0][24]=CodeError[0] | LoadLowerDSC[0] | LoadUpperDSC[0];
assign ECD[1][24]=CodeError[1] | LoadLowerDSC[1] | LoadUpperDSC[1];
assign ECD[0][25]=CodeError[0] | (DLMachine_A==AERSS);
assign ECD[1][25]=CodeError[1] | (DLMachine_B==AERSS);
assign ECD[0][26]=InvalidCPL[0] & ~CodeError[0];
assign ECD[1][26]=InvalidCPL[1] & ~CodeError[1];
assign ECD[0][27]=InvalidTaskID[0] & ~CodeError[0];
assign ECD[1][27]=InvalidTaskID[1] & ~CodeError[1];
assign ECD[0][28]=InvalidType[0] & ~CodeError[0];
assign ECD[1][28]=InvalidType[1] & ~CodeError[1];

assign CSEL[0]=ADR_A[13][23:0];
assign CSEL[1]=ADR_B[13][23:0];

/*
===========================================================================================================
				Asynchronous part
===========================================================================================================
*/
always @*
	begin
	
	// LOOP instruction flag
	LoopInstFlag[0]=MiscInstReg[0][3] & MiscInstReg[0][2] & MiscInstReg[0][1] & MiscInstReg[0][0];
	LoopInstFlag[1]=MiscInstReg[1][3] & MiscInstReg[1][2] & MiscInstReg[1][1] & MiscInstReg[1][0];

	CheckNode[0]=(CheckACT[0] & CheckAR[0][3] & ~CheckNetwork[0] & ~CheckAR[0][2] & (CheckOffset[0][36:5]>=CheckLL[0]) & (CheckOffset[0][36:5]<CheckUL[0]) & (CheckCMD[0] | CheckAR[0][1]) & 
						(~CheckCMD[0] | CheckAR[0][0])) | (DLMachine_A==LBS) | (DLMachine_A==LLSS) | (DLMachine_A==LSLS) |
									((DLMachine_A==STS) & CheckTag[0][6] & CheckTag[0][5] & ~CheckTag[0][4] & ~CheckTag[0][3]);
									
	CheckNode[1]=(CheckACT[1] & CheckAR[1][3] & ~CheckNetwork[1] & ~CheckAR[1][2] & (CheckOffset[1][36:5]>=CheckLL[1]) & (CheckOffset[1][36:5]<CheckUL[1]) & (CheckCMD[1] | CheckAR[1][1]) & 
						(~CheckCMD[1] | CheckAR[1][0])) | (DLMachine_B==LBS) | (DLMachine_B==LLSS) | (DLMachine_B==LSLS) |
									((DLMachine_B==STS) & CheckTag[1][6] & CheckTag[1][5] & ~CheckTag[1][4] & ~CheckTag[1][3]);
									
	CheckStreamNode[0]=CheckACT[0] & CheckAR[0][3] & ~CheckNetwork[0] & CheckAR[0][2];
	CheckStreamNode[1]=CheckACT[1] & CheckAR[1][3] & ~CheckNetwork[1] & CheckAR[1][2];
	
	CheckNetNode[0]=CheckACT[0] & CheckNetwork[0];
	CheckNetNode[1]=CheckACT[1] & CheckNetwork[1];

	// Next node on the check access stage
	MemChannelSel=(CheckNode[1] | CheckStreamNode[1] | CheckNetNode[1]) & (~TAGo[8] | ~(CheckNode[0] | CheckStreamNode[0] | CheckNetNode[0]));
	
	CheckNext[0]=(~ACT | NEXT) & (~StreamACT | StreamNEXT) & (~NetACT | NetNEXT) & ~MemChannelSel;
	CheckNext[1]=(~ACT | NEXT) & (~StreamACT | StreamNEXT) & (~NetACT | NetNEXT) & MemChannelSel;
	
	// next node on the memory forming stage
	MemNext[0]=~CheckACT[0] | (CheckNext[0] & ((CheckAR[0][3] & (CheckOffset[0][36:5]>=CheckLL[0]) & (CheckOffset[0][36:5]<CheckUL[0]) &
													(CheckCMD[0] | CheckAR[0][1]) & 
													(~CheckCMD[0] | CheckAR[0][0])) | (CheckAR[0][3] & CheckAR[0][2]) | CheckNetwork[0])) |
						((DLMachine_A==STS) & (~CheckTag[0][6] | ~CheckTag[0][5] | CheckTag[0][4] | CheckTag[0][3] | CheckNext[0]));

	MemNext[1]=~CheckACT[1] | (CheckNext[1] & ((CheckAR[1][3] & (CheckOffset[1][36:5]>=CheckLL[1]) & (CheckOffset[1][36:5]<CheckUL[1]) &
													(CheckCMD[1] | CheckAR[1][1]) & 
													(~CheckCMD[1] | CheckAR[1][0])) | (CheckAR[1][3] & CheckAR[1][2]) | CheckNetwork[1])) |
						((DLMachine_B==STS) & (~CheckTag[1][6] | ~CheckTag[1][5] | CheckTag[1][4] | CheckTag[1][3] | CheckNext[1]));
	
	// forming condition code for prefetcher
	case (PrefInstReg[0][11:9])
		3'd0:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][16] & ~(|PrefCCBypassReg[0])) | (FADDZero & PrefCCBypassReg[0][0]) |
										(FMULZero[0] & PrefCCBypassReg[0][1]) | (FMULZero[1] & PrefCCBypassReg[0][2]) |
										(ALUZero & PrefCCBypassReg[0][3]) | (ShiftZERO & PrefCCBypassReg[0][4]) | (MiscZero[0] & PrefCCBypassReg[0][5]));
		3'd1:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][15] & ~PrefCCBypassReg[0][3] & ~PrefCCBypassReg[0][5]) | (ALUCOUT[15] & PrefCCBypassReg[0][3]) |
										(MiscCOUT[0] & PrefCCBypassReg[0][5]));
		3'd2:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][17] & ~(|PrefCCBypassReg[0])) | (FADDSign & PrefCCBypassReg[0][0]) | (FMULSign[0] & PrefCCBypassReg[0][1]) |
										(FMULSign[1] & PrefCCBypassReg[0][2]) | (ALUSign & PrefCCBypassReg[0][3]) | (ShiftSign & PrefCCBypassReg[0][4]) | (MiscSign[0] & PrefCCBypassReg[0][5]));
		3'd3:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][18] & ~PrefCCBypassReg[0][3] & ~PrefCCBypassReg[0][4]) | (ALUOVR & PrefCCBypassReg[0][3]) | (ShiftOVR & PrefCCBypassReg[0][4]));
		3'd4:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][19] & ~PrefCCBypassReg[0][0] & ~PrefCCBypassReg[0][1] & ~PrefCCBypassReg[0][2] & ~PrefCCBypassReg[0][5]) |
										(FADDInf & PrefCCBypassReg[0][0]) | (FMULInf[0] & PrefCCBypassReg[0][1]) | (FMULInf[1] & PrefCCBypassReg[0][2]) | (MiscOVR[0] & PrefCCBypassReg[0][5]));
		3'd5:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][20] & ~PrefCCBypassReg[0][0] & ~PrefCCBypassReg[0][1] & ~PrefCCBypassReg[0][2] & ~PrefCCBypassReg[0][5]) |
										(FADDNaN & PrefCCBypassReg[0][0]) | (FMULNaN[0] & PrefCCBypassReg[0][1]) | (FMULNaN[1] & PrefCCBypassReg[0][2]) | (MiscNaN[0] & PrefCCBypassReg[0][5]));
		3'd6:	PrefCC[0]=PrefInstReg[0][12] ^ ((AFR_A[PrefInstReg[0][8:5]][21] & ~PrefCCBypassReg[0][4]) | (ShiftCOUT & PrefCCBypassReg[0][4]));
		3'd7:	PrefCC[0]=1'b1;
		endcase
	case (PrefInstReg[1][11:9])
		3'd0:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][16] & ~(|PrefCCBypassReg[1])) | (FADDZero & PrefCCBypassReg[1][0]) | (FMULZero[0] & PrefCCBypassReg[1][1]) |
										(FMULZero[1] & PrefCCBypassReg[1][2]) | (ALUZero & PrefCCBypassReg[1][3]) | (ShiftZERO & PrefCCBypassReg[1][4]) | (MiscZero[1] & PrefCCBypassReg[1][5]));
		3'd1:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][15] & ~PrefCCBypassReg[1][3] & ~PrefCCBypassReg[1][5]) | (ALUCOUT[15] & PrefCCBypassReg[1][3]) |
										(MiscCOUT[1] & PrefCCBypassReg[1][5]));
		3'd2:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][17] & ~(|PrefCCBypassReg[1])) | (FADDSign & PrefCCBypassReg[1][0]) | (FMULSign[0] & PrefCCBypassReg[1][1]) |
										(FMULSign[1] & PrefCCBypassReg[1][2]) | (ALUSign & PrefCCBypassReg[1][3]) | (ShiftSign & PrefCCBypassReg[1][4]) | (MiscSign[1] & PrefCCBypassReg[1][5]));
		3'd3:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][18] & ~PrefCCBypassReg[1][3] & ~PrefCCBypassReg[1][4]) | (ALUOVR & PrefCCBypassReg[1][3]) | (ShiftOVR & PrefCCBypassReg[1][4]));
		3'd4:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][19] & ~PrefCCBypassReg[1][0] & ~PrefCCBypassReg[1][1] & ~PrefCCBypassReg[1][2] & ~PrefCCBypassReg[1][5]) |
										(FADDInf & PrefCCBypassReg[1][0]) | (FMULInf[0] & PrefCCBypassReg[1][1]) | (FMULInf[1] & PrefCCBypassReg[1][2]) | (MiscOVR[1] & PrefCCBypassReg[1][5]));
		3'd5:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][20] & ~PrefCCBypassReg[1][0] & ~PrefCCBypassReg[1][1] & ~PrefCCBypassReg[1][2] & ~PrefCCBypassReg[1][5]) |
										(FADDNaN & PrefCCBypassReg[1][0]) | (FMULNaN[0] & PrefCCBypassReg[1][1]) | (FMULNaN[1] & PrefCCBypassReg[1][2]) | (MiscNaN[1] & PrefCCBypassReg[1][5]));
		3'd6:	PrefCC[1]=PrefInstReg[1][12] ^ ((AFR_B[PrefInstReg[1][8:5]][21] & ~PrefCCBypassReg[1][4]) | (ShiftCOUT & PrefCCBypassReg[1][4]));
		3'd7:	PrefCC[1]=1'b1;
		endcase

	// forming flags for reset LI counters
	for (i0=0; i0<16; i0=i0+1)
		begin
		LIResetFlag[0][i0]=(~FADDSelFlag & FADDInstReg[0] & ((FADDInstReg[5:2]==i0) | (FADDInstReg[9:6]==i0) | (FADDInstReg[13:10]==i0)))|
						(~FMULSelFlag & FMULInstReg[0] & ((FMULInstReg[4:1]==i0) | (FMULInstReg[8:5]==i0) | (FMULInstReg[12:9]==i0)))|
						(~FMULACCSelFlag & FMULACCReg[0] & ((FMULACCReg[7:4]==i0) | (FMULACCReg[11:8]==i0) | (FMULACCReg[15:12]==i0)))|
						(~FDIVSelFlag & FDIVInstReg[0] & (((FDIVInstReg[4:1]==i0) & ~FDIVInstReg[13]) | (FDIVInstReg[8:5]==i0) | (FDIVInstReg[12:9]==i0)))|
						(~ALUSelFlag & ALUInstReg[0] & (((ALUInstReg[6:3]==i0) & ~ALUInstReg[15]) | ((ALUInstReg[10:7]==i0) & ~ALUInstReg[15]) | 
											((ALUInstReg[14:11]==i0) & ~ALUInstReg[24]) | ((ALUInstReg[23:20]==i0) & ALUInstReg[24]) |
											((ALUInstReg[19:16]==i0) & ALUInstReg[24])))|
						(~ShiftSelFlag & ShiftInstReg[0] & ((ShiftInstReg[12:9]==i0) | (ShiftInstReg[4] & (ShiftInstReg[8:5]==i0))))|
						(MiscInstReg[0][0] & ((MiscInstReg[0][11:8]==i0) | (MiscInstReg[0][3] & ~(MiscInstReg[0][2] & MiscInstReg[0][1]) & (MiscInstReg[0][7:4]==i0))))|
						(MovInstReg[0][0] & (((MovInstReg[0][14:11]==i0) & (MovInstReg[0][2:1]!=2'b11)) | ((MovInstReg[0][10:7]==i0) & (MovInstReg[0][2:1]==2'b00))))|
						(PrefInstReg[0][0] & (((PrefInstReg[0][8:5]==i0) & (PrefInstReg[0][4:1]==4'd2)) | 
											((PrefInstReg[0][16:13]==i0) & (PrefInstReg[0][8:1]==8'hF0) & 
																	((PrefInstReg[0][12:10]==3'd3) | (PrefInstReg[0][12:10]==3'd5) | (PrefInstReg[0][12:9]==4'hC)))))|
						(MemInstReg[0][0] & (((MemInstReg[0][15:12]==i0) & (MemInstReg[0][4:1]!=4'd6) & (~(MemInstReg[0][11] & (&MemInstReg[0][3:1])))) | 
											((MemInstReg[0][11:8]==i0) & ((MemInstReg[0][4:3]==2'b10) | 
																														(MemInstReg[0][4:1]==4'b1100) |
																														(MemInstReg[0][4:1]==4'b0000) |
																														(MemInstReg[0][4:1]==4'b0110)))));
		LIResetFlag[1][i0]=(FADDSelFlag & FADDInstReg[0] & ((FADDInstReg[5:2]==i0) | (FADDInstReg[9:6]==i0) | (FADDInstReg[13:10]==i0)))|
						(FMULSelFlag & FMULInstReg[0] & ((FMULInstReg[4:1]==i0) | (FMULInstReg[8:5]==i0) | (FMULInstReg[12:9]==i0)))|
						(FMULACCSelFlag & FMULACCReg[0] & ((FMULACCReg[7:4]==i0) | (FMULACCReg[11:8]==i0) | (FMULACCReg[15:12]==i0)))|
						(FDIVSelFlag & FDIVInstReg[0] & (((FDIVInstReg[4:1]==i0) & ~FDIVInstReg[13]) | (FDIVInstReg[8:5]==i0) | (FDIVInstReg[12:9]==i0)))|
						(ALUSelFlag & ALUInstReg[0] & (((ALUInstReg[6:3]==i0) & ~ALUInstReg[15]) | ((ALUInstReg[10:7]==i0) & ~ALUInstReg[15]) | 
											((ALUInstReg[14:11]==i0) & ~ALUInstReg[24]) | ((ALUInstReg[23:20]==i0) & ALUInstReg[24]) |
											((ALUInstReg[19:16]==i0) & ALUInstReg[24])))|
						(ShiftSelFlag & ShiftInstReg[0] & ((ShiftInstReg[12:9]==i0) | (ShiftInstReg[4] & (ShiftInstReg[8:5]==i0))))|
						(MiscInstReg[1][0] & ((MiscInstReg[1][11:8]==i0) | (MiscInstReg[1][3] & ~(MiscInstReg[1][2] & MiscInstReg[1][1]) & (MiscInstReg[1][7:4]==i0))))|
						(MovInstReg[1][0] & (((MovInstReg[1][14:11]==i0) & (MovInstReg[1][2:1]!=2'b11)) | ((MovInstReg[1][10:7]==i0) & (MovInstReg[1][2:1]==2'b00))))|
						(PrefInstReg[1][0] & (((PrefInstReg[1][8:5]==i0) & (PrefInstReg[1][4:1]==4'd2)) | 
											((PrefInstReg[1][16:13]==i0) & (PrefInstReg[1][8:1]==8'hF0) & 
																	((PrefInstReg[1][12:10]==3'd3) | (PrefInstReg[1][12:10]==3'd5) | (PrefInstReg[1][12:9]==4'hC)))))|
						(MemInstReg[1][0] & (((MemInstReg[1][15:12]==i0) & (MemInstReg[1][4:1]!=4'd6) & (~(MemInstReg[1][11] & (&MemInstReg[1][3:1])))) | 
											((MemInstReg[1][11:8]==i0) & ((MemInstReg[1][4:3]==2'b10) | 
																														(MemInstReg[1][4:1]==4'b1100) |
																														(MemInstReg[1][4:1]==4'b0000) |
																														(MemInstReg[1][4:1]==4'b0110)))));
		end

	// Memory operand Size forming
	MemoryOSValue[0][4]=MemLDST[0] & (MemSize[0]==3'b100);
	MemoryOSValue[0][3]=MemPUSH[0] | MemPOP[0] | (MemLDST[0] & (MemSize[0]==3'b011));
	MemoryOSValue[0][2]=MemLDST[0] & (MemSize[0]==3'b010);
	MemoryOSValue[0][1]=MemLDST[0] & (MemSize[0]==3'b001);
	MemoryOSValue[0][0]=MemLDST[0] & (MemSize[0]==3'b000);
	MemoryOSValue[1][4]=MemLDST[1] & (MemSize[1]==3'b100);
	MemoryOSValue[1][3]=MemPUSH[1] | MemPOP[1] | (MemLDST[1] & (MemSize[1]==3'b011));
	MemoryOSValue[1][2]=MemLDST[1] & (MemSize[1]==3'b010);
	MemoryOSValue[1][1]=MemLDST[1] & (MemSize[1]==3'b001);
	MemoryOSValue[1][0]=MemLDST[1] & (MemSize[1]==3'b000);

	// interface to the descriptor reloading system
	// Load New sel flag
	LoadNewDSC[0]=CheckACT[0] & ~CheckAR[0][3] & ~CheckNetwork[0];
	LoadNewDSC[1]=CheckACT[1] & ~CheckAR[1][3] & ~CheckNetwork[1];
	// load lower segment
	LoadLowerDSC[0]=CheckACT[0] & CheckAR[0][3] & ~CheckAR[0][2] & (CheckOffset[0][36:5]<CheckLL[0]) & ~CheckNetwork[0];
	LoadLowerDSC[1]=CheckACT[1] & CheckAR[1][3] & ~CheckAR[1][2] & (CheckOffset[1][36:5]<CheckLL[1]) & ~CheckNetwork[1];
	// load upper segment
	LoadUpperDSC[0]=CheckACT[0] & CheckAR[0][3] & ~CheckAR[0][2] & (CheckOffset[0][36:5]>=CheckUL[0]) & ~CheckNetwork[0];
	LoadUpperDSC[1]=CheckACT[1] & CheckAR[1][3] & ~CheckAR[1][2] & (CheckOffset[1][36:5]>=CheckUL[1]) & ~CheckNetwork[1];
	// access error by type
	AccessError[0]=CheckACT[0] & CheckAR[0][3] & ~CheckNetwork[0] & ((~CheckCMD[0] & ~CheckAR[0][1]) | (CheckCMD[0] & ~CheckAR[0][0])) & ~CheckPref[0];
	AccessError[1]=CheckACT[1] & CheckAR[1][3] & ~CheckNetwork[1] & ((~CheckCMD[1] & ~CheckAR[1][1]) | (CheckCMD[1] & ~CheckAR[1][0])) & ~CheckPref[1];

	// channel selection 
	FADDSel=FADDInstBus[1][0] & (~FADDSelFlag | ~FADDInstBus[0][0]);
	FMULSel=FMULInstBus[1][0] & (~FMULSelFlag | ~FMULInstBus[0][0]);
	FMULACCSel=FMULACCBus[1][0] & (~FMULACCSelFlag | ~FMULACCBus[0][0]);
	FDIVSel=FDIVInstBus[1][0] & (~FDIVSelFlag | ~FDIVInstBus[0][0]);
	ALUSel=ALUInstBus[1][0] & (~ALUSelFlag | ~ALUInstBus[0][0]);
	ShiftSel=ShiftInstBus[1][0] & (~ShiftSelFlag | ~ShiftInstBus[0][0]);
	
	end

/*
===========================================================================================================
				Synchronous part
===========================================================================================================
*/
always @(negedge RESET or posedge CLK)
if (!RESET) begin
				LIFlag[0]<=0;
				LIFlag[1]<=0;
				GPVFReg[0]<=16'hFFFF;
				GPVFReg[1]<=16'hFFFF;
				AFR_A[0]<=32'd0;
				AFR_B[0]<=32'd0;
				AFR_A[1]<=32'd0;
				AFR_B[1]<=32'd0;
				AFR_A[2]<=32'd0;
				AFR_B[2]<=32'd0;
				AFR_A[3]<=32'd0;
				AFR_B[3]<=32'd0;
				AFR_A[4]<=32'd0;
				AFR_B[4]<=32'd0;
				AFR_A[5]<=32'd0;
				AFR_B[5]<=32'd0;
				AFR_A[6]<=32'd0;
				AFR_B[6]<=32'd0;
				AFR_A[7]<=32'd0;
				AFR_B[7]<=32'd0;
				AFR_A[8]<=32'd0;
				AFR_B[8]<=32'd0;
				AFR_A[9]<=32'd0;
				AFR_B[9]<=32'd0;
				AFR_A[10]<=32'd0;
				AFR_B[10]<=32'd0;
				AFR_A[11]<=32'd0;
				AFR_B[11]<=32'd0;
				AFR_A[12]<=32'd0;
				AFR_B[12]<=32'd0;
				AFR_A[13]<=32'd0;
				AFR_B[13]<=32'd0;
				AFR_A[14]<=32'd0;
				AFR_B[14]<=32'd0;
				AFR_A[15]<=32'd0;
				AFR_B[15]<=32'd0;
				ADR_A[0]<=0;
				ADR_B[0]<=0;
				ADR_A[1]<=0;
				ADR_B[1]<=0;
				ADR_A[2]<=0;
				ADR_B[2]<=0;
				ADR_A[3]<=0;
				ADR_B[3]<=0;
				ADR_A[4]<=0;
				ADR_B[4]<=0;
				ADR_A[5]<=0;
				ADR_B[5]<=0;
				ADR_A[6]<=0;
				ADR_B[6]<=0;
				ADR_A[7]<=0;
				ADR_B[7]<=0;
				ADR_A[8]<=0;
				ADR_B[8]<=0;
				ADR_A[9]<=0;
				ADR_B[9]<=0;
				ADR_A[10]<=0;
				ADR_B[10]<=0;
				ADR_A[11]<=0;
				ADR_B[11]<=0;
				ADR_A[12]<=0;
				ADR_B[12]<=0;
				ADR_A[13]<=0;
				ADR_B[13]<=0;
				ADR_A[14]<=0;
				ADR_B[14]<=0;
				ADR_A[15]<=0;
				ADR_B[15]<=0;
				GPR_A[0]<=0;
				GPR_B[0]<=0;
				GPR_A[1]<=0;
				GPR_B[1]<=0;
				GPR_A[2]<=0;
				GPR_B[2]<=0;
				GPR_A[3]<=0;
				GPR_B[3]<=0;
				GPR_A[4]<=0;
				GPR_B[4]<=0;
				GPR_A[5]<=0;
				GPR_B[5]<=0;
				GPR_A[6]<=0;
				GPR_B[6]<=0;
				GPR_A[7]<=0;
				GPR_B[7]<=0;
				GPR_A[8]<=0;
				GPR_B[8]<=0;
				GPR_A[9]<=0;
				GPR_B[9]<=0;
				GPR_A[10]<=0;
				GPR_B[10]<=0;
				GPR_A[11]<=0;
				GPR_B[11]<=0;
				GPR_A[12]<=0;
				GPR_B[12]<=0;
				GPR_A[13]<=0;
				GPR_B[13]<=0;
				GPR_A[14]<=0;
				GPR_B[14]<=0;
				GPR_A[15]<=0;
				GPR_B[15]<=0;
				FMULACCReg[0]<=1'b0;
				FADDInstReg[0]<=1'b0;
				FMULInstReg[0]<=1'b0;
				FDIVInstReg[0]<=1'b0;
				FDIVACTReg<=1'b0;
				ALUInstReg[0]<=1'b0;
				ShiftInstReg[0]<=1'b0;
				MiscInstReg[0][0]<=1'b0;
				MiscInstReg[1][0]<=1'b0;
				LoopInstReg[0][0]<=1'b0;
				LoopInstReg[1][0]<=1'b0;
				PrefInstReg[0][0]<=1'b0;
				PrefInstReg[1][0]<=1'b0;
				MovInstReg[0][0]<=1'b0;
				MovInstReg[1][0]<=1'b0;
				MemInstReg[0][0]<=1'b0;
				MemInstReg[1][0]<=1'b0;
				MemBusy<=0;
				MemCNT[0]<=0;
				MemCNT[1]<=0;
				CheckACT<=0;
				ACT<=1'b0;
				StreamACT<=1'b0;
				NetACT<=1'b0;
				DLMachine_A<=WS;
				DLMachine_B<=WS;
				DescriptorLoadState<=0;
				DTR_A[0]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[0]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[1]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[1]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[2]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[2]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[3]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[3]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[4]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[4]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[5]<=156'hB000000000000FFFFFFFF00000000FFFFFFFFFC;
				DTR_B[5]<=156'hB000000000000FFFFFFFF00000000FFFFFFFFFC;
				DTR_A[6]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[6]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_A[7]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR_B[7]<=156'hB000000000000FFFFFFFF000000000000000000;
				PrefCallReg<=0;
				PrefRetReg<=0;
				MemReadAR<=0;
				MemLoadOffset<=0;
				MemLoadSel<=0;
				MemReq<=0;
				MemPUSH<=0;
				MemPOP<=0;
				MemADRPushPop<=0;
				MemLDO<=0;
				FMULACCACTReg<=0;
				FMULACCDRDYFlag<=0;
				FFT32NEXTReg<=0;
				FADDSelFlag<=0;
				FMULSelFlag<=0;
				FMULACCSelFlag<=0;
				FDIVSelFlag<=0;
				ALUSelFlag<=0;
				ShiftSelFlag<=0;
				TAGo<=0;
				IV[0]<=0;
				IV[1]<=0;
				FMULACCSelReg<=0;
				MemFifoFullFlag<=0;
				end
else begin
	
	// Fifo full flag
	MemFifoFullFlag[0]<=(MemFifoUsedW[0]>6'd59);
	MemFifoFullFlag[1]<=(MemFifoUsedW[1]>6'd59);
	
	// Instructions transfered to the sequencer
	IV[0]<=IVF[0] & {4{IFetch[0] & InsRDY[0]}};
	IV[1]<=IVF[1] & {4{IFetch[1] & InsRDY[1]}};

	// EU empty flag
	EMPTY[0]<=PrefEMPTY[0] & SeqEMPTY[0] & (&GPVFReg[0]);
	EMPTY[1]<=PrefEMPTY[1] & SeqEMPTY[1] & (&GPVFReg[1]);
	
	// output data for context store operations
	case (RA[5:4])
		2'd0: CDATA<=RA[6] ? GPR_B[RA[3:0]][63:0] : GPR_A[RA[3:0]][63:0];
		2'd1: CDATA<=RA[6] ? GPR_B[RA[3:0]][127:64] : GPR_A[RA[3:0]][127:64];
		2'd2: CDATA<=RA[6] ? {32'd0, AFR_B[RA[3:0]]} : {32'd0, AFR_A[RA[3:0]]};
		2'd3: CDATA<=RA[6] ? {27'd0, ADR_B[RA[3:0]]} : {27'd0, ADR_A[RA[3:0]]};
		endcase
	
	// Storing TAGi
	TAGiReg<=TAGi;

	// LI flags
	for (i1=0; i1<16; i1=i1+1)
		begin
		LIFlag[0][i1]<=(&MovInstReg[0][2:0]) & (MovInstReg[0][14:11]==i1);
		LIFlag[1][i1]<=(&MovInstReg[1][2:0]) & (MovInstReg[1][14:11]==i1);
		end
	
	// processign GPR valid flags
	for (i2=0; i2<16; i2=i2+1)
			begin
			GPVFReg[0][i2]<=(GPVFReg[0][i2] & GPVFINVD[0][i2])|
						(~FADDDST[4] & (FADDDST[3:0]==i2) & FADDRDY)|
						(~FMULDST[0][4] & (FMULDST[0][3:0]==i2) & FMULRDY[0])|
						(~FMULDST[1][4] & (FMULDST[1][3:0]==i2) & FMULRDY[1])|
						FMULACCSelNode[0][i2]|
						(~FMULACCDSTReg[4] & (FMULACCDSTReg[3:0]==i2) & FMULACCACTReg & FMULACCCMDReg)|
						(~FDIVDST[4] & (FDIVDST[3:0]==i2) & FDIVRDY)|
						(~ALUDST[4] & (ALUDST[3:0]==i2) & ALURDY)|
						(~ShiftDST[4] & (ShiftDST[3:0]==i2) & ShiftRDY)|
						((MiscDST[0]==i2) & MiscRDY[0])|
						((MovInstReg[0][14:11]==i2) & MovInstReg[0][0])|
						(MemReadAR[0] & (MemDST[0]==i2))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i2) & ~TAGi[6] & ~TAGi[5] & (~TAGi[7] | TAGi[4])) |
						(SkipDataRead[0] & (STAGReg[0]==i2));
			GPVFReg[1][i2]<=(GPVFReg[1][i2] & GPVFINVD[1][i2])|
						(FADDDST[4] & (FADDDST[3:0]==i2) & FADDRDY)|
						(FMULDST[0][4] & (FMULDST[0][3:0]==i2) & FMULRDY[0])|
						(FMULDST[1][4] & (FMULDST[1][3:0]==i2) & FMULRDY[1])|
						FMULACCSelNode[1][i2]|
						(FMULACCDSTReg[4] & (FMULACCDSTReg[3:0]==i2) & FMULACCACTReg & FMULACCCMDReg)|
						(FDIVDST[4] & (FDIVDST[3:0]==i2) & FDIVRDY)|
						(ALUDST[4] & (ALUDST[3:0]==i2) & ALURDY)|
						(ShiftDST[4] & (ShiftDST[3:0]==i2) & ShiftRDY)|
						((MiscDST[1]==i2) & MiscRDY[1])|
						((MovInstReg[1][14:11]==i2) & MovInstReg[1][0])|
						(MemReadAR[1] & (MemDST[1]==i2))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i2) & ~TAGi[6] & ~TAGi[5] & (~TAGi[7] | TAGi[4])) |
						(SkipDataRead[1] & (STAGReg[1]==i2));
			end
	// result strobe nodes
	for (i3=0; i3<16; i3=i3+1)
		begin
		FlagWrite[0][i3]<=(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(~FMULACCDSTReg[4] & FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg[3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3))|
						(~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3))|
						(MiscRDYR[0] & (MiscDSTR[0]==i3))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ((TAGi[5] & ~TAGi[4]) | (~TAGi[5] & (~TAGi[7] | TAGi[4]))));

		FlagWrite[1][i3]<=(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(FMULACCDSTReg[4] & FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg[3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3))|
						(ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3))|
						(MiscRDYR[1] & (MiscDSTR[1]==i3))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ((TAGi[5] & ~TAGi[4]) | (~TAGi[5] & (~TAGi[7] | TAGi[4]))));
						
		GPRByteNode[0][i3]<=(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3))|
						(~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3))|
						(MiscRDYR[0] & (MiscDSTR[0]==i3))|
						(MovInstReg[0][0] & (MovInstReg[0][14:11]==i3) & (MovInstReg[0][2:1]!=2'b01))|
						(MemReadAR[0] & (MemDST[0]==i3))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);
						
		GPRByteNode[1][i3]<=(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3))|
						(ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3))|
						(MiscRDYR[1] & (MiscDSTR[1]==i3))|
						(MovInstReg[1][0] & (MovInstReg[1][14:11]==i3) & (MovInstReg[1][2:1]!=2'b01))|
						(MemReadAR[1] & (MemDST[1]==i3))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRWordNode[0][i3]<=(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & (|ALUSR))|
						(~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & (|ShiftSR))|
						(MiscRDYR[0] & (MiscDSTR[0]==i3) & (|MiscSR[0]))|
						(MovInstReg[0][0] & (MovInstReg[0][14:11]==i3) & (MovInstReg[0][2:1]!=2'b01))|
						(MemReadAR[0] & (MemDST[0]==i3))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3) & (|SZi[1:0]) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRWordNode[1][i3]<=(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & (|ALUSR))|
						(ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & (|ShiftSR))|
						(MiscRDYR[1] & (MiscDSTR[1]==i3) & (|MiscSR[1]))|
						(MovInstReg[1][0] & (MovInstReg[1][14:11]==i3) & (MovInstReg[1][2:1]!=2'b01))|
						(MemReadAR[1] & (MemDST[1]==i3))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3) & (|SZi[1:0]) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRDwordNode[0][i3]<=(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & ALUSR[1])|
						(~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & ShiftSR[1])|
						(MiscRDYR[0] & (MiscDSTR[0]==i3) & (MiscSR[0][2] | MiscSR[0][1]))|
						(MovInstReg[0][0] & (MovInstReg[0][14:11]==i3) & (MovInstReg[0][2:1]!=2'b01))|
						(MemReadAR[0] & (MemDST[0]==i3))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3)& SZi[1] & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRDwordNode[1][i3]<=(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3))|
						(ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & ALUSR[1])|
						(ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & ShiftSR[1])|
						(MiscRDYR[1] & (MiscDSTR[1]==i3) & (MiscSR[1][2] | MiscSR[1][1]))|
						(MovInstReg[1][0] & (MovInstReg[1][14:11]==i3) & (MovInstReg[1][2:1]!=2'b01))|
						(MemReadAR[1] & (MemDST[1]==i3))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3)& SZi[1] & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRQwordNode[0][i3]<=(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3) & (FDIVSR[2] | FDIVSR[0]))|
						(~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & (&ALUSR))|
						(~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & ShiftSR[1] & ShiftSR[0])|
						(MiscRDYR[0] & (MiscDSTR[0]==i3) & ((MiscSR[0][1] & MiscSR[0][0]) | MiscSR[0][2]))|
						(MovInstReg[0][0] & (MovInstReg[0][14:11]==i3) & (MovInstReg[0][2:1]!=2'b01))|
						(MemReadAR[0] & (MemDST[0]==i3))|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3) & (&SZi[1:0]) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);

		GPRQwordNode[1][i3]<=(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i3))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3) & (FDIVSR[2] | FDIVSR[0]))|
						(ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i3) & (&ALUSR))|
						(ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i3) & ShiftSR[1] & ShiftSR[0])|
						(MiscRDYR[1] & (MiscDSTR[1]==i3) & ((MiscSR[1][1] & MiscSR[1][0]) | MiscSR[1][2]))|
						(MovInstReg[1][0] & (MovInstReg[1][14:11]==i3) & (MovInstReg[1][2:1]!=2'b01))|
						(MemReadAR[1] & (MemDST[1]==i3))|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3) & (&SZi[1:0]) & ~TAGi[6] & ~TAGi[5] & ~TAGi[4]);
		
		GPROwordNode[0][i3]<=(MovInstReg[0][0] & (MovInstReg[0][14:11]==i3) & (MovInstReg[0][2:1]!=2'b01))|
						(~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3) & FDIVSR[2])|
						(~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(MiscRDYR[0] & (MiscDSTR[0]==i3) & MiscSR[0][2])|
						(~TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ~TAGi[5] & TAGi[4]);
		
		GPROwordNode[1][i3]<=(MovInstReg[1][0] & (MovInstReg[1][14:11]==i3) & (MovInstReg[1][2:1]!=2'b01))|
						(FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i3))|
						(FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i3) & FDIVSR[2])|
						(FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i3))|
						(MiscRDYR[1] & (MiscDSTR[1]==i3) & MiscSR[1][2])|
						(TAGi[8] & DRDY & (TAGi[3:0]==i3) & ~TAGi[6] & ~TAGi[5] & TAGi[4]);
		end
	// data selection nodes
	for (i4=0; i4<16; i4=i4+1)
		begin
		FADDSelNode[0][i4]<=~FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i4);
		FADDSelNode[1][i4]<=FADDDSTR[4] & FADDRDYR & (FADDDSTR[3:0]==i4);
		FMULSelNode[0][i4]<=~FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i4);
		FMULSelNode[1][i4]<=FMULDSTR[0][4] & FMULRDYR[0] & (FMULDSTR[0][3:0]==i4);
		FMULQSelNode[0][i4]<=~FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i4);
		FMULQSelNode[1][i4]<=FMULDSTR[1][4] & FMULRDYR[1] & (FMULDSTR[1][3:0]==i4);
		FMULACCSelNode[0][i4]<=~FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i4);
		FMULACCSelNode[1][i4]<=FMULACCDST[4] & FMULACCRDY & (FMULACCDST[3:0]==i4);
		FFTSelNode[0][i4]<=~FMULACCDSTReg[4] & FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg[3:0]==i4);
		FFTSelNode[1][i4]<=FMULACCDSTReg[4] & FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg[3:0]==i4);
		FDIVSelNode[0][i4]<=~FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i4);
		FDIVSelNode[1][i4]<=FDIVDST[4] & FDIVRDY & (FDIVDST[3:0]==i4);
		ALUSelNode[0][i4]<=~ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i4);
		ALUSelNode[1][i4]<=ALUDSTR[4] & ALURDYR & (ALUDSTR[3:0]==i4);
		ShiftSelNode[0][i4]<=~ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i4);
		ShiftSelNode[1][i4]<=ShiftDSTR[4] & ShiftRDYR & (ShiftDSTR[3:0]==i4);
		MiscSelNode[0][i4]<=MiscRDYR[0] & (MiscDSTR[0]==i4);
		MiscSelNode[1][i4]<=MiscRDYR[1] & (MiscDSTR[1]==i4);
		MovSelNode[0][i4]<=(MovInstReg[0][0] & (MovInstReg[0][14:11]==i4) & (MovInstReg[0][2:1]!=2'b01));
		MovSelNode[1][i4]<=(MovInstReg[1][0] & (MovInstReg[1][14:11]==i4) & (MovInstReg[1][2:1]!=2'b01));
		MemSelNode[0][i4]<=~TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & ~TAGi[5];
		MemSelNode[1][i4]<=TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & ~TAGi[5];
		MemFSelNode[0][i4]<=~TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & TAGi[5] & ~TAGi[4];
		MemFSelNode[1][i4]<=TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & TAGi[5] & ~TAGi[4];
		MemASelNode[0][i4]<=~TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & TAGi[5] & TAGi[4];
		MemASelNode[1][i4]<=TAGi[8] & DRDY & (TAGi[3:0]==i4) & ~TAGi[6] & TAGi[5] & TAGi[4];
		MemARSelNode[0][i4]<=MemReadAR[0] & (MemDST[0]==i4);
		MemARSelNode[1][i4]<=MemReadAR[1] & (MemDST[1]==i4);
		end
	// load selector from memory node
	MemLSelNode[0]<=~TAGi[8] & DRDY & ~TAGi[6] & TAGi[0] & TAGi[5] & TAGi[4];
	MemLSelNode[1]<=TAGi[8] & DRDY & ~TAGi[6] & TAGi[0] & TAGi[5] & TAGi[4];

	// DTR selection nodes
	for (i5=0; i5<8; i5=i5+1)
		begin
		DTRWriteFlag[0][i5]<=~TAGi[8] & DRDY & ~TAGi[7] & TAGi[6] & ~TAGi[5] &(TAGi[4:2]==i5);
		DTRWriteFlag[1][i5]<=TAGi[8] & DRDY & ~TAGi[7] & TAGi[6] & ~TAGi[5] &(TAGi[4:2]==i5);
		end
	DTRWriteFlag[0][8]<=~TAGi[8] & DRDY & ~TAGi[7] & TAGi[6] & ~TAGi[5];
	DTRWriteFlag[1][8]<=TAGi[8] & DRDY & ~TAGi[7] & TAGi[6] & ~TAGi[5];
	
	// Context loading Flag
	ContextLoadFlag<=CLOAD;	

	// delayed ready registers
	FADDRDYR<=FADDRDY;
	FMULRDYR[0]<=FMULRDY[0];
	FMULRDYR[1]<=FMULRDY[1];
	ALURDYR<=ALURDY;
	ShiftRDYR<=ShiftRDY;
	MiscRDYR<=MiscRDY;
	// delayed destination registers
	FADDDSTR<=FADDDST;
	FMULDSTR[0]<=FMULDST[0];
	FMULDSTR[1]<=FMULDST[1];
	ALUDSTR<=ALUDST;
	ShiftDSTR<=ShiftDST;
	MiscDSTR[0]<=MiscDST[0];
	MiscDSTR[1]<=MiscDST[1];
	// delayed size registers
	FDIVSRReg<=FDIVSR;
	ALUSRReg<=ALUSR;
	ShiftSRReg<=ShiftSR;
	MiscSRReg[0]<=MiscSR[0];
	MiscSRReg[1]<=MiscSR[1];
	SZiReg<=SZi;

	// storing results into registers
	for (i6=0; i6<16; i6=i6+1)
		begin
		// storing arithmetic flags
		if (FlagWrite[0][i6])
			begin
			// CF[15:0]
			AFR_A[i6][14:0]<=(ALUCOUT[14:0] & {15{ALUSelNode[0][i6]}}) | (DTi[14:0] & {15{MemFSelNode[0][i6]}});
			AFR_A[i6][15]<=(ALUCOUT[15] & ALUSelNode[0][i6])|(MiscCOUT[0] & MiscSelNode[0][i6])|(DTi[15] & MemFSelNode[0][i6]);
			// ZF
			AFR_A[i6][16]<=(FADDZero & FADDSelNode[0][i6])|(FMULZero[0] & FMULSelNode[0][i6])|(FMULZero[1] & FMULQSelNode[0][i6])|
						(FDIVZero & FDIVSelNode[0][i6])|(ALUZero & ALUSelNode[0][i6])|(ShiftZERO & ShiftSelNode[0][i6])|
						(FMULACCZERO & FMULACCSelNode[0][i6])|(MiscZero[0] & MiscSelNode[0][i6])|(DTi[16] & MemFSelNode[0][i6])|
						(FFT32NEXTReg & FFTSelNode[0][i6]);
			// SF
			AFR_A[i6][17]<=(FADDSign & FADDSelNode[0][i6])|(FMULSign[0] & FMULSelNode[0][i6])|(FMULSign[1] & FMULQSelNode[0][i6])|
						(FDIVSign & FDIVSelNode[0][i6])|(ALUSign & ALUSelNode[0][i6])|(ShiftSign & ShiftSelNode[0][i6])|
						(FMULACCSIGN & FMULACCSelNode[0][i6])|(MiscSign[0] & MiscSelNode[0][i6])|(DTi[17] & MemFSelNode[0][i6]);
			// OF
			AFR_A[i6][18]<=(ALUOVR & ALUSelNode[0][i6])|(ShiftOVR & ShiftSelNode[0][i6])|(DTi[18] & MemFSelNode[0][i6]);
			// IF
			AFR_A[i6][19]<=(FADDInf & FADDSelNode[0][i6])|(FMULInf[0] & FMULSelNode[0][i6])|(FMULInf[1] & FMULQSelNode[0][i6])|
						(FDIVInf & FDIVSelNode[0][i6])|(MiscOVR[0] & MiscSelNode[0][i6])|(DTi[19] & MemFSelNode[0][i6])|
						(FMULACCINF & FMULACCSelNode[0][i6]);
			// NF
			AFR_A[i6][20]<=(FADDNaN & FADDSelNode[0][i6])|(FMULNaN[0] & FMULSelNode[0][i6])|(FMULNaN[1] & FMULQSelNode[0][i6])|
						(FDIVNaN & FDIVSelNode[0][i6])|(MiscNaN[0] & MiscSelNode[0][i6])|(DTi[20] & MemFSelNode[0][i6])|
						(FMULACCNAN & FMULACCSelNode[0][i6])|(MemSelNode[0][i6] & (&SZiReg));
			// DBF
			AFR_A[i6][21]<=(ShiftCOUT & ShiftSelNode[0][i6])|(DTi[21] & MemFSelNode[0][i6]);
			end
		if (FlagWrite[1][i6])
			begin
			// CF[15:0]
			AFR_B[i6][14:0]<=(ALUCOUT[14:0] & {15{ALUSelNode[1][i6]}}) | (DTi[14:0] & {15{MemFSelNode[1][i6]}});
			AFR_B[i6][15]<=(ALUCOUT[15] & ALUSelNode[1][i6])|(MiscCOUT[1] & MiscSelNode[1][i6])|(DTi[15] & MemFSelNode[1][i6]);
			// ZF
			AFR_B[i6][16]<=(FADDZero & FADDSelNode[1][i6])|(FMULZero[0] & FMULSelNode[1][i6])|(FMULZero[1] & FMULQSelNode[1][i6])|
						(FDIVZero & FDIVSelNode[1][i6])|(ALUZero & ALUSelNode[1][i6])|(ShiftZERO & ShiftSelNode[1][i6])|
						(FMULACCZERO & FMULACCSelNode[1][i6])|(MiscZero[1] & MiscSelNode[1][i6])|(DTi[16] & MemFSelNode[1][i6])|
						(FFT32NEXTReg & FFTSelNode[1][i6]);
			// SF
			AFR_B[i6][17]<=(FADDSign & FADDSelNode[1][i6])|(FMULSign[0] & FMULSelNode[1][i6])|(FMULSign[1] & FMULQSelNode[1][i6])|
						(FDIVSign & FDIVSelNode[1][i6])|(ALUSign & ALUSelNode[1][i6])|(ShiftSign & ShiftSelNode[1][i6])|
						(FMULACCSIGN & FMULACCSelNode[1][i6])|(MiscSign[1] & MiscSelNode[1][i6])|(DTi[17] & MemFSelNode[1][i6]);
			// OF
			AFR_B[i6][18]<=(ALUOVR & ALUSelNode[1][i6])|(ShiftOVR & ShiftSelNode[1][i6])|(DTi[18] & MemFSelNode[1][i6]);
			// IF
			AFR_B[i6][19]<=(FADDInf & FADDSelNode[1][i6])|(FMULInf[0] & FMULSelNode[1][i6])|(FMULInf[1] & FMULQSelNode[1][i6])|
						(FDIVInf & FDIVSelNode[1][i6])|(MiscOVR[1] & MiscSelNode[1][i6])|(DTi[19] & MemFSelNode[1][i6])|
						(FMULACCINF & FMULACCSelNode[1][i6]);
			// NF
			AFR_B[i6][20]<=(FADDNaN & FADDSelNode[1][i6])|(FMULNaN[0] & FMULSelNode[1][i6])|(FMULNaN[1] & FMULQSelNode[1][i6])|
						(FDIVNaN & FDIVSelNode[1][i6])|(MiscNaN[1] & MiscSelNode[1][i6])|(DTi[20] & MemFSelNode[1][i6])|
						(FMULACCNAN & FMULACCSelNode[1][i6])|(MemSelNode[1][i6] & (&SZiReg));
			// DBF
			AFR_B[i6][21]<=(ShiftCOUT & ShiftSelNode[1][i6])|(DTi[21] & MemFSelNode[1][i6]);
			end
		// Size of operand and address mode
		if (MemFSelNode[0][i6]) AFR_A[i6][27:22]<=DTi[27:22];
			else if (MemSelNode[0][i6]) AFR_A[i6][24:22]<=TAGiReg[7] ? 3'd4 : SZiReg;
				else if (MovSelNode[0][i6]) AFR_A[i6][24:22]<=MovSR[0];
					else if (MemARSelNode[0][i6]) AFR_A[i6][24:22]<=3'b011;
						else if (FADDSelNode[0][i6] | FMULSelNode[0][i6] | FMULQSelNode[0][i6] | FDIVSelNode[0][i6] | ALUSelNode[0][i6] | ShiftSelNode[0][i6] | MiscSelNode[0][i6] | FMULACCSelNode[0][i6])
							begin
							AFR_A[i6][24]<=FMULQSelNode[0][i6] | (FADDSR[2] & FADDSelNode[0][i6]) | (MiscSRReg[0][2] & MiscSelNode[0][i6]) | (FDIVSRReg[2] & FDIVSelNode[0][i6]);
							AFR_A[i6][23:22]<=(FADDSR[1:0] & {2{FADDSelNode[0][i6]}})|
										({1'b1, FMULSR} & {2{FMULSelNode[0][i6]}})|
										(FDIVSRReg[1:0] & {2{FDIVSelNode[0][i6]}})|
										(ALUSRReg & {2{ALUSelNode[0][i6]}})|
										(ShiftSRReg & {2{ShiftSelNode[0][i6]}})|
										(MiscSRReg[0][1:0] & {2{MiscSelNode[0][i6]}})| {FMULACCSelNode[0][i6], 1'b0};
							end
		if (MemFSelNode[1][i6]) AFR_B[i6][27:22]<=DTi[27:22];
			else if (MemSelNode[1][i6]) AFR_B[i6][24:22]<=TAGiReg[7] ? 3'd4 : SZiReg;
				else if (MovSelNode[1][i6]) AFR_B[i6][24:22]<=MovSR[1];
					else if (MemARSelNode[1][i6]) AFR_B[i6][24:22]<=3'b011;
						else if (FADDSelNode[1][i6] | FMULSelNode[1][i6] | FMULQSelNode[1][i6] | FDIVSelNode[1][i6] | ALUSelNode[1][i6] | ShiftSelNode[1][i6] | MiscSelNode[1][i6] | FMULACCSelNode[1][i6])
							begin
							AFR_B[i6][24]<=FMULQSelNode[1][i6] | (FADDSR[2] & FADDSelNode[1][i6]) | (MiscSRReg[1][2] & MiscSelNode[1][i6]) | (FDIVSRReg[2] & FDIVSelNode[1][i6]);
							AFR_B[i6][23:22]<=(FADDSR[1:0] & {2{FADDSelNode[1][i6]}})|
										({1'b1, FMULSR} & {2{FMULSelNode[1][i6]}})|
										(FDIVSRReg[1:0] & {2{FDIVSelNode[1][i6]}})|
										(ALUSRReg & {2{ALUSelNode[1][i6]}})|
										(ShiftSRReg & {2{ShiftSelNode[1][i6]}})|
										(MiscSRReg[1][1:0] & {2{MiscSelNode[1][i6]}})| {FMULACCSelNode[1][i6], 1'b0};
							end
		//LI byte counter
		if (LIResetFlag[0][i6] | LIRESET[0]) AFR_A[i6][31:28]<=4'b0000;
			else if (MemFSelNode[0][i6]) AFR_A[i6][31:28]<=DTi[31:28] & {4{ContextLoadFlag[0]}};
				else if (LIFlag[0][i6]) AFR_A[i6][31:28]<=AFR_A[i6][31:28]+4'd1;
		if (LIResetFlag[1][i6] | LIRESET[1]) AFR_B[i6][31:28]<=4'b0000;
			else if (MemFSelNode[1][i6]) AFR_B[i6][31:28]<=DTi[31:28] & {4{ContextLoadFlag[1]}};
				else if (LIFlag[1][i6]) AFR_B[i6][31:28]<=AFR_B[i6][31:28]+4'd1;

		// GPR Bits 7:0
		if (GPRByteNode[0][i6]) GPR_A[i6][7:0]<=(FADDR[7:0] & {8{FADDSelNode[0][i6]}})|
											(FMULR[7:0] & {8{FMULSelNode[0][i6]}})|
											(FMULRQ[7:0] & {8{FMULQSelNode[0][i6]}})|
											(FMULACCR[7:0] & {8{FMULACCSelNode[0][i6]}})|
											(FDIVR[7:0] & {8{FDIVSelNode[0][i6]}})|
											(ALUR[7:0] & {8{ALUSelNode[0][i6]}})|
											(ShiftR[7:0] & {8{ShiftSelNode[0][i6]}})|
											(MiscR[0][7:0] & {8{MiscSelNode[0][i6]}})|
											(MovReg[0][7:0] & {8{MovSelNode[0][i6]}})|
											(DTi[7:0] & {8{MemSelNode[0][i6]}})|
											(ARData[0][7:0] & {8{MemARSelNode[0][i6]}});
		if (GPRByteNode[1][i6]) GPR_B[i6][7:0]<=(FADDR[7:0] & {8{FADDSelNode[1][i6]}})|
											(FMULR[7:0] & {8{FMULSelNode[1][i6]}})|
											(FMULRQ[7:0] & {8{FMULQSelNode[1][i6]}})|
											(FMULACCR[7:0] & {8{FMULACCSelNode[1][i6]}})|
											(FDIVR[7:0] & {8{FDIVSelNode[1][i6]}})|
											(ALUR[7:0] & {8{ALUSelNode[1][i6]}})|
											(ShiftR[7:0] & {8{ShiftSelNode[1][i6]}})|
											(MiscR[1][7:0] & {8{MiscSelNode[1][i6]}})|
											(MovReg[1][7:0] & {8{MovSelNode[1][i6]}})|
											(DTi[7:0] & {8{MemSelNode[1][i6]}})|
											(ARData[1][7:0] & {8{MemARSelNode[1][i6]}});
		// GPR Bits 15:8
		if (GPRWordNode[0][i6]) GPR_A[i6][15:8]<=(FADDR[15:8] & {8{FADDSelNode[0][i6]}})|
											(FMULR[15:8] & {8{FMULSelNode[0][i6]}})|
											(FMULRQ[15:8] & {8{FMULQSelNode[0][i6]}})|
											(FMULACCR[15:8] & {8{FMULACCSelNode[0][i6]}})|
											(FDIVR[15:8] & {8{FDIVSelNode[0][i6]}})|
											(ALUR[15:8] & {8{ALUSelNode[0][i6]}})|
											(ShiftR[15:8] & {8{ShiftSelNode[0][i6]}})|
											(MiscR[0][15:8] & {8{MiscSelNode[0][i6]}})|
											(MovReg[0][15:8] & {8{MovSelNode[0][i6]}})|
											(DTi[15:8] & {8{MemSelNode[0][i6]}})|
											(ARData[0][15:8] & {8{MemARSelNode[0][i6]}});
		if (GPRWordNode[1][i6]) GPR_B[i6][15:8]<=(FADDR[15:8] & {8{FADDSelNode[1][i6]}})|
											(FMULR[15:8] & {8{FMULSelNode[1][i6]}})|
											(FMULRQ[15:8] & {8{FMULQSelNode[1][i6]}})|
											(FMULACCR[15:8] & {8{FMULACCSelNode[1][i6]}})|
											(FDIVR[15:8] & {8{FDIVSelNode[1][i6]}})|
											(ALUR[15:8] & {8{ALUSelNode[1][i6]}})|
											(ShiftR[15:8] & {8{ShiftSelNode[1][i6]}})|
											(MiscR[1][15:8] & {8{MiscSelNode[1][i6]}})|
											(MovReg[1][15:8] & {8{MovSelNode[1][i6]}})|
											(DTi[15:8] & {8{MemSelNode[1][i6]}})|
											(ARData[1][15:8] & {8{MemARSelNode[1][i6]}});

		if (GPRDwordNode[0][i6]) GPR_A[i6][31:16]<=(FADDR[31:16] & {16{FADDSelNode[0][i6]}})|
											(FMULR[31:16] & {16{FMULSelNode[0][i6]}})|
											(FMULRQ[31:16] & {16{FMULQSelNode[0][i6]}})|
											(FMULACCR[31:16] & {16{FMULACCSelNode[0][i6]}})|
											(FDIVR[31:16] & {16{FDIVSelNode[0][i6]}})|
											(ALUR[31:16] & {16{ALUSelNode[0][i6]}})|
											(ShiftR[31:16] & {16{ShiftSelNode[0][i6]}})|
											(MiscR[0][31:16] & {16{MiscSelNode[0][i6]}})|
											(MovReg[0][31:16] & {16{MovSelNode[0][i6]}})|
											(DTi[31:16] & {16{MemSelNode[0][i6]}})|
											(ARData[0][31:16] & {16{MemARSelNode[0][i6]}});
		if (GPRDwordNode[1][i6]) GPR_B[i6][31:16]<=(FADDR[31:16] & {16{FADDSelNode[1][i6]}})|
											(FMULR[31:16] & {16{FMULSelNode[1][i6]}})|
											(FMULRQ[31:16] & {16{FMULQSelNode[1][i6]}})|
											(FMULACCR[31:16] & {16{FMULACCSelNode[1][i6]}})|
											(FDIVR[31:16] & {16{FDIVSelNode[1][i6]}})|
											(ALUR[31:16] & {16{ALUSelNode[1][i6]}})|
											(ShiftR[31:16] & {16{ShiftSelNode[1][i6]}})|
											(MiscR[1][31:16] & {16{MiscSelNode[1][i6]}})|
											(MovReg[1][31:16] & {16{MovSelNode[1][i6]}})|
											(DTi[31:16] & {16{MemSelNode[1][i6]}})|
											(ARData[1][31:16] & {16{MemARSelNode[1][i6]}});

		if (GPRQwordNode[0][i6]) GPR_A[i6][63:32]<=(FADDR[63:32] & {32{FADDSelNode[0][i6]}})|
											(FMULR[63:32] & {32{FMULSelNode[0][i6]}})|
											(FMULRQ[63:32] & {32{FMULQSelNode[0][i6]}})|
											(FDIVR[63:32] & {32{FDIVSelNode[0][i6]}})|
											(ALUR[63:32] & {32{ALUSelNode[0][i6]}})|
											(ShiftR[63:32] & {32{ShiftSelNode[0][i6]}})|
											(MiscR[0][63:32] & {32{MiscSelNode[0][i6]}})|
											(MovReg[0][63:32] & {32{MovSelNode[0][i6]}})|
											(DTi[63:32] & {32{MemSelNode[0][i6]}})|
											(ARData[0][36:32] & {32{MemARSelNode[0][i6]}});
		if (GPRQwordNode[1][i6]) GPR_B[i6][63:32]<=(FADDR[63:32] & {32{FADDSelNode[1][i6]}})|
											(FMULR[63:32] & {32{FMULSelNode[1][i6]}})|
											(FMULRQ[63:32] & {32{FMULQSelNode[1][i6]}})|
											(FDIVR[63:32] & {32{FDIVSelNode[1][i6]}})|
											(ALUR[63:32] & {32{ALUSelNode[1][i6]}})|
											(ShiftR[63:32] & {32{ShiftSelNode[1][i6]}})|
											(MiscR[1][63:32] & {32{MiscSelNode[1][i6]}})|
											(MovReg[1][63:32] & {32{MovSelNode[1][i6]}})|
											(DTi[63:32] & {32{MemSelNode[1][i6]}})|
											(ARData[1][36:32] & {32{MemARSelNode[1][i6]}});
		
		if (GPROwordNode[0][i6]) GPR_A[i6][127:64]<=(MovReg[0][127:64] & {64{MovSelNode[0][i6]}})|
											(DTi & {64{MemSelNode[0][i6]}})|
											(FMULRQ[127:64] & {64{FMULQSelNode[0][i6]}})|
											(FDIVR[127:64] & {64{FDIVSelNode[0][i6]}})|
											(FADDR[127:64] & {64{FADDSelNode[0][i6]}}) |
											(MiscR[0][127:64] & {64{MiscSelNode[0][i6]}});
		if (GPROwordNode[1][i6]) GPR_B[i6][127:64]<=(MovReg[1][127:64] & {64{MovSelNode[1][i6]}})|
											(DTi & {64{MemSelNode[1][i6]}})|
											(FMULRQ[127:64] & {64{FMULQSelNode[1][i6]}})|
											(FDIVR[127:64] & {64{FDIVSelNode[1][i6]}})|
											(FADDR[127:64] & {64{FADDSelNode[1][i6]}}) |
											(MiscR[1][127:64] & {64{MiscSelNode[1][i6]}});
		end

//=================================================================================================
// FADD Channel
	if (FADDInstBus[1][0] | FADDInstBus[0][0]) FADDSelFlag<=FADDSel;
	FADDInstReg<=FADDSel ? FADDInstBus[1] : FADDInstBus[0];
	FADDACTReg<=FADDInstReg[0];
	FADDCMDReg<=FADDInstReg[1];
	FADDBypassAReg[0]<=FADDRDYR & (FADDDSTR=={FADDSel, FADDSel ? FADDInstBus[1][5:2] : FADDInstBus[0][5:2]});
	FADDBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FADDSel, FADDSel ? FADDInstBus[1][5:2] : FADDInstBus[0][5:2]});
	FADDBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FADDSel, FADDSel ? FADDInstBus[1][5:2] : FADDInstBus[0][5:2]});
	FADDBypassAReg[3]<=ALURDYR & (ALUDSTR=={FADDSel, FADDSel ? FADDInstBus[1][5:2] : FADDInstBus[0][5:2]});
	FADDBypassAReg[4]<=ShiftRDYR & (ShiftDSTR=={FADDSel, FADDSel ? FADDInstBus[1][5:2] : FADDInstBus[0][5:2]});
	FADDBypassAReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FADDInstBus[0][5:2]) & ~FADDSel;
	FADDBypassAReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FADDInstBus[1][5:2]) & FADDSel;
	FADDAReg<=(GPR_A[FADDInstReg[5:2]] & {128{~(|FADDBypassAReg) & ~FADDSelFlag}}) |
				(GPR_B[FADDInstReg[5:2]] & {128{~(|FADDBypassAReg) & FADDSelFlag}}) |
				(FADDR & {128{FADDBypassAReg[0]}}) |
				({64'd0, FMULR & {64{FADDBypassAReg[1]}}}) |
				(FMULRQ & {128{FADDBypassAReg[2]}}) |
				({GPR_A[FADDInstReg[5:2]][127:64], ALUR} & {128{FADDBypassAReg[3] & ~FADDSelFlag}}) |
				({GPR_B[FADDInstReg[5:2]][127:64], ALUR} & {128{FADDBypassAReg[3] & FADDSelFlag}}) |
				({GPR_A[FADDInstReg[5:2]][127:64], ShiftR} & {128{FADDBypassAReg[4] & ~FADDSelFlag}}) |
				({GPR_B[FADDInstReg[5:2]][127:64], ShiftR} & {128{FADDBypassAReg[4] & FADDSelFlag}}) |
				(MiscR[0] & {128{FADDBypassAReg[5]}}) |
				(MiscR[1] & {128{FADDBypassAReg[6]}});
	FADDSAReg<=(AFR_A[FADDInstReg[5:2]][24:22] & {3{~(|FADDBypassAReg) & ~FADDSelFlag}}) |
				(AFR_B[FADDInstReg[5:2]][24:22] & {3{~(|FADDBypassAReg) & FADDSelFlag}}) |
				(FADDSR & {3{FADDBypassAReg[0]}})|
				({2'd1, FMULSR} & {3{FADDBypassAReg[1]}})|
				({FADDBypassAReg[2], 2'd0}) |
				({1'b0, ALUSRReg & {2{FADDBypassAReg[3]}}})|
				({1'b0, ShiftSRReg & {2{FADDBypassAReg[4]}}})|
				(MiscSRReg[0] & {3{FADDBypassAReg[5]}})|
				(MiscSRReg[1] & {3{FADDBypassAReg[6]}});
	FADDBypassBReg[0]<=FADDRDYR & (FADDDSTR=={FADDSel, FADDSel ? FADDInstBus[1][9:6] : FADDInstBus[0][9:6]});
	FADDBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FADDSel, FADDSel ? FADDInstBus[1][9:6] : FADDInstBus[0][9:6]});
	FADDBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FADDSel, FADDSel ? FADDInstBus[1][9:6] : FADDInstBus[0][9:6]});
	FADDBypassBReg[3]<=ALURDYR & (ALUDSTR=={FADDSel, FADDSel ? FADDInstBus[1][9:6] : FADDInstBus[0][9:6]});
	FADDBypassBReg[4]<=ShiftRDYR & (ShiftDSTR=={FADDSel, FADDSel ? FADDInstBus[1][9:6] : FADDInstBus[0][9:6]});
	FADDBypassBReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FADDInstBus[0][9:6]) & ~FADDSel;
	FADDBypassBReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FADDInstBus[1][9:6]) & FADDSel;
	FADDBReg<=(GPR_A[FADDInstReg[9:6]] & {128{~(|FADDBypassBReg) & ~FADDSelFlag}}) |
				(GPR_B[FADDInstReg[9:6]] & {128{~(|FADDBypassBReg) & FADDSelFlag}}) |
				(FADDR & {128{FADDBypassBReg[0]}}) |
				({64'd0, FMULR & {64{FADDBypassBReg[1]}}}) |
				(FMULRQ & {128{FADDBypassBReg[2]}}) |
				({GPR_A[FADDInstReg[9:6]][127:64], ALUR} & {128{FADDBypassBReg[3] & ~FADDSelFlag}}) |
				({GPR_B[FADDInstReg[9:6]][127:64], ALUR} & {128{FADDBypassBReg[3] & FADDSelFlag}}) |
				({GPR_A[FADDInstReg[9:6]][127:64], ShiftR} & {128{FADDBypassBReg[4] & ~FADDSelFlag}}) |
				({GPR_B[FADDInstReg[9:6]][127:64], ShiftR} & {128{FADDBypassBReg[4] & FADDSelFlag}}) |
				(MiscR[0] & {128{FADDBypassBReg[5]}}) |
				(MiscR[1] & {128{FADDBypassBReg[6]}});
	FADDSBReg<=(AFR_A[FADDInstReg[9:6]][24:22] & {3{~(|FADDBypassBReg) & ~FADDSelFlag}})|
				(AFR_B[FADDInstReg[9:6]][24:22] & {3{~(|FADDBypassBReg) & FADDSelFlag}})|
				(FADDSR & {3{FADDBypassBReg[0]}})|
				({2'd1, FMULSR} & {3{FADDBypassBReg[1]}})|
				({FADDBypassBReg[2], 2'd0}) |
				({1'b0, ALUSRReg & {2{FADDBypassBReg[3]}}})|
				({1'b0, ShiftSRReg & {2{FADDBypassBReg[4]}}})|
				(MiscSRReg[0] & {3{FADDBypassBReg[5]}})|
				(MiscSRReg[1] & {3{FADDBypassBReg[6]}});
	FADDDSTReg<={FADDSelFlag, FADDInstReg[13:10]};
	
//=================================================================================================
// FMUL channel
	if (FMULInstBus[1][0] | FMULInstBus[0][0]) FMULSelFlag<=FMULSel;
	FMULInstReg<=FMULSel ? FMULInstBus[1] : FMULInstBus[0];
	FMULACTReg<=FMULInstReg[0];
	FMULBypassAReg[0]<=FADDRDYR & (FADDDSTR=={FMULSel, FMULSel ? FMULInstBus[1][4:1] : FMULInstBus[0][4:1]});
	FMULBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FMULSel, FMULSel ? FMULInstBus[1][4:1] : FMULInstBus[0][4:1]});
	FMULBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FMULSel, FMULSel ? FMULInstBus[1][4:1] : FMULInstBus[0][4:1]});
	FMULBypassAReg[3]<=ALURDYR & (ALUDSTR=={FMULSel, FMULSel ? FMULInstBus[1][4:1] : FMULInstBus[0][4:1]});
	FMULBypassAReg[4]<=ShiftRDYR & (ShiftDSTR=={FMULSel, FMULSel ? FMULInstBus[1][4:1] : FMULInstBus[0][4:1]});
	FMULBypassAReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FMULInstBus[0][4:1]) & ~FMULSel;
	FMULBypassAReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FMULInstBus[1][4:1]) & FMULSel;
	FMULAReg<=(GPR_A[FMULInstReg[4:1]] & {128{~(|FMULBypassAReg) & ~FMULSelFlag}}) |
				(GPR_B[FMULInstReg[4:1]] & {128{~(|FMULBypassAReg) & FMULSelFlag}}) |
				(FADDR & {128{FMULBypassAReg[0]}}) |
				({64'd0, FMULR & {64{FMULBypassAReg[1]}}}) |
				(FMULRQ & {128{FMULBypassAReg[2]}}) |
				({GPR_A[FMULInstReg[4:1]][127:64], ALUR} & {128{FMULBypassAReg[3] & ~FMULSelFlag}}) |
				({GPR_B[FMULInstReg[4:1]][127:64], ALUR} & {128{FMULBypassAReg[3] & FMULSelFlag}}) |
				({GPR_A[FMULInstReg[4:1]][127:64], ShiftR} & {128{FMULBypassAReg[4] & ~FMULSelFlag}}) |
				({GPR_B[FMULInstReg[4:1]][127:64], ShiftR} & {128{FMULBypassAReg[4] & FMULSelFlag}}) |
				(MiscR[0] & {128{FMULBypassAReg[5]}}) |
				(MiscR[1] & {128{FMULBypassAReg[6]}});
	FMULSAReg<=(AFR_A[FMULInstReg[4:1]][24:22] & {3{~(|FMULBypassAReg) & ~FMULSelFlag}}) |
				(AFR_B[FMULInstReg[4:1]][24:22] & {3{~(|FMULBypassAReg) & FMULSelFlag}}) |
				(FADDSR & {3{FMULBypassAReg[0]}})|
				({2'd1, FMULSR} & {3{FMULBypassAReg[1]}})|
				({FMULBypassAReg[2], 2'd0}) |
				({1'b0, ALUSRReg & {2{FMULBypassAReg[3]}}})|
				({1'b0, ShiftSRReg & {2{FMULBypassAReg[4]}}})|
				(MiscSRReg[0] & {3{FMULBypassAReg[5]}})|
				(MiscSRReg[1] & {3{FMULBypassAReg[6]}});
	FMULBypassBReg[0]<=FADDRDYR & (FADDDSTR=={FMULSel, FMULSel ? FMULInstBus[1][8:5] : FMULInstBus[0][8:5]});
	FMULBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FMULSel, FMULSel ? FMULInstBus[1][8:5] : FMULInstBus[0][8:5]});
	FMULBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FMULSel, FMULSel ? FMULInstBus[1][8:5] : FMULInstBus[0][8:5]});
	FMULBypassBReg[3]<=ALURDYR & (ALUDSTR=={FMULSel, FMULSel ? FMULInstBus[1][8:5] : FMULInstBus[0][8:5]});
	FMULBypassBReg[4]<=ShiftRDYR & (ShiftDSTR=={FMULSel, FMULSel ? FMULInstBus[1][8:5] : FMULInstBus[0][8:5]});
	FMULBypassBReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FMULInstBus[0][8:5]) & ~FMULSel;
	FMULBypassBReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FMULInstBus[1][8:5]) & FMULSel;
	FMULBReg<=(GPR_A[FMULInstReg[8:5]] & {128{~(|FMULBypassBReg) & ~FMULSelFlag}}) |
				(GPR_B[FMULInstReg[8:5]] & {128{~(|FMULBypassBReg) & FMULSelFlag}}) |
				(FADDR & {128{FMULBypassBReg[0]}}) |
				({64'd0, FMULR & {64{FMULBypassBReg[1]}}}) |
				(FMULRQ & {128{FMULBypassBReg[2]}}) |
				({GPR_A[FMULInstReg[8:5]][127:64], ALUR} & {128{FMULBypassBReg[3] & ~FMULSelFlag}}) |
				({GPR_B[FMULInstReg[8:5]][127:64], ALUR} & {128{FMULBypassBReg[3] & FMULSelFlag}}) |
				({GPR_A[FMULInstReg[8:5]][127:64], ShiftR} & {128{FMULBypassBReg[4] & ~FMULSelFlag}}) |
				({GPR_B[FMULInstReg[8:5]][127:64], ShiftR} & {128{FMULBypassBReg[4] & FMULSelFlag}}) |
				(MiscR[0] & {128{FMULBypassBReg[5]}}) |
				(MiscR[1] & {128{FMULBypassBReg[6]}});
	FMULSBReg<=(AFR_A[FMULInstReg[8:5]][24:22] & {3{~(|FMULBypassBReg) & ~FMULSelFlag}})|
				(AFR_B[FMULInstReg[8:5]][24:22] & {3{~(|FMULBypassBReg) & FMULSelFlag}})|
				(FADDSR & {3{FMULBypassBReg[0]}})|
				({2'd1, FMULSR} & {3{FMULBypassBReg[1]}})|
				({FMULBypassBReg[2], 2'd0}) |
				({1'b0, ALUSRReg & {2{FMULBypassBReg[3]}}})|
				({1'b0, ShiftSRReg & {2{FMULBypassBReg[4]}}})|
				(MiscSRReg[0] & {3{FMULBypassBReg[5]}})|
				(MiscSRReg[1] & {3{FMULBypassBReg[6]}});
	FMULDSTReg<={FMULSelFlag, FMULInstReg[12:9]};

//=================================================================================================
//							FMULACC Channel
//0 - ACT, 3:1 - ctrlSel, 7:4 - DST, 11:8 - CtrlOffsetReg, 15:12 - DataOffsetReg, 18:16 - DataSel, 19 - CMD 0-FMULLACC/1-FFT

	FMULACCReg[0]<=(FMULACCReg[0] | FMULACCBus[0][0] | FMULACCBus[1][0]) & (~FMULACCReg[0] | (FMULACCACTReg & ~FMULACCNEXT)) & RESET;
	if (~FMULACCReg[0])
		begin
		FMULACCReg[19:1]<=FMULACCSel ? FMULACCBus[1][19:1] : FMULACCBus[0][19:1];
		FMULACCSelFlag<=FMULACCSel;
		end
	
	FMULACCACTReg<=((FMULACCACTReg & ~FMULACCNEXT) | FMULACCReg[0]) & RESET;
	
	FFT32NEXTReg<=FFT32NEXT;
	
	FFTBypassReg[0]<=FADDRDYR & (FADDDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][7:4] : FMULACCBus[0][7:4]});
	FFTBypassReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][7:4] : FMULACCBus[0][7:4]});
	FFTBypassReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][7:4] : FMULACCBus[0][7:4]});
	FFTBypassReg[3]<=ALURDYR & (ALUDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][7:4] : FMULACCBus[0][7:4]});
	FFTBypassReg[4]<=ShiftRDYR & (ShiftDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][7:4] : FMULACCBus[0][7:4]});
	FFTBypassReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FMULACCBus[0][7:4]) & ~FMULACCSel;
	FFTBypassReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FMULACCBus[1][7:4]) & FMULACCSel;

	FMULACCBypassControlOffsetReg[0]<=FADDRDYR & (FADDDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][11:8] : FMULACCBus[0][11:8]});
	FMULACCBypassControlOffsetReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][11:8] : FMULACCBus[0][11:8]});
	FMULACCBypassControlOffsetReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][11:8] : FMULACCBus[0][11:8]});
	FMULACCBypassControlOffsetReg[3]<=ALURDYR & (ALUDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][11:8] : FMULACCBus[0][11:8]});
	FMULACCBypassControlOffsetReg[4]<=ShiftRDYR & (ShiftDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][11:8] : FMULACCBus[0][11:8]});
	FMULACCBypassControlOffsetReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FMULACCBus[0][11:8]) & ~FMULACCSel;
	FMULACCBypassControlOffsetReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FMULACCBus[1][11:8]) & FMULACCSel;

	FMULACCBypassDataOffsetReg[0]<=FADDRDYR & (FADDDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][15:12] : FMULACCBus[0][15:12]});
	FMULACCBypassDataOffsetReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][15:12] : FMULACCBus[0][15:12]});
	FMULACCBypassDataOffsetReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FMULACCSel, FMULACCSel ? FMULACCBus[1][15:12] : FMULACCBus[0][15:12]});
	FMULACCBypassDataOffsetReg[3]<=ALURDYR & (ALUDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][15:12] : FMULACCBus[0][15:12]});
	FMULACCBypassDataOffsetReg[4]<=ShiftRDYR & (ShiftDSTR=={FMULACCSel, FMULACCSel ? FMULACCBus[1][15:12] : FMULACCBus[0][15:12]});
	FMULACCBypassDataOffsetReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FMULACCBus[0][15:12]) & ~FMULACCSel;
	FMULACCBypassDataOffsetReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FMULACCBus[1][15:12]) & FMULACCSel;

	if (FMULACCNEXT | ~FMULACCACTReg)
		begin
		FMULACCDSTReg<={FMULACCSelFlag, FMULACCReg[7:4]};
		FMULACCCtrlSelReg<={FMULACCSelFlag, FMULACCReg[3:1]};
		FMULACCDataSelReg<={FMULACCSelFlag, FMULACCReg[18:16]};
		
		FMULACCCMDReg<=FMULACCReg[19];
		
		FMULACCSelReg<=FMULACCSelFlag;
		
		FFTCtrlBaseReg<=FMULACCSelFlag ? ADR_B[{FMULACCReg[3:1],1'b0}][36:3] : ADR_A[{FMULACCReg[3:1],1'b0}][36:3];
		FFTDataBaseReg<=FMULACCSelFlag ? ADR_B[{FMULACCReg[18:16],1'b0}][36:3] : ADR_A[{FMULACCReg[18:16],1'b0}][36:3];
		FFTCtrlSelReg<=FMULACCSelFlag ? ADR_B[{FMULACCReg[3:1],1'b1}][31:0] : ADR_A[{FMULACCReg[3:1],1'b1}][31:0];
		FFTDataSelReg<=FMULACCSelFlag ? ADR_B[{FMULACCReg[18:16],1'b1}][31:0] : ADR_A[{FMULACCReg[18:16],1'b1}][31:0];
		
		FFTParReg<=(GPR_A[FMULACCReg[7:4]][4:0] & {5{~(|FFTBypassReg) & ~FMULACCSelFlag}})|
					(GPR_B[FMULACCReg[7:4]][4:0] & {5{~(|FFTBypassReg) & FMULACCSelFlag}})|
					(FADDR[4:0] & {5{FFTBypassReg[0]}}) |
					(FMULR[4:0] & {5{FFTBypassReg[1]}}) |
					(FMULRQ[4:0] & {5{FFTBypassReg[2]}}) |
					(ALUR[4:0] & {5{FFTBypassReg[3]}}) |
					(ShiftR[4:0] & {5{FFTBypassReg[4]}}) |
					(MiscR[0][4:0] & {5{FFTBypassReg[5]}}) |
					(MiscR[1][4:0] & {5{FFTBypassReg[6]}});
					
		FFTIndexReg<=(GPR_A[FMULACCReg[7:4]][50:32] & {19{~(|FFTBypassReg) & ~FMULACCSelFlag}})|
					(GPR_B[FMULACCReg[7:4]][50:32] & {19{~(|FFTBypassReg) & FMULACCSelFlag}})|
					(FADDR[50:32] & {19{FFTBypassReg[0]}}) |
					(FMULR[50:32] & {19{FFTBypassReg[1]}}) |
					(FMULRQ[50:32] & {19{FFTBypassReg[2]}}) |
					(ALUR[50:32] & {19{FFTBypassReg[3]}}) |
					(ShiftR[50:32] & {19{FFTBypassReg[4]}}) |
					(MiscR[0][50:32] & {19{FFTBypassReg[5]}}) |
					(MiscR[1][50:32] & {19{FFTBypassReg[6]}});
		
		FMULACCCtrlOffsetReg<=(GPR_A[FMULACCReg[11:8]][36:3] & {34{~(|FMULACCBypassControlOffsetReg) & ~FMULACCSelFlag}})|
					(GPR_B[FMULACCReg[11:8]][36:3] & {34{~(|FMULACCBypassControlOffsetReg) & FMULACCSelFlag}})|
					(FADDR[36:3] & {34{FMULACCBypassControlOffsetReg[0]}}) |
					(FMULR[36:3] & {34{FMULACCBypassControlOffsetReg[1]}}) |
					(FMULRQ[36:3] & {34{FMULACCBypassControlOffsetReg[2]}}) |
					(ALUR[36:3] & {34{FMULACCBypassControlOffsetReg[3]}}) |
					(ShiftR[36:3] & {34{FMULACCBypassControlOffsetReg[4]}}) |
					(MiscR[0][36:3] & {34{FMULACCBypassControlOffsetReg[5]}}) |
					(MiscR[1][36:3] & {34{FMULACCBypassControlOffsetReg[6]}});
		
		FMULACCDataOffsetReg<=(GPR_A[FMULACCReg[15:12]][36:2] & {35{~(|FMULACCBypassDataOffsetReg) & ~FMULACCSelFlag}})|
					(GPR_B[FMULACCReg[15:12]][36:2] & {35{~(|FMULACCBypassDataOffsetReg) & FMULACCSelFlag}})|
					(FADDR[36:2] & {35{FMULACCBypassDataOffsetReg[0]}}) |
					(FMULR[36:2] & {35{FMULACCBypassDataOffsetReg[1]}}) |
					(FMULRQ[36:2] & {35{FMULACCBypassDataOffsetReg[2]}}) |
					(ALUR[36:2] & {35{FMULACCBypassDataOffsetReg[3]}}) |
					(ShiftR[36:2] & {35{FMULACCBypassDataOffsetReg[4]}}) |
					(MiscR[0][36:2] & {35{FMULACCBypassDataOffsetReg[5]}}) |
					(MiscR[1][36:2] & {35{FMULACCBypassDataOffsetReg[6]}});
		end
	FMULACCDRDYFlag<=DRDY & (TAGi[7:1]==7'b1100000);

//=================================================================================================
//FDIV channel
	FDIVInstReg[0]<=(FDIVInstReg[0] | FDIVInstBus[1][0] | FDIVInstBus[0][0]) & (~FDIVInstReg[0] | (FDIVACTReg & ~FDIVNEXT));
	if (~FDIVInstReg[0])
		begin
		FDIVInstReg[13:1]<=FDIVSel ? FDIVInstBus[1][13:1] : FDIVInstBus[0][13:1];
		FDIVSelFlag<=FDIVSel;
		end
	FDIVACTReg<=(FDIVACTReg & ~FDIVNEXT) | FDIVInstReg[0];
	
	FDIVBypassAReg[0]<=FADDRDYR & (FADDDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][4:1] : FDIVInstBus[0][4:1]});
	FDIVBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FDIVSel, FDIVSel ? FDIVInstBus[1][4:1] : FDIVInstBus[0][4:1]});
	FDIVBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FDIVSel, FDIVSel ? FDIVInstBus[1][4:1] : FDIVInstBus[0][4:1]});
	FDIVBypassAReg[3]<=ALURDYR & (ALUDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][4:1] : FDIVInstBus[0][4:1]});
	FDIVBypassAReg[4]<=ShiftRDYR & (ShiftDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][4:1] : FDIVInstBus[0][4:1]});
	FDIVBypassAReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FDIVInstBus[0][4:1]) & ~FDIVSel;
	FDIVBypassAReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FDIVInstBus[1][4:1]) & FDIVSel;
	
	FDIVBypassBReg[0]<=FADDRDYR & (FADDDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][8:5] : FDIVInstBus[0][8:5]});
	FDIVBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={FDIVSel, FDIVSel ? FDIVInstBus[1][8:5] : FDIVInstBus[0][8:5]});
	FDIVBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={FDIVSel, FDIVSel ? FDIVInstBus[1][8:5] : FDIVInstBus[0][8:5]});
	FDIVBypassBReg[3]<=ALURDYR & (ALUDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][8:5] : FDIVInstBus[0][8:5]});
	FDIVBypassBReg[4]<=ShiftRDYR & (ShiftDSTR=={FDIVSel, FDIVSel ? FDIVInstBus[1][8:5] : FDIVInstBus[0][8:5]});
	FDIVBypassBReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==FDIVInstBus[0][8:5]) & ~FDIVSel;
	FDIVBypassBReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==FDIVInstBus[1][8:5]) & FDIVSel;
	
	if (FDIVNEXT | ~FDIVACTReg)
		begin
		FDIVAReg<=(GPR_A[FDIVInstReg[4:1]] & {128{~(|FDIVBypassAReg) & ~FDIVSelFlag}})|
					(GPR_B[FDIVInstReg[4:1]] & {128{~(|FDIVBypassAReg) & FDIVSelFlag}})|
					(FADDR & {128{FDIVBypassAReg[0]}}) |
					({64'd0, FMULR & {64{FDIVBypassAReg[1]}}}) |
					(FMULRQ & {128{FDIVBypassAReg[2]}}) |
					({GPR_A[FDIVInstReg[4:1]][127:64], ALUR} & {128{FDIVBypassAReg[3] & ~FDIVSelFlag}}) |
					({GPR_B[FDIVInstReg[4:1]][127:64], ALUR} & {128{FDIVBypassAReg[3] & FDIVSelFlag}}) |
					({GPR_A[FDIVInstReg[4:1]][127:64], ShiftR} & {128{FDIVBypassAReg[4] & ~FDIVSelFlag}}) |
					({GPR_B[FDIVInstReg[4:1]][127:64], ShiftR} & {128{FDIVBypassAReg[4] & FDIVSelFlag}}) |
					(MiscR[0] & {128{FDIVBypassAReg[5]}}) |
					(MiscR[1] & {128{FDIVBypassAReg[6]}});
		FDIVSAReg<=(AFR_A[FDIVInstReg[4:1]][24:22] & {3{~(|FDIVBypassAReg) & ~FDIVSelFlag}})|
					(AFR_B[FDIVInstReg[4:1]][24:22] & {3{~(|FDIVBypassAReg) & FDIVSelFlag}})|
					(FADDSR & {3{FDIVBypassAReg[0]}})|
					({2'd1, FMULSR} & {3{FDIVBypassAReg[1]}})|
					({FDIVBypassAReg[2], 2'd0}) |
					({1'b0, ALUSRReg & {2{FDIVBypassAReg[3]}}})|
					({1'b0, ShiftSRReg & {2{FDIVBypassAReg[4]}}})|
					(MiscSRReg[0] & {3{FDIVBypassAReg[5]}})|
					(MiscSRReg[1] & {3{FDIVBypassAReg[6]}});
		FDIVBReg<=(GPR_A[FDIVInstReg[8:5]] & {128{~(|FDIVBypassBReg) & ~FDIVSelFlag}})|
					(GPR_B[FDIVInstReg[8:5]] & {128{~(|FDIVBypassBReg) & FDIVSelFlag}})|
					(FADDR & {128{FDIVBypassBReg[0]}}) |
					({64'd0, FMULR & {64{FDIVBypassBReg[1]}}}) |
					(FMULRQ & {128{FDIVBypassBReg[2]}}) |
					({GPR_A[FDIVInstReg[8:5]][127:64], ALUR} & {128{FDIVBypassBReg[3] & ~FDIVSelFlag}}) |
					({GPR_B[FDIVInstReg[8:5]][127:64], ALUR} & {128{FDIVBypassBReg[3] & FDIVSelFlag}}) |
					({GPR_A[FDIVInstReg[8:5]][127:64], ShiftR} & {128{FDIVBypassBReg[4] & ~FDIVSelFlag}}) |
					({GPR_B[FDIVInstReg[8:5]][127:64], ShiftR} & {128{FDIVBypassBReg[4] & FDIVSelFlag}}) |
					(MiscR[0] & {128{FDIVBypassBReg[5]}}) |
					(MiscR[1] & {128{FDIVBypassBReg[6]}});
		FDIVSBReg<=(AFR_A[FDIVInstReg[8:5]][24:22] & {3{~(|FDIVBypassBReg) & ~FDIVSelFlag}})|
					(AFR_B[FDIVInstReg[8:5]][24:22] & {3{~(|FDIVBypassBReg) & FDIVSelFlag}})|
					(FADDSR & {3{FDIVBypassBReg[0]}})|
					({2'd1, FMULSR} & {3{FDIVBypassBReg[1]}})|
					({FDIVBypassBReg[2], 2'd0}) |
					({1'b0, ALUSRReg & {2{FDIVBypassBReg[3]}}})|
					({1'b0, ShiftSRReg & {2{FDIVBypassBReg[4]}}})|
					(MiscSRReg[0] & {3{FDIVBypassBReg[5]}})|
					(MiscSRReg[1] & {3{FDIVBypassBReg[6]}});
		FDIVDSTReg<={FDIVSelFlag, FDIVInstReg[12:9]};
		FDIVCMDReg<=FDIVInstReg[13];
		end

//=================================================================================================
// ALU channel
	ALUInstReg<=ALUSel ? ALUInstBus[1] : ALUInstBus[0];
	if (ALUInstBus[1][0] | ALUInstBus[0][0]) ALUSelFlag<=ALUSel;
	ALUACTReg<=ALUInstReg[0];
	ALUOpCODEReg<={ALUInstReg[24], ALUInstReg[2:1]};

	ALUBypassAReg[0]<=FADDRDYR & (FADDDSTR=={ALUSel, ALUSel ? ALUInstBus[1][6:3] : ALUInstBus[0][6:3]});
	ALUBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ALUSel, ALUSel ? ALUInstBus[1][6:3] : ALUInstBus[0][6:3]});
	ALUBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ALUSel, ALUSel ? ALUInstBus[1][6:3] : ALUInstBus[0][6:3]});
	ALUBypassAReg[3]<=ALURDYR & (ALUDSTR=={ALUSel, ALUSel ? ALUInstBus[1][6:3] : ALUInstBus[0][6:3]});
	ALUBypassAReg[4]<=ShiftRDYR & (ShiftDSTR=={ALUSel, ALUSel ? ALUInstBus[1][6:3] : ALUInstBus[0][6:3]});
	ALUBypassAReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ALUInstBus[0][6:3]) & ~ALUSel;
	ALUBypassAReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ALUInstBus[1][6:3]) & ALUSel;

	ALUAReg<=ALUInstReg[15] ? {58'd0, ALUInstReg[8:3]} :
				((GPR_A[ALUInstReg[6:3]][63:0] & {64{~(|ALUBypassAReg) & ~ALUSelFlag}}) |
					(GPR_B[ALUInstReg[6:3]][63:0] & {64{~(|ALUBypassAReg) & ALUSelFlag}}) |
					(FADDR[63:0] & {64{ALUBypassAReg[0]}}) |
					(FMULR & {64{ALUBypassAReg[1]}}) |
					(FMULRQ[63:0] & {64{ALUBypassAReg[2]}}) |
					(ALUR & {64{ALUBypassAReg[3]}}) | 
					(ShiftR & {64{ALUBypassAReg[4]}}) | 
					(MiscR[0][63:0] & {64{ALUBypassAReg[5]}}) | 
					(MiscR[1][63:0] & {64{ALUBypassAReg[6]}}));

	ALUSAReg<=((AFR_A[ALUInstReg[6:3]][23:22] & {2{~(|ALUBypassAReg) & ~ALUSelFlag}}) |
				(AFR_B[ALUInstReg[6:3]][23:22] & {2{~(|ALUBypassAReg) & ALUSelFlag}}) |
				(FADDSR[1:0] & {2{ALUBypassAReg[0]}}) |
				({1'b1, FMULSR} & {2{ALUBypassAReg[1]}}) |
				(ALUSRReg & {2{ALUBypassAReg[3]}}) |
				(ShiftSRReg & {2{ALUBypassAReg[4]}}) |
				(MiscSRReg[0][1:0] & {2{ALUBypassAReg[5]}}) |
				(MiscSRReg[1][1:0] & {2{ALUBypassAReg[6]}})) & {2{~ALUInstReg[15]}};
	
	ALUBypassBReg[0]<=FADDRDYR & (FADDDSTR=={ALUSel, ALUSel ? ALUInstBus[1][10:7] : ALUInstBus[0][10:7]});
	ALUBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ALUSel, ALUSel ? ALUInstBus[1][10:7] : ALUInstBus[0][10:7]});
	ALUBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ALUSel, ALUSel ? ALUInstBus[1][10:7] : ALUInstBus[0][10:7]});
	ALUBypassBReg[3]<=ALURDYR & (ALUDSTR=={ALUSel, ALUSel ? ALUInstBus[1][10:7] : ALUInstBus[0][10:7]});
	ALUBypassBReg[4]<=ShiftRDYR & (ShiftDSTR=={ALUSel, ALUSel ? ALUInstBus[1][10:7] : ALUInstBus[0][10:7]});
	ALUBypassBReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ALUInstBus[0][10:7]) & ~ALUSel;
	ALUBypassBReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ALUInstBus[1][10:7]) & ALUSel;

	ALUBReg<=ALUInstReg[15] ? {58'd0, ALUInstReg[14:9]} : 
				((GPR_A[ALUInstReg[10:7]][63:0] & {64{~(|ALUBypassBReg) & ~ALUSelFlag}}) |
					(GPR_B[ALUInstReg[10:7]][63:0] & {64{~(|ALUBypassBReg) & ALUSelFlag}}) |
					(FADDR[63:0] & {64{ALUBypassBReg[0]}}) |
					(FMULR & {64{ALUBypassBReg[1]}}) |
					(FMULRQ[63:0] & {64{ALUBypassBReg[2]}}) |
					(ALUR & {64{ALUBypassBReg[3]}}) |
					(ShiftR & {64{ALUBypassBReg[4]}}) |
					(MiscR[0][63:0] & {64{ALUBypassBReg[5]}}) |
					(MiscR[1][63:0] & {64{ALUBypassBReg[6]}}));

	ALUSBReg<=((AFR_A[ALUInstReg[10:7]][23:22] & {2{~(|ALUBypassBReg) & ~ALUSelFlag}}) |
					(AFR_B[ALUInstReg[10:7]][23:22] & {2{~(|ALUBypassBReg) & ALUSelFlag}}) |
					(FADDSR[1:0] & {2{ALUBypassBReg[0]}}) |
					({1'b1, FMULSR} & {2{ALUBypassBReg[1]}}) |
					(ALUSRReg & {2{ALUBypassBReg[3]}}) |
					(ShiftSRReg & {2{ALUBypassBReg[4]}}) |
					(MiscSRReg[0][1:0] & {2{ALUBypassBReg[5]}}) |
					(MiscSRReg[1][1:0] & {2{ALUBypassBReg[6]}})) & {2{~ALUInstReg[15]}};

	ALUBypassCReg[0]<=FADDRDYR & (FADDDSTR=={ALUSel, ALUSel ? ALUInstBus[1][19:16] : ALUInstBus[0][19:16]});
	ALUBypassCReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ALUSel, ALUSel ? ALUInstBus[1][19:16] : ALUInstBus[0][19:16]});
	ALUBypassCReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ALUSel, ALUSel ? ALUInstBus[1][19:16] : ALUInstBus[0][19:16]});
	ALUBypassCReg[3]<=ALURDYR & (ALUDSTR=={ALUSel, ALUSel ? ALUInstBus[1][19:16] : ALUInstBus[0][19:16]});
	ALUBypassCReg[4]<=ShiftRDYR & (ShiftDSTR=={ALUSel, ALUSel ? ALUInstBus[1][19:16] : ALUInstBus[0][19:16]});
	ALUBypassCReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ALUInstBus[0][19:16]) & ~ALUSel;
	ALUBypassCReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ALUInstBus[1][19:16]) & ALUSel;

	ALUCReg<=(GPR_A[ALUInstReg[19:16]][63:0] & {64{~(|ALUBypassCReg) & ~ALUSelFlag}}) |
				(GPR_B[ALUInstReg[19:16]][63:0] & {64{~(|ALUBypassCReg) & ALUSelFlag}}) |
				(FADDR[63:0] & {64{ALUBypassCReg[0]}}) |
				(FMULR & {64{ALUBypassCReg[1]}}) |
				(FMULRQ[63:0] & {64{ALUBypassCReg[2]}}) |
				(ALUR & {64{ALUBypassCReg[3]}}) |
				(ShiftR & {64{ALUBypassCReg[4]}}) |
				(MiscR[0][63:0] & {64{ALUBypassCReg[5]}}) |
				(MiscR[1][63:0] & {64{ALUBypassCReg[6]}});

	ALUSCReg<=((AFR_A[ALUInstReg[19:16]][23:22] & {2{~(|ALUBypassCReg) & ~ALUSelFlag}}) |
					(AFR_B[ALUInstReg[19:16]][23:22] & {2{~(|ALUBypassCReg) & ALUSelFlag}}) |
					(FADDSR[1:0] & {2{ALUBypassCReg[0]}}) |
					({1'b1, FMULSR} & {2{ALUBypassCReg[1]}}) |
					(ALUSRReg & {2{ALUBypassCReg[3]}}) |
					(ShiftSRReg & {2{ALUBypassCReg[4]}}) |
					(MiscSRReg[0][1:0] & {2{ALUBypassCReg[5]}}) |
					(MiscSRReg[1][1:0] & {2{ALUBypassCReg[6]}})) & {2{ALUInstReg[24]}};

	ALUBypassDReg[0]<=FADDRDYR & (FADDDSTR=={ALUSel, ALUSel ? ALUInstBus[1][23:20] : ALUInstBus[0][23:20]});
	ALUBypassDReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ALUSel, ALUSel ? ALUInstBus[1][23:20] : ALUInstBus[0][23:20]});
	ALUBypassDReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ALUSel, ALUSel ? ALUInstBus[1][23:20] : ALUInstBus[0][23:20]});
	ALUBypassDReg[3]<=ALURDYR & (ALUDSTR=={ALUSel, ALUSel ? ALUInstBus[1][23:20] : ALUInstBus[0][23:20]});
	ALUBypassDReg[4]<=ShiftRDYR & (ShiftDSTR=={ALUSel, ALUSel ? ALUInstBus[1][23:20] : ALUInstBus[0][23:20]});
	ALUBypassDReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ALUInstBus[0][23:20]) & ~ALUSel;
	ALUBypassDReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ALUInstBus[1][23:20]) & ALUSel;

	ALUDReg<=(GPR_A[ALUInstReg[23:20]][63:0] & {64{~(|ALUBypassDReg) & ~ALUSelFlag}}) |
				(GPR_B[ALUInstReg[23:20]][63:0] & {64{~(|ALUBypassDReg) & ALUSelFlag}}) |
				(FADDR[63:0] & {64{ALUBypassDReg[0]}}) |
				(FMULR & {64{ALUBypassDReg[1]}}) |
				(FMULRQ[63:0] & {64{ALUBypassDReg[2]}}) |
				(ALUR & {64{ALUBypassDReg[3]}}) |
				(ShiftR & {64{ALUBypassDReg[4]}}) |
				(MiscR[0][63:0] & {64{ALUBypassDReg[5]}}) |
				(MiscR[1][63:0] & {64{ALUBypassDReg[6]}});

	ALUSDReg<=((AFR_A[ALUInstReg[23:20]][23:22] & {2{~(|ALUBypassDReg) & ~ALUSelFlag}}) |
					(AFR_B[ALUInstReg[23:20]][23:22] & {2{~(|ALUBypassDReg) & ALUSelFlag}}) | 
					(FADDSR[1:0] & {2{ALUBypassDReg[0]}}) |
					({1'b1, FMULSR} & {2{ALUBypassDReg[1]}}) |
					(ALUSRReg & {2{ALUBypassDReg[3]}}) |
					(ShiftSRReg & {2{ALUBypassDReg[4]}}) |
					(MiscSRReg[0][1:0] & {2{ALUBypassDReg[5]}}) |
					(MiscSRReg[1][1:0] & {2{ALUBypassDReg[6]}})) & {2{ALUInstReg[24]}};

	ALUDSTReg<={ALUSelFlag, ALUInstReg[24] ? ALUInstReg[23:20] : ALUInstReg[14:11]};

//=================================================================================================
// Shifter channel
	ShiftInstReg<=ShiftSel ? ShiftInstBus[1] : ShiftInstBus[0];
	if (ShiftInstBus[1][0] | ShiftInstBus[0][0]) ShiftSelFlag<=ShiftSel;
	
	ShiftACTReg<=ShiftInstReg[0];
	
	ShiftBypassAReg[0]<=FADDRDYR & (FADDDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][12:9] : ShiftInstBus[0][12:9]});
	ShiftBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ShiftSel, ShiftSel ? ShiftInstBus[1][12:9] : ShiftInstBus[0][12:9]});
	ShiftBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ShiftSel, ShiftSel ? ShiftInstBus[1][12:9] : ShiftInstBus[0][12:9]});
	ShiftBypassAReg[3]<=ALURDYR & (ALUDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][12:9] : ShiftInstBus[0][12:9]});
	ShiftBypassAReg[4]<=ShiftRDYR & (ShiftDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][12:9] : ShiftInstBus[0][12:9]});
	ShiftBypassAReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ShiftInstBus[0][12:9]) & ~ShiftSel;
	ShiftBypassAReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ShiftInstBus[1][12:9]) & ShiftSel;

	ShiftAReg<=(GPR_A[ShiftInstReg[12:9]][63:0] & {64{~(|ShiftBypassAReg) & ~ShiftSelFlag}}) |
				(GPR_B[ShiftInstReg[12:9]][63:0] & {64{~(|ShiftBypassAReg) & ShiftSelFlag}}) |
				(FADDR[63:0] & {64{ShiftBypassAReg[0]}}) |
				(FMULR & {64{ShiftBypassAReg[1]}}) | 
				(FMULRQ[63:0] & {64{ShiftBypassAReg[2]}}) |
				(ALUR & {64{ShiftBypassAReg[3]}}) |
				(ShiftR & {64{ShiftBypassAReg[4]}}) |
				(MiscR[0][63:0] & {64{ShiftBypassAReg[5]}}) |
				(MiscR[1][63:0] & {64{ShiftBypassAReg[6]}});

	ShiftSAReg<=(AFR_A[ShiftInstReg[12:9]][23:22] & {2{~(|ShiftBypassAReg) & ~ShiftSelFlag}}) |
				(AFR_B[ShiftInstReg[12:9]][23:22] & {2{~(|ShiftBypassAReg) & ShiftSelFlag}}) |
				(FADDSR[1:0] & {2{ShiftBypassAReg[0]}}) |
				({1'b1, FMULSR} & {2{ShiftBypassAReg[1]}}) |
				(ALUSRReg & {2{ShiftBypassAReg[3]}}) |
				(ShiftSRReg & {2{ShiftBypassAReg[4]}}) |
				(MiscSRReg[0][1:0] & {2{ShiftBypassAReg[5]}}) |
				(MiscSRReg[1][1:0] & {2{ShiftBypassAReg[6]}});

	ShiftBypassBReg[0]<=FADDRDYR & (FADDDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][8:5] : ShiftInstBus[0][8:5]});
	ShiftBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]=={ShiftSel, ShiftSel ? ShiftInstBus[1][8:5] : ShiftInstBus[0][8:5]});
	ShiftBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]=={ShiftSel, ShiftSel ? ShiftInstBus[1][8:5] : ShiftInstBus[0][8:5]});
	ShiftBypassBReg[3]<=ALURDYR & (ALUDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][8:5] : ShiftInstBus[0][8:5]});
	ShiftBypassBReg[4]<=ShiftRDYR & (ShiftDSTR=={ShiftSel, ShiftSel ? ShiftInstBus[1][8:5] : ShiftInstBus[0][8:5]});
	ShiftBypassBReg[5]<=MiscRDYR[0] & (MiscDSTR[0]==ShiftInstBus[0][8:5]) & ~ShiftSel;
	ShiftBypassBReg[6]<=MiscRDYR[1] & (MiscDSTR[1]==ShiftInstBus[1][8:5]) & ShiftSel;

	ShiftBReg<=ShiftInstReg[4] ? ((GPR_A[ShiftInstReg[8:5]][5:0] & {6{~(|ShiftBypassBReg) & ~ShiftSelFlag}}) | 
								(GPR_B[ShiftInstReg[8:5]][5:0] & {6{~(|ShiftBypassBReg) & ShiftSelFlag}}) | 
								(FADDR[5:0] & {6{ShiftBypassBReg[0]}}) |
								(FMULR[5:0] & {6{ShiftBypassBReg[1]}}) | 
								(FMULRQ[5:0] & {6{ShiftBypassBReg[2]}}) |
								(ALUR[5:0] & {6{ShiftBypassBReg[3]}}) |
								(ShiftR[5:0] & {6{ShiftBypassBReg[4]}}) |
								(MiscR[0][5:0] & {6{ShiftBypassBReg[5]}}) |
								(MiscR[1][5:0] & {6{ShiftBypassBReg[6]}})) : {2'b00, ShiftInstReg[8:5]};							

	ShiftDSTReg<={ShiftSelFlag, ShiftInstReg[12:9]};
	ShiftOPRReg<=ShiftInstReg[3:1];

//=================================================================================================
// miscellaneous operations channel
	MiscInstReg[0]<=MiscInstBus[0];
	MiscInstReg[1]<=MiscInstBus[1];
	MiscACTReg[0]<=MiscInstReg[0][0];
	MiscACTReg[1]<=MiscInstReg[1][0];
	
	MiscBypassAReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, MiscInstBus[0][7:4]});
	MiscBypassAReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, MiscInstBus[0][7:4]});
	MiscBypassAReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, MiscInstBus[0][7:4]});
	MiscBypassAReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, MiscInstBus[0][7:4]});
	MiscBypassAReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, MiscInstBus[0][7:4]});
	MiscBypassAReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==MiscInstBus[0][7:4]);
	
	MiscBypassAReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, MiscInstBus[1][7:4]});
	MiscBypassAReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, MiscInstBus[1][7:4]});
	MiscBypassAReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, MiscInstBus[1][7:4]});
	MiscBypassAReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, MiscInstBus[1][7:4]});
	MiscBypassAReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, MiscInstBus[1][7:4]});
	MiscBypassAReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==MiscInstBus[1][7:4]);

	MiscBypassBReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, MiscInstBus[0][11:8]});
	MiscBypassBReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, MiscInstBus[0][11:8]});
	MiscBypassBReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, MiscInstBus[0][11:8]});
	MiscBypassBReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, MiscInstBus[0][11:8]});
	MiscBypassBReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, MiscInstBus[0][11:8]});
	MiscBypassBReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==MiscInstBus[0][11:8]);

	MiscBypassBReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, MiscInstBus[1][11:8]});
	MiscBypassBReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, MiscInstBus[1][11:8]});
	MiscBypassBReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, MiscInstBus[1][11:8]});
	MiscBypassBReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, MiscInstBus[1][11:8]});
	MiscBypassBReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, MiscInstBus[1][11:8]});
	MiscBypassBReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==MiscInstBus[1][11:8]);
	
	MiscCINReg[0]<=(AFR_A[MiscInstReg[0][11:8]][15:0] & {16{~MiscBypassBReg[0][3]}}) | (ALUCOUT & {16{MiscBypassBReg[0][3]}});
	MiscCINReg[1]<=(AFR_B[MiscInstReg[1][11:8]][15:0] & {16{~MiscBypassBReg[1][3]}}) | (ALUCOUT & {16{MiscBypassBReg[1][3]}});

	MiscAReg[0]<=(MiscInstReg[0][3] & (~MiscInstReg[0][2] | ~MiscInstReg[0][1])) ? ((GPR_A[MiscInstReg[0][7:4]] & {128{~(|MiscBypassAReg[0])}}) | 
																		(FADDR & {128{MiscBypassAReg[0][0]}}) |
																		({64'd0, FMULR & {64{MiscBypassAReg[0][1]}}}) |
																		(FMULRQ & {128{MiscBypassAReg[0][2]}}) |
																		({GPR_A[MiscInstReg[0][7:4]][127:64], ALUR} & {128{MiscBypassAReg[0][3]}}) |
																		({GPR_A[MiscInstReg[0][7:4]][127:64], ShiftR} & {128{MiscBypassAReg[0][4]}}) |
																		(MiscR[0] & {128{MiscBypassAReg[0][5]}})) :
																		((GPR_A[MiscInstReg[0][11:8]] & {128{~(|MiscBypassBReg[0])}}) | 
																		(FADDR & {128{MiscBypassBReg[0][0]}}) |
																		({64'd0, FMULR & {64{MiscBypassBReg[0][1]}}}) |
																		(FMULRQ & {128{MiscBypassBReg[0][2]}}) |
																		({GPR_A[MiscInstReg[0][11:8]][127:64], ALUR} & {128{MiscBypassBReg[0][3]}}) |
																		({GPR_A[MiscInstReg[0][11:8]][127:64], ShiftR} & {128{MiscBypassBReg[0][4]}}) |
																		(MiscR[0] & {128{MiscBypassBReg[0][5]}}));

	MiscAReg[1]<=(MiscInstReg[1][3] & (~MiscInstReg[1][2] | ~MiscInstReg[1][1])) ? ((GPR_B[MiscInstReg[1][7:4]] & {128{~(|MiscBypassAReg[1])}}) | 
																		(FADDR & {128{MiscBypassAReg[1][0]}}) |
																		({64'd0, FMULR & {64{MiscBypassAReg[1][1]}}}) |
																		(FMULRQ & {128{MiscBypassAReg[1][2]}}) |
																		({GPR_B[MiscInstReg[1][7:4]][127:64], ALUR} & {128{MiscBypassAReg[1][3]}}) |
																		({GPR_B[MiscInstReg[1][7:4]][127:64], ShiftR} & {128{MiscBypassAReg[1][4]}}) |
																		(MiscR[1] & {128{MiscBypassAReg[1][5]}})) :
																		((GPR_B[MiscInstReg[1][11:8]] & {128{~(|MiscBypassBReg[1])}}) | 
																		(FADDR & {128{MiscBypassBReg[1][0]}}) |
																		({64'd0, FMULR & {64{MiscBypassBReg[1][1]}}}) |
																		(FMULRQ & {128{MiscBypassBReg[1][2]}}) |
																		({GPR_B[MiscInstReg[1][11:8]][127:64], ALUR} & {128{MiscBypassBReg[1][3]}}) |
																		({GPR_B[MiscInstReg[1][11:8]][127:64], ShiftR} & {128{MiscBypassBReg[1][4]}}) |
																		(MiscR[1] & {128{MiscBypassBReg[1][5]}}));

	MiscSAReg[0]<=(MiscInstReg[0][3] & (~MiscInstReg[0][2] | ~MiscInstReg[0][1])) ? ((AFR_A[MiscInstReg[0][7:4]][24:22] & {3{~(|MiscBypassAReg[0])}})|
																		(FADDSR & {3{MiscBypassAReg[0][0]}})|
																		({2'd1, FMULSR} & {3{MiscBypassAReg[0][1]}})|
																		({MiscBypassAReg[0][2], 2'd0}) |
																		({1'b0, ALUSRReg & {2{MiscBypassAReg[0][3]}}})|
																		({1'b0, ShiftSRReg & {2{MiscBypassAReg[0][4]}}})|
																		(MiscSRReg[0] & {3{MiscBypassAReg[0][5]}})) : 
																		((AFR_A[MiscInstReg[0][11:8]][24:22] & {3{~(|MiscBypassBReg[0])}})|
																		(FADDSR & {3{MiscBypassBReg[0][0]}})|
																		({2'd1, FMULSR} & {3{MiscBypassBReg[0][1]}})|
																		({MiscBypassBReg[0][2], 2'd0}) |
																		({1'b0, ALUSRReg & {2{MiscBypassBReg[0][3]}}})|
																		({1'b0, ShiftSRReg & {2{MiscBypassBReg[0][4]}}})|
																		(MiscSRReg[0] & {3{MiscBypassBReg[0][5]}}));

	MiscSAReg[1]<=(MiscInstReg[1][3] & (~MiscInstReg[1][2] | ~MiscInstReg[1][1])) ? ((AFR_B[MiscInstReg[1][7:4]][24:22] & {3{~(|MiscBypassAReg[1])}})|
																		(FADDSR & {3{MiscBypassAReg[1][0]}})|
																		({2'd1, FMULSR} & {3{MiscBypassAReg[1][1]}})|
																		({MiscBypassAReg[1][2], 2'd0}) |
																		({1'b0, ALUSRReg & {2{MiscBypassAReg[1][3]}}})|
																		({1'b0, ShiftSRReg & {2{MiscBypassAReg[1][4]}}})|
																		(MiscSRReg[1] & {3{MiscBypassAReg[1][5]}})) : 
																		((AFR_B[MiscInstReg[1][11:8]][24:22] & {3{~(|MiscBypassBReg[1])}})|
																		(FADDSR & {3{MiscBypassBReg[1][0]}})|
																		({2'd1, FMULSR} & {3{MiscBypassBReg[1][1]}})|
																		({MiscBypassBReg[1][2], 2'd0}) |
																		({1'b0, ALUSRReg & {2{MiscBypassBReg[1][3]}}})|
																		({1'b0, ShiftSRReg & {2{MiscBypassBReg[1][4]}}})|
																		(MiscSRReg[1] & {3{MiscBypassBReg[1][5]}}));
	
	MiscSDReg[0]<=(AFR_A[MiscInstReg[0][11:8]][24:22] & {3{~(|MiscBypassBReg[0])}})|
				(FADDSR & {3{MiscBypassBReg[0][0]}})|
				({2'd1, FMULSR} & {3{MiscBypassBReg[0][1]}})|
				({MiscBypassBReg[0][2], 2'd0}) |
				({1'b0, ALUSRReg & {2{MiscBypassBReg[0][3]}}})|
				({1'b0, ShiftSRReg & {2{MiscBypassBReg[0][4]}}})|
				(MiscSRReg[0] & {3{MiscBypassBReg[0][5]}});
	
	MiscSDReg[1]<=(AFR_B[MiscInstReg[1][11:8]][24:22] & {3{~(|MiscBypassBReg[1])}})|
				(FADDSR & {3{MiscBypassBReg[1][0]}})|
				({2'd1, FMULSR} & {3{MiscBypassBReg[1][1]}})|
				({MiscBypassBReg[1][2], 2'd0}) |
				({1'b0, ALUSRReg & {2{MiscBypassBReg[1][3]}}})|
				({1'b0, ShiftSRReg & {2{MiscBypassBReg[1][4]}}})|
				(MiscSRReg[1] & {3{MiscBypassBReg[1][5]}});

	MiscDSTReg[0]<=MiscInstReg[0][11:8];
	MiscDSTReg[1]<=MiscInstReg[1][11:8];
	MiscOPRReg[0]<=MiscInstReg[0][3:1];
	MiscOPRReg[1]<=MiscInstReg[1][3:1];
	
//=================================================================================================
// loop instruction channel
	LoopInstReg[0]<=LoopInstBus[0];
	LoopInstReg[1]<=LoopInstBus[1];
	
	LoopBypassReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, LoopInstBus[0][15:12]});
	LoopBypassReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, LoopInstBus[0][15:12]});
	LoopBypassReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, LoopInstBus[0][15:12]});
	LoopBypassReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, LoopInstBus[0][15:12]});
	LoopBypassReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, LoopInstBus[0][15:12]});
	LoopBypassReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==LoopInstBus[0][15:12]);
	
	LoopBypassReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, LoopInstBus[1][15:12]});
	LoopBypassReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, LoopInstBus[1][15:12]});
	LoopBypassReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, LoopInstBus[1][15:12]});
	LoopBypassReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, LoopInstBus[1][15:12]});
	LoopBypassReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, LoopInstBus[1][15:12]});
	LoopBypassReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==LoopInstBus[1][15:12]);
	
//=================================================================================================
// prefetcher channel
	PrefInstReg[0]<=PrefInstBus[0];
	PrefInstReg[1]<=PrefInstBus[1];

	PrefBypassReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, PrefInstBus[0][16:13]});
	PrefBypassReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, PrefInstBus[0][16:13]});
	PrefBypassReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, PrefInstBus[0][16:13]});
	PrefBypassReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, PrefInstBus[0][16:13]});
	PrefBypassReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, PrefInstBus[0][16:13]});
	PrefBypassReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==PrefInstBus[0][16:13]);

	PrefBypassReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, PrefInstBus[1][16:13]});
	PrefBypassReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, PrefInstBus[1][16:13]});
	PrefBypassReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, PrefInstBus[1][16:13]});
	PrefBypassReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, PrefInstBus[1][16:13]});
	PrefBypassReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, PrefInstBus[1][16:13]});
	PrefBypassReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==PrefInstBus[1][16:13]);
	
	PrefCCBypassReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, PrefInstBus[0][8:5]});
	PrefCCBypassReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, PrefInstBus[0][8:5]});
	PrefCCBypassReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, PrefInstBus[0][8:5]});
	PrefCCBypassReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, PrefInstBus[0][8:5]});
	PrefCCBypassReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, PrefInstBus[0][8:5]});
	PrefCCBypassReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==PrefInstBus[0][8:5]);
	
	PrefCCBypassReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, PrefInstBus[1][8:5]});
	PrefCCBypassReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, PrefInstBus[1][8:5]});
	PrefCCBypassReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, PrefInstBus[1][8:5]});
	PrefCCBypassReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, PrefInstBus[1][8:5]});
	PrefCCBypassReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, PrefInstBus[1][8:5]});
	PrefCCBypassReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==PrefInstBus[1][8:5]);
	
//=================================================================================================
// register movement operation
	MovInstReg[0]<=MovInstBus[0];
	MovInstReg[1]<=MovInstBus[1];

	CopyBypassReg[0][0]<=FADDRDYR & (FADDDSTR=={1'b0, MovInstBus[0][10:7]});
	CopyBypassReg[0][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b0, MovInstBus[0][10:7]});
	CopyBypassReg[0][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b0, MovInstBus[0][10:7]});
	CopyBypassReg[0][3]<=ALURDYR & (ALUDSTR=={1'b0, MovInstBus[0][10:7]});
	CopyBypassReg[0][4]<=ShiftRDYR & (ShiftDSTR=={1'b0, MovInstBus[0][10:7]});
	CopyBypassReg[0][5]<=MiscRDYR[0] & (MiscDSTR[0]==MovInstBus[0][10:7]);

	CopyBypassReg[1][0]<=FADDRDYR & (FADDDSTR=={1'b1, MovInstBus[1][10:7]});
	CopyBypassReg[1][1]<=FMULRDYR[0] & (FMULDSTR[0]=={1'b1, MovInstBus[1][10:7]});
	CopyBypassReg[1][2]<=FMULRDYR[1] & (FMULDSTR[1]=={1'b1, MovInstBus[1][10:7]});
	CopyBypassReg[1][3]<=ALURDYR & (ALUDSTR=={1'b1, MovInstBus[1][10:7]});
	CopyBypassReg[1][4]<=ShiftRDYR & (ShiftDSTR=={1'b1, MovInstBus[1][10:7]});
	CopyBypassReg[1][5]<=MiscRDYR[1] & (MiscDSTR[1]==MovInstBus[1][10:7]);

	if (&MovInstReg[0][2:0]) 	begin
							// load immediate data mode
							case (AFR_A[MovInstReg[0][14:11]][31:28])
								4'h0: MovReg[0]<={{120{MovInstReg[0][10]}},MovInstReg[0][10:3]};
								4'h1: MovReg[0]<={{112{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][7:0]};
								4'h2: MovReg[0]<={{104{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][15:0]};
								4'h3: MovReg[0]<={{96{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][23:0]};
								4'h4: MovReg[0]<={{88{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][31:0]};
								4'h5: MovReg[0]<={{80{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][39:0]};
								4'h6: MovReg[0]<={{72{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][47:0]};
								4'h7: MovReg[0]<={{64{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][55:0]};
								4'h8: MovReg[0]<={{56{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][63:0]};
								4'h9: MovReg[0]<={{48{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][71:0]};
								4'hA: MovReg[0]<={{40{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][79:0]};
								4'hB: MovReg[0]<={{32{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][87:0]};
								4'hC: MovReg[0]<={{24{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][95:0]};
								4'hD: MovReg[0]<={{16{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][103:0]};
								4'hE: MovReg[0]<={{8{MovInstReg[0][10]}},MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][111:0]};
								4'hF: MovReg[0]<={MovInstReg[0][10:3],GPR_A[MovInstReg[0][14:11]][119:0]};
								endcase
							// size
							MovSR[0][0]<=(~AFR_A[MovInstReg[0][14:11]][31] & AFR_A[MovInstReg[0][14:11]][30])|
										(~AFR_A[MovInstReg[0][14:11]][31] & ~AFR_A[MovInstReg[0][14:11]][30] & ~AFR_A[MovInstReg[0][14:11]][29] & AFR_A[MovInstReg[0][14:11]][28]);
							MovSR[0][1]<=(AFR_A[MovInstReg[0][14:11]][30] | AFR_A[MovInstReg[0][14:11]][29]) & ~AFR_A[MovInstReg[0][14:11]][31];
							MovSR[0][2]<=AFR_A[MovInstReg[0][14:11]][31];
							end
			else begin
				if (MovInstReg[0][2:0]==3'b001)	begin
												// COPY operations
												MovReg[0]<=(GPR_A[MovInstReg[0][10:7]] & {128{~(|CopyBypassReg[0])}}) | 
														(FADDR & {128{CopyBypassReg[0][0]}}) |
														({64'd0, FMULR & {64{CopyBypassReg[0][1]}}}) |
														(FMULRQ & {128{CopyBypassReg[0][2]}}) |
														({GPR_A[MovInstReg[0][10:7]][127:64], ALUR} & {128{CopyBypassReg[0][3]}}) |
														({GPR_A[MovInstReg[0][10:7]][127:64], ShiftR} & {128{CopyBypassReg[0][4]}}) |
														(MiscR[0] & {128{CopyBypassReg[0][5]}});
												MovSR[0]<=(AFR_A[MovInstReg[0][10:7]][24:22] & {3{~(|CopyBypassReg[0])}})|
														(FADDSR & {3{CopyBypassReg[0][0]}})|
														({2'd1, FMULSR} & {3{CopyBypassReg[0][1]}})|
														({CopyBypassReg[0][2], 2'd0}) |
														({1'b0, ALUSRReg & {2{CopyBypassReg[0][3]}}})|
														({1'b0, ShiftSRReg & {2{CopyBypassReg[0][4]}}})|
														(MiscSRReg[0] & {3{CopyBypassReg[0][5]}});
												end
										else if (MovInstReg[0][2:0]==3'b011) 
												begin
												if (MovInstReg[0][7]) AFR_A[MovInstReg[0][14:11]][27:25]<=MovInstReg[0][10:8];  // AMODE
															else	AFR_A[MovInstReg[0][14:11]][24:22]<=MovInstReg[0][10:8]; // SIZE
												end
				end

	if (&MovInstReg[1][2:0]) 	begin
							// load immediate data mode
							case (AFR_B[MovInstReg[1][14:11]][31:28])
								4'h0: MovReg[1]<={{120{MovInstReg[1][10]}},MovInstReg[1][10:3]};
								4'h1: MovReg[1]<={{112{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][7:0]};
								4'h2: MovReg[1]<={{104{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][15:0]};
								4'h3: MovReg[1]<={{96{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][23:0]};
								4'h4: MovReg[1]<={{88{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][31:0]};
								4'h5: MovReg[1]<={{80{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][39:0]};
								4'h6: MovReg[1]<={{72{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][47:0]};
								4'h7: MovReg[1]<={{64{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][55:0]};
								4'h8: MovReg[1]<={{56{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][63:0]};
								4'h9: MovReg[1]<={{48{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][71:0]};
								4'hA: MovReg[1]<={{40{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][79:0]};
								4'hB: MovReg[1]<={{32{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][87:0]};
								4'hC: MovReg[1]<={{24{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][95:0]};
								4'hD: MovReg[1]<={{16{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][103:0]};
								4'hE: MovReg[1]<={{8{MovInstReg[1][10]}},MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][111:0]};
								4'hF: MovReg[1]<={MovInstReg[1][10:3],GPR_B[MovInstReg[1][14:11]][119:0]};
								endcase
							// size
							MovSR[1][0]<=(~AFR_B[MovInstReg[1][14:11]][31] & AFR_B[MovInstReg[1][14:11]][30])|
										(~AFR_B[MovInstReg[1][14:11]][31] & ~AFR_B[MovInstReg[1][14:11]][30] & ~AFR_B[MovInstReg[1][14:11]][29] & AFR_B[MovInstReg[1][14:11]][28]);
							MovSR[1][1]<=(AFR_B[MovInstReg[1][14:11]][30] | AFR_B[MovInstReg[1][14:11]][29]) & ~AFR_B[MovInstReg[1][14:11]][31];
							MovSR[1][2]<=AFR_B[MovInstReg[1][14:11]][31];
							end
			else begin
				if (MovInstReg[1][2:0]==3'b001)	begin
												// COPY operations
												MovReg[1]<=(GPR_B[MovInstReg[1][10:7]] & {128{~(|CopyBypassReg[1])}}) | 
														(FADDR & {128{CopyBypassReg[1][0]}}) |
														({64'd0, FMULR & {64{CopyBypassReg[1][1]}}}) |
														(FMULRQ & {128{CopyBypassReg[1][2]}}) |
														({GPR_B[MovInstReg[1][10:7]][127:64], ALUR} & {128{CopyBypassReg[1][3]}}) |
														({GPR_B[MovInstReg[1][10:7]][127:64], ShiftR} & {128{CopyBypassReg[1][4]}}) |
														(MiscR[1] & {128{CopyBypassReg[1][5]}});
												MovSR[1]<=(AFR_B[MovInstReg[1][10:7]][24:22] & {3{~(|CopyBypassReg[1])}})|
														(FADDSR & {3{CopyBypassReg[1][0]}})|
														({2'd1, FMULSR} & {3{CopyBypassReg[1][1]}})|
														({CopyBypassReg[1][2], 2'd0}) |
														({1'b0, ALUSRReg & {2{CopyBypassReg[1][3]}}})|
														({1'b0, ShiftSRReg & {2{CopyBypassReg[1][4]}}})|
														(MiscSRReg[1] & {3{CopyBypassReg[1][5]}});
												end
										else if (MovInstReg[1][2:0]==3'b011) 
												begin
												if (MovInstReg[1][7]) AFR_B[MovInstReg[1][14:11]][27:25]<=MovInstReg[1][10:8];  // AMODE
															else	AFR_B[MovInstReg[1][14:11]][24:22]<=MovInstReg[1][10:8]; // SIZE
												end
				end

//=================================================================================================
//
// Memory operations and address register 
//
	if (~MemDelayFlag[0] & ~MemFifoFullFlag[0]) MemInstReg[0]<=MemInstBus[0];
	if (~MemDelayFlag[1] & ~MemFifoFullFlag[1]) MemInstReg[1]<=MemInstBus[1];

	MemDelayFlag[0]<=~MemDelayFlag[0] & MemInstBus[0][0] & ((FADDRDYR & (FADDDSTR=={1'b0, MemInstBus[0][15:12]})) | 
															(FMULRDYR[0] & (FMULDSTR[0]=={1'b0, MemInstBus[0][15:12]})) |
															(FMULRDYR[1] & (FMULDSTR[1]=={1'b0, MemInstBus[0][15:12]})) |
															(ALURDYR & (ALUDSTR=={1'b0, MemInstBus[0][15:12]})) |
															(ShiftRDYR & (ShiftDSTR=={1'b0, MemInstBus[0][15:12]})) |
															(MiscRDYR[0] & (MiscDSTR[0]==MemInstBus[0][15:12])) |
															(FADDRDYR & (FADDDSTR=={1'b0, MemInstBus[0][11:8]})) |
															(FMULRDYR[0] & (FMULDSTR[0]=={1'b0, MemInstBus[0][11:8]})) |
															(FMULRDYR[1] & (FMULDSTR[1]=={1'b0, MemInstBus[0][11:8]})) |
															(ALURDYR & (ALUDSTR=={1'b0, MemInstBus[0][11:8]})) |
															(ShiftRDYR & (ShiftDSTR=={1'b0, MemInstBus[0][11:8]})) |
															(MiscRDYR[0] & (MiscDSTR[0]==MemInstBus[0][11:8])));
	
	MemDelayFlag[1]<=~MemDelayFlag[1] & MemInstBus[1][0] & ((FADDRDYR & (FADDDSTR=={1'b1, MemInstBus[1][15:12]})) |
															(FMULRDYR[0] & (FMULDSTR[0]=={1'b1, MemInstBus[1][15:12]})) |
															(FMULRDYR[1] & (FMULDSTR[1]=={1'b1, MemInstBus[1][15:12]})) |
															(ALURDYR & (ALUDSTR=={1'b1, MemInstBus[1][15:12]})) |
															(ShiftRDYR & (ShiftDSTR=={1'b1, MemInstBus[1][15:12]})) |
															(MiscRDYR[1] & (MiscDSTR[1]==MemInstBus[1][15:12])) |
															(FADDRDYR & (FADDDSTR=={1'b1, MemInstBus[1][11:8]})) |
															(FMULRDYR[0] & (FMULDSTR[0]=={1'b1, MemInstBus[1][11:8]})) |
															(FMULRDYR[1] & (FMULDSTR[1]=={1'b1, MemInstBus[1][11:8]})) |
															(ALURDYR & (ALUDSTR=={1'b1, MemInstBus[1][11:8]})) |
															(ShiftRDYR & (ShiftDSTR=={1'b1, MemInstBus[1][11:8]})) |
															(MiscRDYR[1] & (MiscDSTR[1]==MemInstBus[1][11:8])));
	
	
	// busy flag of memory command
	MemBusy[0]<=(MemBusy[0] & ~MemLoadOffset[0] & (~MemLoadSel[0] | (MemDST[0]=={CheckSEL[0],CheckACT[0]})) & ~MemReadAR[0] & 
				~(MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4]))) | MemCNT[0][1] | MemCNT[0][0] | ~MemFifoEmpty[0];
	MemBusy[1]<=(MemBusy[1] & ~MemLoadOffset[1] & (~MemLoadSel[1] | (MemDST[1]=={CheckSEL[1],CheckACT[1]})) & ~MemReadAR[1] &
				~(MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4]))) | MemCNT[1][1] | MemCNT[1][0] | ~MemFifoEmpty[1];
	
	// Memory interface unit operation flags
	if ((~MemBusy[0] | (MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) | MemLoadOffset[0] | (MemLoadSel[0] & (MemDST[0]!={CheckSEL[0],CheckACT[0]})) | MemReadAR[0]) & ~MemCNT[0][1] & ~MemCNT[0][0])
		begin
		// Read AR
		MemReadAR[0]<=~MemFifoEmpty[0] & ~MemFifoBus[0][3] & MemFifoBus[0][2] & ~MemFifoBus[0][1] & MemFifoBus[0][0] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		// Load AR (offset)
		MemLoadOffset[0]<=~MemFifoEmpty[0] & ~MemFifoBus[0][3] & MemFifoBus[0][2] & MemFifoBus[0][1] & ~MemFifoBus[0][0] & ~MemFifoBus[0][11] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		// Load AR (selector)
		MemLoadSel[0]<=~MemFifoEmpty[0] & ~MemFifoBus[0][3] & MemFifoBus[0][2] & MemFifoBus[0][1] & ~MemFifoBus[0][0] & MemFifoBus[0][11] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		// Request flag to the ATU
		MemReq[0]<=~MemFifoEmpty[0] & (MemFifoBus[0][3] | (~MemFifoBus[0][2] & ~MemFifoBus[0][1] & ~MemFifoBus[0][0]) |
												(MemFifoBus[0][2] & MemFifoBus[0][1] & MemFifoBus[0][0])) & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		// Read/Write flag
		MemOpr[0]<=MemFifoBus[0][3];
		// PUsh/POP/LDST flags
		MemPUSH[0]<=~MemFifoEmpty[0] & ~MemFifoBus[0][3] & MemFifoBus[0][2] & MemFifoBus[0][1] & MemFifoBus[0][0] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		MemPOP[0]<=~MemFifoEmpty[0] & MemFifoBus[0][3] & MemFifoBus[0][2] & MemFifoBus[0][1] & MemFifoBus[0][0] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		MemLDST[0]<=~MemFifoEmpty[0] & ((MemFifoBus[0][3] & (~MemFifoBus[0][2] | ~MemFifoBus[0][1] | ~MemFifoBus[0][0])) |
									(~MemFifoBus[0][3] & ~MemFifoBus[0][2] & ~MemFifoBus[0][1] & ~MemFifoBus[0][0])) & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		MemLDO[0]<=~MemFifoEmpty[0] & MemFifoBus[0][3] & MemFifoBus[0][2] & ~MemFifoBus[0][1] & ~MemFifoBus[0][0] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		MemADRPushPop[0]<=~MemFifoEmpty[0] & MemFifoBus[0][2] & MemFifoBus[0][1] & MemFifoBus[0][0] & MemFifoBus[0][10] & ~MemFifoBus[0][215] & ~MemFifoBus[0][216];
		
		PrefCallReg[0]<=~MemFifoEmpty[0] & MemFifoBus[0][215];
		PrefRetReg[0]<=~MemFifoEmpty[0] & MemFifoBus[0][216];
		// Size
		if (MemFifoBus[0][3:0]==4'b0000) MemSize[0]<=MemFifoBus[0][207:205];
								else MemSize[0]<=MemFifoBus[0][2:0];
		// SEL field register
		if (MemFifoBus[0][3:0]==4'b0110) MemSEL[0]<=MemFifoBus[0][14:12];
								else MemSEL[0]<=MemFifoBus[0][6:4];
		// DST field register
		MemDST[0]<=MemFifoBus[0][14:11];
		// Offset from GPR
		MemGPROffset[0]<=MemFifoBus[0][51:15];
		// Offset register
		MemOFF[0]<=MemFifoBus[0][10:7];
		// address mode
		MemAMode[0]<=MemFifoBus[0][54:52];
		// GPR flags
		MemAFR[0]<=MemFifoBus[0][214:183];
		// GPR
		MemGPR[0]<=MemFifoBus[0][182:55];
		// data to GPR
		ARData[0]<=ADR_A[MemOFF[0]];
		end
	if ((~MemBusy[1] | (MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])) | MemLoadOffset[1] | (MemLoadSel[1] & (MemDST[1]!={CheckSEL[1],CheckACT[1]})) | MemReadAR[1]) & ~MemCNT[1][1] & ~MemCNT[1][0])
		begin
		// Read AR
		MemReadAR[1]<=~MemFifoEmpty[1] & ~MemFifoBus[1][3] & MemFifoBus[1][2] & ~MemFifoBus[1][1] & MemFifoBus[1][0] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		// Load AR (offset)
		MemLoadOffset[1]<=~MemFifoEmpty[1] & ~MemFifoBus[1][3] & MemFifoBus[1][2] & MemFifoBus[1][1] & ~MemFifoBus[1][0] & ~MemFifoBus[1][11] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		// Load AR (selector)
		MemLoadSel[1]<=~MemFifoEmpty[1] & ~MemFifoBus[1][3] & MemFifoBus[1][2] & MemFifoBus[1][1] & ~MemFifoBus[1][0] & MemFifoBus[1][11] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		// Request flag to the ATU
		MemReq[1]<=~MemFifoEmpty[1] & (MemFifoBus[1][3] | (~MemFifoBus[1][2] & ~MemFifoBus[1][1] & ~MemFifoBus[1][0]) |
												(MemFifoBus[1][2] & MemFifoBus[1][1] & MemFifoBus[1][0])) & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		// Read/Write flag
		MemOpr[1]<=MemFifoBus[1][3];
		// PUsh/POP/LDST flags
		MemPUSH[1]<=~MemFifoEmpty[1] & ~MemFifoBus[1][3] & MemFifoBus[1][2] & MemFifoBus[1][1] & MemFifoBus[1][0] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		MemPOP[1]<=~MemFifoEmpty[1] & MemFifoBus[1][3] & MemFifoBus[1][2] & MemFifoBus[1][1] & MemFifoBus[1][0] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		MemLDST[1]<=~MemFifoEmpty[1] & ((MemFifoBus[1][3] & (~MemFifoBus[1][2] | ~MemFifoBus[1][1] | ~MemFifoBus[1][0])) |
									(~MemFifoBus[1][3] & ~MemFifoBus[1][2] & ~MemFifoBus[1][1] & ~MemFifoBus[1][0])) & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		MemLDO[1]<=~MemFifoEmpty[1] & MemFifoBus[1][3] & MemFifoBus[1][2] & ~MemFifoBus[1][1] & ~MemFifoBus[1][0] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		MemADRPushPop[1]<=~MemFifoEmpty[1] & MemFifoBus[1][2] & MemFifoBus[1][1] & MemFifoBus[1][0] & MemFifoBus[1][10] & ~MemFifoBus[1][215] & ~MemFifoBus[1][216];
		
		PrefCallReg[1]<=~MemFifoEmpty[1] & MemFifoBus[1][215];
		PrefRetReg[1]<=~MemFifoEmpty[1] & MemFifoBus[1][216];
		// Size
		if (MemFifoBus[1][3:0]==4'b0000) MemSize[1]<=MemFifoBus[1][207:205];
								else MemSize[1]<=MemFifoBus[1][2:0];
		// SEL field register
		if (MemFifoBus[1][3:0]==4'b0110) MemSEL[1]<=MemFifoBus[1][14:12];
								else MemSEL[1]<=MemFifoBus[1][6:4];
		// DST field register
		MemDST[1]<=MemFifoBus[1][14:11];
		// Offset from GPR
		MemGPROffset[1]<=MemFifoBus[1][51:15];
		// Offset register
		MemOFF[1]<=MemFifoBus[1][10:7];
		// address mode
		MemAMode[1]<=MemFifoBus[1][54:52];
		// GPR flags
		MemAFR[1]<=MemFifoBus[1][214:183];
		// GPR
		MemGPR[1]<=MemFifoBus[1][182:55];
		// data to GPR
		ARData[1]<=ADR_B[MemOFF[1]];
		end

	// Count of the bus cycles
	if ((~MemBusy[0] | (MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) | MemLoadOffset[0] | (MemLoadSel[0] & (MemDST[0]!={CheckSEL[0],CheckACT[0]})) | MemReadAR[0]) & ~MemFifoEmpty[0] & (MemCNT[0]==2'd0) & ~MemFifoBus[0][215] & ~MemFifoBus[0][216])
					begin
					MemCNT[0][0]<=(MemFifoBus[0][3:0]==4'b1100) |
							((MemFifoBus[0][3:0]==4'b0000) & MemFifoBus[0][207]);
					MemCNT[0][1]<=~MemFifoBus[0][10] & (MemFifoBus[0][2:0]==3'b111);
					end
				else if (MemNext[0] & (MemCNT[0]!=2'b00) & (~FMULACCMemACT | FMULACCDSTReg[4])) MemCNT[0]<=MemCNT[0]-2'd1;
	if ((~MemBusy[1] | (MemNext[1] & (~FMULACCMemACT | FMULACCDSTReg[4])) | MemLoadOffset[1] | (MemLoadSel[1] & (MemDST[1]!={CheckSEL[1],CheckACT[1]})) | MemReadAR[1]) & ~MemFifoEmpty[1] & (MemCNT[1]==2'd0) & ~MemFifoBus[1][215] & ~MemFifoBus[1][216])
					begin
					MemCNT[1][0]<=(MemFifoBus[1][3:0]==4'b1100) |
							((MemFifoBus[1][3:0]==4'b0000) & MemFifoBus[1][207]);
					MemCNT[1][1]<=~MemFifoBus[1][10] & (MemFifoBus[1][2:0]==3'b111);
					end
				else if (MemNext[1] & (MemCNT[1]!=2'b00) & (~FMULACCMemACT | ~FMULACCDSTReg[4])) MemCNT[1]<=MemCNT[1]-2'd1;

	// resetting the descriptor valid flags 
	for (i7=0; i7<8; i7=i7+1)
		begin
		if (MemLoadSel[0] & (MemSEL[0]==i7) & (MemDST[0]!={CheckSEL[0],CheckACT[0] & ~CheckAR[0][3]})) DTR_A[i7][155]<=DTR_A[i7][155] & (MemGPROffset[0][31:0]==ADR_A[{MemSEL[0],1'b1}][31:0]);
			else if (MemLSelNode[0] & (TAGiReg[3:1]==i7)) DTR_A[i7][155]<=DTR_A[i7][155] & (DTi[31:0]==ADR_A[TAGiReg[3:0]][31:0]);
		if (MemLoadSel[1] & (MemSEL[1]==i7) & (MemDST[1]!={CheckSEL[1],CheckACT[1] & ~CheckAR[1][3]})) DTR_B[i7][155]<=DTR_B[i7][155] & (MemGPROffset[1][31:0]==ADR_B[{MemSEL[1],1'b1}][31:0]);
			else if (MemLSelNode[1] & (TAGiReg[3:1]==i7)) DTR_B[i7][155]<=DTR_B[i7][155] & (DTi[31:0]==ADR_B[TAGiReg[3:0]][31:0]);
		end
	
	// second cycle for 128-bit transfers
	if ((MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) | ~MemBusy[0]) MemSecondCycle[0]<=(MemCNT[0]==2'b01);
	if ((MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])) | ~MemBusy[1]) MemSecondCycle[1]<=(MemCNT[1]==2'b01);
	
	//
	// processing address registers
	//
	for (i8=0; i8<16; i8=i8+1)
		begin
		if (i8[0])
				begin
				// for selector registers
				if ((i8!=15) & (i8!=13))
						begin
						if (MemASelNode[0][i8])	ADR_A[i8]<=DTi[36:0];
							else if (MemLoadSel[0] & (MemDST[0]==i8) & ((MemDST[0]!={CheckSEL[0],CheckACT[0] & ~CheckAR[0][3]}) | MemNext[0])) ADR_A[i8]<=MemGPROffset[0];
						if (MemASelNode[1][i8])	ADR_B[i8]<=DTi[36:0];
							else if (MemLoadSel[1] & (MemDST[1]==i8) & ((MemDST[1]!={CheckSEL[1],CheckACT[1] & ~CheckAR[1][3]}) | MemNext[1])) ADR_B[i8]<=MemGPROffset[1];
						end
					else begin
						// stack selector and code selector can't be loaded from GPR's
						if (MemASelNode[0][i8]) ADR_A[i8]<=DTi[36:0];
							else if (MemLoadSel[0] & (MemDST[0]==i8) & ~CPL[0][1] & ~CPL[0][0]) ADR_A[i8]<=MemGPROffset[0];
						if (MemASelNode[1][i8]) ADR_B[i8]<=DTi[36:0];
							else if (MemLoadSel[1] & (MemDST[1]==i8) & ~CPL[1][1] & ~CPL[1][0]) ADR_B[i8]<=MemGPROffset[1];
						end
				end
			else begin
				// for offset registers
				if (i8==14)
						begin
						// stack offset can be loaded from memory or modified in PUSH/POP/CALL/RET operations
						if (MemASelNode[0][i8]) ADR_A[i8]<=DTi[36:0];
							else if (MemLoadOffset[0] & (MemDST[0]==i8)) ADR_A[i8]<=MemGPROffset[0];
								else if ((MemPUSH[0] | PrefCallReg[0]) & MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) ADR_A[i8]<=ADR_A[i8]-8;
									else if ((MemPOP[0] | PrefRetReg[0]) & MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4])) ADR_A[i8]<=ADR_A[i8]+8;
						if (MemASelNode[1][i8]) ADR_B[i8]<=DTi[36:0];
							else if (MemLoadOffset[1] & (MemDST[1]==i8)) ADR_B[i8]<=MemGPROffset[1];
								else if ((MemPUSH[1] | PrefCallReg[1]) & MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])) ADR_B[i8]<=ADR_B[i8]-8;
									else if ((MemPOP[1] | PrefRetReg[1]) & MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4])) ADR_B[i8]<=ADR_B[i8]+8;
						end
					else begin
						// all other offset registers
						if (MemASelNode[0][i8]) ADR_A[i8]<=DTi[36:0];
							else if (MemLoadOffset[0] & (MemDST[0]==i8)) ADR_A[i8]<=MemGPROffset[0];
									else if (MemLDST[0] & MemNext[0] & (~FMULACCMemACT | FMULACCDSTReg[4]) & (({1'b0,MemSEL[0]}<<1)==i8) & MemReq[0] & ~MemCNT[0][1] & ~MemCNT[0][0])
										begin
										if (MemAMode[0]==3'b001) ADR_A[i8]<=ADR_A[i8]+MemGPROffset[0];
											else if (MemAMode[0][2] & ~MemAMode[0][0]) ADR_A[i8]<=ADR_A[i8]+MemoryOSValue[0];
												else if (MemAMode[0][2] & MemAMode[0][0]) ADR_A[i8]<=ADR_A[i8]-MemoryOSValue[0];
										end
						if (MemASelNode[1][i8]) ADR_B[i8]<=DTi[36:0];
							else if (MemLoadOffset[1] & (MemDST[1]==i8)) ADR_B[i8]<=MemGPROffset[1];
									else if (MemLDST[1] & MemNext[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4]) & (({1'b0,MemSEL[1]}<<1)==i8) & MemReq[1] & ~MemCNT[1][1] & ~MemCNT[1][0])
										begin
										if (MemAMode[1]==3'b001) ADR_B[i8]<=ADR_B[i8]+MemGPROffset[1];
											else if (MemAMode[1][2] & ~MemAMode[1][0]) ADR_B[i8]<=ADR_B[i8]+MemoryOSValue[1];
												else if (MemAMode[1][2] & MemAMode[1][0]) ADR_B[i8]<=ADR_B[i8]-MemoryOSValue[1];
										end
						end
				end
		end
	//
	// Conversion logical address to physical with access verification
	//
	CheckACT[0]<=(CheckACT[0] & ~MemNext[0]) | MemReq[0] | PrefACT[0] | PrefCallReg[0] | PrefRetReg[0] | (FMULACCMemACT & ~FMULACCDSTReg[4]);
	CheckACT[1]<=(CheckACT[1] & ~MemNext[1]) | MemReq[1] | PrefACT[1] | PrefCallReg[1] | PrefRetReg[1] | (FMULACCMemACT & FMULACCDSTReg[4]);
	
	// check offset and access type stage
	if (MemNext[0])
		begin
		// prefetcher flag
		CheckPref[0]<=PrefACT[0] & ~MemReq[0] & ~PrefCallReg[0] & ~PrefRetReg[0] & (~FMULACCMemACT | FMULACCDSTReg[4]);
		// selector index
		if (FMULACCMemACT & ~FMULACCDSTReg[4]) CheckSEL[0]<=FMULACCMemSEL;
			else if (PrefCallReg[0] | PrefRetReg[0]) CheckSEL[0]<=3'd7;
					else if (MemReq[0]) CheckSEL[0]<=MemSEL[0] | {3{MemPUSH[0] | MemPOP[0]}};
							else CheckSEL[0]<=3'd6;
							
		// Command
		if (PrefCallReg[0]) CheckCMD[0]<=FMULACCMemACT & ~FMULACCDSTReg[4];
			else if (MemReq[0]) CheckCMD[0]<=MemOpr[0] | (FMULACCMemACT & ~FMULACCDSTReg[4]) | MemPOP[0];
					else CheckCMD[0]<=1'b1;
					
		// operand size
		if (FMULACCMemACT & ~FMULACCDSTReg[4]) CheckOS[0]<={1'b1,FMULACCSIZE};
			else if (MemReq[0]) CheckOS[0]<=MemSize[0][1:0] | {2{MemSize[0][2]}};
					else CheckOS[0]<=2'b11;

		// Forming OFFSET 
		if (FMULACCMemACT & ~FMULACCDSTReg[4]) CheckOffset[0]<=ADR_A[{1'b0,FMULACCMemSEL}<<1]+{FMULACCMemOffset,2'd0};
			else if (~MemReq[0] & ~PrefCallReg[0] & ~PrefRetReg[0]) CheckOffset[0]<=PrefOffset[0];
				else if (MemPUSH[0] | PrefCallReg[0]) CheckOffset[0]<=ADR_A[14]-36'd8;
					else if (MemPOP[0] | PrefRetReg[0]) CheckOffset[0]<=ADR_A[14];
							else case (MemAMode[0])
								3'b000 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+{33'd0,MemSecondCycle[0],3'd0};
								3'b001 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+{33'd0,MemSecondCycle[0],3'd0};
								3'b010 : CheckOffset[0]<=MemGPROffset[0]+{33'd0,MemSecondCycle[0],3'd0};
								3'b011 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+MemGPROffset[0]+{33'd0,MemSecondCycle[0],3'd0};
								3'b100 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+{33'd0,MemSecondCycle[0],3'd0};
								3'b101 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+{33'd0,MemSecondCycle[0],3'd0};
								3'b110 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+MemGPROffset[0]+{33'd0,MemSecondCycle[0],3'd0};
								3'b111 : CheckOffset[0]<=ADR_A[{1'b0,MemSEL[0]}<<1]+MemGPROffset[0]+{33'd0,MemSecondCycle[0],3'd0};
								endcase
		// Base address limits and access rights
		if (FMULACCMemACT & ~FMULACCDSTReg[4])
				begin
				CheckBase[0]<=DTR_A[FMULACCMemSEL][39:0];
				CheckLL[0]<=DTR_A[FMULACCMemSEL][71:40];
				CheckUL[0]<=DTR_A[FMULACCMemSEL][103:72];
				CheckLowerSel[0]<=DTR_A[FMULACCMemSEL][127:104];
				CheckUpperSel[0]<=DTR_A[FMULACCMemSEL][151:128];
				CheckAR[0]<=DTR_A[FMULACCMemSEL][155:152];
				CheckNetwork[0]<=(CPU!=ADR_A[1+({1'b0,FMULACCMemSEL}<<1)][31:24]) & (|ADR_A[1+({1'b0,FMULACCMemSEL}<<1)][31:24]);
				CheckSelector[0]<=ADR_A[1+({1'b0,FMULACCMemSEL}<<1)][31:0];
				end
			else begin
				if (MemPOP[0] | MemPUSH[0] | PrefCallReg[0] | PrefRetReg[0])
						begin
						// stack access
						CheckBase[0]<=DTR_A[7][39:0];
						CheckLL[0]<=DTR_A[7][71:40];
						CheckUL[0]<=DTR_A[7][103:72];
						CheckLowerSel[0]<=DTR_A[7][127:104];
						CheckUpperSel[0]<=DTR_A[7][151:128];
						CheckAR[0]<=DTR_A[7][155:152];
						CheckNetwork[0]<=(CPU!=ADR_A[15][31:24]) & (|ADR_A[15][31:24]);
						CheckSelector[0]<=ADR_A[15][31:0];
						end
					else begin
						if (MemReq[0])
							begin
							// data transactions
							CheckBase[0]<=DTR_A[MemSEL[0]][39:0];
							CheckLL[0]<=DTR_A[MemSEL[0]][71:40];
							CheckUL[0]<=DTR_A[MemSEL[0]][103:72];
							CheckLowerSel[0]<=DTR_A[MemSEL[0]][127:104];
							CheckUpperSel[0]<=DTR_A[MemSEL[0]][151:128];
							CheckAR[0]<=DTR_A[MemSEL[0]][155:152];
							CheckNetwork[0]<=(CPU!=ADR_A[1+({1'b0,MemSEL[0]}<<1)][31:24]) & (|ADR_A[1+({1'b0,MemSEL[0]}<<1)][31:24]);
							CheckSelector[0]<=ADR_A[1+({1'b0,MemSEL[0]}<<1)][31:0];
							end
							else begin
							// code fetch
							CheckBase[0]<=DTR_A[6][39:0];
							CheckLL[0]<=DTR_A[6][71:40];
							CheckUL[0]<=DTR_A[6][103:72];
							CheckLowerSel[0]<=DTR_A[6][127:104];
							CheckUpperSel[0]<=DTR_A[6][151:128];
							CheckAR[0]<=DTR_A[6][155:152];
							CheckNetwork[0]<=(CPU!=ADR_A[13][31:24]) & (|ADR_A[13][31:24]);
							CheckSelector[0]<=ADR_A[13][31:0];
							end
					end
				end
		// forming data to memory
		if (PrefCallReg[0]) CheckData[0]<=MemGPR[0][63:0];
			else if (MemPUSH[0] & (MemCNT[0]==2'b10)) CheckData[0]<=MemAFR[0];
					else if (MemPUSH[0] & (MemCNT[0]==2'b01)) CheckData[0]<=MemGPR[0][127:64];
							else if (MemPUSH[0] & MemSecondCycle[0]) CheckData[0]<=MemGPR[0][63:0];
									else if (MemPUSH[0] & (MemCNT[0]==2'b00)) CheckData[0]<=ADR_A[MemDST[0]];
											else if (MemSecondCycle[0]) CheckData[0]<=MemGPR[0][127:64];
													else CheckData[0]<=MemGPR[0][63:0];
		// tag
		if (FMULACCMemACT & ~FMULACCDSTReg[4]) CheckTag[0]<={7'b1100000, FMULACCTAGo};
			else if ((PrefCallReg[0] | PrefRetReg[0]) | (~MemReq[0] & ~PrefCallReg[0] & ~PrefRetReg[0]))
						begin
						CheckTag[0][6:4]<=3'b110;
						CheckTag[0][3]<=PrefCallReg[0] | PrefRetReg[0];
						CheckTag[0][2:0]<=PrefTag[0];
						CheckTag[0][7]<=1'b0;
						end
					else begin
						CheckTag[0][3:0]<=MemDST[0];
						CheckTag[0][4]<=(MemSecondCycle[0] & MemLDST[0]) | (~MemLDST[0] & (MemCNT[0]==2'b01)) | MemADRPushPop[0];
						CheckTag[0][5]<=(MemPUSH[0] & (MemCNT[0]==2'b10))|(MemPOP[0] & (MemCNT[0]==2'b00))| MemADRPushPop[0];
						CheckTag[0][6]<=1'b0;
						CheckTag[0][7]<=MemLDO[0];
						end
		end
	if (MemNext[1])
		begin
		// prefetcher flag
		CheckPref[1]<=PrefACT[1] & ~MemReq[1] & ~PrefCallReg[1] & ~PrefRetReg[1] & (~FMULACCMemACT | ~FMULACCDSTReg[4]);
		
		// selector index
		if (FMULACCMemACT & FMULACCDSTReg[4]) CheckSEL[1]<=FMULACCMemSEL;
			else if (PrefCallReg[1] | PrefRetReg[1]) CheckSEL[1]<=3'd7;
					else if (MemReq[1]) CheckSEL[1]<=MemSEL[1] | {3{MemPUSH[1] | MemPOP[1]}};
							else CheckSEL[1]<=3'd6;
							
		// Command
		if (PrefCallReg[1]) CheckCMD[1]<=FMULACCMemACT;
			else if (MemReq[1]) CheckCMD[1]<=MemOpr[1] | (FMULACCMemACT & FMULACCDSTReg[4]) | MemPOP[1];
					else CheckCMD[1]<=1'b1;
					
		// operand size
		if (FMULACCMemACT & FMULACCDSTReg[4]) CheckOS[1]<={1'b1,FMULACCSIZE};
			else if (MemReq[1]) CheckOS[1]<=MemSize[1][1:0] | {2{MemSize[1][2]}};
					else CheckOS[1]<=2'b11;
					
		// Forming OFFSET 
		if (FMULACCMemACT & FMULACCDSTReg[4]) CheckOffset[1]<=ADR_B[{1'b0,FMULACCMemSEL}<<1]+{FMULACCMemOffset,2'd0};
			else if (~MemReq[1] & ~PrefCallReg[1] & ~PrefRetReg[1]) CheckOffset[1]<=PrefOffset[1];
				else if (MemPUSH[1] | PrefCallReg[1]) CheckOffset[1]<=ADR_B[14]-36'd8;
					else if (MemPOP[1] | PrefRetReg[1]) CheckOffset[1]<=ADR_B[14];
							else case (MemAMode[1])
								3'b000 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b001 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b010 : CheckOffset[1]<=MemGPROffset[1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b011 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+MemGPROffset[1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b100 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b101 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b110 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+MemGPROffset[1]+{33'd0,MemSecondCycle[1],3'd0};
								3'b111 : CheckOffset[1]<=ADR_B[{1'b0,MemSEL[1]}<<1]+MemGPROffset[1]+{33'd0,MemSecondCycle[1],3'd0};
								endcase
							
		// Base address limits and access rights
		if (FMULACCMemACT & FMULACCDSTReg[4])
				begin
				CheckBase[1]<=DTR_B[FMULACCMemSEL][39:0];
				CheckLL[1]<=DTR_B[FMULACCMemSEL][71:40];
				CheckUL[1]<=DTR_B[FMULACCMemSEL][103:72];
				CheckLowerSel[1]<=DTR_B[FMULACCMemSEL][127:104];
				CheckUpperSel[1]<=DTR_B[FMULACCMemSEL][151:128];
				CheckAR[1]<=DTR_B[FMULACCMemSEL][155:152];
				CheckNetwork[1]<=(CPU!=ADR_B[1+({1'b0,FMULACCMemSEL}<<1)][31:24]) & (|ADR_B[1+({1'b0,FMULACCMemSEL}<<1)][31:24]);
				CheckSelector[1]<=ADR_B[1+({1'b0,FMULACCMemSEL}<<1)][31:0];
				end
			else begin
				if (MemPOP[1] | MemPUSH[1] | PrefCallReg[1] | PrefRetReg[1])
						begin
						// stack access
						CheckBase[1]<=DTR_B[7][39:0];
						CheckLL[1]<=DTR_B[7][71:40];
						CheckUL[1]<=DTR_B[7][103:72];
						CheckLowerSel[1]<=DTR_B[7][127:104];
						CheckUpperSel[1]<=DTR_B[7][151:128];
						CheckAR[1]<=DTR_B[7][155:152];
						CheckNetwork[1]<=(CPU!=ADR_B[15][31:24]) & (|ADR_B[15][31:24]);
						CheckSelector[1]<=ADR_B[15][31:0];
						end
					else begin
						if (MemReq[1])
							begin
							// data transactions
							CheckBase[1]<=DTR_B[MemSEL[1]][39:0];
							CheckLL[1]<=DTR_B[MemSEL[1]][71:40];
							CheckUL[1]<=DTR_B[MemSEL[1]][103:72];
							CheckLowerSel[1]<=DTR_B[MemSEL[1]][127:104];
							CheckUpperSel[1]<=DTR_B[MemSEL[1]][151:128];
							CheckAR[1]<=DTR_B[MemSEL[1]][155:152];
							CheckNetwork[1]<=(CPU!=ADR_B[1+({1'b0,MemSEL[1]}<<1)][31:24]) & (|ADR_B[1+({1'b0,MemSEL[1]}<<1)][31:24]);
							CheckSelector[1]<=ADR_B[1+({1'b0,MemSEL[1]}<<1)][31:0];
							end
							else begin
							// code fetch
							CheckBase[1]<=DTR_B[6][39:0];
							CheckLL[1]<=DTR_B[6][71:40];
							CheckUL[1]<=DTR_B[6][103:72];
							CheckLowerSel[1]<=DTR_B[6][127:104];
							CheckUpperSel[1]<=DTR_B[6][151:128];
							CheckAR[1]<=DTR_B[6][155:152];
							CheckNetwork[1]<=(CPU!=ADR_B[13][31:24]) & (|ADR_B[13][31:24]);
							CheckSelector[1]<=ADR_B[13][31:0];
							end
					end
				end
		// forming data to memory
		if (PrefCallReg[1]) CheckData[1]<=MemGPR[1][63:0];
			else if (MemPUSH[1] & (MemCNT[1]==2'b10)) CheckData[1]<=MemAFR[1];
					else if (MemPUSH[1] & (MemCNT[1]==2'b01)) CheckData[1]<=MemGPR[1][127:64];
							else if (MemPUSH[1] & MemSecondCycle[1]) CheckData[1]<=MemGPR[1][63:0];
									else if (MemPUSH[1] & (MemCNT[1]==2'b00)) CheckData[1]<=ADR_B[MemDST[1]];
											else if (MemSecondCycle[1]) CheckData[1]<=MemGPR[1][127:64];
													else CheckData[1]<=MemGPR[1][63:0];
		// tag
		if (FMULACCMemACT & FMULACCDSTReg[4]) CheckTag[1]<={7'b1100000, FMULACCTAGo};
			else if ((PrefCallReg[1] | PrefRetReg[1]) | (~MemReq[1] & ~PrefCallReg[1] & ~PrefRetReg[1]))
						begin
						CheckTag[1][6:4]<=3'b110;
						CheckTag[1][3]<=PrefCallReg[1] | PrefRetReg[1];
						CheckTag[1][2:0]<=PrefTag[1];
						CheckTag[1][7]<=1'b0;
						end
					else begin
						CheckTag[1][3:0]<=MemDST[1];
						CheckTag[1][4]<=(MemSecondCycle[1] & MemLDST[1]) | (~MemLDST[1] & (MemCNT[1]==2'b01)) | MemADRPushPop[1];
						CheckTag[1][5]<=(MemPUSH[1] & (MemCNT[1]==2'b10))|(MemPOP[1] & (MemCNT[1]==2'b00))| MemADRPushPop[1];
						CheckTag[1][6]<=1'b0;
						CheckTag[1][7]<=MemLDO[1];
						end
		end
		
	// reloading descriptor when he loaded from table
	if (DTRLoadedFlag[0])
		begin
		CheckBase[0]<=DTR_A[CheckSEL[0]][39:0];
		CheckLL[0]<=DTR_A[CheckSEL[0]][71:40];
		CheckUL[0]<=DTR_A[CheckSEL[0]][103:72];
		CheckLowerSel[0]<=DTR_A[CheckSEL[0]][127:104];
		CheckUpperSel[0]<=DTR_A[CheckSEL[0]][151:128];
		CheckAR[0]<=DTR_A[CheckSEL[0]][155:152];
		end
	if (DTRLoadedFlag[1])
		begin
		CheckBase[1]<=DTR_B[CheckSEL[1]][39:0];
		CheckLL[1]<=DTR_B[CheckSEL[1]][71:40];
		CheckUL[1]<=DTR_B[CheckSEL[1]][103:72];
		CheckLowerSel[1]<=DTR_B[CheckSEL[1]][127:104];
		CheckUpperSel[1]<=DTR_B[CheckSEL[1]][151:128];
		CheckAR[1]<=DTR_B[CheckSEL[1]][155:152];
		end

	//
	// output stage
	//
	// local memory access activation
	/*ACT<=(ACT & ~NEXT) | (CheckNext[0] & CheckACT[0] & CheckAR[0][3] & ~CheckNetwork[0] & ~CheckAR[0][2] & (CheckOffset[0][36:5]>=CheckLL[0]) & (CheckOffset[0][36:5]<CheckUL[0]) & (CheckCMD[0] | CheckAR[0][1]) & 
									(~CheckCMD[0] | CheckAR[0][0])) | (DLMachine_A==LBS) | (DLMachine_A==LLSS) | (DLMachine_A==LSLS) |
									((DLMachine_A==STS) & CheckTag[0][6] & CheckTag[0][5] & ~CheckTag[0][4] & ~CheckTag[0][3]) |
						 (CheckNext[1] & CheckACT[1] & CheckAR[1][3] & ~CheckNetwork[1] & ~CheckAR[1][2] & (CheckOffset[1][36:5]>=CheckLL[1]) & (CheckOffset[1][36:5]<CheckUL[1]) & (CheckCMD[1] | CheckAR[1][1]) & 
									(~CheckCMD[1] | CheckAR[1][0])) | (DLMachine_B==LBS) | (DLMachine_B==LLSS) | (DLMachine_B==LSLS) |
									((DLMachine_B==STS) & CheckTag[1][6] & CheckTag[1][5] & ~CheckTag[1][4] & ~CheckTag[1][3]);*/
	ACT<=(ACT & ~NEXT) | (CheckNext[0] & CheckNode[0]) | (CheckNext[1] & CheckNode[1]);
	// stream access activation
	//StreamACT<=(StreamACT & ~StreamNEXT) | (CheckACT[0] & CheckAR[0][3] & ~CheckNetwork[0] & CheckAR[0][2] & CheckNext[0]) |
	//										(CheckACT[1] & CheckAR[1][3] & ~CheckNetwork[1] & CheckAR[1][2] & CheckNext[1]);
	StreamACT<=(StreamACT & ~StreamNEXT) | (CheckStreamNode[0] & CheckNext[0]) | (CheckStreamNode[1] & CheckNext[1]);
	
	// network access activation
	NetACT<=(NetACT & ~NetNEXT) | (CheckNext[0] & CheckNetNode[0]) | (CheckNext[1] & CheckNetNode[1]);
	
	if ((~ACT | NEXT) & (~StreamACT | StreamNEXT) & (~NetACT | NetNEXT))
		begin
		// command
		CMD<=MemChannelSel ? (CheckCMD[1] | DescriptorLoadState[1]) : (CheckCMD[0] | DescriptorLoadState[0]);
		// operand size
		OS<=MemChannelSel ? (CheckOS[1] | {2{DescriptorLoadState[1]}}) : (CheckOS[0] | {2{DescriptorLoadState[0]}});
		// forming physical address
		ADDRESS[2:0]<=MemChannelSel ? (DescriptorLoadState[1] ? 3'b000 : CheckOffset[1][2:0]) : (DescriptorLoadState[0] ? 3'b000 : CheckOffset[0][2:0]);
		ADDRESS[3]<=MemChannelSel ? (DescriptorLoadState[1] ? (DLMachine_B==LLSS) : CheckOffset[1][3]) : (DescriptorLoadState[0] ? (DLMachine_A==LLSS) : CheckOffset[0][3]);
		ADDRESS[4]<=MemChannelSel ? (DescriptorLoadState[1] ? (DLMachine_B==LSLS) : CheckOffset[1][4]) : (DescriptorLoadState[0] ? (DLMachine_A==LSLS) : CheckOffset[0][4]);
		ADDRESS[44:5]<=MemChannelSel ? (DescriptorLoadState[1] ? DTBASE + {16'd0, DLSelector[1]} : (CheckNetwork[1] ? {8'd0,CheckOffset[1][36:5]} : CheckBase[1]+{8'd0,(CheckOffset[1][36:5]-CheckLL[1])})) :
										(DescriptorLoadState[0] ? DTBASE + {16'd0, DLSelector[0]} : (CheckNetwork[0] ? {8'd0,CheckOffset[0][36:5]} : CheckBase[0]+{8'd0,(CheckOffset[0][36:5]-CheckLL[0])}));
		// offset
		OFFSET<=MemChannelSel ? CheckOffset[1][36:0] : CheckOffset[0][36:0];
		// selector (for network accesses)
		SELECTOR<=MemChannelSel ? CheckSelector[1] : CheckSelector[0];
		// data to memory
		DTo<=MemChannelSel ? CheckData[1] : CheckData[0];
		// tag
		TAGo[0]<=MemChannelSel ? (DescriptorLoadState[1] ? (DLMachine_B==LLSS) : CheckTag[1][0]) : (DescriptorLoadState[0] ? (DLMachine_A==LLSS) : CheckTag[0][0]);
		TAGo[1]<=MemChannelSel ? (DescriptorLoadState[1] ? (DLMachine_B==LSLS) : CheckTag[1][1]) : (DescriptorLoadState[0] ? (DLMachine_A==LSLS) : CheckTag[0][1]);
		TAGo[4:2]<=MemChannelSel ? (DescriptorLoadState[1] ? CheckSEL[1] : CheckTag[1][4:2] | {((DLMachine_B==STS) & CheckTag[1][6] & CheckTag[1][5] & ~CheckTag[1][4] & ~CheckTag[1][3]), 2'b00}) :
									(DescriptorLoadState[0] ? CheckSEL[0] : CheckTag[0][4:2] | {((DLMachine_A==STS) & CheckTag[0][6] & CheckTag[0][5] & ~CheckTag[0][4] & ~CheckTag[0][3]), 2'b00});
		TAGo[5]<=MemChannelSel ? (DescriptorLoadState[1] ? 1'b0 : CheckTag[1][5]) : (DescriptorLoadState[0] ? 1'b0 : CheckTag[0][5]);
		TAGo[6]<=MemChannelSel ? (DescriptorLoadState[1] ? 1'b1 : CheckTag[1][6]) : (DescriptorLoadState[0] ? 1'b1 : CheckTag[0][6]);
		TAGo[7]<=MemChannelSel ? (DescriptorLoadState[1] ? 1'b0 : CheckTag[1][7]) : (DescriptorLoadState[0] ? 1'b0 : CheckTag[0][7]);
		TAGo[8]<=MemChannelSel;
		end

	//
	// Loading DT registers
	//
	DescriptorLoadState[0]<=(DLMachine_A==CSS)|(DLMachine_A==LBS)|(DLMachine_A==LLSS)|(DLMachine_A==LSLS);
	DescriptorLoadState[1]<=(DLMachine_B==CSS)|(DLMachine_B==LBS)|(DLMachine_B==LLSS)|(DLMachine_B==LSLS);
	// state machine for descriptor loading
		case (DLMachine_A)
				// wait state
				WS:	if (LoadNewDSC[0] | LoadLowerDSC[0] | LoadUpperDSC[0]) DLMachine_A<=CSS;
						else if (AccessError[0]) DLMachine_A<=AERSS;
								else DLMachine_A<=WS;
				// checking selector value
				CSS: if (DLSelector[0]==24'd0) DLMachine_A<=ZSS;
						else if (DLSelector[0]>=DTLIMIT) DLMachine_A<=INVSS;
							else DLMachine_A<=LBS;
				// load base address and access rights
				LBS: if ((~ACT | NEXT) & ~MemChannelSel) DLMachine_A<=LLSS;
						else DLMachine_A<=LBS;
				// load link selectors and check descriptor type
				LLSS: if ((~ACT | NEXT) & ~MemChannelSel) DLMachine_A<=LSLS;
						else DLMachine_A<=LLSS;
				// load segment limits
				LSLS: if ((~ACT | NEXT) & ~MemChannelSel) DLMachine_A<=RWS;
						else DLMachine_A<=LSLS;
				// waiting for transaction retry condition
				RWS: if (~RetryTransactionFlag[0]) DLMachine_A<=RWS;
						else if (~ValidDescriptor[0]) DLMachine_A<=INVOBS;
								else DLMachine_A<=WS;
				// zero selector reporting
				ZSS: DLMachine_A<=STS;
				// invalid selector reporting
				INVSS: DLMachine_A<=STS;
				// invalid object reporting (CPL or type)
				INVOBS: DLMachine_A<=STS;
				// access error
				AERSS: DLMachine_A<=STS;
				// skip transaction after error reporting
				STS: if (CheckTag[0][6] & CheckTag[0][5] & ~CheckTag[0][4] & ~CheckTag[0][3] & ~CheckNext[0]) DLMachine_A<=STS;
						else DLMachine_A<=WS;
				endcase
		case (DLMachine_B)
				// wait state
				WS:	if (LoadNewDSC[1] | LoadLowerDSC[1] | LoadUpperDSC[1]) DLMachine_B<=CSS;
						else if (AccessError[1]) DLMachine_B<=AERSS;
								else DLMachine_B<=WS;
				// checking selector value
				CSS: if (DLSelector[1]==24'd0) DLMachine_B<=ZSS;
						else if (DLSelector[1]>=DTLIMIT) DLMachine_B<=INVSS;
							else DLMachine_B<=LBS;
				// load base address and access rights
				LBS: if ((~ACT | NEXT) & MemChannelSel) DLMachine_B<=LLSS;
						else DLMachine_B<=LBS;
				// load link selectors and check descriptor type
				LLSS: if ((~ACT | NEXT) & MemChannelSel) DLMachine_B<=LSLS;
						else DLMachine_B<=LLSS;
				// load segment limits
				LSLS: if ((~ACT | NEXT) & MemChannelSel) DLMachine_B<=RWS;
						else DLMachine_B<=LSLS;
				// waiting for transaction retry condition
				RWS: if (~RetryTransactionFlag[1]) DLMachine_B<=RWS;
						else if (~ValidDescriptor[1]) DLMachine_B<=INVOBS;
								else DLMachine_B<=WS;
				// zero selector reporting
				ZSS: DLMachine_B<=STS;
				// invalid selector reporting
				INVSS: DLMachine_B<=STS;
				// invalid object reporting (CPL or type)
				INVOBS: DLMachine_B<=STS;
				// access error
				AERSS: DLMachine_B<=STS;
				// skip transaction after error reporting
				STS: if (CheckTag[1][6] & CheckTag[1][5] & ~CheckTag[1][4] & ~CheckTag[1][3] & ~CheckNext[1]) DLMachine_B<=STS;
						else DLMachine_B<=WS;
				endcase
	// temporary selector register
	if (DLMachine_A==WS) for (i9=0; i9<24; i9=i9+1) DLSelector[0][i9]<=(LoadNewDSC[0] & CheckSelector[0][i9])|
															(LoadLowerDSC[0] & CheckLowerSel[0][i9])|
															(LoadUpperDSC[0] & CheckUpperSel[0][i9]);
	if (DLMachine_B==WS) for (i10=0; i10<24; i10=i10+1) DLSelector[1][i10]<=(LoadNewDSC[1] & CheckSelector[1][i10])|
															(LoadLowerDSC[1] & CheckLowerSel[1][i10])|
															(LoadUpperDSC[1] & CheckUpperSel[1][i10]);
				
	// 0 - base and AR, 1 - link selectors, 2 - limits
	for (i11=0; i11<8; i11=i11+1)
				begin
				if (DTRWriteFlag[0][i11])
					case (TAGiReg[1:0])
						2'b00 : begin
								DTR_A[i11][39:0]<=DTi[39:0];
								DTR_A[i11][153:152]<=DTi[61:60];
								DTR_A[i11][154]<=DTi[56];
								DTR_A[i11][155]<=DTi[57] & (CPL[0]<=DTi[59:58]) & ((TASKID[0]==DTi[55:40]) | (~(|TASKID[0])) | (~(|DTi[55:40])));
								end
						2'b01 : begin
								DTR_A[i11][127:104]<=DTi[23:0];
								DTR_A[i11][151:128]<=DTi[55:32];
								end
						2'b10 :	begin
								DTR_A[i11][103:40]<=DTi;
								end
						2'b11 :	DTR_A[i11]<=156'hB000000000000FFFFFFFF000000000000000000;
						endcase
				if (DTRWriteFlag[1][i11])
					case (TAGiReg[1:0])
						2'b00 : begin
								DTR_B[i11][39:0]<=DTi[39:0];
								DTR_B[i11][153:152]<=DTi[61:60];
								DTR_B[i11][154]<=DTi[56];
								DTR_B[i11][155]<=DTi[57] & (CPL[1]<=DTi[59:58]) & ((TASKID[1]==DTi[55:40]) | (~(|TASKID[1])) | (~(|DTi[55:40])));
								end
						2'b01 : begin
								DTR_B[i11][127:104]<=DTi[23:0];
								DTR_B[i11][151:128]<=DTi[55:32];
								end
						2'b10 :	begin
								DTR_B[i11][103:40]<=DTi;
								end
						2'b11 :	DTR_B[i11]<=156'hB000000000000FFFFFFFF000000000000000000;
						endcase
				end
	DTRLoadedFlag[0]<=DTRWriteFlag[0][8] & (TAGiReg[1:0]==2'b10);
	DTRLoadedFlag[1]<=DTRWriteFlag[1][8] & (TAGiReg[1:0]==2'b10);
	// flag to enable check transaction again
	RetryTransactionFlag[0]<=DTRLoadedFlag[0];
	RetryTransactionFlag[1]<=DTRLoadedFlag[1];

	// valid descriptor flag
	if (DTRWriteFlag[0][8] & (TAGiReg[1:0]==2'b00))
		begin
		ValidDescriptor[0]<=DTi[57] & (CPL[0]<=DTi[59:58]) & ((TASKID[0]==DTi[55:40]) | (~(|TASKID[0])) | (~(|DTi[55:40])));
		InvalidType[0]<=~DTi[57];
		InvalidCPL[0]<=(CPL[0]>DTi[59:58]);
		InvalidTaskID[0]<=(TASKID[0]!=DTi[55:40]) & (|TASKID[0]) & (|DTi[55:40]);
		InvalidSelector[0]<=CheckSelector[0][23:0];
		end
	if (DTRWriteFlag[1][8] & (TAGiReg[1:0]==2'b00))
		begin
		ValidDescriptor[1]<=DTi[57] & (CPL[1]<=DTi[59:58]) & ((TASKID[1]==DTi[55:40]) | (~(|TASKID[1])) | (~(|DTi[55:40])));
		InvalidType[1]<=~DTi[57];
		InvalidCPL[1]<=(CPL[1]>DTi[59:58]);
		InvalidTaskID[1]<=(TASKID[1]!=DTi[55:40]) & (|TASKID[1]) & (|DTi[55:40]);
		InvalidSelector[1]<=CheckSelector[1][23:0];
		end
	
	// skip read operation (validate flags)
	SkipDataRead[0]<=CheckACT[0] & CheckCMD[0] & (DLMachine_A==STS) & ~CheckTag[0][6] & ~CheckTag[0][5];
	SkipDataRead[1]<=CheckACT[1] & CheckCMD[1] & (DLMachine_B==STS) & ~CheckTag[1][6] & ~CheckTag[1][5];
	if (DLMachine_A==STS) STAGReg[0]<=CheckTag[0][3:0];
	if (DLMachine_B==STS) STAGReg[1]<=CheckTag[1][3:0];
	
	end

endmodule: EU64V0T2

