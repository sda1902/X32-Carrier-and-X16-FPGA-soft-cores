module EU64X32 (
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
	input wire FFTMemNEXT, FFTNetNEXT,
	output wire FFTMemACT, FFTNetACT, FFTMemCMD,
	output wire [41:0] FFTMemADDR,
	output wire [33:0] FFTMemOFFSET,
	output wire [31:0] FFTMemSEL,
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

integer i0, i1, i2, i3, i4, i5, i6, i7, i8;

// general purpose register file
reg [127:0] GPR [31:0];
// arithmetic flags
reg [31:0] AFR [31:0];
reg [31:0] FlagWrite;
// address register file
reg [36:0] ADR [15:0];
// GPR valid flags
reg [31:0] GPVFReg;
logic [31:0] GPVFINVD;

// FACC unit resources
logic [25:0] FMULACCBus;
reg [25:0] FMULACCReg; //0 - ACT, 1 - CMD,  6:2 - CtrlOffsetReg, 9:7 - ctrlSel, 14:10 - DataOffsetReg, 17:15 - DataSel, 22:18 - DST, 25:23 - data format
reg FMULACCACTReg, FMULACCCMDReg, FFT32NEXTReg;
logic FMULACCNEXT;
reg [4:0] FMULACCDSTReg;
reg [2:0] FMULACCDataSelReg, FMULACCCtrlSelReg;
reg [34:0] FMULACCDataOffsetReg;
reg [33:0] FMULACCCtrlOffsetReg;
logic FMULACCRDY, FMULACCSIGN, FMULACCZERO, FMULACCINF, FMULACCNAN;
logic [31:0] FMULACCR;
logic [4:0] FMULACCDST;
logic FMULACCMemACT, FMULACCSIZE, FMULACCTAGo;
logic [2:0] FMULACCMemSEL;
logic [34:0] FMULACCMemOffset;
reg FMULACCDRDYFlag;
reg [5:0] FMULACCBypassControlOffsetReg, FMULACCBypassDataOffsetReg, FFTBypassReg;
logic SkipFifoData, SkipFifoFlag;
reg [4:0] FFTParReg;

// FFT resources
logic FFT32NEXT;
reg [31:0] FFTDataSelReg, FFTCtrlSelReg;
reg [33:0] FFTDataBaseReg, FFTCtrlBaseReg;
reg [18:0] FFTIndexReg;

// FADD unit resources
logic [26:0] FADDInstBus;
reg [26:0] FADDInstReg;
reg [127:0] FADDAReg, FADDBReg;
reg [2:0] FADDSAReg, FADDSBReg, FADDSDReg;
reg [4:0] FADDDSTReg, FADDDSTR;
reg [5:0] FADDBypassAReg, FADDBypassBReg;
reg FADDACTReg, FADDRDYR;
reg [1:0] FADDCMDReg;
logic [127:0] FADDR;
logic [4:0] FADDDST;
logic [2:0] FADDSR;
logic FADDRDY, FADDZero, FADDSign, FADDInf, FADDNaN;

// FMUL resources
logic [26:0] FMULInstBus;
reg [26:0] FMULInstReg;
reg [127:0] FMULAReg, FMULBReg;
reg FMULACTReg;
reg [2:0] FMULSAReg, FMULSBReg, FMULSDReg;
reg [4:0] FMULDSTReg;
reg [5:0] FMULBypassAReg, FMULBypassBReg;
logic [127:0] FMULR;
logic [127:0] FMULRQ;
logic [4:0] FMULDST [1:0];
logic [2:0] FMULSR;
logic [1:0] FMULRDY, FMULZero, FMULSign, FMULInf, FMULNaN;
reg [1:0] FMULRDYR, FMULCMDReg;
reg [4:0] FMULDSTR [1:0];

// FDIV unit resources
logic [26:0] FDIVInstBus;
reg [26:0] FDIVInstReg;
reg [127:0] FDIVAReg, FDIVBReg;
reg FDIVACTReg;
reg [1:0] FDIVCMDReg;
reg [2:0] FDIVSAReg, FDIVSBReg, FDIVSDReg;
reg [4:0] FDIVDSTReg;
reg [5:0] FDIVBypassAReg, FDIVBypassBReg;
logic [127:0] FDIVR;
logic [4:0] FDIVDST;
logic [2:0] FDIVSR;
logic FDIVRDY, FDIVZero, FDIVInf, FDIVNaN, FDIVSign, FDIVNEXT;

// Integer ALU Resources
logic [27:0] ALUInstBus;
reg [27:0] ALUInstReg;
reg ALUACTReg, ALURDYR;
reg [63:0] ALUAReg, ALUBReg, ALUDReg;
reg [1:0] ALUSAReg, ALUSBReg, ALUSDReg;
reg [2:0] ALUOpCODEReg;
reg [4:0] ALUDSTReg, ALUDSTR;
reg [5:0] ALUBypassAReg, ALUBypassBReg, ALUBypassDReg;
logic [63:0] ALUR;
logic [4:0] ALUDST;
logic ALURDY, ALUOVR, ALUSign, ALUZero;
logic [15:0] ALUCOUT;
logic [1:0] ALUSR;

// Parallel shifter resources
logic [28:0] ShiftInstBus;
reg [28:0] ShiftInstReg;
reg [63:0] ShiftAReg, ShiftDReg;
reg [5:0] ShiftBReg, ShiftBypassAReg, ShiftBypassBReg, ShiftBypassDReg;
reg [6:0] ShiftCReg;
reg [4:0] ShiftDSTReg, ShiftDSTR;
reg [2:0] ShiftOPRReg;
reg [1:0] ShiftSAReg, ShiftDSTSR;
reg ShiftACTReg, ShiftRDYR;
logic [63:0] ShiftR;
logic [4:0] ShiftDST;
logic ShiftRDY, ShiftOVR, ShiftZERO, ShiftCOUT, ShiftSign;
logic [1:0] ShiftSR;

// miscellaneous unit resources
logic [27:0] MiscInstBus;
reg [27:0] MiscInstReg;
reg [2:0] MiscOPRReg;
reg MiscACTReg, MiscRDYR;
reg [127:0] MiscAReg;
reg [15:0] MiscBReg;
reg [4:0] MiscDSTReg, MiscDSTR;
reg [2:0] MiscSAReg, MiscSBReg, MiscSDReg;
reg [15:0] MiscCINReg;
reg [5:0] MiscBypassAReg, MiscBypassBReg;
logic [127:0] MiscR;
logic [4:0] MiscDST;
logic [2:0] MiscSR;
logic MiscRDY, MiscCOUT, MiscOVR, MiscSign, MiscZero, MiscNaN;

// data movement resources
reg [27:0] MovInstReg;
logic [27:0] MovInstBus;
reg [127:0] MovReg;
reg [2:0] MovSR;
reg [5:0] CopyBypassReg, LIBypassReg;
logic [127:0] MovBusDST, MovBusSRC;
reg MOVSign, MOVZF;

// prefetch control resources
logic [28:0] PrefInstBus;
reg [28:0] PrefInstReg;
reg [5:0] PrefBypassReg;
logic IFetch, InsRDY, PrefACT, PrefCall, PrefRet, PrefEMPTY, PrefERST, CodeError;
logic [3:0] IVF;
logic [127:0] INST;
logic [36:0] PrefOffset;
logic [34:0] PrefRealIP;
logic [2:0] PrefTag;
logic [63:0] PrefDataBus;
reg PrefCC, PrefCallReg, PrefRetReg;
logic SeqEMPTY, MFLag;
reg [63:0] PrefR;

// memory read/write resources
logic [28:0] MemInstBus;
reg [28:0] MemInstReg;
reg MemDelayFlag, MemFifoFullFlag;
logic [226:0] MemFifoBus;
logic MemFifoEmpty;
wire [5:0] MemFifoUsedW;
reg MemBusy, MemReq, MemLoadSel, MemOpr, MemADRPushPop, MemPUSH, MemPOP, MemLDST, MemLDO, MemLoadOffset,
	MemSecondCycle, MemReadAR, MemLSelNode, MemNext, MemLoadImmediate, MemIncrement, MemAdd;
reg [2:0] MemSEL, MemSize, MemAMode;
reg [31:0] MemAFR;
reg [36:0] ARData, MemGPROffset;
reg [127:0] MemGPR;
reg [4:0] MemDST;
reg [4:0] MemoryOSValue;
reg [15:0] MemASelNode, MemImmediateBus;
reg [1:0] MemCNT;
reg [2:0] SZiReg;
reg [8:0] TAGiReg, MemAddOffset;
reg [4:0] MemAOffset;
logic [31:0] MemNewSel;

// check memory access stage
reg CheckACT, CheckCMD, CheckNetwork, CheckNext, CheckPref;
reg [1:0] CheckOS;
reg [36:0] CheckOffset;
reg [31:0] CheckLL, CheckUL, CheckSelector;
reg [3:0] CheckAR;
reg [39:0] CheckBase;
reg [23:0] CheckLowerSel, CheckUpperSel;
reg [63:0] CheckData;
reg [8:0] CheckTag;
reg [2:0] CheckSEL;

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
reg [155:0] DTR [7:0];
reg [8:0] DTRWriteFlag;
reg DTRLoadedFlag, DescriptorLoadState, ValidDescriptor, LoadNewDSC, LoadLowerDSC, LoadUpperDSC, RetryTransactionFlag;
reg [23:0] DLSelector;
// state machine for descriptor loading
reg [3:0] DLMachine;
localparam WS=4'd0, CSS=4'd1, ZSS=4'd2, INVSS=4'd3, LBS=4'd4, LLSS=4'd5, LSLS=4'd6, RWS=4'd7, INVOBS=4'd8, STS=4'd9, AERSS=4'd10;
reg SkipDataRead, InvalidType, InvalidCPL, InvalidTaskID, AccessError;
reg [4:0] STAGReg;
reg [23:0] InvalidSelector;


// wire result flags
reg [31:0] GPRByteNode, GPRWordNode, GPRDwordNode, GPRQwordNode, GPROwordNode, FADDSelNode, FMULSelNode, FMULQSelNode, 
			FMULACCSelNode, FDIVSelNode, ALUSelNode, ShiftSelNode, MiscSelNode, MovSelNode, MemSelNode, MemARSelNode,
			FFTSelNode, LFRNode, PrefSelNode, MemFSelNode;

/*
===========================================================================================================
				Modules
===========================================================================================================
*/
// 			memory operations queue
// 27:0 	- MemInstReg
// 64:28 	- Offset from GPR
// 192:65	- Data to memory
// 224:193	- AFR content
// 225		- PrefCall flag
// 226		- PrefRet flag
// 
//	0-ACT, 4:1-CMD, 9:5-Aditional offset, 12:10-AMODE, 17:13-Offset Register, 20:18-MAR, 25:21-DST/SRC, 28:26-Format
//
sc_fifo MemFIFO (.data({PrefRet, PrefCall, AFR[MemInstReg[25:21]], PrefCall ? {91'd0,PrefRealIP,2'b00}:GPR[MemInstReg[25:21]], GPR[MemInstReg[17:13]][36:0], MemInstReg[28:1]}),
				.wrreq((MemInstReg[0] & ~MemDelayFlag & ~MemFifoFullFlag) | PrefCall | PrefRet),
				.rdreq((~MemBusy | (MemNext & ~FMULACCMemACT) | MemLoadOffset | (MemLoadSel & (MemDST!={CheckSEL,CheckACT})) | MemReadAR) & ~MemCNT[1] & ~MemCNT[0]),
				.clock(CLK), .sclr(~RESET), .q(MemFifoBus), .empty(MemFifoEmpty), .almost_empty(), .usedw(MemFifoUsedW));
defparam MemFIFO.LPM_WIDTH=227, MemFIFO.LPM_NUMWORDS=64, MemFIFO.LPM_WIDTHU=6;

// Instruction prefetcher
Prefetcher32M Pref (.CLK(CLK), .RESET(RESET), .CSELCHG(MemASelNode[13]), .DRDY(DRDY), .TAGi(TAGi), .DTi(DTi), .IFETCH(IFetch), .IRDY(InsRDY),
				.VF(IVF), .IBUS(INST), .NEXT(~MemReq & MemNext & ~FMULACCMemACT & ~PrefCallReg & ~PrefRetReg), .ACT(PrefACT), .OFFSET(PrefOffset), .TAGo(PrefTag),
				// instruction for prefetcher
				.CBUS(PrefInstReg), .GPRBUS(PrefDataBus),
				// flags
				.CC(PrefCC), .MOVFLAG(MFLag | MemInstReg[0]), .CALL(PrefCall), .RET(PrefRet), .ERST(PrefERST), .RIP(PrefRealIP), .CEXEC(CEXEC),
				.ESMSG(ESMSG), .CONTINUE(CONTINUE), .STOP(CSTOP | ESTB),
				// interface to message and memory control system
				.GPINDX(PARREG),
				.SMSG(MSGREQ), .MALLOC(MALLOCREQ), .GPAR(PARREQ), .EMSG(ENDMSG), .BKPT(BKPT), .EMPTY(PrefEMPTY), .HALT(HALT), .PARAM(PARAM),
				.SLEEP(NPCS), .SMSGBKPT(SMSGBKPT),
				// code fetch error
				.CFERROR(CodeError),
				// Fatal error reporting
				.FATAL(FATAL)
				);


// Instruction sequencer
Sequencer32 Seq (.CLK(CLK), .RESET(RESET), .IRDY(InsRDY), .VF(IVF), .IBUS(INST),
				.IRD(IFetch), .GPRVF(GPVFReg), .GPRINVD(GPVFINVD), .EMPTY(SeqEMPTY), .MOVFLAG(MFLag), .FDIVRDY(~FDIVInstReg[0]), .FMULACCRDY(~FMULACCReg[0]),
				.MEMRDY(~MemDelayFlag), .FADDBus(FADDInstBus), .FMULBus(FMULInstBus),
				.FMULACCBus(FMULACCBus), .FDIVBus(FDIVInstBus), .ALUBus(ALUInstBus), .ShiftBus(ShiftInstBus), .MiscBus(MiscInstBus), .MovBus(MovInstBus),
				.MemBus(MemInstBus), .CtrlBus(PrefInstBus));

// 32-bit multiplier/accumulator
Neuro32 FMULACC (.CLK(CLK), .RESET(RESET), .ACT(FMULACCACTReg & ~FMULACCCMDReg), .MAERR(CheckACT & CheckCMD & (DLMachine==STS) & (CheckTag[8:1]==8'b11000000)),
				.NEXT(FMULACCNEXT), .DSTi(FMULACCDSTReg), .DataSEL(FMULACCDataSelReg), .CtrlSEL(FMULACCCtrlSelReg), .DataOffset(FMULACCDataOffsetReg),
				.CtrlOffset(FMULACCCtrlOffsetReg), .RDY(FMULACCRDY), .SIGN(FMULACCSIGN), .ZERO(FMULACCZERO), .INF(FMULACCINF), .NAN(FMULACCNAN),
				.R(FMULACCR), .DSTo(FMULACCDST),
				// memory interface
				.MemNEXT(MemNext), .MemACT(FMULACCMemACT), .MemSEL(FMULACCMemSEL), .MemOffset(FMULACCMemOffset), .SIZE(FMULACCSIZE),
				.TAGo(FMULACCTAGo), .DRDY(FMULACCDRDYFlag | SkipFifoFlag),
				.TAGi((TAGiReg[0] & FMULACCDRDYFlag) | (SkipFifoData & ~FMULACCDRDYFlag)), .DTi(DTi));

SFifo SkipFifo(.CLK(CLK), .RST(RESET), .D(CheckTag[0]), .WR(CheckACT & CheckCMD & (DLMachine==STS) & (CheckTag[8:1]==8'b11000000)),
				.Q(SkipFifoData), .VALID(SkipFifoFlag), .RD(~FMULACCDRDYFlag));


// 32-bit FFT processor
fft32 FFT32(.CLK(CLK), .RESET(RESET), .CPU(CPU), .DTBASE(DTBASE), .DTLIMIT(DTLIMIT), .CPL(CPL), .TASKID(TASKID), .CPSR(CPSR),
				// command interface
				.NEXT(FFT32NEXT), .ACT(FMULACCACTReg & FMULACCCMDReg), .DataObject(FFTDataSelReg), .ControlObject(FFTCtrlSelReg),
				.DataOffset(FFTDataBaseReg+FMULACCDataOffsetReg[34:1]), .ControlOffset(FFTCtrlBaseReg+FMULACCCtrlOffsetReg),
				.PAR(FFTParReg), .INDEX(FFTIndexReg),
				// memory interface
				.MemNEXT(FFTMemNEXT), .NetNEXT(FFTNetNEXT), .MemACT(FFTMemACT), .NetACT(FFTNetACT), .MemCMD(FFTMemCMD), .MemADDR(FFTMemADDR),
				.MemOFFSET(FFTMemOFFSET), .MemSEL(FFTMemSEL), .MemDO(FFTMemDO), .MemTO(FFTMemTO), .MemDRDY(DRDY), .MemDI(DTi), .MemTI(TAGi),
				// error report interface
				.ESTB(FFTESTB), .ECD(FFTECD), .ECPSR(FFTCPSR));

// 128-bit adder module
FPADD128V FPAdder(.CLK(CLK), .RESET(RESET), .ACT(FADDACTReg), .CMD(FADDCMDReg), .A(FADDAReg), .B(FADDBReg),
		.SA(FADDSAReg), .SB(FADDSBReg), .SD(FADDSDReg), .DSTI(FADDDSTReg), .RDY(FADDRDY), .SIGN(FADDSign), .ZERO(FADDZero), .INF(FADDInf),
		.NAN(FADDNaN), .SR(FADDSR), .DSTO(FADDDST), .R(FADDR));

// 128-bit FP multiplier
FPMUL128V FPMult (.CLK(CLK), .RESET(RESET), .ACT(FMULACTReg), .CMD(FMULCMDReg), .DSTI(FMULDSTReg), .A(FMULAReg), .B(FMULBReg),
				.SA(FMULSAReg), .SB(FMULSBReg), .SD(FMULSDReg), .RDYSD(FMULRDY[0]), .RDYQ(FMULRDY[1]), .ZEROSD(FMULZero[0]), .SIGNSD(FMULSign[0]),
				.INFSD(FMULInf[0]), .NANSD(FMULNaN[0]), .ZEROQ(FMULZero[1]), .SIGNQ(FMULSign[1]), .INFQ(FMULInf[1]),
				.NANQ(FMULNaN[1]), .SR(FMULSR), .DSTSD(FMULDST[0]), .DSTQ(FMULDST[1]), .RSD(FMULR), .RQ(FMULRQ));

// FP 64-bit divisor
FPDIV128V FDIV (.CLK(CLK), .ACT(FDIVACTReg), .CMD(FDIVCMDReg), .SA(FDIVSAReg), .SB(FDIVSBReg), .SD(FDIVSDReg), .RST(RESET), .A(FDIVAReg), .B(FDIVBReg),
				.DSTi(FDIVDSTReg), .R(FDIVR), .DSTo(FDIVDST), .RDY(FDIVRDY), .Zero(FDIVZero), .Inf(FDIVInf),
				.NaN(FDIVNaN), .Sign(FDIVSign), .SR(FDIVSR), .NEXT(FDIVNEXT));

// integer ALU
ALU64X32 IntALU (.CLK(CLK), .ACT(ALUACTReg), .DSTi(ALUDSTReg), .A(ALUAReg), .B(ALUBReg), .D(ALUDReg),
				.OpCODE(ALUOpCODEReg), .SA(ALUSAReg), .SB(ALUSBReg), .SD(ALUSDReg), .R(ALUR), .COUT(ALUCOUT),
				.DSTo(ALUDST), .SR(ALUSR), .RDY(ALURDY), .OVR(ALUOVR), .Zero(ALUZero), .Sign(ALUSign));

// shifter
Shifter64X32 Sht (.CLK(CLK), .ACT(ShiftACTReg), .A(ShiftAReg), .B(ShiftBReg), .C(ShiftCReg), .D(ShiftDReg), .DSTi(ShiftDSTReg),
				.SA(ShiftSAReg), .SD(ShiftDSTSR), .OPR(ShiftOPRReg[2:0]), .R(ShiftR), .DSTo(ShiftDST), .RDY(ShiftRDY), .OVR(ShiftOVR),
				.ZERO(ShiftZERO), .SIGN(ShiftSign), .COUT(ShiftCOUT), .SR(ShiftSR));

// misc unit
Misc64X32 Misc (.CLK(CLK), .ACT(MiscACTReg), .OpCODE(MiscOPRReg), .SA(MiscSAReg), .SB(MiscSBReg), .SD(MiscSDReg), .DSTi(MiscDSTReg),
				.CIN(MiscCINReg), .A(MiscAReg), .B(MiscBReg), .RDY(MiscRDY), .ZERO(MiscZero), .NaN(MiscNaN), .SIGN(MiscSign),
				.OVR(MiscOVR), .COUT(MiscCOUT), .SR(MiscSR), .DSTo(MiscDST), .R(MiscR));

/*
===========================================================================================================
				Assignments part
===========================================================================================================
*/
assign RIP={PrefRealIP, 2'b00};

// error reporting
assign ESTB=(((DLMachine==ZSS) | (DLMachine==INVSS) | (DLMachine==AERSS)) & ~CheckTag[8] & ~CheckTag[6]) | CodeError | (DLMachine==INVOBS);
assign ECD[23:0]=CodeError ? ADR[13][23:0] : ((DLMachine==INVOBS) ? InvalidSelector : CheckSelector[23:0]);
assign ECD[24]=CodeError | LoadLowerDSC | LoadUpperDSC;
assign ECD[25]=CodeError | (DLMachine==AERSS);
assign ECD[26]=InvalidCPL & ~CodeError;
assign ECD[27]=InvalidTaskID & ~CodeError;
assign ECD[28]=InvalidType & ~CodeError;

assign CSEL=ADR[13][23:0];

/*
===========================================================================================================
				Asynchronous part
===========================================================================================================
*/
always @*
	begin

	// Next node on the check access stage
	CheckNext=(~ACT | NEXT) & (~StreamACT | StreamNEXT) & (~NetACT | NetNEXT);
	
	// next node on the memory forming stage
	MemNext=~CheckACT | (CheckNext & ((CheckAR[3] & (CheckOffset[36:5]>=CheckLL) & (CheckOffset[36:5]<CheckUL) & (CheckCMD | CheckAR[1]) & 
													(~CheckCMD | CheckAR[0])) | (CheckAR[3] & CheckAR[2]) | CheckNetwork)) |
						((DLMachine==STS) & ((CheckTag[8:3]!=6'h28) | CheckNext));
	
	// forming condition code for prefetcher
	case (PrefInstReg[28:26])
		3'd0:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][16] & ~(|PrefBypassReg)) | (FADDZero & PrefBypassReg[0]) | (FMULZero[0] & PrefBypassReg[1]) |
										(FMULZero[1] & PrefBypassReg[2]) | (ALUZero & PrefBypassReg[3]) | (ShiftZERO & PrefBypassReg[4]) | (MiscZero & PrefBypassReg[5]));
		3'd1:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][15] & ~PrefBypassReg[3] & ~PrefBypassReg[5]) | (ALUCOUT[15] & PrefBypassReg[3]) |
										(MiscCOUT & PrefBypassReg[5]));
		3'd2:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][17] & ~(|PrefBypassReg)) | (FADDSign & PrefBypassReg[0]) | (FMULSign[0] & PrefBypassReg[1]) |
										(FMULSign[1] & PrefBypassReg[2]) | (ALUSign & PrefBypassReg[3]) | (ShiftSign & PrefBypassReg[4]) | (MiscSign & PrefBypassReg[5]));
		3'd3:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][18] & ~PrefBypassReg[3] & ~PrefBypassReg[4]) | (ALUOVR & PrefBypassReg[3]) | (ShiftOVR & PrefBypassReg[4]));
		3'd4:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][19] & ~PrefBypassReg[0] & ~PrefBypassReg[1] & ~PrefBypassReg[2] & ~PrefBypassReg[5]) |
										(FADDInf & PrefBypassReg[0]) | (FMULInf[0] & PrefBypassReg[1]) | (FMULInf[1] & PrefBypassReg[2]) | (MiscOVR & PrefBypassReg[5]));
		3'd5:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][20] & ~PrefBypassReg[0] & ~PrefBypassReg[1] & ~PrefBypassReg[2] & ~PrefBypassReg[5]) |
										(FADDNaN & PrefBypassReg[0]) | (FMULNaN[0] & PrefBypassReg[1]) | (FMULNaN[1] & PrefBypassReg[2]) | (MiscNaN & PrefBypassReg[5]));
		3'd6:	PrefCC=PrefInstReg[1] ^ ((AFR[PrefInstReg[25:21]][21] & ~PrefBypassReg[4]) | (ShiftCOUT & PrefBypassReg[4]));
		3'd7:	PrefCC=1'b1;
		endcase

	// Memory operand Size forming
	MemoryOSValue[4]=MemLDST & (MemSize==3'b100);
	MemoryOSValue[3]=MemPUSH | MemPOP | (MemLDST & (MemSize==3'b011));
	MemoryOSValue[2]=MemLDST & (MemSize==3'b010);
	MemoryOSValue[1]=MemLDST & (MemSize==3'b001);
	MemoryOSValue[0]=MemLDST & (MemSize==3'b000);

	// interface to the descriptor reloading system
	// Load New sel flag
	LoadNewDSC=CheckACT & ~CheckAR[3] & ~CheckNetwork;
	// load lower segment
	LoadLowerDSC=CheckACT & CheckAR[3] & ~CheckAR[2] & (CheckOffset[36:5]<CheckLL) & ~CheckNetwork;
	// load upper segment
	LoadUpperDSC=CheckACT & CheckAR[3] & ~CheckAR[2] & (CheckOffset[36:5]>=CheckUL) & ~CheckNetwork;
	// access error by type
	AccessError=CheckACT & CheckAR[3] & ~CheckNetwork & ((~CheckCMD & ~CheckAR[1]) | (CheckCMD & ~CheckAR[0])) & ~CheckPref;
	
	MovBusDST=(GPR[MovInstReg[24:20]] & {128{~(|LIBypassReg)}}) |
				(FADDR & {128{LIBypassReg[0]}}) |
				(FMULR & {128{LIBypassReg[1]}}) |
				(FMULRQ & {128{LIBypassReg[2]}}) |
				({GPR[MovInstReg[24:20]][127:64], ALUR} & {128{LIBypassReg[3]}}) | 
				({GPR[MovInstReg[24:20]][127:64], ShiftR} & {128{LIBypassReg[4]}}) |
				(MiscR & {128{LIBypassReg[5]}});
				
	MovBusSRC=(GPR[MovInstReg[8:4]] & {128{~(|CopyBypassReg)}}) |
				(FADDR & {128{CopyBypassReg[0]}}) |
				(FMULR & {128{CopyBypassReg[1]}}) |
				(FMULRQ & {128{CopyBypassReg[2]}}) |
				({GPR[MovInstReg[8:4]][127:64], ALUR} & {128{CopyBypassReg[3]}}) |
				({GPR[MovInstReg[8:4]][127:64], ShiftR} & {128{CopyBypassReg[4]}}) |
				(MiscR & {128{CopyBypassReg[5]}});

	PrefDataBus=(GPR[PrefInstReg[25:21]][63:0] & {64{~(|PrefBypassReg)}}) | 
				(FADDR[63:0] & {64{PrefBypassReg[0]}}) |
				(FMULR[63:0] & {64{PrefBypassReg[1]}}) |
				(FMULRQ[63:0] & {64{PrefBypassReg[2]}}) |
				(ALUR & {64{PrefBypassReg[3]}}) |
				(ShiftR & {64{PrefBypassReg[4]}}) |
				(MiscR[63:0] & {64{PrefBypassReg[5]}});

	// new selector
	casez ({MemAdd,MemIncrement,MemLoadImmediate})
		3'b000: MemNewSel=MemGPROffset[31:0];
		3'b001: if (MemSize[0]) MemNewSel={MemImmediateBus,ADR[{MemSEL,1'b1}][15:0]};
					else MemNewSel={16'd0,MemImmediateBus};
		3'b01?: MemNewSel=ADR[{MemSEL,1'b1}][31:0]+{{16{MemImmediateBus[15]}},MemImmediateBus};
		3'b1??: MemNewSel=ADR[{MemSEL,1'b1}][31:0]+MemGPROffset[31:0];
		endcase
	
	end

/*
===========================================================================================================
				Synchronous part
===========================================================================================================
*/
always @(negedge RESET or posedge CLK)
if (!RESET) begin
				GPVFReg<=32'hFFFFFFFF;
				AFR[0]<=32'd0;
				AFR[1]<=32'd0;
				AFR[2]<=32'd0;
				AFR[3]<=32'd0;
				AFR[4]<=32'd0;
				AFR[5]<=32'd0;
				AFR[6]<=32'd0;
				AFR[7]<=32'd0;
				AFR[8]<=32'd0;
				AFR[9]<=32'd0;
				AFR[10]<=32'd0;
				AFR[11]<=32'd0;
				AFR[12]<=32'd0;
				AFR[13]<=32'd0;
				AFR[14]<=32'd0;
				AFR[15]<=32'd0;
				AFR[16]<=32'd0;
				AFR[17]<=32'd0;
				AFR[18]<=32'd0;
				AFR[19]<=32'd0;
				AFR[20]<=32'd0;
				AFR[21]<=32'd0;
				AFR[22]<=32'd0;
				AFR[23]<=32'd0;
				AFR[24]<=32'd0;
				AFR[25]<=32'd0;
				AFR[26]<=32'd0;
				AFR[27]<=32'd0;
				AFR[28]<=32'd0;
				AFR[29]<=32'd0;
				AFR[30]<=32'd0;
				AFR[31]<=32'd0;
				ADR[0]<=0;
				ADR[1]<=0;
				ADR[2]<=0;
				ADR[3]<=0;
				ADR[4]<=0;
				ADR[5]<=0;
				ADR[6]<=0;
				ADR[7]<=0;
				ADR[8]<=0;
				ADR[9]<=0;
				ADR[10]<=0;
				ADR[11]<=0;
				ADR[12]<=0;
				ADR[13]<=0;
				ADR[14]<=0;
				ADR[15]<=0;
				GPR[0]<=0;
				GPR[1]<=0;
				GPR[2]<=0;
				GPR[3]<=0;
				GPR[4]<=0;
				GPR[5]<=0;
				GPR[6]<=0;
				GPR[7]<=0;
				GPR[8]<=0;
				GPR[9]<=0;
				GPR[10]<=0;
				GPR[11]<=0;
				GPR[12]<=0;
				GPR[13]<=0;
				GPR[14]<=0;
				GPR[15]<=0;
				GPR[16]<=0;
				GPR[17]<=0;
				GPR[18]<=0;
				GPR[19]<=0;
				GPR[20]<=0;
				GPR[21]<=0;
				GPR[22]<=0;
				GPR[23]<=0;
				GPR[24]<=0;
				GPR[25]<=0;
				GPR[26]<=0;
				GPR[27]<=0;
				GPR[28]<=0;
				GPR[29]<=0;
				GPR[30]<=0;
				GPR[31]<=0;
				FMULACCReg[0]<=1'b0;
				FADDInstReg[0]<=1'b0;
				FMULInstReg[0]<=1'b0;
				FDIVInstReg[0]<=1'b0;
				FDIVACTReg<=1'b0;
				ALUInstReg[0]<=1'b0;
				ShiftInstReg[0]<=1'b0;
				MiscInstReg[0]<=1'b0;
				PrefInstReg[0]<=1'b0;
				MovInstReg[0]<=1'b0;
				MemInstReg[0]<=1'b0;
				MemBusy<=1'b0;
				MemCNT<=2'b00;
				CheckACT<=1'b0;
				ACT<=1'b0;
				StreamACT<=1'b0;
				NetACT<=1'b0;
				DLMachine<=WS;
				DescriptorLoadState<=1'b0;
				DTR[0]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[1]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[2]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[3]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[4]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[5]<=156'hB000000000000FFFFFFFF00000000FFFFFFFFFC;
				DTR[6]<=156'hB000000000000FFFFFFFF000000000000000000;
				DTR[7]<=156'hB000000000000FFFFFFFF000000000000000000;
				PrefCallReg<=1'b0;
				PrefRetReg<=1'b0;
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
				IV<=0;
				LFRNode<=0;
				MemFifoFullFlag<=0;
				end
else begin
	
	// Fifo full flag
	MemFifoFullFlag<=(MemFifoUsedW>6'd59);
	
	// Instructions transfered to the sequencer
	IV<=IVF & {4{IFetch & InsRDY}};
	
	// EU empty flag
	EMPTY<=PrefEMPTY & SeqEMPTY & (&GPVFReg);
	
	// output data for context store operations
	case (RA[6:5])
		2'd0: CDATA<=GPR[RA[4:0]][63:0];
		2'd1: CDATA<=GPR[RA[4:0]][127:64];
		2'd2: CDATA<={32'd0, AFR[RA[4:0]]};
		2'd3: CDATA<={27'd0, ADR[RA[3:0]]};
		endcase
	
	// Storing TAGi
	// 0000XXXXX - registers R[31:0], bits [63:0]
	// 0001XXXXX - registers R[31:0], bits [127:64]
	// 
	TAGiReg<=TAGi;
	
	// processign GPR valid flags
	for (i0=0; i0<32; i0=i0+1)
		GPVFReg[i0]<=(GPVFReg[i0] & GPVFINVD[i0])|
						((FADDDST==i0) & FADDRDY)|
						((FMULDST[0]==i0) & FMULRDY[0])|
						((FMULDST[1]==i0) & FMULRDY[1])|
						FMULACCSelNode[i0]|
						((FMULACCDSTReg==i0) & FMULACCACTReg & FMULACCCMDReg)|
						((FDIVDST==i0) & FDIVRDY)|
						((ALUDST==i0) & ALURDY)|
						((ShiftDST==i0) & ShiftRDY)|
						((MiscDST==i0) & MiscRDY)|
						((MovInstReg[24:20]==i0) & MovInstReg[0])|
						(MemReadAR & (MemDST==i0))|
						(PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i0))|
						(DRDY & (TAGi[4:0]==i0) & ~TAGi[8] & ((~TAGi[7] & ~TAGi[6])|TAGi[6]|(TAGi[7] & TAGi[5]))) |
						(SkipDataRead & (STAGReg==i0));
	// result strobe nodes
	for (i1=0; i1<32; i1=i1+1)
		begin
		// load flags from GPR's node
		LFRNode[i1]<=(MovInstBus[3:0]==4'hB) & (MovInstBus[24:20]==i1);
		
		// flag write registers during arithmetic or logic operations
		FlagWrite[i1]<=(FADDRDYR & (FADDDSTR==i1))|
						(FMULRDYR[0] & (FMULDSTR[0]==i1))|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FMULACCRDY & (FMULACCDST==i1))|
						(FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg==i1))|
						(FDIVRDY & (FDIVDST==i1))|
						(ALURDYR & (ALUDSTR==i1))|
						(ShiftRDYR & (ShiftDSTR==i1))|
						(MiscRDYR & (MiscDSTR==i1))|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]==3'd3))|
						(DRDY & (TAGi[4:0]==i1) & ~TAGi[8] & ((TAGi[6] & ~TAGi[5])|(~TAGi[6] & (~TAGi[7] | TAGi[5]))));

		GPRByteNode[i1]<=(FADDRDYR & (FADDDSTR==i1))|
						(FMULRDYR[0] & (FMULDSTR[0]==i1))|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FMULACCRDY & (FMULACCDST==i1))|
						(FDIVRDY & (FDIVDST==i1))|
						(ALURDYR & (ALUDSTR==i1))|
						(ShiftRDYR & (ShiftDSTR==i1))|
						(MiscRDYR & (MiscDSTR==i1))|
						(PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i1))|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]!=3'd5))|
						(MemReadAR & (MemDST==i1))|
						(DRDY & (TAGi[4:0]==i1) & ~TAGi[8] & ~TAGi[6] & ~TAGi[5]);

		GPRWordNode[i1]<=(FADDRDYR & (FADDDSTR==i1))|
						(FMULRDYR[0] & (FMULDSTR[0]==i1))|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FMULACCRDY & (FMULACCDST==i1))|
						(FDIVRDY & (FDIVDST==i1))|
						(ALURDYR & (ALUDSTR==i1) & (|ALUSR))|
						(ShiftRDYR & (ShiftDSTR==i1) & (|ShiftSR))|
						(MiscRDYR & (MiscDSTR==i1) & (|MiscSR))|
						(PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i1))|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]!=3'd5) & (|MovInstReg[27:25] | (MovInstReg[3:1]==3'd2)))|
						(MemReadAR & (MemDST==i1))|
						(DRDY & (TAGi[4:0]==i1) & (|SZi[1:0]) & ~TAGi[8] & ~TAGi[6] & ~TAGi[5]);

		GPRDwordNode[i1]<=(FADDRDYR & (FADDDSTR==i1))|
						(FMULRDYR[0] & (FMULDSTR[0]==i1))|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FMULACCRDY & (FMULACCDST==i1))|
						(FDIVRDY & (FDIVDST==i1))|
						(ALURDYR & (ALUDSTR==i1) & ALUSR[1])|
						(ShiftRDYR & (ShiftDSTR==i1) & ShiftSR[1])|
						(MiscRDYR & (MiscDSTR==i1) & (MiscSR[2] | MiscSR[1]))|
						(PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i1))|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]!=3'd5) & (|MovInstReg[27:26] | (MovInstReg[3:1]==3'd2)))|
						(MemReadAR & (MemDST==i1))|
						(DRDY & (TAGi[4:0]==i1)& SZi[1] & ~TAGi[8] & ~TAGi[6] & ~TAGi[5]);

		GPRQwordNode[i1]<=(FADDRDYR & (FADDDSTR==i1) & (FADDSR[2] | &FADDSR[1:0]))|
						(FMULRDYR[0] & (FMULDSTR[0]==i1) & (FMULSR[2] | &FMULSR[1:0]))|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FDIVRDY & (FDIVDST==i1) & (FDIVSR[2] | FDIVSR[0]))|
						(ALURDYR & (ALUDSTR==i1) & (&ALUSR))|
						(ShiftRDYR & (ShiftDSTR==i1) & ShiftSR[1] & ShiftSR[0])|
						(MiscRDYR & (MiscDSTR==i1) & ((MiscSR[1] & MiscSR[0]) | MiscSR[2]))|
						(PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i1))|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]!=3'd5) & (MovInstReg[27] | (&MovInstReg[26:25]) | (MovInstReg[3:1]==3'd2)))|
						(MemReadAR & (MemDST==i1))|
						(DRDY & (TAGi[4:0]==i1) & (&SZi[1:0]) & ~TAGi[8] & ~TAGi[6] & ~TAGi[5]);
		
		GPROwordNode[i1]<=(FMULRDYR[0] & (FMULDSTR[0]==i1) & FMULSR[2])|
						(FMULRDYR[1] & (FMULDSTR[1]==i1))|
						(FDIVRDY & (FDIVDST==i1) & FDIVSR[2])|
						(FADDRDYR & (FADDDSTR==i1) & FADDSR[2])|
						(MiscRDYR & (MiscDSTR==i1) & MiscSR[2])|
						(MovInstReg[0] & (MovInstReg[24:20]==i1) & (MovInstReg[3:1]!=3'd5) & (MovInstReg[27] | (MovInstReg[3:1]==3'd2)))|
						(DRDY & (TAGi[4:0]==i1) & ~TAGi[8] & ~TAGi[6] & TAGi[5]);
		end
	// data selection nodes
	for (i2=0; i2<32; i2=i2+1)
		begin
		FADDSelNode[i2]<=FADDRDYR & (FADDDSTR==i2);
		FMULSelNode[i2]<=FMULRDYR[0] & (FMULDSTR[0]==i2);
		FMULQSelNode[i2]<=FMULRDYR[1] & (FMULDSTR[1]==i2);
		FMULACCSelNode[i2]<=FMULACCRDY & (FMULACCDST==i2);
		FFTSelNode[i2]<=FMULACCACTReg & FMULACCCMDReg & (FMULACCDSTReg==i2);
		FDIVSelNode[i2]<=FDIVRDY & (FDIVDST==i2);
		ALUSelNode[i2]<=ALURDYR & (ALUDSTR==i2);
		ShiftSelNode[i2]<=ShiftRDYR & (ShiftDSTR==i2);
		MiscSelNode[i2]<=MiscRDYR & (MiscDSTR==i2);
		MovSelNode[i2]<=(MovInstReg[0] & (MovInstReg[24:20]==i2) & (MovInstReg[3:1]!=3'b101));
		MemSelNode[i2]<=DRDY & (TAGi[4:0]==i2) & ~TAGi[8] & ~TAGi[6];
		MemFSelNode[i2]<=DRDY & (TAGi[4:0]==i2) & ~TAGi[8] & TAGi[6] & ~TAGi[5];
		if (i2<16) MemASelNode[i2]<=DRDY & (TAGi[3:0]==i2) & ~TAGi[8] & TAGi[6] & TAGi[5];
		MemARSelNode[i2]<=MemReadAR & (MemDST==i2);
		PrefSelNode[i2]<=PrefInstReg[0] & (PrefInstReg[4:1]==4'h6) & (PrefInstReg[25:21]==i2);
		end
	// load selector from memory node
	MemLSelNode<=DRDY & ~TAGi[8] & TAGi[0] & TAGi[6] & TAGi[5];

	// DTR selection nodes
	for (i3=0; i3<8; i3=i3+1) DTRWriteFlag[i3]<=DRDY & TAGi[8] & ~TAGi[7] & ~TAGi[6] & ~TAGi[5] & (TAGi[4:2]==i3);
	DTRWriteFlag[8]<=DRDY & TAGi[8] & ~TAGi[7] & ~TAGi[6] & ~TAGi[5];

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
	MiscDSTR<=MiscDST;
	// delayed size registers
	SZiReg<=SZi;

	// storing results into registers
	for (i4=0; i4<32; i4=i4+1)
		begin
		// storing arithmetic flags
		if (LFRNode[i4]) AFR[i4][21:0]<=GPR[MovInstReg[8:4]][21:0];
			else if (FlagWrite[i4])
				begin
				// CF[15:0]
				AFR[i4][14:0]<=(ALUCOUT[14:0] & {15{ALUSelNode[i4]}}) | (DTi[14:0] & {15{MemFSelNode[i4]}});
				AFR[i4][15]<=(ALUCOUT[15] & ALUSelNode[i4])|(MiscCOUT & MiscSelNode[i4])|(DTi[15] & MemFSelNode[i4]);
				// ZF
				AFR[i4][16]<=(FADDZero & FADDSelNode[i4])|(FMULZero[0] & FMULSelNode[i4])|(FMULZero[1] & FMULQSelNode[i4])|
						(FDIVZero & FDIVSelNode[i4])|(ALUZero & ALUSelNode[i4])|(ShiftZERO & ShiftSelNode[i4])|
						(FMULACCZERO & FMULACCSelNode[i4])|(MiscZero & MiscSelNode[i4])|(DTi[16] & MemFSelNode[i4])|
						(FFT32NEXTReg & FFTSelNode[i4]) | (MOVZF & MovSelNode[i4]);
				// SF
				AFR[i4][17]<=(FADDSign & FADDSelNode[i4])|(FMULSign[0] & FMULSelNode[i4])|(FMULSign[1] & FMULQSelNode[i4])|
						(FDIVSign & FDIVSelNode[i4])|(ALUSign & ALUSelNode[i4])|(ShiftSign & ShiftSelNode[i4])|
						(FMULACCSIGN & FMULACCSelNode[i4])|(MiscSign & MiscSelNode[i4])|(DTi[17] & MemFSelNode[i4])|
						(MOVSign & MovSelNode[i4]);
				// OF
				AFR[i4][18]<=(ALUOVR & ALUSelNode[i4])|(ShiftOVR & ShiftSelNode[i4])|(DTi[18] & MemFSelNode[i4]);
				// IF
				AFR[i4][19]<=(FADDInf & FADDSelNode[i4])|(FMULInf[0] & FMULSelNode[i4])|(FMULInf[1] & FMULQSelNode[i4])|
						(FDIVInf & FDIVSelNode[i4])|(MiscOVR & MiscSelNode[i4])|(DTi[19] & MemFSelNode[i4])|
						(FMULACCINF & FMULACCSelNode[i4]);
				// NF
				AFR[i4][20]<=(FADDNaN & FADDSelNode[i4])|(FMULNaN[0] & FMULSelNode[i4])|(FMULNaN[1] & FMULQSelNode[i4])|
						(FDIVNaN & FDIVSelNode[i4])|(MiscNaN & MiscSelNode[i4])|(DTi[20] & MemFSelNode[i4])|
						(FMULACCNAN & FMULACCSelNode[i4])|(MemSelNode[i4] & (&SZiReg));
				// DBF
				AFR[i4][21]<=(ShiftCOUT & ShiftSelNode[i4])|(DTi[21] & MemFSelNode[i4]);
				end
		//reserved bits
		if (LFRNode[i4]) AFR[i4][31:22]<=GPR[MovInstReg[8:4]][31:22];
			else if (MemFSelNode[i4]) AFR[i4][31:22]<=DTi[31:22];

		// GPR Bits 7:0
		if (GPRByteNode[i4]) GPR[i4][7:0]<=(FADDR[7:0] & {8{FADDSelNode[i4]}})|
											(FMULR[7:0] & {8{FMULSelNode[i4]}})|
											(FMULRQ[7:0] & {8{FMULQSelNode[i4]}})|
											(FMULACCR[7:0] & {8{FMULACCSelNode[i4]}})|
											(FDIVR[7:0] & {8{FDIVSelNode[i4]}})|
											(ALUR[7:0] & {8{ALUSelNode[i4]}})|
											(ShiftR[7:0] & {8{ShiftSelNode[i4]}})|
											(MiscR[7:0] & {8{MiscSelNode[i4]}})|
											(PrefR[7:0] & {8{PrefSelNode[i4]}})|
											(MovReg[7:0] & {8{MovSelNode[i4]}})|
											(DTi[7:0] & {8{MemSelNode[i4]}})|
											(ARData[7:0] & {8{MemARSelNode[i4]}});
		// GPR Bits 15:8
		if (GPRWordNode[i4]) GPR[i4][15:8]<=(FADDR[15:8] & {8{FADDSelNode[i4]}})|
											(FMULR[15:8] & {8{FMULSelNode[i4]}})|
											(FMULRQ[15:8] & {8{FMULQSelNode[i4]}})|
											(FMULACCR[15:8] & {8{FMULACCSelNode[i4]}})|
											(FDIVR[15:8] & {8{FDIVSelNode[i4]}})|
											(ALUR[15:8] & {8{ALUSelNode[i4]}})|
											(ShiftR[15:8] & {8{ShiftSelNode[i4]}})|
											(MiscR[15:8] & {8{MiscSelNode[i4]}})|
											(PrefR[15:8] & {8{PrefSelNode[i4]}})|
											(MovReg[15:8] & {8{MovSelNode[i4]}})|
											(DTi[15:8] & {8{MemSelNode[i4]}})|
											(ARData[15:8] & {8{MemARSelNode[i4]}});

		if (GPRDwordNode[i4]) GPR[i4][31:16]<=(FADDR[31:16] & {16{FADDSelNode[i4]}})|
											(FMULR[31:16] & {16{FMULSelNode[i4]}})|
											(FMULRQ[31:16] & {16{FMULQSelNode[i4]}})|
											(FMULACCR[31:16] & {16{FMULACCSelNode[i4]}})|
											(FDIVR[31:16] & {16{FDIVSelNode[i4]}})|
											(ALUR[31:16] & {16{ALUSelNode[i4]}})|
											(ShiftR[31:16] & {16{ShiftSelNode[i4]}})|
											(MiscR[31:16] & {16{MiscSelNode[i4]}})|
											(PrefR[31:16] & {16{PrefSelNode[i4]}})|
											(MovReg[31:16] & {16{MovSelNode[i4]}})|
											(DTi[31:16] & {16{MemSelNode[i4]}})|
											(ARData[31:16] & {16{MemARSelNode[i4]}});

		if (GPRQwordNode[i4]) GPR[i4][63:32]<=(FADDR[63:32] & {32{FADDSelNode[i4]}})|
											(FMULR[63:32] & {32{FMULSelNode[i4]}})|
											(FMULRQ[63:32] & {32{FMULQSelNode[i4]}})|
											(FDIVR[63:32] & {32{FDIVSelNode[i4]}})|
											(ALUR[63:32] & {32{ALUSelNode[i4]}})|
											(ShiftR[63:32] & {32{ShiftSelNode[i4]}})|
											(MiscR[63:32] & {32{MiscSelNode[i4]}})|
											(PrefR[63:32] & {32{PrefSelNode[i4]}})|
											(MovReg[63:32] & {32{MovSelNode[i4]}})|
											(DTi[63:32] & {32{MemSelNode[i4]}})|
											(ARData[36:32] & {32{MemARSelNode[i4]}});
		
		if (GPROwordNode[i4]) GPR[i4][127:64]<=(MovReg[127:64] & {64{MovSelNode[i4]}})|
											(DTi & {64{MemSelNode[i4]}})|
											(FMULR[127:64] & {64{FMULSelNode[i4]}})|
											(FMULRQ[127:64] & {64{FMULQSelNode[i4]}})|
											(FDIVR[127:64] & {64{FDIVSelNode[i4]}})|
											(FADDR[127:64] & {64{FADDSelNode[i4]}}) |
											(MiscR[127:64] & {64{MiscSelNode[i4]}});
		end

	//=============================================================================================
	// 						FADD Channel
	//	0-ACT, 1-CMD[0], 6:2-SRC1, 9:7-Size1, 14:10-SRC2, 17:15-Size2, 22:18-DST, 25:23-SizeDST, 26-CMD[1]
	FADDInstReg<=FADDInstBus;
	FADDACTReg<=FADDInstReg[0];
	FADDCMDReg<={FADDInstReg[26],FADDInstReg[1]};
	FADDBypassAReg[0]<=FADDRDYR & (FADDDSTR==FADDInstBus[6:2]);
	FADDBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FADDInstBus[6:2]);
	FADDBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FADDInstBus[6:2]);
	FADDBypassAReg[3]<=ALURDYR & (ALUDSTR==FADDInstBus[6:2]);
	FADDBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==FADDInstBus[6:2]);
	FADDBypassAReg[5]<=MiscRDYR & (MiscDSTR==FADDInstBus[6:2]);
	FADDAReg<=(GPR[FADDInstReg[6:2]] & {128{~(|FADDBypassAReg)}}) |
				(FADDR & {128{FADDBypassAReg[0]}}) |
				(FMULR & {128{FADDBypassAReg[1]}}) |
				(FMULRQ & {128{FADDBypassAReg[2]}}) |
				({GPR[FADDInstReg[6:2]][127:64], ALUR} & {128{FADDBypassAReg[3]}}) |
				({GPR[FADDInstReg[6:2]][127:64], ShiftR} & {128{FADDBypassAReg[4]}}) |
				(MiscR & {128{FADDBypassAReg[5]}});
	FADDSAReg<=FADDInstReg[9:7];
	
	FADDBypassBReg[0]<=FADDRDYR & (FADDDSTR==FADDInstBus[14:10]);
	FADDBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FADDInstBus[14:10]);
	FADDBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FADDInstBus[14:10]);
	FADDBypassBReg[3]<=ALURDYR & (ALUDSTR==FADDInstBus[14:10]);
	FADDBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==FADDInstBus[14:10]);
	FADDBypassBReg[5]<=MiscRDYR & (MiscDSTR==FADDInstBus[14:10]);
	FADDBReg<=(GPR[FADDInstReg[14:10]] & {128{~(|FADDBypassBReg)}}) |
				(FADDR & {128{FADDBypassBReg[0]}}) |
				(FMULR & {128{FADDBypassBReg[1]}}) |
				(FMULRQ & {128{FADDBypassBReg[2]}}) |
				({GPR[FADDInstReg[14:10]][127:64], ALUR} & {128{FADDBypassBReg[3]}}) |
				({GPR[FADDInstReg[14:10]][127:64], ShiftR} & {128{FADDBypassBReg[4]}}) |
				(MiscR & {128{FADDBypassBReg[5]}});
	FADDSBReg<=FADDInstReg[17:15];
	
	FADDSDReg<=FADDInstReg[25:23];
	FADDDSTReg<=FADDInstReg[22:18];
	
	//=============================================================================================
	// 						FMUL channel
	//	0-ACT, 2:1-CMD, 7:3-SRC1, 10:8-Size1, 15:11-SRC2, 18:16-Size2, 23:19-DST, 26:24-SizeDST
	FMULInstReg<=FMULInstBus;
	FMULACTReg<=FMULInstReg[0];
	FMULCMDReg<=FMULInstReg[2:1];
	
	FMULBypassAReg[0]<=FADDRDYR & (FADDDSTR==FMULInstBus[7:3]);
	FMULBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FMULInstBus[7:3]);
	FMULBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FMULInstBus[7:3]);
	FMULBypassAReg[3]<=ALURDYR & (ALUDSTR==FMULInstBus[7:3]);
	FMULBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==FMULInstBus[7:3]);
	FMULBypassAReg[5]<=MiscRDYR & (MiscDSTR==FMULInstBus[7:3]);
	FMULAReg<=(GPR[FMULInstReg[7:3]] & {128{~(|FMULBypassAReg)}})|
				(FADDR & {128{FMULBypassAReg[0]}}) |
				(FMULR & {128{FMULBypassAReg[1]}}) |
				(FMULRQ & {128{FMULBypassAReg[2]}}) |
				({GPR[FMULInstReg[7:3]][127:64], ALUR} & {128{FMULBypassAReg[3]}}) |
				({GPR[FMULInstReg[7:3]][127:64], ShiftR} & {128{FMULBypassAReg[4]}}) |
				(MiscR & {128{FMULBypassAReg[5]}});
	FMULSAReg<=FMULInstReg[10:8];
	
	FMULBypassBReg[0]<=FADDRDYR & (FADDDSTR==FMULInstBus[15:11]);
	FMULBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FMULInstBus[15:11]);
	FMULBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FMULInstBus[15:11]);
	FMULBypassBReg[3]<=ALURDYR & (ALUDSTR==FMULInstBus[15:11]);
	FMULBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==FMULInstBus[15:11]);
	FMULBypassBReg[5]<=MiscRDYR & (MiscDSTR==FMULInstBus[15:11]);
	FMULBReg<=(GPR[FMULInstReg[15:11]] & {128{~(|FMULBypassBReg)}})|
				(FADDR & {128{FMULBypassBReg[0]}}) |
				(FMULR & {128{FMULBypassBReg[1]}}) |
				(FMULRQ & {128{FMULBypassBReg[2]}}) |
				({GPR[FMULInstReg[15:11]][127:64], ALUR} & {128{FMULBypassBReg[3]}}) |
				({GPR[FMULInstReg[15:11]][127:64], ShiftR} & {128{FMULBypassBReg[4]}}) |
				(MiscR & {128{FMULBypassBReg[5]}});
	FMULSBReg<=FMULInstReg[18:16];
	
	FMULDSTReg<=FMULInstReg[23:19];
	FMULSDReg<=FMULInstReg[26:24];

	//=================================================================================================
	//						FMULACC Channel
	//	0-ACT, 1-CMD, 6:2-SRCC, 9:7-MARC, 14:10-SRCD, 17:15-MARD, 22:18-DST, 25:23-Format
	FMULACCReg[0]<=(FMULACCReg[0] | FMULACCBus[0]) & (~FMULACCReg[0] | (FMULACCACTReg & ~FMULACCNEXT)) & RESET;
	if (~FMULACCReg[0]) FMULACCReg[25:1]<=FMULACCBus[25:1];
	
	FMULACCACTReg<=((FMULACCACTReg & ~FMULACCNEXT) | FMULACCReg[0]) & RESET;
	
	FFT32NEXTReg<=FFT32NEXT;
	
	FFTBypassReg[0]<=FADDRDYR & (FADDDSTR==FMULACCBus[22:18]);
	FFTBypassReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FMULACCBus[22:18]);
	FFTBypassReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FMULACCBus[22:18]);
	FFTBypassReg[3]<=ALURDYR & (ALUDSTR==FMULACCBus[22:18]);
	FFTBypassReg[4]<=ShiftRDYR & (ShiftDSTR==FMULACCBus[22:18]);
	FFTBypassReg[5]<=MiscRDYR & (MiscDSTR==FMULACCBus[22:18]);

	FMULACCBypassControlOffsetReg[0]<=FADDRDYR & (FADDDSTR==FMULACCBus[6:2]);
	FMULACCBypassControlOffsetReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FMULACCBus[6:2]);
	FMULACCBypassControlOffsetReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FMULACCBus[6:2]);
	FMULACCBypassControlOffsetReg[3]<=ALURDYR & (ALUDSTR==FMULACCBus[6:2]);
	FMULACCBypassControlOffsetReg[4]<=ShiftRDYR & (ShiftDSTR==FMULACCBus[6:2]);
	FMULACCBypassControlOffsetReg[5]<=MiscRDYR & (MiscDSTR==FMULACCBus[6:2]);

	FMULACCBypassDataOffsetReg[0]<=FADDRDYR & (FADDDSTR==FMULACCBus[14:10]);
	FMULACCBypassDataOffsetReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FMULACCBus[14:10]);
	FMULACCBypassDataOffsetReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FMULACCBus[14:10]);
	FMULACCBypassDataOffsetReg[3]<=ALURDYR & (ALUDSTR==FMULACCBus[14:10]);
	FMULACCBypassDataOffsetReg[4]<=ShiftRDYR & (ShiftDSTR==FMULACCBus[14:10]);
	FMULACCBypassDataOffsetReg[5]<=MiscRDYR & (MiscDSTR==FMULACCBus[14:10]);

	if (FMULACCNEXT | ~FMULACCACTReg)
		begin
		FMULACCDSTReg<=FMULACCReg[22:18];
		FMULACCCtrlSelReg<=FMULACCReg[9:7];
		FMULACCDataSelReg<=FMULACCReg[17:15];
		
		FMULACCCMDReg<=FMULACCReg[1];
		
		FFTCtrlBaseReg<=ADR[{FMULACCReg[9:7],1'b0}][36:3];
		FFTDataBaseReg<=ADR[{FMULACCReg[17:15],1'b0}][36:3];
		FFTCtrlSelReg<=ADR[{FMULACCReg[9:7],1'b1}][31:0];
		FFTDataSelReg<=ADR[{FMULACCReg[17:15],1'b1}][31:0];
		
		FFTParReg<=(GPR[FMULACCReg[22:18]][4:0] & {5{~(|FFTBypassReg)}})|
					(FADDR[4:0] & {5{FFTBypassReg[0]}}) |
					(FMULR[4:0] & {5{FFTBypassReg[1]}}) |
					(FMULRQ[4:0] & {5{FFTBypassReg[2]}}) |
					(ALUR[4:0] & {5{FFTBypassReg[3]}}) |
					(ShiftR[4:0] & {5{FFTBypassReg[4]}}) |
					(MiscR[4:0] & {5{FFTBypassReg[5]}});
					
		FFTIndexReg<=(GPR[FMULACCReg[22:18]][50:32] & {19{~(|FFTBypassReg)}})|
					(FADDR[50:32] & {19{FFTBypassReg[0]}}) |
					(FMULR[50:32] & {19{FFTBypassReg[1]}}) |
					(FMULRQ[50:32] & {19{FFTBypassReg[2]}}) |
					(ALUR[50:32] & {19{FFTBypassReg[3]}}) |
					(ShiftR[50:32] & {19{FFTBypassReg[4]}}) |
					(MiscR[50:32] & {19{FFTBypassReg[5]}});
		
		FMULACCCtrlOffsetReg<=(GPR[FMULACCReg[6:2]][36:3] & {34{~(|FMULACCBypassControlOffsetReg)}})|
					(FADDR[36:3] & {34{FMULACCBypassControlOffsetReg[0]}}) |
					(FMULR[36:3] & {34{FMULACCBypassControlOffsetReg[1]}}) |
					(FMULRQ[36:3] & {34{FMULACCBypassControlOffsetReg[2]}}) |
					(ALUR[36:3] & {34{FMULACCBypassControlOffsetReg[3]}}) |
					(ShiftR[36:3] & {34{FMULACCBypassControlOffsetReg[4]}}) |
					(MiscR[36:3] & {34{FMULACCBypassControlOffsetReg[5]}});
		
		FMULACCDataOffsetReg<=(GPR[FMULACCReg[14:10]][36:2] & {35{~(|FMULACCBypassDataOffsetReg)}})|
					(FADDR[36:2] & {35{FMULACCBypassDataOffsetReg[0]}}) |
					(FMULR[36:2] & {35{FMULACCBypassDataOffsetReg[1]}}) |
					(FMULRQ[36:2] & {35{FMULACCBypassDataOffsetReg[2]}}) |
					(ALUR[36:2] & {35{FMULACCBypassDataOffsetReg[3]}}) |
					(ShiftR[36:2] & {35{FMULACCBypassDataOffsetReg[4]}}) |
					(MiscR[36:2] & {35{FMULACCBypassDataOffsetReg[5]}});
		end
	FMULACCDRDYFlag<=DRDY & (TAGi[8:1]==8'b11000000);

	//=================================================================================================
	//						FDIV channel
	//	0-ACT, 2:1-CMD, 7:3-SRC1, 10:8-Size1, 15:11-SRC2, 18:16-Size2, 23:19-DST, 26:24-SizeDST
	FDIVInstReg[0]<=(FDIVInstReg[0] | FDIVInstBus[0]) & (~FDIVInstReg[0] | (FDIVACTReg & ~FDIVNEXT));
	if (~FDIVInstReg[0]) FDIVInstReg[26:1]<=FDIVInstBus[26:1];
	FDIVACTReg<=(FDIVACTReg & ~FDIVNEXT) | FDIVInstReg[0];
	FDIVBypassAReg[0]<=FADDRDYR & (FADDDSTR==FDIVInstBus[7:3]);
	FDIVBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FDIVInstBus[7:3]);
	FDIVBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FDIVInstBus[7:3]);
	FDIVBypassAReg[3]<=ALURDYR & (ALUDSTR==FDIVInstBus[7:3]);
	FDIVBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==FDIVInstBus[7:3]);
	FDIVBypassAReg[5]<=MiscRDYR & (MiscDSTR==FDIVInstBus[7:3]);
	
	FDIVBypassBReg[0]<=FADDRDYR & (FADDDSTR==FDIVInstBus[15:11]);
	FDIVBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==FDIVInstBus[15:11]);
	FDIVBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==FDIVInstBus[15:11]);
	FDIVBypassBReg[3]<=ALURDYR & (ALUDSTR==FDIVInstBus[15:11]);
	FDIVBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==FDIVInstBus[15:11]);
	FDIVBypassBReg[5]<=MiscRDYR & (MiscDSTR==FDIVInstBus[15:11]);
	if (FDIVNEXT | ~FDIVACTReg)
		begin
		FDIVAReg<=(GPR[FDIVInstReg[7:3]] & {128{~(|FDIVBypassAReg)}})|
					(FADDR & {128{FDIVBypassAReg[0]}}) |
					(FMULR & {128{FDIVBypassAReg[1]}}) |
					(FMULRQ & {128{FDIVBypassAReg[2]}}) |
					({GPR[FDIVInstReg[7:3]][127:64], ALUR} & {128{FDIVBypassAReg[3]}}) |
					({GPR[FDIVInstReg[7:3]][127:64], ShiftR} & {128{FDIVBypassAReg[4]}}) |
					(MiscR & {128{FDIVBypassAReg[5]}});
		FDIVSAReg<=FDIVInstReg[10:8];
		FDIVBReg<=(GPR[FDIVInstReg[15:11]] & {128{~(|FDIVBypassBReg)}})|
					(FADDR & {128{FDIVBypassBReg[0]}}) |
					(FMULR & {128{FDIVBypassBReg[1]}}) |
					(FMULRQ & {128{FDIVBypassBReg[2]}}) |
					({GPR[FDIVInstReg[15:11]][127:64], ALUR} & {128{FDIVBypassBReg[3]}}) |
					({GPR[FDIVInstReg[15:11]][127:64], ShiftR} & {128{FDIVBypassBReg[4]}}) |
					(MiscR & {128{FDIVBypassBReg[5]}});
		FDIVSBReg<=FDIVInstReg[18:16];
		FDIVDSTReg<=FDIVInstReg[23:19];
		FDIVCMDReg<=FDIVInstReg[2:1];
		FDIVSDReg<=FDIVInstReg[26:24];
		end

	//=================================================================================================
	// 						ALU channel
	//	0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
	ALUInstReg<=ALUInstBus;
	ALUACTReg<=ALUInstReg[0];
	ALUOpCODEReg<=ALUInstReg[3:1];

	ALUBypassAReg[0]<=FADDRDYR & (FADDDSTR==ALUInstBus[8:4]);
	ALUBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ALUInstBus[8:4]);
	ALUBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ALUInstBus[8:4]);
	ALUBypassAReg[3]<=ALURDYR & (ALUDSTR==ALUInstBus[8:4]);
	ALUBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==ALUInstBus[8:4]);
	ALUBypassAReg[5]<=MiscRDYR & (MiscDSTR==ALUInstBus[8:4]);

	ALUAReg<=((GPR[ALUInstReg[8:4]][63:0] & {64{~(|ALUBypassAReg)}}) |
				(FADDR[63:0] & {64{ALUBypassAReg[0]}}) |
				(FMULR[63:0] & {64{ALUBypassAReg[1]}}) |
				(FMULRQ[63:0] & {64{ALUBypassAReg[2]}}) |
				(ALUR & {64{ALUBypassAReg[3]}}) |
				(ShiftR & {64{ALUBypassAReg[4]}}) | 
				(MiscR[63:0] & {64{ALUBypassAReg[5]}}));

	ALUSAReg<=ALUInstReg[10:9];
	
	ALUBypassBReg[0]<=FADDRDYR & (FADDDSTR==ALUInstBus[16:12]);
	ALUBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ALUInstBus[16:12]);
	ALUBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ALUInstBus[16:12]);
	ALUBypassBReg[3]<=ALURDYR & (ALUDSTR==ALUInstBus[16:12]);
	ALUBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==ALUInstBus[16:12]);
	ALUBypassBReg[5]<=MiscRDYR & (MiscDSTR==ALUInstBus[16:12]);

	ALUBReg<=((GPR[ALUInstReg[16:12]][63:0] & {64{~(|ALUBypassBReg)}}) |
				(FADDR[63:0] & {64{ALUBypassBReg[0]}}) |
				(FMULR[63:0] & {64{ALUBypassBReg[1]}}) | 
				(FMULRQ[63:0] & {64{ALUBypassBReg[2]}}) |
				(ALUR & {64{ALUBypassBReg[3]}}) | 
				(ShiftR & {64{ALUBypassBReg[4]}}) |
				(MiscR[63:0] & {64{ALUBypassBReg[5]}}));

	ALUSBReg<=ALUInstReg[18:17];
	
	ALUBypassDReg[0]<=FADDRDYR & (FADDDSTR==ALUInstBus[24:20]);
	ALUBypassDReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ALUInstBus[24:20]);
	ALUBypassDReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ALUInstBus[24:20]);
	ALUBypassDReg[3]<=ALURDYR & (ALUDSTR==ALUInstBus[24:20]);
	ALUBypassDReg[4]<=ShiftRDYR & (ShiftDSTR==ALUInstBus[24:20]);
	ALUBypassDReg[5]<=MiscRDYR & (MiscDSTR==ALUInstBus[24:20]);

	ALUDReg<=((GPR[ALUInstReg[24:20]][63:0] & {64{~(|ALUBypassDReg)}}) |
				(FADDR[63:0] & {64{ALUBypassDReg[0]}}) |
				(FMULR[63:0] & {64{ALUBypassDReg[1]}}) | 
				(FMULRQ[63:0] & {64{ALUBypassDReg[2]}}) |
				(ALUR & {64{ALUBypassDReg[3]}}) | 
				(ShiftR & {64{ALUBypassDReg[4]}}) |
				(MiscR[63:0] & {64{ALUBypassDReg[5]}}));
	
	ALUSDReg<=ALUInstReg[26:25];

	ALUDSTReg<=ALUInstReg[24:20];

	//=================================================================================================
	// 						Shifter channel
	//	0-ACT, 4:1-CMD, 9:5-SRC1, 12:10-Size1, 17:13-SRC2, 20:18-Size2, 25:21-DST, 28:26-SizeDST
	ShiftInstReg<=ShiftInstBus;
	ShiftACTReg<=ShiftInstReg[0];
	
	ShiftBypassAReg[0]<=FADDRDYR & (FADDDSTR==ShiftInstBus[9:5]);
	ShiftBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ShiftInstBus[9:5]);
	ShiftBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ShiftInstBus[9:5]);
	ShiftBypassAReg[3]<=ALURDYR & (ALUDSTR==ShiftInstBus[9:5]);
	ShiftBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==ShiftInstBus[9:5]);
	ShiftBypassAReg[5]<=MiscRDYR & (MiscDSTR==ShiftInstBus[9:5]);
	
	ShiftAReg<=(GPR[ShiftInstReg[9:5]][63:0] & {64{~(|ShiftBypassAReg)}}) | 
				(FADDR[63:0] & {64{ShiftBypassAReg[0]}}) |
				(FMULR[63:0] & {64{ShiftBypassAReg[1]}}) | 
				(FMULRQ[63:0] & {64{ShiftBypassAReg[2]}}) |
				(ALUR & {64{ShiftBypassAReg[3]}}) |
				(ShiftR & {64{ShiftBypassAReg[4]}}) |
				(MiscR[63:0] & {64{ShiftBypassAReg[5]}});

	ShiftSAReg<=ShiftInstReg[11:10];

	ShiftBypassBReg[0]<=FADDRDYR & (FADDDSTR==ShiftInstBus[17:13]);
	ShiftBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ShiftInstBus[17:13]);
	ShiftBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ShiftInstBus[17:13]);
	ShiftBypassBReg[3]<=ALURDYR & (ALUDSTR==ShiftInstBus[17:13]);
	ShiftBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==ShiftInstBus[17:13]);
	ShiftBypassBReg[5]<=MiscRDYR & (MiscDSTR==ShiftInstBus[17:13]);

	ShiftBReg<=ShiftInstReg[4] ? ShiftInstReg[18:13] : ((GPR[ShiftInstReg[17:13]][5:0] & {6{~(|ShiftBypassBReg)}}) | 
								(FADDR[5:0] & {6{ShiftBypassBReg[0]}}) |
								(FMULR[5:0] & {6{ShiftBypassBReg[1]}}) | 
								(FMULRQ[5:0] & {6{ShiftBypassBReg[2]}}) |
								(ALUR[5:0] & {6{ShiftBypassBReg[3]}}) |
								(ShiftR[5:0] & {6{ShiftBypassBReg[4]}}) |
								(MiscR[5:0] & {6{ShiftBypassBReg[5]}}));

	ShiftCReg<=((GPR[ShiftInstReg[17:13]][14:8] & {7{~(|ShiftBypassBReg)}}) | 
								(FADDR[14:8] & {7{ShiftBypassBReg[0]}}) |
								(FMULR[14:8] & {7{ShiftBypassBReg[1]}}) | 
								(FMULRQ[14:8] & {7{ShiftBypassBReg[2]}}) |
								(ALUR[14:8] & {7{ShiftBypassBReg[3]}}) |
								(ShiftR[14:8] & {7{ShiftBypassBReg[4]}}) |
								(MiscR[14:8] & {7{ShiftBypassBReg[5]}}));

	// value for FIELDSET
	ShiftBypassDReg[0]<=FADDRDYR & (FADDDSTR==ShiftInstBus[25:21]);
	ShiftBypassDReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==ShiftInstBus[25:21]);
	ShiftBypassDReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==ShiftInstBus[25:21]);
	ShiftBypassDReg[3]<=ALURDYR & (ALUDSTR==ShiftInstBus[25:21]);
	ShiftBypassDReg[4]<=ShiftRDYR & (ShiftDSTR==ShiftInstBus[25:21]);
	ShiftBypassDReg[5]<=MiscRDYR & (MiscDSTR==ShiftInstBus[25:21]);

	ShiftDReg<=(GPR[ShiftInstReg[25:21]][63:0] & {64{~(|ShiftBypassDReg)}}) | 
				(FADDR[63:0] & {64{ShiftBypassDReg[0]}}) |
				(FMULR[63:0] & {64{ShiftBypassDReg[1]}}) | 
				(FMULRQ[63:0] & {64{ShiftBypassDReg[2]}}) |
				(ALUR & {64{ShiftBypassDReg[3]}}) |
				(ShiftR & {64{ShiftBypassDReg[4]}}) |
				(MiscR[63:0] & {64{ShiftBypassDReg[5]}});
	
	ShiftDSTReg<=ShiftInstReg[25:21];
	ShiftOPRReg<=ShiftInstReg[3:1];
	ShiftDSTSR<=ShiftInstReg[27:26];

	//=================================================================================================
	// 						miscellaneous operations channel
	//	0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
	MiscInstReg<=MiscInstBus;
	MiscACTReg<=MiscInstReg[0];
	
	MiscBypassAReg[0]<=FADDRDYR & (FADDDSTR==MiscInstBus[8:4]);
	MiscBypassAReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==MiscInstBus[8:4]);
	MiscBypassAReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==MiscInstBus[8:4]);
	MiscBypassAReg[3]<=ALURDYR & (ALUDSTR==MiscInstBus[8:4]);
	MiscBypassAReg[4]<=ShiftRDYR & (ShiftDSTR==MiscInstBus[8:4]);
	MiscBypassAReg[5]<=MiscRDYR & (MiscDSTR==MiscInstBus[8:4]);

	MiscBypassBReg[0]<=FADDRDYR & (FADDDSTR==MiscInstBus[16:12]);
	MiscBypassBReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==MiscInstBus[16:12]);
	MiscBypassBReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==MiscInstBus[16:12]);
	MiscBypassBReg[3]<=ALURDYR & (ALUDSTR==MiscInstBus[16:12]);
	MiscBypassBReg[4]<=ShiftRDYR & (ShiftDSTR==MiscInstBus[16:12]);
	MiscBypassBReg[5]<=MiscRDYR & (MiscDSTR==MiscInstBus[16:12]);
	
	MiscCINReg<=(AFR[MiscInstReg[8:4]][15:0] & {16{~MiscBypassAReg[3]}}) | (ALUCOUT & {16{MiscBypassAReg[3]}});

	MiscAReg<=((GPR[MiscInstReg[8:4]] & {128{~(|MiscBypassAReg)}}) | 
				(FADDR & {128{MiscBypassAReg[0]}}) |
				(FMULR & {128{MiscBypassAReg[1]}}) |
				(FMULRQ & {128{MiscBypassAReg[2]}}) |
				({GPR[MiscInstReg[8:4]][127:64], ALUR} & {128{MiscBypassAReg[3]}}) |
				({GPR[MiscInstReg[8:4]][127:64], ShiftR} & {128{MiscBypassAReg[4]}}) |
				(MiscR & {128{MiscBypassAReg[5]}}));
	MiscSAReg<=MiscInstReg[11:9];
	
	MiscBReg<=((GPR[MiscInstReg[16:12]][15:0] & {16{~(|MiscBypassBReg)}}) | 
				(FADDR[15:0] & {16{MiscBypassBReg[0]}}) |
				(FMULR[15:0] & {16{MiscBypassBReg[1]}}) |
				(FMULRQ[15:0] & {16{MiscBypassBReg[2]}}) |
				(ALUR[15:0] & {16{MiscBypassBReg[3]}}) |
				(ShiftR[15:0] & {16{MiscBypassBReg[4]}}) |
				(MiscR[15:0] & {16{MiscBypassBReg[5]}}));
	MiscSBReg<=MiscInstReg[19:17];	
	
	MiscSDReg<=MiscInstReg[27:25];
	MiscDSTReg<=MiscInstReg[24:20];
	MiscOPRReg<=MiscInstReg[3:1];
	
	//=================================================================================================
	// 						prefetcher channel
	//	0-ACT, 4:1-CMD, 20:5-Displacement, 25:21-DSTR/SRC, 28:26-CC
	PrefInstReg<=PrefInstBus;

	PrefBypassReg[0]<=FADDRDYR & (FADDDSTR==PrefInstBus[25:21]);
	PrefBypassReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==PrefInstBus[25:21]);
	PrefBypassReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==PrefInstBus[25:21]);
	PrefBypassReg[3]<=ALURDYR & (ALUDSTR==PrefInstBus[25:21]);
	PrefBypassReg[4]<=ShiftRDYR & (ShiftDSTR==PrefInstBus[25:21]);
	PrefBypassReg[5]<=MiscRDYR & (MiscDSTR==PrefInstBus[25:21]);
	
	PrefR<=PrefDataBus-64'd1;
	
	//=================================================================================================
	// 						register movement operation
	//	0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
	MovInstReg<=MovInstBus;

	CopyBypassReg[0]<=FADDRDYR & (FADDDSTR==MovInstBus[8:4]);
	CopyBypassReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==MovInstBus[8:4]);
	CopyBypassReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==MovInstBus[8:4]);
	CopyBypassReg[3]<=ALURDYR & (ALUDSTR==MovInstBus[8:4]);
	CopyBypassReg[4]<=ShiftRDYR & (ShiftDSTR==MovInstBus[8:4]);
	CopyBypassReg[5]<=MiscRDYR & (MiscDSTR==MovInstBus[8:4]);

	LIBypassReg[0]<=FADDRDYR & (FADDDSTR==MovInstBus[24:20]);
	LIBypassReg[1]<=FMULRDYR[0] & (FMULDSTR[0]==MovInstBus[24:20]);
	LIBypassReg[2]<=FMULRDYR[1] & (FMULDSTR[1]==MovInstBus[24:20]);
	LIBypassReg[3]<=ALURDYR & (ALUDSTR==MovInstBus[24:20]);
	LIBypassReg[4]<=ShiftRDYR & (ShiftDSTR==MovInstBus[24:20]);
	LIBypassReg[5]<=MiscRDYR & (MiscDSTR==MovInstBus[24:20]);
	
	case (MovInstReg[3:1])
		// COPYZX
		3'd0: case (MovInstReg[11:9])
					0: MovReg<={120'd0,(GPR[MovInstReg[8:4]][7:0] & {8{~(|CopyBypassReg)}}) | (FADDR[7:0] & {8{CopyBypassReg[0]}}) |
								(FMULR[7:0] & {8{CopyBypassReg[1]}}) | (FMULRQ[7:0] & {8{CopyBypassReg[2]}}) |
								(ALUR[7:0] & {8{CopyBypassReg[3]}}) | (ShiftR[7:0] & {8{CopyBypassReg[4]}}) |
								(MiscR[7:0] & {8{CopyBypassReg[5]}})};
					1: MovReg<={112'd0,(GPR[MovInstReg[8:4]][15:0] & {16{~(|CopyBypassReg)}}) | (FADDR[15:0] & {16{CopyBypassReg[0]}}) |
								(FMULR[15:0] & {16{CopyBypassReg[1]}}) | (FMULRQ[15:0] & {16{CopyBypassReg[2]}}) |
								(ALUR[15:0] & {16{CopyBypassReg[3]}}) | (ShiftR[15:0] & {16{CopyBypassReg[4]}}) |
								(MiscR[15:0] & {16{CopyBypassReg[5]}})};
					2: MovReg<={96'd0,(GPR[MovInstReg[8:4]][31:0] & {32{~(|CopyBypassReg)}}) | (FADDR[31:0] & {32{CopyBypassReg[0]}}) |
								(FMULR[31:0] & {32{CopyBypassReg[1]}}) | (FMULRQ[31:0] & {32{CopyBypassReg[2]}}) |
								(ALUR[31:0] & {32{CopyBypassReg[3]}}) | (ShiftR[31:0] & {32{CopyBypassReg[4]}}) |
								(MiscR[31:0] & {32{CopyBypassReg[5]}})};
					3: MovReg<={64'd0,(GPR[MovInstReg[8:4]][63:0] & {64{~(|CopyBypassReg)}}) | (FADDR[63:0] & {64{CopyBypassReg[0]}}) |
								(FMULR[63:0] & {64{CopyBypassReg[1]}}) | (FMULRQ[63:0] & {64{CopyBypassReg[2]}}) |
								(ALUR[63:0] & {64{CopyBypassReg[3]}}) | (ShiftR[63:0] & {64{CopyBypassReg[4]}}) |
								(MiscR[63:0] & {64{CopyBypassReg[5]}})};
					default: MovReg<=MovBusSRC;
					endcase
		// COPYSX
		3'd1: case (MovInstReg[11:9])
					0: MovReg<=({{120{GPR[MovInstReg[8:4]][7]}},GPR[MovInstReg[8:4]][7:0]} & {128{~(|CopyBypassReg)}}) |
								({{120{FADDR[7]}},FADDR[7:0]} & {128{CopyBypassReg[0]}}) |
								({{120{FMULR[7]}},FMULR[7:0]} & {128{CopyBypassReg[1]}}) |
								({{120{FMULRQ[7]}},FMULRQ[7:0]} & {128{CopyBypassReg[2]}}) |
								({{120{ALUR[7]}},ALUR[7:0]} & {128{CopyBypassReg[3]}}) |
								({{120{ShiftR[7]}},ShiftR[7:0]} & {128{CopyBypassReg[4]}}) |
								({{120{MiscR[7]}},MiscR[7:0]} & {128{CopyBypassReg[5]}});
					1: MovReg<=({{112{GPR[MovInstReg[8:4]][15]}},GPR[MovInstReg[8:4]][15:0]} & {128{~(|CopyBypassReg)}}) |
								({{112{FADDR[15]}},FADDR[15:0]} & {128{CopyBypassReg[0]}}) |
								({{112{FMULR[15]}},FMULR[15:0]} & {128{CopyBypassReg[1]}}) |
								({{112{FMULRQ[15]}},FMULRQ[15:0]} & {128{CopyBypassReg[2]}}) |
								({{112{ALUR[15]}},ALUR[15:0]} & {128{CopyBypassReg[3]}}) |
								({{112{ShiftR[15]}},ShiftR[15:0]} & {128{CopyBypassReg[4]}}) |
								({{112{MiscR[15]}},MiscR[15:0]} & {128{CopyBypassReg[5]}});
					2: MovReg<=({{96{GPR[MovInstReg[8:4]][31]}},GPR[MovInstReg[8:4]][31:0]} & {128{~(|CopyBypassReg)}}) |
								({{96{FADDR[31]}},FADDR[31:0]} & {128{CopyBypassReg[0]}}) |
								({{96{FMULR[31]}},FMULR[31:0]} & {128{CopyBypassReg[1]}}) |
								({{96{FMULRQ[31]}},FMULRQ[31:0]} & {128{CopyBypassReg[2]}}) |
								({{96{ALUR[31]}},ALUR[31:0]} & {128{CopyBypassReg[3]}}) |
								({{96{ShiftR[31]}},ShiftR[31:0]} & {128{CopyBypassReg[4]}}) |
								({{96{MiscR[31]}},MiscR[31:0]} & {128{CopyBypassReg[5]}});
					3: MovReg<=({{64{GPR[MovInstReg[8:4]][63]}},GPR[MovInstReg[8:4]][63:0]} & {128{~(|CopyBypassReg)}}) |
								({{64{FADDR[63]}},FADDR[63:0]} & {128{CopyBypassReg[0]}}) |
								({{64{FMULR[63]}},FMULR[63:0]} & {128{CopyBypassReg[1]}}) |
								({{64{FMULRQ[63]}},FMULRQ[63:0]} & {128{CopyBypassReg[2]}}) |
								({{64{ALUR[63]}},ALUR[63:0]} & {128{CopyBypassReg[3]}}) |
								({{64{ShiftR[63]}},ShiftR[63:0]} & {128{CopyBypassReg[4]}}) |
								({{64{MiscR[63]}},MiscR[63:0]} & {128{CopyBypassReg[5]}});
					default: MovReg<=(GPR[MovInstReg[8:4]] & {128{~(|CopyBypassReg)}}) | 
									(FADDR & {128{CopyBypassReg[0]}}) |
									(FMULR & {128{CopyBypassReg[1]}}) | 
									(FMULRQ & {128{CopyBypassReg[2]}}) |
									({{64{ALUR[63]}}, ALUR} & {128{CopyBypassReg[3]}}) |
									({{64{ShiftR[63]}}, ShiftR} & {128{CopyBypassReg[4]}}) |
									(MiscR & {128{CopyBypassReg[5]}});
					endcase
		// LID
		3'd2: case (MovInstReg[27:25])
					0: MovReg<={{112{MovInstReg[19]}}, MovInstReg[19:4]};
					1: MovReg<={{96{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[15:0]};
					2: MovReg<={{80{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[31:0]};
					3: MovReg<={{64{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[47:0]};
					4: MovReg<={{48{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[63:0]};
					5: MovReg<={{32{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[79:0]};
					6: MovReg<={{16{MovInstReg[19]}}, MovInstReg[19:4], MovBusDST[95:0]};
					7: MovReg<={MovInstReg[19:4], MovBusDST[111:0]};
					endcase
		// NOT
		3'd3: MovReg<=~MovBusSRC;
		// SFR
		3'd4: MovReg<={96'd0,AFR[MovInstReg[8:4]]};
		// XCHG
		3'd6: MovReg<={MovBusSRC[63:0], MovBusSRC[127:64]};
		endcase
	// flags processing during NOT operations
	case (MovInstReg[26:25])
		2'd0: 	begin
				MOVZF<=&MovBusSRC[7:0];
				MOVSign<=~MovBusSRC[7];
				end
		2'd1:	begin
				MOVZF<=&MovBusSRC[15:0];
				MOVSign<=~MovBusSRC[15];
				end
		2'd2:	begin
				MOVZF<=&MovBusSRC[31:0];
				MOVSign<=~MovBusSRC[31];
				end
		2'd3:	begin
				MOVZF<=&MovBusSRC[63:0];
				MOVSign<=~MovBusSRC[63];
				end
		endcase

	//=================================================================================================
	//
	// 						Memory operations and address register 
	//
	// 27:0 	- MemInstReg
	// 64:28 	- Offset from GPR
	// 192:65	- Data to memory
	// 224:193	- AFR content
	// 225		- PrefCall flag
	// 226		- PrefRet flag
	//
	// 0-ACT, 4:1-CMD, 9:5-Aditional offset, 12:10-AMODE, 17:13-Offset Register, 20:18-MAR, 25:21-DST/SRC, 28:26-Format
	if (~MemDelayFlag & ~MemFifoFullFlag) MemInstReg<=MemInstBus;

	MemDelayFlag<=~MemDelayFlag & MemInstBus[0] & ((FADDRDYR & (FADDDSTR==MemInstBus[25:21])) | (FMULRDYR[0] & (FMULDSTR[0]==MemInstBus[25:21])) |
					(FMULRDYR[1] & (FMULDSTR[1]==MemInstBus[25:21])) | (ALURDYR & (ALUDSTR==MemInstBus[25:21])) | (ShiftRDYR & (ShiftDSTR==MemInstBus[25:21])) |
					(MiscRDYR & (MiscDSTR==MemInstBus[25:21])) | (FADDRDYR & (FADDDSTR==MemInstBus[17:13])) | (FMULRDYR[0] & (FMULDSTR[0]==MemInstBus[17:13])) |
					(FMULRDYR[1] & (FMULDSTR[1]==MemInstBus[17:13])) | (ALURDYR & (ALUDSTR==MemInstBus[17:13])) | (ShiftRDYR & (ShiftDSTR==MemInstBus[17:13])) |
					(MiscRDYR & (MiscDSTR==MemInstBus[17:13])));
	
	// busy flag of memory command
	MemBusy<=(MemBusy & ~MemLoadOffset & (~MemLoadSel | (MemDST=={CheckSEL,CheckACT})) & ~MemReadAR & ~(MemNext & ~FMULACCMemACT)) | MemCNT[1] | MemCNT[0] | ~MemFifoEmpty;
	
	// Memory interface unit operation flags
	if ((~MemBusy | (MemNext & ~FMULACCMemACT) | MemLoadOffset | (MemLoadSel & (MemDST!={CheckSEL,CheckACT})) | MemReadAR) & ~MemCNT[1] & ~MemCNT[0])
		begin
		// Read AR
		MemReadAR<=~MemFifoEmpty & (MemFifoBus[3:0]==4'h9) & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Load AR (offset)
		MemLoadOffset<=~MemFifoEmpty & ((MemFifoBus[3:0]==4'h8)|(MemFifoBus[3:0]==4'hA)|(MemFifoBus[3:0]==4'hB)|(MemFifoBus[3:0]==4'hC)) & ~MemFifoBus[20] & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Load AR (selector)
		MemLoadSel<=~MemFifoEmpty & ((MemFifoBus[3:0]==4'h8)|(MemFifoBus[3:0]==4'hA)|(MemFifoBus[3:0]==4'hB)|(MemFifoBus[3:0]==4'hC)) & MemFifoBus[20] & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Load immediate (offset)
		MemLoadImmediate<=~MemFifoEmpty & (MemFifoBus[3:0]==4'hA) & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Increment address register
		MemIncrement<=~MemFifoEmpty & (MemFifoBus[3:0]==4'hB) & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Add address register
		MemAdd<=~MemFifoEmpty & (MemFifoBus[3:0]==4'hC) & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Request flag to the ATU
		MemReq<=~MemFifoEmpty & ~MemFifoBus[3] & ~MemFifoBus[225] & ~MemFifoBus[226];
		// Read/Write flag
		MemOpr<=MemFifoBus[0];
		// PUsh/POP/LDST flags
		MemPUSH<=~MemFifoEmpty & (MemFifoBus[3:2]==2'h1) & ~MemFifoBus[0] & ~MemFifoBus[225] & ~MemFifoBus[226];
		MemPOP<=~MemFifoEmpty & (MemFifoBus[3:2]==2'h1) & MemFifoBus[0] & ~MemFifoBus[225] & ~MemFifoBus[226];
		MemLDST<=~MemFifoEmpty & (MemFifoBus[3:1]==3'd0) & ~MemFifoBus[225] & ~MemFifoBus[226];
		MemLDO<=~MemFifoEmpty & (MemFifoBus[3:0]==4'd1) & MemFifoBus[27] & ~MemFifoBus[225] & ~MemFifoBus[226];
		MemADRPushPop<=~MemFifoEmpty & (MemFifoBus[3:1]==3'd3) & ~MemFifoBus[225] & ~MemFifoBus[226];
		PrefCallReg<=~MemFifoEmpty & MemFifoBus[225];
		PrefRetReg<=~MemFifoEmpty & MemFifoBus[226];
		// Size
		MemSize<=MemFifoBus[27:25] | {3{(MemFifoBus[3:2]==2'h1) & ~MemFifoBus[225] & ~MemFifoBus[226]}};
		// SEL field register
		if (MemFifoBus[3]) MemSEL<=MemFifoBus[23:21];
					else MemSEL<=MemFifoBus[19:17];
		// DST field register
		MemDST<=MemFifoBus[24:20];
		// Offset from GPR
		MemGPROffset<=MemFifoBus[64:28];
		// additional offset
		MemAOffset<=MemFifoBus[8:4];
		MemAddOffset<=({{4{MemFifoBus[8]}},MemFifoBus[8:4]} & {9{(MemFifoBus[3:1]==3'd0)}}) << {MemFifoBus[27],~MemFifoBus[27] & MemFifoBus[26],~MemFifoBus[27] & MemFifoBus[25]};
		// address mode
		MemAMode<=MemFifoBus[11:9];
		// GPR flags
		MemAFR<=MemFifoBus[224:193];
		// GPR
		MemGPR<=MemFifoBus[192:65];
		// data to GPR
		ARData<=ADR[MemAOffset[3:0]] & {{5{~MemAOffset[0]}},32'hFFFFFFFF};
		// 16-bit immediate data for ADR's
		MemImmediateBus<=MemFifoBus[19:4];
		end
	// Count of the bus cycles
	if ((~MemBusy | (MemNext & ~FMULACCMemACT) | MemLoadOffset | (MemLoadSel & (MemDST!={CheckSEL,CheckACT})) | MemReadAR) & ~MemFifoEmpty & (MemCNT==2'd0) & ~MemFifoBus[225] & ~MemFifoBus[226])
					begin
					MemCNT[0]<=(MemFifoBus[3:1]==3'd0) & MemFifoBus[27];
					MemCNT[1]<=(MemFifoBus[3:1]==3'b010);
					end
				else if (MemNext & (MemCNT!=2'b00) & ~FMULACCMemACT) MemCNT<=MemCNT-2'd1;

	// resetting the descriptor valid flags 
	for (i5=0; i5<8; i5=i5+1)
		if (MemLoadSel & (MemSEL==i5) & (MemDST!={CheckSEL,CheckACT & ~CheckAR[3]})) DTR[i5][155]<=(MemNewSel==ADR[{MemSEL,1'b1}][31:0]) & DTR[i5][155];
			else if (MemLSelNode & (TAGiReg[3:1]==i5)) DTR[i5][155]<=(DTi[31:0]==ADR[TAGiReg[3:0]][31:0]) & DTR[i5][155];
	
	// second cycle for 128-bit transfers
	if ((MemNext & ~FMULACCMemACT) | ~MemBusy) MemSecondCycle<=(MemCNT==2'b01);
	//
	// processing address registers
	//
	for (i6=0; i6<16; i6=i6+1)
		if (i6[0])
				begin
				// for selector registers
				if ((i6!=15) & (i6!=13))
						begin
						if (MemASelNode[i6]) ADR[i6]<=DTi[36:0];
							else if (MemLoadSel & (MemDST[3:0]==i6) & ((MemDST!={CheckSEL,CheckACT & ~CheckAR[3]}) | MemNext))
									begin
									casez ({MemAdd,MemIncrement,MemLoadImmediate})
										3'b000: ADR[i6]<=MemGPROffset;
										3'b001: if (MemSize[0]) ADR[i6]<={ADR[i6][36:32],MemImmediateBus,ADR[i6][15:0]};
													else ADR[i6]<={21'd0,MemImmediateBus};
										3'b01?: ADR[i6]<=ADR[i6]+{{21{MemImmediateBus[15]}},MemImmediateBus};
										3'b1??: ADR[i6]<=ADR[i6]+MemGPROffset;
										endcase
									end
						end
					else begin
						// stack selector and code selector can't be loaded from GPR's at the CPL<>0
						if (MemASelNode[i6]) ADR[i6]<=DTi[36:0];
							else if (MemLoadSel & (MemDST[3:0]==i6) & ~CPL[1] & ~CPL[0]) 
									begin
									casez ({MemAdd,MemIncrement,MemLoadImmediate})
										3'b000: ADR[i6]<=MemGPROffset;
										3'b001: if (MemSize[0]) ADR[i6]<={ADR[i6][36:32],MemImmediateBus,ADR[i6][15:0]};
													else ADR[i6]<={21'd0,MemImmediateBus};
										3'b01?: ADR[i6]<=ADR[i6]+{{21{MemImmediateBus[15]}},MemImmediateBus};
										3'b1??: ADR[i6]<=ADR[i6]+MemGPROffset;
										endcase
									end
						end
				end
			else begin
				// for offset registers
				if (i6==14)
						begin
						// stack offset can be loaded from memory or modified in PUSH/POP/CALL/RET operations
						if (MemASelNode[i6]) ADR[i6]<=DTi[36:0];
							else if (MemLoadOffset & (MemDST[3:0]==i6))
								begin
								casez ({MemAdd,MemIncrement,MemLoadImmediate})
									3'b000: ADR[i6]<=MemGPROffset;
									3'b001: casez (MemSize[1:0])
												2'b00: ADR[i6]<={{21{MemImmediateBus[15]}},MemImmediateBus};
												2'b01: ADR[i6]<={{5{MemImmediateBus[15]}},MemImmediateBus,ADR[i6][15:0]};
												2'b1?: ADR[i6]<={MemImmediateBus[4:0],ADR[i6][31:0]};
												endcase
									3'b01?: ADR[i6]<=ADR[i6]+{{21{MemImmediateBus[15]}},MemImmediateBus};
									3'b1??: ADR[i6]<=ADR[i6]+MemGPROffset;
									endcase
								end
								else if ((MemPUSH | PrefCallReg) & MemNext & ~FMULACCMemACT) ADR[i6]<=ADR[i6]-8;
									else if ((MemPOP | PrefRetReg) & MemNext & ~FMULACCMemACT) ADR[i6]<=ADR[i6]+8;
						end
					else begin
						// all other offset registers
						if (MemASelNode[i6]) ADR[i6]<=DTi[36:0];
							else if (MemLoadOffset & (MemDST[3:0]==i6))
									begin
									casez ({MemAdd,MemIncrement,MemLoadImmediate})
										3'b000: ADR[i6]<=MemGPROffset;
										3'b001: casez (MemSize[1:0])
													2'b00: ADR[i6]<={{21{MemImmediateBus[15]}},MemImmediateBus};
													2'b01: ADR[i6]<={{5{MemImmediateBus[15]}},MemImmediateBus,ADR[i6][15:0]};
													2'b1?: ADR[i6]<={MemImmediateBus[4:0],ADR[i6][31:0]};
													endcase
										3'b01?: ADR[i6]<=ADR[i6]+{{21{MemImmediateBus[15]}},MemImmediateBus};
										3'b1??: ADR[i6]<=ADR[i6]+MemGPROffset;
										endcase
									end
									else if (MemLDST & MemNext & ~FMULACCMemACT & (({1'b0,MemSEL}<<1)==i6) & MemReq & ~MemCNT[1] & ~MemCNT[0])
										begin
										if (MemAMode==3'b001) ADR[i6]<=ADR[i6]+MemGPROffset;
											else if (MemAMode[2] & ~MemAMode[0]) ADR[i6]<=ADR[i6]+MemoryOSValue;
												else if (MemAMode[2] & MemAMode[0]) ADR[i6]<=ADR[i6]-MemoryOSValue;
										end
						end
				end
	//
	// Conversion logical address to physical with access verification
	//
	CheckACT<=(CheckACT  & ~MemNext) | MemReq | PrefACT | PrefCallReg | PrefRetReg | FMULACCMemACT;
	
	// check offset and access type stage
	if (MemNext)
		begin
		// prefetcher flag
		CheckPref<=PrefACT & ~MemReq & ~PrefCallReg & ~PrefRetReg & ~FMULACCMemACT;
		// selector index
		if (FMULACCMemACT) CheckSEL<=FMULACCMemSEL;
			else if (PrefCallReg | PrefRetReg) CheckSEL<=3'd7;
					else if (MemReq) CheckSEL<=MemSEL | {3{MemPUSH | MemPOP}};
							else CheckSEL<=3'd6;
					
		// Command
		if (PrefCallReg) CheckCMD<=FMULACCMemACT;
			else if (MemReq) CheckCMD<=MemOpr | FMULACCMemACT | MemPOP;
					else CheckCMD<=1'b1;
			
		// operand size
		if (FMULACCMemACT) CheckOS<={1'b1,FMULACCSIZE};
			else if (MemReq) CheckOS<=MemSize[1:0] | {2{MemSize[2]}};
					else CheckOS<=2'b11;
		// Forming OFFSET 
		if (FMULACCMemACT) CheckOffset<=ADR[{1'b0,FMULACCMemSEL}<<1]+{FMULACCMemOffset,2'd0};
			else if (~MemReq & ~PrefCallReg & ~PrefRetReg) CheckOffset<=PrefOffset;
				else if (MemPUSH | PrefCallReg) CheckOffset<=ADR[14]-36'd8;
					else if (MemPOP | PrefRetReg) CheckOffset<=ADR[14];
							else case (MemAMode)
								3'b000 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b001 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b010 : CheckOffset<=MemGPROffset+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b011 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+MemGPROffset+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b100 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b101 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b110 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+MemGPROffset+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								3'b111 : CheckOffset<=ADR[{1'b0,MemSEL}<<1]+MemGPROffset+{33'd0,MemSecondCycle,3'd0}+{{28{MemAddOffset[8]}},MemAddOffset};
								endcase
		// Base address limits and access rights
		if (FMULACCMemACT)
				begin
				CheckBase<=DTR[FMULACCMemSEL][39:0];
				CheckLL<=DTR[FMULACCMemSEL][71:40];
				CheckUL<=DTR[FMULACCMemSEL][103:72];
				CheckLowerSel<=DTR[FMULACCMemSEL][127:104];
				CheckUpperSel<=DTR[FMULACCMemSEL][151:128];
				CheckAR<=DTR[FMULACCMemSEL][155:152];
				CheckNetwork<=(CPU!=ADR[1+({1'b0,FMULACCMemSEL}<<1)][31:24]) & (|ADR[1+({1'b0,FMULACCMemSEL}<<1)][31:24]);
				CheckSelector<=ADR[1+({1'b0,FMULACCMemSEL}<<1)][31:0];
				end
			else begin
				if (MemPOP | MemPUSH | PrefCallReg | PrefRetReg)			//NEW
						begin
						// stack access
						CheckBase<=DTR[7][39:0];
						CheckLL<=DTR[7][71:40];
						CheckUL<=DTR[7][103:72];
						CheckLowerSel<=DTR[7][127:104];
						CheckUpperSel<=DTR[7][151:128];
						CheckAR<=DTR[7][155:152];
						CheckNetwork<=(CPU!=ADR[15][31:24]) & (|ADR[15][31:24]);
						CheckSelector<=ADR[15][31:0];
						end
					else begin
						if (MemReq)
							begin
							// data transactions
							CheckBase<=DTR[MemSEL][39:0];
							CheckLL<=DTR[MemSEL][71:40];
							CheckUL<=DTR[MemSEL][103:72];
							CheckLowerSel<=DTR[MemSEL][127:104];
							CheckUpperSel<=DTR[MemSEL][151:128];
							CheckAR<=DTR[MemSEL][155:152];
							CheckNetwork<=(CPU!=ADR[1+({1'b0,MemSEL}<<1)][31:24]) & (|ADR[1+({1'b0,MemSEL}<<1)][31:24]);
							CheckSelector<=ADR[1+({1'b0,MemSEL}<<1)][31:0];
							end
							else begin
							// code fetch
							CheckBase<=DTR[6][39:0];
							CheckLL<=DTR[6][71:40];
							CheckUL<=DTR[6][103:72];
							CheckLowerSel<=DTR[6][127:104];
							CheckUpperSel<=DTR[6][151:128];
							CheckAR<=DTR[6][155:152];
							CheckNetwork<=(CPU!=ADR[13][31:24]) & (|ADR[13][31:24]);
							CheckSelector<=ADR[13][31:0];
							end
					end
				end
		// forming data to memory
		if (PrefCallReg) CheckData<=MemGPR[63:0];
			else if (MemPUSH & (MemCNT==2'b10)) CheckData<=MemAFR;
					else if (MemPUSH & (MemCNT==2'b01)) CheckData<=MemGPR[127:64];
							else if (MemPUSH & MemSecondCycle) CheckData<=MemGPR[63:0];
									else if (MemPUSH & (MemCNT==2'b00)) CheckData<=ADR[MemDST];
											else if (MemSecondCycle) CheckData<=MemGPR[127:64];
													else CheckData<=MemGPR[63:0];
		// tag
		if (FMULACCMemACT) CheckTag<={8'b11000000, FMULACCTAGo};
			else if ((PrefCallReg | PrefRetReg) | (~MemReq & ~PrefCallReg & ~PrefRetReg))
						begin
						CheckTag[2:0]<=PrefTag;
						CheckTag[3]<=PrefCallReg | PrefRetReg;
						CheckTag[8:4]<=5'b10100;
						end
					else begin
						CheckTag[4:0]<=MemDST;
						CheckTag[5]<=(MemSecondCycle & MemLDST) | (~MemLDST & (MemCNT==2'b01)) | MemADRPushPop;
						CheckTag[6]<=(MemPUSH & (MemCNT==2'b10))|(MemPOP & (MemCNT==2'b00))| MemADRPushPop;
						CheckTag[7]<=MemLDO;
						CheckTag[8]<=1'b0;
						end
		end
	// reloading descriptor when he loaded from table
	if (DTRLoadedFlag)
		begin
		CheckBase<=DTR[CheckSEL][39:0];
		CheckLL<=DTR[CheckSEL][71:40];
		CheckUL<=DTR[CheckSEL][103:72];
		CheckLowerSel<=DTR[CheckSEL][127:104];
		CheckUpperSel<=DTR[CheckSEL][151:128];
		CheckAR<=DTR[CheckSEL][155:152];
		end

	//
	// output stage
	//
	// local memory access activation
	ACT<=(ACT & ~NEXT) | (CheckNext & CheckACT & CheckAR[3] & ~CheckNetwork & ~CheckAR[2] & (CheckOffset[36:5]>=CheckLL) & (CheckOffset[36:5]<CheckUL) & (CheckCMD | CheckAR[1]) & 
									(~CheckCMD | CheckAR[0])) | (DLMachine==LBS) | (DLMachine==LLSS) | (DLMachine==LSLS) |
									((DLMachine==STS) & (CheckTag[8:3]==6'h28));
	// stream access activation
	StreamACT<=(StreamACT & ~StreamNEXT) | (CheckACT & CheckAR[3] & ~CheckNetwork & CheckAR[2] & CheckNext);
	
	// network access activation
	NetACT<=(NetACT & ~NetNEXT) | (CheckNext & CheckACT & CheckNetwork);
	
	if ((~ACT | NEXT) & (~StreamACT | StreamNEXT) & (~NetACT | NetNEXT))
		begin
		// command
		CMD<=CheckCMD | DescriptorLoadState;
		// operand size
		OS<=CheckOS | {2{DescriptorLoadState}};
		// forming physical address
		ADDRESS[2:0]<=DescriptorLoadState ? 3'b000 : CheckOffset[2:0];
		ADDRESS[3]<=DescriptorLoadState ? (DLMachine==LLSS) : CheckOffset[3];
		ADDRESS[4]<=DescriptorLoadState ? (DLMachine==LSLS) : CheckOffset[4];
		ADDRESS[44:5]<=DescriptorLoadState ? DTBASE + {16'd0, DLSelector} : (CheckNetwork ? {8'd0,CheckOffset[36:5]} : CheckBase+{8'd0,(CheckOffset[36:5]-CheckLL)});
		// offset
		OFFSET<=CheckOffset[36:0];
		// selector (for network accesses)
		SELECTOR<=CheckSelector;
		// data to memory
		DTo<=CheckData;
		// tag
		TAGo[0]<=DescriptorLoadState ? (DLMachine==LLSS) : CheckTag[0];
		TAGo[1]<=DescriptorLoadState ? (DLMachine==LSLS) : CheckTag[1];
		TAGo[4:2]<=DescriptorLoadState ? CheckSEL : CheckTag[4:2] | {((DLMachine==STS) & (CheckTag[8:3]==6'h28)), 2'b00};
		TAGo[8:5]<=DescriptorLoadState ? 4'd8 : CheckTag[8:5];
		end

	//
	// Loading DT registers
	//
	DescriptorLoadState<=(DLMachine==CSS)|(DLMachine==LBS)|(DLMachine==LLSS)|(DLMachine==LSLS);
	// state machine for descriptor loading
		case (DLMachine)
				// wait state
				WS:	if (LoadNewDSC | LoadLowerDSC | LoadUpperDSC) DLMachine<=CSS;
						else if (AccessError) DLMachine<=AERSS;
								else DLMachine<=WS;
				// checking selector value
				CSS: if (DLSelector==24'd0) DLMachine<=ZSS;
						else if (DLSelector>=DTLIMIT) DLMachine<=INVSS;
							else DLMachine<=LBS;
				// load base address and access rights
				LBS: if (~ACT | NEXT) DLMachine<=LLSS;
						else DLMachine<=LBS;
				// load link selectors and check descriptor type
				LLSS: if (~ACT | NEXT) DLMachine<=LSLS;
						else DLMachine<=LLSS;
				// load segment limits
				LSLS: if (~ACT | NEXT) DLMachine<=RWS;
						else DLMachine<=LSLS;
				// waiting for transaction retry condition
				RWS: if (~RetryTransactionFlag) DLMachine<=RWS;
						else if (~ValidDescriptor) DLMachine<=INVOBS;
								else DLMachine<=WS;
				// zero selector reporting
				ZSS: DLMachine<=STS;
				// invalid selector reporting
				INVSS: DLMachine<=STS;
				// invalid object reporting (CPL or type)
				INVOBS: DLMachine<=STS;
				// access error
				AERSS: DLMachine<=STS;
				// skip transaction after error reporting
				STS: if ((CheckTag[8:3]==6'h28) & ~CheckNext) DLMachine<=STS;
						else DLMachine<=WS;
				endcase
	// temporary selector register
	if (DLMachine==WS) for (i7=0; i7<24; i7=i7+1) DLSelector[i7]<=(LoadNewDSC & CheckSelector[i7])|
																	(LoadLowerDSC & CheckLowerSel[i7])|
																	(LoadUpperDSC & CheckUpperSel[i7]);
				
	// 0 - base and AR, 1 - link selectors, 2 - limits
	for (i8=0; i8<8; i8=i8+1)
				if (DTRWriteFlag[i8])
					case (TAGiReg[1:0])
						2'b00 : begin
								DTR[i8][39:0]<=DTi[39:0];
								DTR[i8][153:152]<=DTi[61:60];
								DTR[i8][154]<=DTi[56];
								DTR[i8][155]<=DTi[57] & (CPL<=DTi[59:58]) & ((TASKID==DTi[55:40]) | (~(|TASKID)) | (~(|DTi[55:40])));
								end
						2'b01 : begin
								DTR[i8][127:104]<=DTi[23:0];
								DTR[i8][151:128]<=DTi[55:32];
								end
						2'b10 :	begin
								DTR[i8][103:40]<=DTi;
								end
						2'b11 :	DTR[i8]<=156'hB000000000000FFFFFFFF000000000000000000;
						endcase
	DTRLoadedFlag<=DTRWriteFlag[8] & (TAGiReg[1:0]==2'b10);
	// flag to enable check transaction again
	RetryTransactionFlag<=DTRLoadedFlag;

	// valid descriptor flag
	if (DTRWriteFlag[8] & (TAGiReg[1:0]==2'b00))
		begin
		ValidDescriptor<=DTi[57] & (CPL<=DTi[59:58]) & ((TASKID==DTi[55:40]) | (~(|TASKID)) | (~(|DTi[55:40])));
		InvalidType<=~DTi[57];
		InvalidCPL<=(CPL>DTi[59:58]);
		InvalidTaskID<=(TASKID!=DTi[55:40]) & (|TASKID) & (|DTi[55:40]);
		InvalidSelector<=CheckSelector[23:0];
		end
	
	// skip read operation (validate flags)
	SkipDataRead<=CheckACT & CheckCMD & (DLMachine==STS) & ~CheckTag[8] & ~CheckTag[6];
	if (DLMachine==STS) STAGReg<=CheckTag[4:0];

	end

endmodule
