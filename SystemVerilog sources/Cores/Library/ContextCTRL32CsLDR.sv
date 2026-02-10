module ContextCTRL32CsLDR ( 
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
	output reg CfgReset, CfgRequest,
	input wire CfgFreeze,
	input wire [3:0] CfgStatus,
	output reg CfgSTB,
	output reg [31:0] CfgData
);


// resources for loading and saving context of EU registers
reg [41:0] ContextAddressReg;
reg [42:0] ContextStartAddrReg;
reg ContextProcFlag, ContextLoadFlag, ContextReqFlag, ContextContinueReqFlag;
reg [8:0] ContextCntr;

reg [31:0] MainControlReg;

logic [75:0] EuDataBus;
logic EuDataValid;
reg [63:0] DataToEuReg;
reg DataToEuRequestReg;

reg [23:0] ScanDTReg;
reg [8:0] EUREG_reg, NewRegIndex;

logic [3:0] MPUWSTB, MPURSTB;
reg [31:0] IOSRCBus[3:0];
logic [15:0] MPUReqBus, MPUMaskBus;
logic [39:0] MPUBaseBus[1:0];
logic [31:0] DToBus;
logic ExtFlag, McuReset;

logic [55:0] FreeRamData;
reg [55:0] RamDataReg;
reg [7:0] RAMAddrReg;
reg [10:0] ProcAddrReg[2:0];
reg [23:0] SelReg, FoundSelReg;
reg [31:0] LengthReg, FoundLengthReg, PortalCFGReg, CfgIDcode;
reg WriteReqFlag, SearchReqFlag, ClearReqFlag, FreeReqFlag, ClearProcFlag, SearchProcFlag, EndProcFlag,
	FreeProcFlag, LengthFoundFlag, FreeFoundFlag, CalcReqFlag, CalcProcFlag, EmptyFreeProcFlag, EmptySearchProcFlag,
	EmptyFreeReqFlag, EmptySearchReqFlag, EmptyFoundFlag, RegIndexSetReg, RegIndexRequestReg, TimerReqFlag,
	MemAllocLockFlag, MemAllocResetReq, MALOCKFReg, PortalContextFlag, CFGAutoFlag, CfgWEnaFlag,
	CfgROMSelectFlag, PortalStateSel;
logic [2:0] ProcType;

reg [2:0] ExtCondReg;

reg [7:0] CFGAddrReg;
reg [1:0] ContextWSBase, ContextWSCntr;

reg [15:0] PortalWDTBase, PortalWDT;

reg [31:0] CfgROM [0:63];
reg [31:0] CfgROMReg;

reg [1:0] MSGPcntr;
reg [95:0] MSGPARAM;

initial begin
$readmemh ("InitialCFG", CfgROM, 0);
end


// An extern module declaration specifies the module's parameters
// and ports.  It provides a prototype for a module that does not
// depend directly on the module declaration.  
extern module MicrocontrollerDT #(parameter Code) 
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
	input wire [15:0] REQ,
	input wire [15:0] IMASK,
	// external base sources
	input wire [39:0] BASE [1:0]
);
MicrocontrollerDT MPU (.CLK(CLK),.RESET(McuReset), .CF(ExtFlag), .IOWSTB(MPUWSTB),.IORSTB(MPURSTB),.IOSRC(IOSRCBus),
						.NEXT(NEXT[1]),.ACT(ACT[1]),.CMD(CMD[1]),.SIZE(SIZE[1]),.ADDRESS(ADDR[1]),.DTo(DToBus),.DRDY(DRDY[1]),
						.DTi(DTi[31:0]), .REQ(MPUReqBus), .IMASK(MPUMaskBus), .BASE(MPUBaseBus));
defparam MPU.Code="Context32CsLDRc.mif";

sc_fifo_thr EUFIFO(.data(DRDY[0] ? {SZi,TAGi[8:0],DTi} : {3'b011,EUREG_reg,DataToEuReg}), .wrreq((DRDY[0] & ~TAGi[9]) | DataToEuRequestReg),
			.rdreq(EURD), .clock(CLK), .sclr(~RESETn), .q(EuDataBus), .empty(EuDataValid));
defparam EUFIFO.LPM_WIDTH=76, EUFIFO.LPM_NUMWORDS=16, EUFIFO.LPM_WIDTHU=4;

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


//=================================================================================================
//		assignments
//=================================================================================================
assign RA=ContextCntr[7:1];
assign DTo[1]={32'd0,DToBus};
assign EUCLOAD=ContextProcFlag;
assign TAGo[1]=10'd0;
assign EUNEXT=NEXT[0];
assign EUDRDY=~EuDataValid;
assign EUDTi=EuDataBus[63:0];
assign EUTAGi=EuDataBus[72:64];
assign EUSZi=EuDataBus[75:73];
assign PortalCFG=CfgROMSelectFlag ? CfgROMReg : PortalCFGReg;

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
// reset memory allocation
MPUReqBus[0]=MemAllocResetReq;
// Memory allocation request (highest priority)
MPUReqBus[1]=MALLOCREQ;
// Get message parameter request
MPUReqBus[2]=GETPARREQ;
// message or interrupt request
MPUReqBus[3]=EUENDMSG;
// end of message request from EU
MPUReqBus[4]=MSGREQ;
// portal message request
MPUReqBus[5]=BKPT;
// system error
MPUReqBus[6]=ERRORREQ;
// breakpoint
MPUReqBus[7]=INTREQ;
// portal send message request
MPUReqBus[8]=PortalSMSG;
// task timer interrupt
MPUReqBus[9]=TimerReqFlag & EUEMPTY;
// unused request pins
MPUReqBus[15:10]=6'd0;

// mask bus
MPUMaskBus={8'b11111111,6'b111111,~MemAllocLockFlag,1'b1};

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
ACT[0]=EUACT | ContextCntr[0];
// command
CMD[0]=ContextProcFlag ? ContextLoadFlag:EUCMD;
// size
SIZE[0]=ContextProcFlag ? 2'b11:EUSZo;
// address
ADDR[0]=ContextProcFlag ? {ContextAddressReg,3'd0}:EUADDR;
// tag
TAGo[0]=ContextProcFlag ? {PortalContextFlag,1'b0,ContextCntr[8:1]}:{1'b0,EUTAGo};
// data to memory
DTo[0]=ContextProcFlag ? PortalContextFlag ? PortalContextDO:CDAT:EUDTo;

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
				READY<=0;
				ContextCntr<=0;
				ContextProcFlag<=1'b0;
				TimerReqFlag<=0;
				CORESTART<=0;
				CORESTOP<=0;
				CORECONT<=0;
				CPSR<=0;
				CSR<=0;
				ContextReqFlag<=1'b0;
				ContextContinueReqFlag<=1'b0;
				RegIndexRequestReg<=0;
				SearchProcFlag<=1'b0;
				ClearProcFlag<=1'b0;
				FreeProcFlag<=1'b0;
				CalcProcFlag<=1'b0;
				EmptyFreeProcFlag<=1'b0;
				EmptySearchProcFlag<=1'b0;
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
				MemAllocLockFlag<=1'b1;
				MemAllocResetReq<=0;
				MALOCKFReg<=0;
				PortalSTOP<=0;
				PortalRUN<=0;
				PortalDIS<=1'b0;
				PortalCFGSTB<=0;
				PortalContextFlag<=0;
				CFGAutoFlag<=0;
				PortalContextSTB<=0;
				ExtCondReg<=0;
				CfgROMSelectFlag<=0;
				PortalCFGRST<=0;
				PortalCFGReg<=0;
				PortalWDTBase<=0;
				PortalWDT<=0;
				PortalStateSel<=0;
				ContextWSBase<=0;
				ContextWSCntr<=0;
				ESMSG<=0;
				INTACK<=0;
				PortalSMSGNext<=0;
				CfgReset<=1'b1;
				CfgSTB<=0;
				CfgWEnaFlag<=0;
				CfgIDcode<=32'h55aa;
				CfgRequest<=0;
				end
else begin

// memory allocation locking
MemAllocLockFlag<=(MemAllocLockFlag | MALOCKF) & (~((MPUWSTB==4'd3) & DToBus[11]));
// request to reset allocation system
MemAllocResetReq<=~MALOCKF & MALOCKFReg;
MALOCKFReg<=MALOCKF;

//-----------------------------------------------
// context controller channel
//-----------------------------------------------
// cycle counter
if ((ContextProcFlag & (ContextCntr[0] ? NEXT[0] : ~PortalContextFlag | (ContextWSCntr==ContextWSBase)))|ContextReqFlag | ContextContinueReqFlag) ContextCntr<=(ContextCntr+9'd1)&{9{~ContextReqFlag & ~ContextContinueReqFlag}};
// address counter
if (ContextReqFlag) ContextAddressReg<=ContextStartAddrReg[41:0];
	else if (ContextProcFlag & ContextCntr[0] & NEXT[0]) ContextAddressReg<=ContextAddressReg+42'd1;
// context processing flag
ContextProcFlag<=(ContextProcFlag | ContextReqFlag | ContextContinueReqFlag) & ~((ContextCntr=={CFGAddrReg,1'b1}) & NEXT[0]);
// read/write flag
if (ContextReqFlag) ContextLoadFlag<=ContextStartAddrReg[42];
// wait states registers base and counter
if (PortalCFGSTB & (PortalCFGAddr==6'h38)) ContextWSBase<=PortalCFG[23:22];
if (~PortalContextFlag | ContextCntr[0] | (ContextWSCntr==ContextWSBase)) ContextWSCntr<=0;
	else ContextWSCntr<=ContextWSCntr+2'd1;
// hardware configuration selector
if (PortalCFGSTB & (PortalCFGAddr==6'h3F)) CfgIDcode<=PortalCFG;

// EU register
if (MALLOCREQ | GETPARREQ | RegIndexSetReg) EUREG_reg<=RegIndexSetReg ? NewRegIndex : {4'd0,EUREG};

RegIndexSetReg<=RegIndexRequestReg;

// interrupt requests
TimerReqFlag<=(TimerReqFlag | PTINTR) & (~TimerReqFlag | ~EUEMPTY);

//condition mux
casez ({ExtCondReg,MainControlReg[10:8]})
	{3'd0,3'd0}: ExtFlag<=SearchProcFlag | ClearProcFlag | FreeProcFlag | CalcProcFlag | EmptyFreeProcFlag | EmptySearchProcFlag;
	{3'd0,3'd1}: ExtFlag<=FreeFoundFlag;
	{3'd0,3'd2}: ExtFlag<=LengthFoundFlag;
	{3'd0,3'd3}: ExtFlag<=EmptyFoundFlag;
	{3'd0,3'd4}: ExtFlag<=ContextProcFlag;
	{3'd0,3'd5}: ExtFlag<=~EUEMPTY;
	{3'd0,3'd6}: ExtFlag<=SMSGBKPT;
	{3'd0,3'd7}: ExtFlag<=DataToEuRequestReg;
	{3'd1,3'd?}: ExtFlag<=PortalEMPTY;
	{3'd2,3'd?}: ExtFlag<=CfgFreeze;
	endcase


// microcontroller ports connection
// P1:P0 connected to mux EUParam and MsgParam
case ({MainControlReg[19],MainControlReg[2:0]})
	4'd0:	begin
			IOSRCBus[0]<=MSGPARAM[31:0];		// entry point offset 
			IOSRCBus[1]<=MSGPARAM[63:32];		// code selector and control byte
			end
	4'd1:	begin
			IOSRCBus[0]<=MSGPARAM[95:64];		// message parameter
			IOSRCBus[1]<={5'd1,CSR};
			end
	4'd2:	begin
			IOSRCBus[0]<={8'd0,DTLIMIT};
			IOSRCBus[1]<={8'd0,CPSR};
			end
	4'd3:	begin
			IOSRCBus[0]<=RIP[31:0];
			IOSRCBus[1]<=ScanDTReg;
			end
	4'd4:	begin
			IOSRCBus[0]<=FREEMEM[31:0];
			IOSRCBus[1]<={24'd0,FREEMEM[39:32]};
			end
	4'd5:	begin
			IOSRCBus[0]<=CACHEDMEM[31:0];
			IOSRCBus[1]<={24'd0,CACHEDMEM[39:32]};
			end
	4'd6:	begin
			IOSRCBus[0]<=EUPARAM[31:0];
			IOSRCBus[1]<=EUPARAM[63:32];
			end
	4'd7:	begin
			IOSRCBus[0]<={27'd0,RIP[36:32]};
			IOSRCBus[1]<=PortalState;
			end
	4'd8:	begin
			IOSRCBus[0]<={8'd0,INTSR};
			IOSRCBus[1]<={16'd0,INTCR};
			end
	4'd9:	begin
			IOSRCBus[0]<='0;
			IOSRCBus[1]<={16'd0,INTCODE};
			end
	4'd10:	begin
			IOSRCBus[0]<=PortalMSG[31:0];
			IOSRCBus[1]<=PortalMSG[63:32];
			end
	4'd11:	begin
			IOSRCBus[0]<={6'd0,PortalCPL,PortalPSO};
			IOSRCBus[1]<={5'd1,7'd15,PortalCPL,2'd0,PortalTaskID};
			end
	4'd12:	begin
			IOSRCBus[0]<={28'd0, CfgStatus};
			IOSRCBus[1]<=CfgIDcode;
			end
	endcase

// start address register for context load/store
if (MPUWSTB==4'd1) ContextStartAddrReg[28:0]<=DToBus[31:3];
if (MPUWSTB==4'd2) ContextStartAddrReg[42:29]<=DToBus[13:0];
if (MPUWSTB==4'd3) MainControlReg<=DToBus;
// generate end of send message
ESMSG<=(MPUWSTB==4'd3) & DToBus[14];
// core start
CORESTART<=(MPUWSTB==4'd3) & DToBus[3];
// core stop generation
CORESTOP<=((MPUWSTB==4'd3) & DToBus[16]) | PTINTR | (MPUWSTB==4'd2);
// core continue signal generation
CORECONT<=(MPUWSTB==4'd3) & DToBus[17];
// INTACK generation
INTACK<=({MainControlReg[19],MainControlReg[2:0]}==4'd9) & MPURSTB[1];
// Next message confirmation for to Portal
PortalSMSGNext<=(MPUWSTB==4'd3) & DToBus[20];

// data register for sending information to EU
if (MPUWSTB==4'd4) DataToEuReg[31:0]<=DToBus;
if (MPUWSTB==4'd5) DataToEuReg[63:32]<=DToBus;
// current DT index for table scan mode
if (MPUWSTB==4'd6) LengthReg<=DToBus;
if (MPUWSTB==4'd7) SelReg<=DToBus[23:0];
if (MPUWSTB==4'd8) ScanDTReg<=DToBus[23:0];

// CPSR register modification
if (MPUWSTB==4'd9) CPSR[7:0]<=DToBus[7:0];
	else if (CPSRSTB[0]) CPSR[7:0]<=EXTDI[39:32];
if (MPUWSTB==4'd9) CPSR[15:8]<=DToBus[15:8];
	else if (CPSRSTB[1]) CPSR[15:8]<=EXTDI[47:40];
if (MPUWSTB==4'd9) CPSR[23:16]<=DToBus[23:16];
	else if (CPSRSTB[2]) CPSR[23:16]<=EXTDI[55:48];

// CSR register
if (MPUWSTB==4'd10) CSR[7:0]<=DToBus[7:0];
	else if (CSRSTB[0]) CSR[7:0]<=EXTDI[7:0];
if (MPUWSTB==4'd10) CSR[15:8]<=DToBus[15:8];
	else if (CSRSTB[1]) CSR[15:8]<=EXTDI[15:8];
if (MPUWSTB==4'd10) CSR[23:16]<=DToBus[23:16];
	else if (CSRSTB[2]) CSR[23:16]<=EXTDI[23:16];
if (MPUWSTB==4'd10) CSR[26:24]<=DToBus[26:24];
	else if (CSRSTB[3]) CSR[26:24]<=EXTDI[26:24];

// error report interface
if (MPUWSTB==4'd11) ERC<=DToBus;
// error signal
ESTB<=(MPUWSTB==4'd11);


//request to load/store context.
ContextReqFlag<=(ContextReqFlag | (MPUWSTB==4'd2)) & ~ContextProcFlag;
ContextContinueReqFlag<=(ContextContinueReqFlag | ((MPUWSTB==4'hE) & DToBus[17])) & ~ContextProcFlag;
	
// sending data to the EU
DataToEuRequestReg<=(MPUWSTB==4'd5) | (DataToEuRequestReg & DRDY[0]);
// setting new core register index
RegIndexRequestReg<=(RegIndexRequestReg | ((MPUWSTB==4'd3) & DToBus[31])) & ~RegIndexSetReg;
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

// message parameter
if ((MPUWSTB==4'd3)|(MPUWSTB==4'd12)) MSGPcntr<=(MSGPcntr+1'b1) & {2{(MPUWSTB==4'd12)}};
if ((MPUWSTB==4'd12)&(MSGPcntr==2'd0)) MSGPARAM[31:0]<=DToBus;
if ((MPUWSTB==4'd12)&(MSGPcntr==2'd1)) MSGPARAM[63:32]<=DToBus;
if ((MPUWSTB==4'd12)&(MSGPcntr==2'd2)) MSGPARAM[95:64]<=DToBus;


/*
---------------------------------------------------------------------------------------------------
							Portal reconfiguration resource

*/

// portal context transfer flag
PortalContextFlag<=(PortalContextFlag | ((MPUWSTB==4'hE) & DToBus[17]))& ~((ContextCntr=={CFGAddrReg,1'b1}) & NEXT[0]);

// configuration address register
if ((MPUWSTB==4'hE) & DToBus[8]) CFGAddrReg<=DToBus[7:0];
	else if ((MPUWSTB==4'hF) & CFGAutoFlag) CFGAddrReg<=CFGAddrReg+8'd1;
if (MPUWSTB==4'hF) PortalCFGAddr<=CFGAddrReg[5:0];
// autoincrement flag
if ((MPUWSTB==4'hE) & DToBus[8]) CFGAutoFlag<=DToBus[16];

// strobe configuration dword
PortalCFGSTB<=(MPUWSTB==4'hF) & CFGAutoFlag;
// configuration data
if (MPUWSTB==4'hF) PortalCFGReg<=DToBus;
// reading configuration ROM
if (MPUWSTB==4'hF) CfgROMReg<=CfgROM[CFGAddrReg[5:0]];
// Cfg ROM selection
if ((MPUWSTB==4'hE) & DToBus[8]) CfgROMSelectFlag<=DToBus[20];
// PortalCFGRST generation
PortalCFGRST<=(MPUWSTB==4'hE) & DToBus[21];

// strobe portal context qword
PortalContextSTB<=DRDY[0] & TAGi[9];
// portal context data
if (DRDY[0] & TAGi[9]) PortalContextDI<=DTi;
// portal context address
if (ContextContinueReqFlag) PortalContextAddress<=0;
	else if (~ContextLoadFlag & ContextProcFlag & ContextCntr[0] & NEXT[0]) PortalContextAddress<=PortalContextAddress+8'd1;
		else if (DRDY[0] & TAGi[9]) PortalContextAddress<=TAGi[7:0];
	
// portal control lines
PortalSTOP<=(MPUWSTB==4'hE) & DToBus[9];
PortalRUN<=(MPUWSTB==4'hE) & DToBus[10];
if (MPUWSTB==4'hE) 
	begin
	PortalDIS<=DToBus[11];
	// reset the cfg data fifo
	CfgReset<=~DToBus[18];
	// reconfiguration cahnnel write enable
	CfgWEnaFlag<=DToBus[19];
	// reconfiguration request
	CfgRequest<=DToBus[23];
	end;


// Partial configuration write data register
if ((MPUWSTB==4'hF)& CfgWEnaFlag) CfgData<=DToBus;
// Partial configuration write strobe
CfgSTB<=(MPUWSTB==4'hF) & CfgWEnaFlag;


// extended multiplexer control
if ((MPUWSTB==4'hE)& DToBus[15]) ExtCondReg<=DToBus[14:12];

// portal status selection
if (MPUWSTB==4'hE) PortalStateSel<=DToBus[22];

end
end

/*
	control port format (P13)
	b0
[2:0]	- mux control 
[3]		- core restart bit
[7:4]	- control interface to the free mem cache
	b1
[10:8]	- EF mux control
[11]	- Ready signal generation
[13:12]	- instruction for free space calculation method
[14]	- ACK to messenger
[15]	- hardware reset generation
	b2
[16]	- core stop signal
[17]	- core continue signal, after MEMALLOC and GETPAR inctructions
[18]	- 
[19]	- Bit [3] of Data mux
[20]	- PortalSMSGNext generation
[21]	- 
[30:22] - index of core register or configuration register
[31]	- set the core register index

		Reconfiguration control P24
	b0
[7:0]	- address of the portal reconfiguration register or context counter
	b1
[8]		- strobe autoincrement flag and address of config register or counter of context and Cfg ROM selection
[9]		- Portal STOP
[10]	- Portal RUN
[11]	- Portal DISABLE
[15:12] - extension of the condition multiplexer, bit 15 enabled selection
	b2
[16]	- autoincrement CFGAddrReg and selection portal CFG channel
[17]	- start load|store portal context
[18]	- reset the config. data FIFO, ~CfgReset
[19]	- enable write partial configuration data to the reconfiguration controller
[20]	- select the initial configuration ROM on PortalCFG
[21]	- PortalCFGRST generation
[22]	- PortalState selection on p1:7
[23]	- configuration start request

	Configuration data register P25 
[31:0]	- 32-bit data to portal CFG or reconfiguration data
*/

endmodule
