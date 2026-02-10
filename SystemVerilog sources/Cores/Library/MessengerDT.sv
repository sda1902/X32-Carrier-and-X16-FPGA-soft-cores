module MessengerDT (
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

extern module Microcontroller #(parameter Code) 
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

reg [95:0] ContextMSGReg [1:0];
reg [79:0] NETMSGReg;

logic [3:0] MPUWSTB;
logic [3:0] MPURSTB;
logic [15:0] MPUReqBus;
wire [39:0] MPUBaseBus[1:0];
logic [31:0] IOSRCBus[3:0];
logic [31:0] MPUDOUTBus;
reg ExtFlag, NETSENDFlag, ThreadFlag, INTREQFlag, INTACKFlag;
reg [1:0] ContextREQFlag;
reg [31:0] DMuxReg;
reg [2:0] DMuxSelReg, CondSelReg;

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
MicrocontrollerDT MPU (.CLK(CLK),.RESET(RESETn), .CF(ExtFlag), .IOWSTB(MPUWSTB),.IORSTB(MPURSTB),.IOSRC(IOSRCBus),
					.NEXT(NEXT),.ACT(ACT),.CMD(CMD),.SIZE(SIZE),.ADDRESS(ADDR),.DTo(MPUDOUTBus),.DRDY(DRDY),
					.DTi(DATI), .REQ(MPUReqBus), .IMASK(16'hFFFF), .BASE(MPUBaseBus));

defparam MPU.Code="MessengerDT.mif";

assign DATO=MPUDOUTBus;
assign ContextMSG[0]=ContextMSGReg[0];
assign ContextMSG[1]=ContextMSGReg[1];
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
// request from EU[0]
MPUReqBus[2]=EUREQ[0];
// request from EU[1]
MPUReqBus[3]=EUREQ[1];
// request breakpoint [0]
MPUReqBus[4]=BKPT[0];
// request breakpoint [1]
MPUReqBus[5]=BKPT[1];
// request from interrupt processing system
MPUReqBus[6]=INTREQ | (MPUDOUTBus[14] & MPUWSTB[0]);
// reserved requests
MPUReqBus[15:7]=9'd0;

// IO source bus
IOSRCBus[0]=DMuxReg;
IOSRCBus[1]={6'd0,ThreadFlag ? CSR[1][19:18] : CSR[0][19:18],ThreadFlag ? CPSR[1] : CPSR[0]};						// CPL and bits [23:0] of PSO selector
IOSRCBus[2]=ThreadFlag ? CSR[1] : CSR[0];									// CSR register content
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
				NETSEND<=0;
				NETSENDFlag<=0;
				EUCONTINUE<=0;
				EURESTART<=0;
				EUHALT<=0;
				ESTB<=0;
				ThreadFlag<=0;
				INTREQFlag<=0;
				INTACKFlag<=0;
				end
else begin
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
[13]	- INTACK
[14]	- regenerate interrupt request
[15]	- EURESTART generation
[18] 	- Thread selection
[19]	- Enable thread selection
*/

// Input data mux
case (DMuxSelReg)
	3'd0:	DMuxReg<=ThreadFlag ? EUPARAM[1][31:0] : EUPARAM[0][31:0];			// message index
	3'd1:	DMuxReg<=ThreadFlag ? EUPARAM[1][63:32] : EUPARAM[0][63:32];		// message parameter
	3'd2:	DMuxReg<={16'd0,INTPARAM};		// interrupt index 
	3'd3:	DMuxReg<={8'd0,INTSR};			// interrupt table selector
	3'd4:	DMuxReg<=NETPARAM[63:32];		// message parameter
	3'd5:	DMuxReg<=NETPARAM[95:64];		// Task ID and Proc Index
	3'd6:	DMuxReg<={6'd0, NETPARAM[121:120], NETPARAM[119:96]};	// target PSO selector and CPL
	3'd7:	DMuxReg<={CPUNUM,DTLIMIT};
	endcase
if (MPUWSTB[0] & MPUDOUTBus[3]) DMuxSelReg<=MPUDOUTBus[2:0];
	else if (MPUWSTB[1] | MPURSTB[0]) DMuxSelReg<=DMuxSelReg+3'd1;		// autoincrement

// message read confirmation to the network controller
NETMSGRD<=MPUWSTB[0] & MPUDOUTBus[6];

// Channel to the context controller
// if ContextMSG==0 request for check message queues in the current process
if ((DMuxSelReg==3'd0) & MPUWSTB[1] & ~ThreadFlag) ContextMSGReg[0][31:0]<=MPUDOUTBus;		// subaddress 0 - procedure offset
if ((DMuxSelReg==3'd1) & MPUWSTB[1] & ~ThreadFlag) ContextMSGReg[0][63:32]<=MPUDOUTBus;		// subaddress 1 - procedure selector and control byte
if ((DMuxSelReg==3'd2) & MPUWSTB[1] & ~ThreadFlag) ContextMSGReg[0][95:64]<=MPUDOUTBus;		// subaddress 2 - PSO (for interrupts) or message parameter (for procedure calls)
if ((DMuxSelReg==3'd0) & MPUWSTB[1] & ThreadFlag) ContextMSGReg[1][31:0]<=MPUDOUTBus;		// subaddress 0 - procedure offset
if ((DMuxSelReg==3'd1) & MPUWSTB[1] & ThreadFlag) ContextMSGReg[1][63:32]<=MPUDOUTBus;		// subaddress 1 - procedure selector and control byte
if ((DMuxSelReg==3'd2) & MPUWSTB[1] & ThreadFlag) ContextMSGReg[1][95:64]<=MPUDOUTBus;		// subaddress 2 - PSO (for interrupts) or message parameter (for procedure calls)
ContextREQ[0]<=(DMuxSelReg==3'd2) & MPUWSTB[1] & ~ThreadFlag;				// request to the context controller
ContextREQ[1]<=(DMuxSelReg==3'd2) & MPUWSTB[1] & ThreadFlag;				// request to the context controller
ContextREQFlag[0]<=(ContextREQFlag[0] | ((DMuxSelReg==3'd2) & MPUWSTB[1] & ~ThreadFlag)) & ~ContextRDY[0];
ContextREQFlag[1]<=(ContextREQFlag[1] | ((DMuxSelReg==3'd2) & MPUWSTB[1] & ThreadFlag)) & ~ContextRDY[1];
// generation ContextCHK signal
ContextCHK[0]<=MPUWSTB[0] & MPUDOUTBus[12] & ~ThreadFlag;
ContextCHK[1]<=MPUWSTB[0] & MPUDOUTBus[12] & ThreadFlag;

// thread flag
if (MPUWSTB[0] & MPUDOUTBus[19]) ThreadFlag<=MPUDOUTBus[18];

// Channel to the network controller
if (((DMuxSelReg==3'd3) & MPUWSTB[1]) | MPUWSTB[2]) NETMSGReg[31:0]<=MPUWSTB[2] ? NETPARAM[31:0]:MPUDOUTBus;			// subaddress 2 - PSO selector and CPU index
if ((DMuxSelReg==3'd4) & MPUWSTB[1]) NETMSGReg[47:32]<=MPUDOUTBus[15:0];	// subaddress 3 - procedure index
if ((DMuxSelReg==3'd5) & MPUWSTB[1]) NETMSGReg[79:48]<=MPUDOUTBus;			// subaddress 4 - message parameter
NETSEND<=((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2];
NETSENDFlag<=(NETSENDFlag | (((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2])) & ~NETRDY;

// network reporting
if (((DMuxSelReg==3'd5) & MPUWSTB[1]) | MPUWSTB[2]) NETTYPE<=MPUWSTB[2];
if (MPUWSTB[2]) NETSTAT<=MPUDOUTBus[4:0];

// EU control
EUCONTINUE[0]<=MPUWSTB[0] & MPUDOUTBus[4] & ~ThreadFlag;
EUCONTINUE[1]<=MPUWSTB[0] & MPUDOUTBus[4] & ThreadFlag;
EUHALT[0]<=MPUWSTB[0] & MPUDOUTBus[5] & ~ThreadFlag;
EUHALT[1]<=MPUWSTB[0] & MPUDOUTBus[5] & ThreadFlag;
EURESTART[0]<=MPUWSTB[0] & MPUDOUTBus[15] & ~ThreadFlag;
EURESTART[1]<=MPUWSTB[0] & MPUDOUTBus[15] & ThreadFlag;

// Error reporting interface
ESTB<=(DMuxSelReg==3'd7) & MPUWSTB[1];
if ((DMuxSelReg==3'd6) & MPUWSTB[1]) ERRC[31:0]<=MPUDOUTBus;			// subaddress 6 - low dword of error code
if ((DMuxSelReg==3'd7) & MPUWSTB[1]) ERRC[63:32]<=MPUDOUTBus;			// subaddress 7 - high dword of error code

// interrupt acknowledgement
INTACK<=MPUDOUTBus[13] & MPUWSTB[0];

// External condition flag
case (CondSelReg)
	3'd0:	ExtFlag<=ThreadFlag ? ContextREQFlag[1] : ContextREQFlag[0];
	3'd1:	ExtFlag<=NETSENDFlag;
	3'd2:	ExtFlag<=ThreadFlag ? MSGBKPT[1] : MSGBKPT[0];
	3'd3:	ExtFlag<=ThreadFlag ? ~EMPTY[1] : ~EMPTY[0];
	3'd4:	ExtFlag<=1'b0;
	3'd5:	ExtFlag<=1'b0;
	3'd6:	ExtFlag<=1'b0;
	3'd7:	ExtFlag<=1'b0;
	endcase
// condition selection register
if (MPUWSTB[0] & MPUDOUTBus[11]) CondSelReg<=MPUDOUTBus[10:8];

end
end

endmodule: MessengerDT
