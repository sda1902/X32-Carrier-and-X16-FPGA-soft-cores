module ContextCTRL4T ( 
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


// resources for loading and saving context of EU registers
reg [41:0] ContextAddressReg;
reg [42:0] ContextStartAddrReg;
reg ContextProcFlag, ContextLoadFlag, ContextReqFlag;
reg [7:0] ContextCntr;

reg [31:0] MainControlReg;

logic [77:0] EuDataBus;
logic EuDataValid;
reg [63:0] DataToEuReg;
reg DataToEuRequestReg;

reg [23:0] ScanDTReg;
reg [8:0] NewRegIndex;
reg [8:0] EUREG_reg [3:0];

logic [3:0] MPUWSTB, MPURSTB;
reg [31:0] IOSRCBus[3:0];
logic [7:0] MPUReqBus, MPUMaskBus, MPUAckBus;
logic [39:0] MPUBaseBus[1:0];
logic [31:0] DToBus;
logic ExtFlag, McuReset;

logic [55:0] FreeRamData;
reg [55:0] RamDataReg;
reg [7:0] RAMAddrReg;
reg [10:0] ProcAddrReg[2:0];
reg [23:0] SelReg, FoundSelReg;
reg [31:0] LengthReg, FoundLengthReg;
reg WriteReqFlag, SearchReqFlag, ClearReqFlag, FreeReqFlag, ClearProcFlag, SearchProcFlag, EndProcFlag,
	FreeProcFlag, LengthFoundFlag, FreeFoundFlag, CalcReqFlag, CalcProcFlag, EmptyFreeProcFlag, EmptySearchProcFlag,
	EmptyFreeReqFlag, EmptySearchReqFlag, EmptyFoundFlag, MemAllocLockFlag, MemAllocResetReq, MALOCKFReg;
logic [2:0] ProcType, AuxMuxReg;

reg [3:0] MAllocReqFlag, GetParFlag, EndMsgFlag, TimerReqFlag, RegIndexSetReg, CPReqFlag, ErrorFlag;

logic [3:0] EUSEL, MAllocSEL, GetParSEL, EndMsgSEL, TimerSEL, EUFREE;
reg [1:0] ThreadReg, ThreadReqReg;

reg [3:0] CPSREqu;
reg CPSRCheckFlag;
reg [23:0] CPSRCheckReg;

// An extern module declaration specifies the module's parameters
// and ports.  It provides a prototype for a module that does not
// depend directly on the module declaration.  
extern module Microcontroller4T #(parameter Code) 
(	input wire CLK, RESET, CF,
	// IO Bus
	output reg [3:0] IOWSTB,
	output reg [3:0] IORSTB,
	input wire [31:0] IOSRC [3:0],
	// memory interface
	input wire NEXT,
	output reg ACT, CMD,
	output reg [1:0] SIZE,
	output reg [44:0] ADDRESS,
	output reg [31:0] DTo,
	input wire DRDY,
	input wire [31:0] DTi,
	// external requests
	input wire [7:0] REQ,
	input wire [7:0] IMASK,
	output reg [7:0] IACK,
	// external base sources
	input wire [39:0] BASE [1:0]
);
Microcontroller4T MPU (.CLK(CLK),.RESET(McuReset), .CF(CPSRCheckFlag ? (|CPSREqu):ExtFlag), .IOWSTB(MPUWSTB),.IORSTB(MPURSTB),.IOSRC(IOSRCBus),
						.NEXT(NEXT[1]),.ACT(ACT[1]),.CMD(CMD[1]),.SIZE(SIZE[1]),.ADDRESS(ADDR[1]),.DTo(DToBus),.DRDY(DRDY[1]),
						.DTi(DTi[31:0]), .REQ(MPUReqBus), .IMASK(MPUMaskBus), .IACK(MPUAckBus), .BASE(MPUBaseBus));
defparam MPU.Code="Context4T.mif";

sc_fifo_thr EUFIFO(.data(DRDY[0] ? {SZi,TAGi,DTi} : {3'b011,ThreadReg,ThreadReg[1] ? (ThreadReg[0] ? EUREG_reg[3] : EUREG_reg[2]):(ThreadReg[0] ? EUREG_reg[1] : EUREG_reg[0]),DataToEuReg}),
			.wrreq(DRDY[0] | DataToEuRequestReg),
			.rdreq(EURD), .clock(CLK), .sclr(~RESETn), .q(EuDataBus), .empty(EuDataValid));
defparam EUFIFO.LPM_WIDTH=78, EUFIFO.LPM_NUMWORDS=16, EUFIFO.LPM_WIDTHU=4;

altsyncram	FreeRam (
				.wren_a(WriteReqFlag | ClearProcFlag), .clock0(CLK), .address_a(RAMAddrReg), .data_a({SelReg,LengthReg} & {56{~ClearProcFlag}}), .q_a(FreeRamData),
				.aclr0(1'b0), .aclr1(1'b0), .address_b(1'b1), .addressstall_a(1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b(1'b1),
				.clock1(1'b1), .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1), .data_b(1'b1), .eccstatus(), .q_b(), .rden_a(1'b1),
				.rden_b (1'b1), .wren_b (1'b0));
defparam
	FreeRam.clock_enable_input_a = "BYPASS",
	FreeRam.clock_enable_output_a = "BYPASS",
	FreeRam.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	FreeRam.lpm_type = "altsyncram",
	FreeRam.numwords_a = 256,
	FreeRam.operation_mode = "SINGLE_PORT",
	FreeRam.outdata_aclr_a = "NONE",
	FreeRam.outdata_reg_a = "CLOCK0",
	FreeRam.power_up_uninitialized = "FALSE",
	FreeRam.init_file = "FreeRam.mif",
	FreeRam.widthad_a = 8,
	FreeRam.width_a = 56,
	FreeRam.width_byteena_a = 1;

// EU data requests arbiter
Arbiter		EUArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(NEXT[0] & ~ContextProcFlag), .REQ(EUACT), .SEL(EUSEL));

// memory allocation arbiter
Arbiter		MAllocArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[2]), .REQ(MAllocReqFlag), .SEL(MAllocSEL));

// get message parameter arbiter
Arbiter		GetParArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[3]), .REQ(GetParFlag), .SEL(GetParSEL));

// end message request
Arbiter		EndMsgArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[4]), .REQ(EndMsgFlag), .SEL(EndMsgSEL));

// process timer arbiter
Arbiter		TimerArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[6]), .REQ(TimerReqFlag), .SEL(TimerSEL));

//=================================================================================================
//		assignments
//=================================================================================================
assign RA=ContextCntr[7:1];
assign DTo[1]={32'd0,DToBus};
assign EUCLOAD[0]=ContextProcFlag & ~ThreadReg[1] & ~ThreadReg[0];
assign EUCLOAD[1]=ContextProcFlag & ~ThreadReg[1] & ThreadReg[0];
assign EUCLOAD[2]=ContextProcFlag & ThreadReg[1] & ~ThreadReg[0];
assign EUCLOAD[3]=ContextProcFlag & ThreadReg[1] & ThreadReg[0];
assign TAGo[1]={ThreadReg,9'd0};
assign EUNEXT[0]=NEXT[0] & ~ContextProcFlag & EUSEL[0];
assign EUNEXT[1]=NEXT[0] & ~ContextProcFlag & EUSEL[1];
assign EUNEXT[2]=NEXT[0] & ~ContextProcFlag & EUSEL[2];
assign EUNEXT[3]=NEXT[0] & ~ContextProcFlag & EUSEL[3];
assign EUDRDY[0]=~EuDataValid & ~EuDataBus[74] & ~EuDataBus[73];
assign EUDRDY[1]=~EuDataValid & ~EuDataBus[74] & EuDataBus[73];
assign EUDRDY[2]=~EuDataValid & EuDataBus[74] & ~EuDataBus[73];
assign EUDRDY[3]=~EuDataValid & EuDataBus[74] & EuDataBus[73];
assign EUDTi=EuDataBus[63:0];
assign EUTAGi=EuDataBus[72:64];
assign EUSZi=EuDataBus[77:75];

//=================================================================================================
//		Logic
//=================================================================================================

always_comb
begin

// base address of descriptor table
MPUBaseBus[0]=DTBASE;
MPUBaseBus[1]=40'hFFFFFFFFFC;

// scan register
IOSRCBus[2]=FoundLengthReg;
IOSRCBus[3]={8'd0,FoundSelReg};

//-----------------------------------------------
// requests to the controller
//-----------------------------------------------
// memory allocation system restart
MPUReqBus[0]=MemAllocResetReq;
// clear process request
MPUReqBus[1]=|CPINTR;
// memory allocation request
MPUReqBus[2]=|MAllocReqFlag;
// Get message parameter request
MPUReqBus[3]=|GetParFlag;
// end of message request from EU
MPUReqBus[4]=|EndMsgFlag;
// message or interrupt request
MPUReqBus[5]=MSGREQ;
// task timer interrupt
MPUReqBus[6]=(TimerReqFlag[0] & EUEMPTY[0])|(TimerReqFlag[1] & EUEMPTY[1])|(TimerReqFlag[2] & EUEMPTY[2])|(TimerReqFlag[3] & EUEMPTY[3]);
// check message queue interrupt
MPUReqBus[7]=CHKREQ;

// mask bus
MPUMaskBus={5'b11111,~MemAllocLockFlag,2'b11};


//
// Type of FreeRam operation
//
// 1 - Clear RAM
// 2 - Search free position in RAM (for free object or free entry)
// 3 - Search free object with enougth length
// 4 - Search free DT entry
// 5 - Calc free space
ProcType[0]=~EndProcFlag & (ClearProcFlag | SearchProcFlag | CalcProcFlag);
ProcType[1]=~EndProcFlag & (FreeProcFlag | EmptyFreeProcFlag | SearchProcFlag);
ProcType[2]=~EndProcFlag & (EmptySearchProcFlag | CalcProcFlag);

//-----------------------------------------------
// EU channel
//-----------------------------------------------
ACT[0]=((|EUACT) & ~ContextProcFlag) | ContextCntr[0];
// command
CMD[0]=ContextProcFlag ? ContextLoadFlag:((EUCMD[0] & EUSEL[0])|(EUCMD[1] & EUSEL[1])|(EUCMD[2] & EUSEL[2])|(EUCMD[3] & EUSEL[3]));
// size
SIZE[0]=ContextProcFlag ? 2'b11:((EUSZo[0]&{2{EUSEL[0]}})|(EUSZo[1]&{2{EUSEL[1]}})|(EUSZo[2]&{2{EUSEL[2]}})|(EUSZo[3]&{2{EUSEL[3]}}));
// address
ADDR[0]=ContextProcFlag ? {ContextAddressReg,3'd0}:((EUADDR[0]&{45{EUSEL[0]}})|(EUADDR[1]&{45{EUSEL[1]}})|(EUADDR[2]&{45{EUSEL[2]}})|(EUADDR[3]&{45{EUSEL[3]}}));
// tag
TAGo[0]=ContextProcFlag ? {ThreadReg,2'b0,ContextCntr[7:1]}:{EUSEL[3] | EUSEL[2], EUSEL[3] | EUSEL[1], ((EUTAGo[0]&{9{EUSEL[0]}})|(EUTAGo[1]&{9{EUSEL[1]}})|(EUTAGo[2]&{9{EUSEL[2]}})|(EUTAGo[3]&{9{EUSEL[3]}}))};
// data to memory
DTo[0]=ContextProcFlag ? ((CDAT[0]&{64{(ThreadReg==2'd0)}})|(CDAT[1]&{64{(ThreadReg==2'd1)}})|(CDAT[2]&{64{(ThreadReg==2'd2)}})|(CDAT[3]&{64{(ThreadReg==2'd3)}})):
						((EUDTo[0]&{64{EUSEL[0]}})|(EUDTo[1]&{64{EUSEL[1]}})|(EUDTo[2]&{64{EUSEL[2]}})|(EUDTo[3]&{64{EUSEL[3]}}));

// EU Free flags
EUFREE[0]=~(|CPSR[0]);
EUFREE[1]=~(|CPSR[1]);
EUFREE[2]=~(|CPSR[2]);
EUFREE[3]=~(|CPSR[3]);

end

//=================================================================================================
//		High-speed interface to memory subsystem
//=================================================================================================
always_ff @(posedge CLK)
begin
// reset to the MCU
McuReset<=RESETn & CENA;
// generate reset signal, if fatal error occurs
RST<=(RST | ~RESETn) & (~(MPUWSTB==4'd3) | ~DToBus[15]);
end

always_ff @(negedge RESETn or posedge CLK)
begin

if (!RESETn) begin
				PTACK<=0;
				READY<=0;
				ContextCntr<=0;
				ContextProcFlag<=1'b0;
				TimerReqFlag<=0;
				MSGACK<=0;
				CORESTART<=0;
				CORESTOP<=0;
				CORECONT<=0;
				CPSR[0]<=0;
				CPSR[1]<=0;
				CPSR[2]<=0;
				CPSR[3]<=0;
				CSR[0]<=0;
				CSR[1]<=0;
				CSR[2]<=0;
				CSR[3]<=0;
				ContextReqFlag<=0;
				RegIndexSetReg<=0;
				SearchProcFlag<=0;
				ClearProcFlag<=0;
				FreeProcFlag<=0;
				CalcProcFlag<=0;
				EmptyFreeProcFlag<=0;
				EmptySearchProcFlag<=0;
				FREEMEM<=40'd0;
				DataToEuRequestReg<=0;
				ESTB<=0;
				EndProcFlag<=0;
				ProcAddrReg[0]<=0;
				ProcAddrReg[1]<=0;
				ProcAddrReg[2]<=0;
				RAMAddrReg<=0;
				WriteReqFlag<=0;
				ClearReqFlag<=0;
				FreeReqFlag<=0;
				CalcReqFlag<=0;
				SearchReqFlag<=0;
				EmptyFreeReqFlag<=0;
				EmptySearchReqFlag<=0;
				EndMsgFlag<=0;
				ThreadReg<=0;
				MemAllocLockFlag<=1'b1;
				MemAllocResetReq<=0;
				MALOCKFReg<=0;
				CPReqFlag<=0;
				GetParFlag<=0;
				MAllocReqFlag<=0;
				CPSREqu<=0;
				CPSRCheckFlag<=0;
				LIRESET<=0;
				ErrorFlag<=0;
				AuxMuxReg<=0;
				end
else begin

// PTInterrupt acknowledge
PTACK<=MPUAckBus[6];

// memory allocation locking
MemAllocLockFlag<=(MemAllocLockFlag | MALOCKF) & (~((MPUWSTB==4'd3) & DToBus[11]));

// request to reset allocation system
MemAllocResetReq<=~MALOCKF & MALOCKFReg;
MALOCKFReg<=MALOCKF;

//-----------------------------------------------
// context controller channel
//-----------------------------------------------
// cycle counter
if ((ContextProcFlag & (~ContextCntr[0] | NEXT[0]))|ContextReqFlag) ContextCntr<=(ContextCntr+8'd1)&{8{~ContextReqFlag}};
// address counter
if (ContextReqFlag) ContextAddressReg<=ContextStartAddrReg[41:0];
	else if (ContextProcFlag & ContextCntr[0] & NEXT[0]) ContextAddressReg<=ContextAddressReg+42'd1;
// context processing flag
ContextProcFlag<=(ContextProcFlag | ContextReqFlag) & ~((ContextCntr=={ThreadReg[1],1'b1,~ThreadReg[1],5'h1F}) & NEXT[0]);
// read/write flag
if (ContextReqFlag) ContextLoadFlag<=ContextStartAddrReg[42];

// EU registers
if (MALLOCREQ[0] | GETPARREQ[0] | RegIndexSetReg[0]) EUREG_reg[0]<=RegIndexSetReg[0] ? NewRegIndex : {4'd0,EUREG[0]};
if (MALLOCREQ[1] | GETPARREQ[1] | RegIndexSetReg[1]) EUREG_reg[1]<=RegIndexSetReg[1] ? NewRegIndex : {4'd0,EUREG[1]};
if (MALLOCREQ[2] | GETPARREQ[2] | RegIndexSetReg[2]) EUREG_reg[2]<=RegIndexSetReg[2] ? NewRegIndex : {4'd0,EUREG[2]};
if (MALLOCREQ[3] | GETPARREQ[3] | RegIndexSetReg[3]) EUREG_reg[3]<=RegIndexSetReg[3] ? NewRegIndex : {4'd0,EUREG[3]};

// clear process requests
CPReqFlag[0]<=(CPReqFlag[0] | CPINTR[0]) & ~MPUAckBus[1];
CPReqFlag[1]<=(CPReqFlag[1] | CPINTR[1]) & ~MPUAckBus[1];
CPReqFlag[2]<=(CPReqFlag[2] | CPINTR[2]) & ~MPUAckBus[1];
CPReqFlag[3]<=(CPReqFlag[3] | CPINTR[3]) & ~MPUAckBus[1];

// memory allocation requests
MAllocReqFlag[0]<=(MAllocReqFlag[0] | MALLOCREQ[0]) & (~MAllocSEL[0] | ~MPUAckBus[2]);
MAllocReqFlag[1]<=(MAllocReqFlag[1] | MALLOCREQ[1]) & (~MAllocSEL[1] | ~MPUAckBus[2]);
MAllocReqFlag[2]<=(MAllocReqFlag[2] | MALLOCREQ[2]) & (~MAllocSEL[2] | ~MPUAckBus[2]);
MAllocReqFlag[3]<=(MAllocReqFlag[3] | MALLOCREQ[3]) & (~MAllocSEL[3] | ~MPUAckBus[2]);

// get message parameter request
GetParFlag[0]<=(GetParFlag[0] | GETPARREQ[0]) & (~GetParSEL[0] | ~MPUAckBus[3]);
GetParFlag[1]<=(GetParFlag[1] | GETPARREQ[1]) & (~GetParSEL[1] | ~MPUAckBus[3]);
GetParFlag[2]<=(GetParFlag[2] | GETPARREQ[2]) & (~GetParSEL[2] | ~MPUAckBus[3]);
GetParFlag[3]<=(GetParFlag[3] | GETPARREQ[3]) & (~GetParSEL[3] | ~MPUAckBus[3]);

// end message requests
EndMsgFlag[0]<=(EndMsgFlag[0] | EUENDMSG[0]) & (~EndMsgSEL[0] | ~MPUAckBus[4]);
EndMsgFlag[1]<=(EndMsgFlag[1] | EUENDMSG[1]) & (~EndMsgSEL[1] | ~MPUAckBus[4]);
EndMsgFlag[2]<=(EndMsgFlag[2] | EUENDMSG[2]) & (~EndMsgSEL[2] | ~MPUAckBus[4]);
EndMsgFlag[3]<=(EndMsgFlag[3] | EUENDMSG[3]) & (~EndMsgSEL[3] | ~MPUAckBus[4]);

// process timer
TimerReqFlag[0]<=(TimerReqFlag[0] | PTINTR[0]) & (~TimerSEL[0] | ~MPUAckBus[6]);
TimerReqFlag[1]<=(TimerReqFlag[1] | PTINTR[1]) & (~TimerSEL[1] | ~MPUAckBus[6]);
TimerReqFlag[2]<=(TimerReqFlag[2] | PTINTR[2]) & (~TimerSEL[2] | ~MPUAckBus[6]);
TimerReqFlag[3]<=(TimerReqFlag[3] | PTINTR[3]) & (~TimerSEL[3] | ~MPUAckBus[6]);

//condition mux
casez ({AuxMuxReg[2:0],MainControlReg[10:8]})
	6'd0: ExtFlag<=SearchProcFlag | ClearProcFlag | FreeProcFlag | CalcProcFlag | EmptyFreeProcFlag | EmptySearchProcFlag;
	6'd1: ExtFlag<=FreeFoundFlag;
	6'd2: ExtFlag<=LengthFoundFlag;
	6'd3: ExtFlag<=EmptyFoundFlag;
	6'd4: ExtFlag<=ContextProcFlag;
	6'd5: ExtFlag<=(~EUEMPTY[0] & (ThreadReg==2'd0))|(~EUEMPTY[1] & (ThreadReg==2'd1))|(~EUEMPTY[2] & (ThreadReg==2'd2))|(~EUEMPTY[3] & (ThreadReg==2'd3));
	6'd6: ExtFlag<=(TimerReqFlag[0] & (ThreadReg==2'd0))|(TimerReqFlag[1] & (ThreadReg==2'd1))|
					(TimerReqFlag[2] & (ThreadReg==2'd2))|(TimerReqFlag[3] & (ThreadReg==2'd3));
	6'd7: ExtFlag<=DataToEuRequestReg;
	6'b001???: ExtFlag<=~MSGERR;
	6'b010???: ExtFlag<=~ErrorFlag[0];
	6'b011???: ExtFlag<=~ErrorFlag[1];
	6'b100???: ExtFlag<=~ErrorFlag[2];
	6'b101???: ExtFlag<=~ErrorFlag[3];
	6'b110???: ExtFlag<=(EUSMSGBKPT[0] & (ThreadReg==2'd0))|(EUSMSGBKPT[1] & (ThreadReg==2'd1))|(EUSMSGBKPT[2] & (ThreadReg==2'd2))|(EUSMSGBKPT[3] & (ThreadReg==2'd3));
	endcase


// microcontroller ports connection
// P1:P0 connected to mux EUParam and MsgParam
case (MainControlReg[2:0])
	3'd0:	begin
			IOSRCBus[0]<=MSGPARAM[31:0];		// entry point offset 
			IOSRCBus[1]<=MSGPARAM[63:32];		// code selector and control byte
			end
	3'd1:	begin
			IOSRCBus[0]<=MSGPARAM[95:64];		// message parameter or PSO Selector
			IOSRCBus[1]<=ThreadReg[1] ? (ThreadReg[0] ? CSR[3] : CSR[2]):(ThreadReg[0] ? CSR[1] : CSR[0]);
			end
	3'd2:	begin
			IOSRCBus[0]<={CPUNUM,DTLIMIT};
			IOSRCBus[1]<={8'd0,ThreadReg[1] ? (ThreadReg[0] ? CPSR[3] : CPSR[2]):(ThreadReg[0] ? CPSR[1] : CPSR[0])};
			end
	3'd3:	begin
			IOSRCBus[0]<=ThreadReg[1] ? (ThreadReg[0] ? RIP[3][31:0] : RIP[2][31:0]):(ThreadReg[0] ? RIP[1][31:0] : RIP[0][31:0]);
			IOSRCBus[1]<=ScanDTReg;
			end
	3'd4:	begin
			IOSRCBus[0]<=FREEMEM[31:0];
			IOSRCBus[1]<={24'd0,FREEMEM[39:32]};
			end
	3'd5:	begin
			IOSRCBus[0]<=CACHEDMEM[31:0];
			IOSRCBus[1]<={24'd0,CACHEDMEM[39:32]};
			end
	3'd6:	begin
			IOSRCBus[0]<=ThreadReg[1] ? (ThreadReg[0] ? EUPARAM[3][31:0] : EUPARAM[2][31:0]):(ThreadReg[0] ? EUPARAM[1][31:0] : EUPARAM[0][31:0]);
			IOSRCBus[1]<=ThreadReg[1] ? (ThreadReg[0] ? EUPARAM[3][63:32] : EUPARAM[2][63:32]):(ThreadReg[0] ? EUPARAM[1][63:32] : EUPARAM[0][63:32]);
			end
	3'd7:	begin
			IOSRCBus[0]<={ThreadReg,EUFREE,MSGTT,20'd0,ThreadReg[1] ? (ThreadReg[0] ? RIP[3][36:32] : RIP[2][36:32]):(ThreadReg[0] ? RIP[1][36:32] : RIP[0][36:32])};
			IOSRCBus[1]<=ThreadReg[1] ? 32'h3D0 : 32'h250;
			end
	endcase

// start address register for context load/store
if (MPUWSTB==4'd1) ContextStartAddrReg[28:0]<=DToBus[31:3];
if (MPUWSTB==4'd2) ContextStartAddrReg[42:29]<=DToBus[13:0];
if (MPUWSTB==4'd3) MainControlReg<=DToBus;

// generate acknowledgement to the messenger
MSGACK<=(MPUWSTB==4'd3) & DToBus[14] & ~DToBus[22];
CHKACK<=(MPUWSTB==4'd3) & DToBus[14] & DToBus[22];

// core start
CORESTART[0]<=(MPUWSTB==4'd3) & DToBus[3] & (ThreadReg==2'd0);
CORESTART[1]<=(MPUWSTB==4'd3) & DToBus[3] & (ThreadReg==2'd1);
CORESTART[2]<=(MPUWSTB==4'd3) & DToBus[3] & (ThreadReg==2'd2);
CORESTART[3]<=(MPUWSTB==4'd3) & DToBus[3] & (ThreadReg==2'd3);

// core stop generation
CORESTOP[0]<=((MPUWSTB==4'd3) & DToBus[16] & (ThreadReg==2'd0)) | PTINTR[0] | ((MPUWSTB==4'd2) & (ThreadReg==2'd0)); 
				// | (MSGREQ & (MSGCHAN==2'd0)) | (CHKREQ & (MSGCHAN==2'd0));
CORESTOP[1]<=((MPUWSTB==4'd3) & DToBus[16] & (ThreadReg==2'd1)) | PTINTR[1] | ((MPUWSTB==4'd2) & (ThreadReg==2'd1)); 
				// | (MSGREQ & (MSGCHAN==2'd1)) | (CHKREQ & (MSGCHAN==2'd1));
CORESTOP[2]<=((MPUWSTB==4'd3) & DToBus[16] & (ThreadReg==2'd2)) | PTINTR[2] | ((MPUWSTB==4'd2) & (ThreadReg==2'd2)); 
				// | (MSGREQ & (MSGCHAN==2'd2)) | (CHKREQ & (MSGCHAN==2'd2));
CORESTOP[3]<=((MPUWSTB==4'd3) & DToBus[16] & (ThreadReg==2'd3)) | PTINTR[3] | ((MPUWSTB==4'd2) & (ThreadReg==2'd3)); 
				// | (MSGREQ & (MSGCHAN==2'd3)) | (CHKREQ & (MSGCHAN==2'd3));

// core continue signal generation
CORECONT[0]<=((MPUWSTB==4'd3) & DToBus[17] & (ThreadReg==2'd0));
CORECONT[1]<=((MPUWSTB==4'd3) & DToBus[17] & (ThreadReg==2'd1));
CORECONT[2]<=((MPUWSTB==4'd3) & DToBus[17] & (ThreadReg==2'd2));
CORECONT[3]<=((MPUWSTB==4'd3) & DToBus[17] & (ThreadReg==2'd3));

// Channel selection flag
if ((MPUWSTB==4'd3) & DToBus[21]) ThreadReg<=DToBus[20] ? ThreadReqReg : DToBus[19:18];
	else if (MPUAckBus[1]) ThreadReg<={CPReqFlag[3] | CPReqFlag[2], CPReqFlag[3] | CPReqFlag[1]};
		else if (MPUAckBus[2]) ThreadReg<={MAllocSEL[3] | MAllocSEL[2], MAllocSEL[3] | MAllocSEL[1]};
			else if (MPUAckBus[3]) ThreadReg<={GetParSEL[3] | GetParSEL[2], GetParSEL[3] | GetParSEL[1]};
				else if (MPUAckBus[4]) ThreadReg<={EndMsgSEL[3] | EndMsgSEL[2], EndMsgSEL[3] | EndMsgSEL[1]};
					else if (MPUAckBus[5] | MPUAckBus[7]) ThreadReg<=MSGCHAN;
						else if (MPUAckBus[6]) ThreadReg<={TimerSEL[3] | TimerSEL[2], TimerSEL[3] | TimerSEL[1]};
							else if ((MPUWSTB==4'd13) & DToBus[0]) ThreadReg<={CPSREqu[3] | CPSREqu[2], CPSREqu[3] | CPSREqu[1]};

if (MPUAckBus[1]) ThreadReqReg<={CPReqFlag[3] | CPReqFlag[2], CPReqFlag[3] | CPReqFlag[1]};
	else if (MPUAckBus[2]) ThreadReqReg<={MAllocSEL[3] | MAllocSEL[2], MAllocSEL[3] | MAllocSEL[1]};
		else if (MPUAckBus[3]) ThreadReqReg<={GetParSEL[3] | GetParSEL[2], GetParSEL[3] | GetParSEL[1]};
			else if (MPUAckBus[4]) ThreadReqReg<={EndMsgSEL[3] | EndMsgSEL[2], EndMsgSEL[3] | EndMsgSEL[1]};
				else if (MPUAckBus[5] | MPUAckBus[7]) ThreadReqReg<=MSGCHAN;
					else if (MPUAckBus[6]) ThreadReqReg<={TimerSEL[3] | TimerSEL[2], TimerSEL[3] | TimerSEL[1]};

// data register for sending information to EU
if (MPUWSTB==4'd4) DataToEuReg[31:0]<=DToBus;
if (MPUWSTB==4'd5) DataToEuReg[63:32]<=DToBus;

// current DT index for table scan mode
if (MPUWSTB==4'd6) LengthReg<=DToBus;
if (MPUWSTB==4'd7) SelReg<=DToBus[23:0];
if (MPUWSTB==4'd8) ScanDTReg<=DToBus[23:0];

// CPSR register modification
if ((MPUWSTB==4'd9) & (ThreadReg==2'd0)) CPSR[0][7:0]<=DToBus[7:0];
	else if (CPSRSTB[0][0]) CPSR[0][7:0]<=EXTDI[39:32];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd0)) CPSR[0][15:8]<=DToBus[15:8];
	else if (CPSRSTB[0][1]) CPSR[0][15:8]<=EXTDI[47:40];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd0)) CPSR[0][23:16]<=DToBus[23:16];
	else if (CPSRSTB[0][2]) CPSR[0][23:16]<=EXTDI[55:48];
	
if ((MPUWSTB==4'd9) & (ThreadReg==2'd1)) CPSR[1][7:0]<=DToBus[7:0];
	else if (CPSRSTB[1][0]) CPSR[1][7:0]<=EXTDI[39:32];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd1)) CPSR[1][15:8]<=DToBus[15:8];
	else if (CPSRSTB[1][1]) CPSR[1][15:8]<=EXTDI[47:40];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd1)) CPSR[1][23:16]<=DToBus[23:16];
	else if (CPSRSTB[1][2]) CPSR[1][23:16]<=EXTDI[55:48];
	
if ((MPUWSTB==4'd9) & (ThreadReg==2'd2)) CPSR[2][7:0]<=DToBus[7:0];
	else if (CPSRSTB[2][0]) CPSR[2][7:0]<=EXTDI[39:32];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd2)) CPSR[2][15:8]<=DToBus[15:8];
	else if (CPSRSTB[2][1]) CPSR[2][15:8]<=EXTDI[47:40];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd2)) CPSR[2][23:16]<=DToBus[23:16];
	else if (CPSRSTB[2][2]) CPSR[2][23:16]<=EXTDI[55:48];
	
if ((MPUWSTB==4'd9) & (ThreadReg==2'd3)) CPSR[3][7:0]<=DToBus[7:0];
	else if (CPSRSTB[3][0]) CPSR[3][7:0]<=EXTDI[39:32];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd3)) CPSR[3][15:8]<=DToBus[15:8];
	else if (CPSRSTB[3][1]) CPSR[3][15:8]<=EXTDI[47:40];
if ((MPUWSTB==4'd9) & (ThreadReg==2'd3)) CPSR[3][23:16]<=DToBus[23:16];
	else if (CPSRSTB[3][2]) CPSR[3][23:16]<=EXTDI[55:48];

// CSR register
if ((MPUWSTB==4'd10) & (ThreadReg==2'd0)) CSR[0][7:0]<=DToBus[7:0];
	else if (CSRSTB[0][0]) CSR[0][7:0]<=EXTDI[7:0];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd0)) CSR[0][15:8]<=DToBus[15:8];
	else if (CSRSTB[0][1]) CSR[0][15:8]<=EXTDI[15:8];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd0)) CSR[0][23:16]<=DToBus[23:16];
	else if (CSRSTB[0][2]) CSR[0][23:16]<=EXTDI[23:16];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd0)) CSR[0][31:24]<=DToBus[31:24];
	else if (CSRSTB[0][3]) CSR[0][31:24]<=EXTDI[31:24];

if ((MPUWSTB==4'd10) & (ThreadReg==2'd1)) CSR[1][7:0]<=DToBus[7:0];
	else if (CSRSTB[1][0]) CSR[1][7:0]<=EXTDI[7:0];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd1)) CSR[1][15:8]<=DToBus[15:8];
	else if (CSRSTB[1][1]) CSR[1][15:8]<=EXTDI[15:8];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd1)) CSR[1][23:16]<=DToBus[23:16];
	else if (CSRSTB[1][2]) CSR[1][23:16]<=EXTDI[23:16];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd1)) CSR[1][31:24]<=DToBus[31:24];
	else if (CSRSTB[1][3]) CSR[1][31:24]<=EXTDI[31:24];

if ((MPUWSTB==4'd10) & (ThreadReg==2'd2)) CSR[2][7:0]<=DToBus[7:0];
	else if (CSRSTB[2][0]) CSR[2][7:0]<=EXTDI[7:0];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd2)) CSR[2][15:8]<=DToBus[15:8];
	else if (CSRSTB[2][1]) CSR[2][15:8]<=EXTDI[15:8];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd2)) CSR[2][23:16]<=DToBus[23:16];
	else if (CSRSTB[2][2]) CSR[2][23:16]<=EXTDI[23:16];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd2)) CSR[2][31:24]<=DToBus[31:24];
	else if (CSRSTB[2][3]) CSR[2][31:24]<=EXTDI[31:24];

if ((MPUWSTB==4'd10) & (ThreadReg==2'd3)) CSR[3][7:0]<=DToBus[7:0];
	else if (CSRSTB[3][0]) CSR[3][7:0]<=EXTDI[7:0];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd3)) CSR[3][15:8]<=DToBus[15:8];
	else if (CSRSTB[3][1]) CSR[3][15:8]<=EXTDI[15:8];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd3)) CSR[3][23:16]<=DToBus[23:16];
	else if (CSRSTB[3][2]) CSR[3][23:16]<=EXTDI[23:16];
if ((MPUWSTB==4'd10) & (ThreadReg==2'd3)) CSR[3][31:24]<=DToBus[31:24];
	else if (CSRSTB[3][3]) CSR[3][31:24]<=EXTDI[31:24];

// error report interface
if (MPUWSTB==4'd11) ERC<=DToBus;
// error signal
ESTB<=(MPUWSTB==4'd11);


//request to load/store context.
ContextReqFlag<=(ContextReqFlag | (MPUWSTB==4'd2)) & ~ContextProcFlag;
	
// sending data to the EU
DataToEuRequestReg<=(MPUWSTB==4'd5) | (DataToEuRequestReg & DRDY[0]);

// setting new core register index
RegIndexSetReg[0]<=(MPUWSTB==4'd3) & DToBus[31] & ~ThreadReg[1] & ~ThreadReg[0];
RegIndexSetReg[1]<=(MPUWSTB==4'd3) & DToBus[31] & ~ThreadReg[1] & ThreadReg[0];
RegIndexSetReg[2]<=(MPUWSTB==4'd3) & DToBus[31] & ThreadReg[1] & ~ThreadReg[0];
RegIndexSetReg[3]<=(MPUWSTB==4'd3) & DToBus[31] & ThreadReg[1] & ThreadReg[0];
if ((MPUWSTB==4'd3) & DToBus[31]) NewRegIndex<=DToBus[30:22];

//-----------------------------------------------
// free objects cache
//-----------------------------------------------
// requests to the controller
WriteReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd1);
ClearReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd2);
FreeReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd3);
CalcReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd4);
SearchReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd5);
EmptyFreeReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd6);
EmptySearchReqFlag<=(MPUWSTB==4'd3) & (DToBus[7:4]==4'd7);

// processing flags
SearchProcFlag<=(SearchProcFlag | SearchReqFlag) & ~EndProcFlag;
ClearProcFlag<=(ClearProcFlag | ClearReqFlag) & ~EndProcFlag;
FreeProcFlag<=(FreeProcFlag | FreeReqFlag) & ~EndProcFlag;
CalcProcFlag<=(CalcProcFlag | CalcReqFlag) & ~EndProcFlag;
EmptyFreeProcFlag<=(EmptyFreeProcFlag | EmptyFreeReqFlag) & ~EndProcFlag;
EmptySearchProcFlag<=(EmptySearchProcFlag | EmptySearchReqFlag) & ~EndProcFlag;

// address counter for free buffer
if (SearchReqFlag | ClearReqFlag | FreeReqFlag | CalcReqFlag | EmptyFreeReqFlag | EmptySearchReqFlag) RAMAddrReg<={SearchReqFlag | FreeReqFlag | CalcReqFlag, 7'd0};
	else if (EndProcFlag & (SearchProcFlag | ClearProcFlag | FreeProcFlag | CalcProcFlag | EmptyFreeProcFlag | EmptySearchProcFlag)) RAMAddrReg<=ProcAddrReg[2][7:0];
		else if (SearchProcFlag | ClearProcFlag | FreeProcFlag | CalcProcFlag | EmptyFreeProcFlag | EmptySearchProcFlag) RAMAddrReg<=RAMAddrReg+8'd1;
		
// Free space calculation
if (MPUWSTB==4'd3)
				case (DToBus[13:12])
					2'd0: FREEMEM<=FREEMEM;
					2'd1: FREEMEM<=40'd0;
					2'd2: FREEMEM<=FREEMEM+{8'd0,LengthReg};
					2'd3: FREEMEM<=FREEMEM-{8'd0,LengthReg}-40'd1;
					endcase
// Cached free space calculation
if (CalcReqFlag) CACHEDMEM<=40'd0;
	else if (ProcAddrReg[2][10:8]==3'd5) CACHEDMEM<=CACHEDMEM+{8'd0,RamDataReg[31:0]};

// delayed address registers
// states
// 1 - Clear RAM
// 2 - Search free position in RAM (for free object or free entry)
// 3 - Search free object with enougth length
// 4 - Search free DT entry
// 5 - Calc free space
//
ProcAddrReg[0]<={ProcType,RAMAddrReg};
ProcAddrReg[1]<=ProcAddrReg[0];
ProcAddrReg[2]<=ProcAddrReg[1];

// flag if object found
if (SearchReqFlag) LengthFoundFlag<=1'b0;
	else if (SearchProcFlag & ~EndProcFlag) LengthFoundFlag<=(ProcAddrReg[1][10:8]==3'd3) & (LengthReg<=FreeRamData[31:0]);
// flag if free position found
if (FreeReqFlag | EmptyFreeReqFlag) FreeFoundFlag<=1'b0;
	else if ((FreeProcFlag | EmptyFreeProcFlag) & ~EndProcFlag) FreeFoundFlag<=(ProcAddrReg[1][10:8]==3'd2) & ~(|FreeRamData[55:32]);
// flag if free DT entry found
if (EmptySearchReqFlag) EmptyFoundFlag<=1'b0;
	else if (EmptySearchProcFlag & ~EndProcFlag) EmptyFoundFlag<=(ProcAddrReg[1][10:8]==3'd4) & (|FreeRamData[55:32]);

// delayed free ram data
RamDataReg<=FreeRamData;

// end processing flag
EndProcFlag<=(&RAMAddrReg[6:0] & (RAMAddrReg[7] | ~(ProcAddrReg[1][10:8]==3'd1))) |
			((ProcAddrReg[1][10:8]==3'd2) & ~(|FreeRamData[55:32])) |
			((ProcAddrReg[1][10:8]==3'd3) & (LengthReg<=FreeRamData[31:0])) |
			((ProcAddrReg[1][10:8]==3'd4) & |FreeRamData[55:32]);

// registers for found length and selector
if (LengthFoundFlag)
	begin
	FoundLengthReg<=RamDataReg[31:0];
	FoundSelReg<=RamDataReg[55:32];
	end

// generate ready signal
READY<=(READY | ((MPUWSTB==4'd3) & DToBus[11])) & CENA & ~MALOCKF;

// PSO comparators
if (MPUWSTB==4'd12) CPSRCheckReg<=DToBus[23:0];
CPSREqu[0]<=(CPSR[0]==CPSRCheckReg);
CPSREqu[1]<=(CPSR[1]==CPSRCheckReg);
CPSREqu[2]<=(CPSR[2]==CPSRCheckReg);
CPSREqu[3]<=(CPSR[3]==CPSRCheckReg);
CPSRCheckFlag<=(CPSRCheckFlag | (MPUWSTB==4'd12)) & (MPUWSTB!=4'd3);

// LIRESET
LIRESET[0]<=(MPUWSTB==4'd13) & DToBus[1] & ~ThreadReg[1] & ~ThreadReg[0];
LIRESET[1]<=(MPUWSTB==4'd13) & DToBus[1] & ~ThreadReg[1] & ThreadReg[0];
LIRESET[2]<=(MPUWSTB==4'd13) & DToBus[1] & ThreadReg[1] & ~ThreadReg[0];
LIRESET[3]<=(MPUWSTB==4'd13) & DToBus[1] & ThreadReg[1] & ThreadReg[0];

// error flags
ErrorFlag[0]<=(ErrorFlag[0] | EUERROR[0]) & ~((MPUWSTB==4'd13) & DToBus[2]);
ErrorFlag[1]<=(ErrorFlag[1] | EUERROR[1]) & ~((MPUWSTB==4'd13) & DToBus[2]);
ErrorFlag[2]<=(ErrorFlag[2] | EUERROR[2]) & ~((MPUWSTB==4'd13) & DToBus[2]);
ErrorFlag[3]<=(ErrorFlag[3] | EUERROR[3]) & ~((MPUWSTB==4'd13) & DToBus[2]);

// auxiliary mux control
if ((MPUWSTB==4'd13) | (MPUWSTB==4'd3)) AuxMuxReg<=DToBus[10:8] & {3{(MPUWSTB==4'd13)}};

end
end

/*
	control port format (P13)
[2:0]	- mux control 
[3]		- core restart bit
[7:4]	- control interface to the free mem cache

[10:8]	- EF mux control
[11]	- Ready signal generation
[13:12]	- instruction for free space calculation method
[14]	- ACT to messenger [22]=0 - MSGACK, [22]=1 - CHKACK
[15]	- hardware reset generation
[16]	- core stop signal

[17]	- core continue signal, after MEMALLOC and GETPAR inctructions
[19:18]	- Thread selection
[20]	- Select thread index from request thread index register
[21]	- enable to change thread selection bits

[30:22] - index of core register
[31]	- set the core register index

	control port format (P23)
[0]		- set thread number from free thread flags
[1]		- generate LIRESET
[2]		- reset ErrorFlag
[10:8]	- AuxMuxReg
*/

endmodule
