module Messenger4T (
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
	output reg [95:0] ContextMSG,
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

reg [79:0] NETMSGReg;

logic [3:0] MPUWSTB;
logic [3:0] MPURSTB;
logic [7:0] MPUReqBus, MPUAckBus;
wire [39:0] MPUBaseBus[1:0];
logic [31:0] IOSRCBus[3:0];
logic [31:0] MPUDOUTBus;
reg ExtFlag, NETSENDFlag, ContextTTReg, INTREQFlag, INTACKFlag, RestartINTR;
reg [1:0] ThreadReg, ThreadReqReg;
reg ContextREQFlag, ContextCHKFlag;
reg [31:0] DMuxReg;
reg [2:0] DMuxSelReg, CondSelReg;
reg [3:0] EUReqReg, BKPTReqReg, CPSREqu;
logic [3:0] EUSEL, BKPTSEL;
reg [23:0] CPSRCheckReg;


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

Microcontroller4T MPU (.CLK(CLK),.RESET(RESETn), .CF(ExtFlag), .IOWSTB(MPUWSTB),.IORSTB(MPURSTB),.IOSRC(IOSRCBus),
					.NEXT(NEXT),.ACT(ACT),.CMD(CMD),.SIZE(SIZE),.ADDRESS(ADDR),.DTo(MPUDOUTBus),.DRDY(DRDY),
					.DTi(DATI), .REQ(MPUReqBus), .IMASK(8'hFF), .IACK(MPUAckBus), .BASE(MPUBaseBus));
defparam MPU.Code="Messenger4T.mif";

Arbiter		EUArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[3]), .REQ(EUReqReg), .SEL(EUSEL));

Arbiter		BKPTArbiter(.CLK(CLK), .RESET(RESETn), .NEXT(MPUAckBus[4]), .REQ(BKPTReqReg), .SEL(BKPTSEL));

assign DATO=MPUDOUTBus;
assign NETMSG=NETMSGReg;
// base address
assign MPUBaseBus[0]=DTBASE;
assign MPUBaseBus[1]=40'hFFFFFFFFFC;		// base to the control registers block


/*
===================================================================================================
		Asynchronous functions
===================================================================================================
*/
always_comb
begin


// request from network interface
MPUReqBus[0]=NETREQ;
// request from error processing system
MPUReqBus[1]=ERRORREQ;
// request from interrupt processing system
MPUReqBus[2]=(INTREQ & ~INTREQFlag) | RestartINTR;
// request from EU
MPUReqBus[3]=|EUReqReg;
// request breakpoint
MPUReqBus[4]=|BKPTReqReg;
// reserved requests
MPUReqBus[7:5]=3'd0;

// IO source bus
IOSRCBus[0]=DMuxReg;
IOSRCBus[1]={6'd0,ThreadReg[1] ? (ThreadReg[0] ? CSR[3][19:18] : CSR[2][19:18]):(ThreadReg[0] ? CSR[1][19:18] : CSR[0][19:18]),
					ThreadReg[1] ? (ThreadReg[0] ? CPSR[3] : CPSR[2]):(ThreadReg[0] ? CPSR[1] : CPSR[0])};						// CPL and bits [23:0] of PSO selector
IOSRCBus[2]=ThreadReg[1] ? (ThreadReg[0] ? CSR[3] : CSR[2]):(ThreadReg[0] ? CSR[1] : CSR[0]);									// CSR register content
IOSRCBus[3]={16'd0,INTCR};									// interrupt table length

end

/*
===================================================================================================
		Registered functions
===================================================================================================
*/
always_ff @(posedge CLK)
begin
// generate reset signal when fatal error occurs
RST<=(RST | ~RESETn) & (~MPUWSTB[0] | ~MPUDOUTBus[7]);
end

always_ff @(negedge RESETn or posedge CLK)
begin
if (!RESETn) begin
				ContextREQ<=0;
				ContextREQFlag<=0;
				ContextCHK<=0;
				ContextCHKFlag<=0;
				NETSEND<=0;
				NETSENDFlag<=0;
				EUCONTINUE<=0;
				EUHALT<=0;
				ESTB<=0;
				ThreadReg<=0;
				ThreadReqReg<=0;
				EUReqReg<=0;
				BKPTReqReg<=0;
				CPSREqu<=0;
				CPSRCheckReg<=0;
				ContextTT<=0;
				ContextTTReg<=0;
				ContextEINTR<=0;
				INTREQFlag<=0;
				INTACKFlag<=0;
				RestartINTR<=0;
				end
else begin

// EU message requests
EUReqReg[0]<=(EUReqReg[0] | EUREQ[0]) & (~EUSEL[0] | ~MPUAckBus[3]);
EUReqReg[1]<=(EUReqReg[1] | EUREQ[1]) & (~EUSEL[1] | ~MPUAckBus[3]);
EUReqReg[2]<=(EUReqReg[2] | EUREQ[2]) & (~EUSEL[2] | ~MPUAckBus[3]);
EUReqReg[3]<=(EUReqReg[3] | EUREQ[3]) & (~EUSEL[3] | ~MPUAckBus[3]);

// BKPT requests
BKPTReqReg[0]<=(BKPTReqReg[0] | BKPT[0]) & (~BKPTSEL[0] | ~MPUAckBus[4]);
BKPTReqReg[1]<=(BKPTReqReg[1] | BKPT[1]) & (~BKPTSEL[1] | ~MPUAckBus[4]);
BKPTReqReg[2]<=(BKPTReqReg[2] | BKPT[2]) & (~BKPTSEL[2] | ~MPUAckBus[4]);
BKPTReqReg[3]<=(BKPTReqReg[3] | BKPT[3]) & (~BKPTSEL[3] | ~MPUAckBus[4]);

// Input data mux
case (DMuxSelReg)
	3'd0:	DMuxReg<=ThreadReg[1] ? (ThreadReg[0] ? EUPARAM[3][31:0] : EUPARAM[2][31:0]):(ThreadReg[0] ? EUPARAM[1][31:0] : EUPARAM[0][31:0]);	// message index
	3'd1:	DMuxReg<=ThreadReg[1] ? (ThreadReg[0] ? EUPARAM[3][63:32] : EUPARAM[2][63:32]):(ThreadReg[0] ? EUPARAM[1][63:32] : EUPARAM[0][63:32]);		// message parameter
	3'd2:	DMuxReg<={16'd0,INTPARAM};		// interrupt index 
	3'd3:	DMuxReg<={8'd0,INTSR};			// interrupt table selector
	3'd4:	DMuxReg<=NETPARAM[63:32];		// message parameter
	3'd5:	DMuxReg<=NETPARAM[95:64];		// Task ID and Proc Index
	3'd6:	DMuxReg<={6'd0, NETPARAM[121:120], NETPARAM[119:96]};	// target PSO selector and CPL
	3'd7:	DMuxReg<={CPUNUM,DTLIMIT};
	endcase
if (MPUWSTB[0] & MPUDOUTBus[3]) DMuxSelReg<=MPUDOUTBus[2:0];
	else if (MPUWSTB[1] | MPURSTB[0]) DMuxSelReg<=DMuxSelReg+3'd1;		// autoincrement
	
// Context type flag
if (MPUWSTB[0] & MPUDOUTBus[23]) ContextTTReg<=MPUDOUTBus[27];

// message read confirmation to the network controller
NETMSGRD<=MPUWSTB[0] & MPUDOUTBus[6];

// Channel to the context controller
// if ContextMSG==0 request for check message queues in the current process
if ((DMuxSelReg==3'd0) & MPUWSTB[1]) ContextMSG[31:0]<=MPUDOUTBus;		// subaddress 0 - procedure offset
if ((DMuxSelReg==3'd1) & MPUWSTB[1]) ContextMSG[63:32]<=MPUDOUTBus;		// subaddress 1 - procedure selector and control byte
if ((DMuxSelReg==3'd2) & MPUWSTB[1]) ContextMSG[95:64]<=MPUDOUTBus;		// subaddress 2 - PSO (for interrupts) or message parameter (for procedure calls)

// set output thread type flag
if (((DMuxSelReg==3'd2) & MPUWSTB[1])|(MPUWSTB[0] & MPUDOUTBus[12])) ContextTT<=ContextTTReg;

// generation ContextREQ signal
ContextREQ<=(DMuxSelReg==3'd2) & MPUWSTB[1];				// request to the context controller
ContextREQFlag<=(ContextREQFlag | ((DMuxSelReg==3'd2) & MPUWSTB[1])) & ~ContextRDY;

// generation ContextCHK signal
ContextCHK<=MPUWSTB[0] & MPUDOUTBus[12];
ContextCHKFlag<=(ContextCHKFlag | (MPUWSTB[0] & MPUDOUTBus[12])) & ~ContextCHKRDY;

// channel register
if (((DMuxSelReg==3'd2) & MPUWSTB[1])|(MPUWSTB[0] & MPUDOUTBus[12])|((DMuxSelReg==3'd2) & MPUWSTB[1])) ContextCHAN<=ThreadReg;

// thread register
if (MPUWSTB[0] & MPUDOUTBus[21]) ThreadReg<=MPUDOUTBus[22] ? {CPSREqu[3] | CPSREqu[2], CPSREqu[3] | CPSREqu[1]}:(MPUDOUTBus[20] ? ThreadReqReg : MPUDOUTBus[19:18]);
	else if (MPUAckBus[3]) ThreadReg<={EUSEL[3] | EUSEL[2], EUSEL[3] | EUSEL[1]};
		else if (MPUAckBus[4]) ThreadReg<={BKPTSEL[3] | BKPTSEL[2], BKPTSEL[3] | BKPTSEL[1]};
if (MPUAckBus[3]) ThreadReqReg<={EUSEL[3] | EUSEL[2], EUSEL[3] | EUSEL[1]};
	else if (MPUAckBus[4]) ThreadReqReg<={BKPTSEL[3] | BKPTSEL[2], BKPTSEL[3] | BKPTSEL[1]};

// Channel to the network controller
if (((DMuxSelReg==3'd3) & MPUWSTB[1]) | MPUWSTB[2]) NETMSGReg[31:0]<=MPUWSTB[2] ? NETPARAM[31:0]:MPUDOUTBus;			// subaddress 2 - PSO selector and CPU index
if ((DMuxSelReg==3'd4) & MPUWSTB[1]) NETMSGReg[47:32]<=MPUDOUTBus[15:0];	// subaddress 3 - procedure index
if ((DMuxSelReg==3'd5) & MPUWSTB[1]) NETMSGReg[79:48]<=MPUDOUTBus;			// subaddress 4 - message parameter
NETSEND<=((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2];
NETSENDFlag<=(NETSENDFlag | (((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2])) & ~NETRDY;
if ((DMuxSelReg==3'd5) & MPUWSTB[1]) NETCPL<=ThreadReg[1] ? (ThreadReg[0] ? CSR[3][19:18] : CSR[2][19:18]):(ThreadReg[0] ? CSR[1][19:18] : CSR[0][19:18]);
if ((DMuxSelReg==3'd5) & MPUWSTB[1]) NETTASKID<=ThreadReg[1] ? (ThreadReg[0] ? CSR[3][15:0] : CSR[2][15:0]):(ThreadReg[0] ? CSR[1][15:0] : CSR[0][15:0]);
if ((DMuxSelReg==3'd5) & MPUWSTB[1]) NETCPSR<=ThreadReg[1] ? (ThreadReg[0] ? CPSR[3] : CPSR[2]):(ThreadReg[0] ? CPSR[1] : CPSR[0]);

// network reporting
if (((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2]) NETTYPE<=MPUWSTB[2];
if (MPUWSTB[2]) NETSTAT<=MPUDOUTBus[4:0];

// EU control
EUCONTINUE[0]<=MPUWSTB[0] & MPUDOUTBus[4] & ~ThreadReg[1] & ~ThreadReg[0];
EUCONTINUE[1]<=MPUWSTB[0] & MPUDOUTBus[4] & ~ThreadReg[1] & ThreadReg[0];
EUCONTINUE[2]<=MPUWSTB[0] & MPUDOUTBus[4] & ThreadReg[1] & ~ThreadReg[0];
EUCONTINUE[3]<=MPUWSTB[0] & MPUDOUTBus[4] & ThreadReg[1] & ThreadReg[0];
EUHALT[0]<=MPUWSTB[0] & MPUDOUTBus[5] & ~ThreadReg[1] & ~ThreadReg[0];
EUHALT[1]<=MPUWSTB[0] & MPUDOUTBus[5] & ~ThreadReg[1] & ThreadReg[0];
EUHALT[2]<=MPUWSTB[0] & MPUDOUTBus[5] & ThreadReg[1] & ~ThreadReg[0];
EUHALT[3]<=MPUWSTB[0] & MPUDOUTBus[5] & ThreadReg[1] & ThreadReg[0];

// Error reporting interface
ESTB<=(DMuxSelReg==3'd7) & MPUWSTB[1];
if ((DMuxSelReg==3'd6) & MPUWSTB[1]) ERRC[31:0]<=MPUDOUTBus;			// subaddress 6 - low dword of error code
if ((DMuxSelReg==3'd7) & MPUWSTB[1]) ERRC[63:32]<=MPUDOUTBus;			// subaddress 7 - high dword of error code

// interrupt acknowledgement
INTACK<=MPUWSTB[0] & MPUDOUTBus[13];

// External condition flag
case (CondSelReg)
	3'd0:	ExtFlag<=ContextREQFlag | ContextCHKFlag;
	3'd1:	ExtFlag<=NETSENDFlag;
	3'd2:	ExtFlag<=|CPSREqu;
	3'd3:	ExtFlag<=ThreadReg[1] ? (ThreadReg[0] ? EUEMPTY[3] : EUEMPTY[2]):(ThreadReg[0] ? EUEMPTY[1] : EUEMPTY[0]);
	3'd4:	ExtFlag<=ThreadReg[1] ? (ThreadReg[0] ? MSGBKPT[3] : MSGBKPT[2]):(ThreadReg[0] ? MSGBKPT[1] : MSGBKPT[0]);
	3'd5:	ExtFlag<=1'b0;
	3'd6:	ExtFlag<=1'b0;
	3'd7:	ExtFlag<=1'b0;
	endcase
// condition selection register
if (MPUWSTB[0] & MPUDOUTBus[11]) CondSelReg<=MPUDOUTBus[10:8];

// checking the current CPSR's
if (MPUWSTB[3]) CPSRCheckReg<=MPUDOUTBus[23:0];
CPSREqu[0]<=(CPSR[0]==CPSRCheckReg);
CPSREqu[1]<=(CPSR[1]==CPSRCheckReg);
CPSREqu[2]<=(CPSR[2]==CPSRCheckReg);
CPSREqu[3]<=(CPSR[3]==CPSRCheckReg);

// generate context error interrupt flag
if (|MPUAckBus) ContextEINTR<=(MPUAckBus==8'h02);

// External IRQ processing
INTREQFlag<=(INTREQFlag | INTREQ) & ~INTACKFlag;
INTACKFlag<=INTACK;

RestartINTR<=(MPUWSTB[0] & MPUDOUTBus[14]);

/*
		control register fields MPUWSTB[0]
[2:0] 	- DMuxSelReg
[3]		- enable write to the DMuxSelReg
[4]		- EUCONTINUE signal generation
[5]		- EUHALT signal generation
[6]		- confirmation to the network controller
[7]		- reset signal generation
[10:8]	- condition flag selection
[11]	- enable write to the condselreg
[12]	- ContextCHK generation
[13]	- INTACK generation
[14]	- Restart enternal interrupt request
[19:18] - Thread selection index
[20]	- 1 - restore trhread index from the EU request register
[21]	- 1 - Enable thread selection
[22]	- 1 - Thread selector sets from CPSR comparator
[23]	- Enable thread type bit - output ContextTT<=MPUDOUTBus[27]
[27]	- thread type flag for ContextTT output
*/

end
end

endmodule: Messenger4T
