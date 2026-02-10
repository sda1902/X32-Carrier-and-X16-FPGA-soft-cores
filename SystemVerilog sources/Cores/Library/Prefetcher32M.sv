module Prefetcher32M #(parameter Mode=0)(
	input wire CLK, RESET, CSELCHG,
	// data bus from memory subsystem
	input wire DRDY,
	input wire [8:0] TAGi,
	input wire [63:0] DTi,
	// instruction bus to sequencer
	input wire IFETCH,
	output wire IRDY,
	output wire [3:0] VF,
	output wire [127:0] IBUS,
	// interface to address translation system
	input wire NEXT,
	output reg ACT,
	output wire [36:0] OFFSET,
	output wire [2:0] TAGo,
	// command interface
	input wire [28:0] CBUS,
	input wire [63:0] GPRBUS,
	input wire CC, MOVFLAG,
	// interface to message and memory control system
	output reg [4:0] GPINDX,
	output reg SMSG, MALLOC, GPAR, EMSG, BKPT, SLEEP,
	output reg [63:0] PARAM,
	output wire CALL, RET, ERST, EMPTY, HALT, SMSGBKPT,
	input wire CEXEC, ESMSG, CONTINUE,
	input wire STOP,
	output wire [34:0] RIP,
	// error reporting
	output reg CFERROR,
	// fatal error report (test purpose)
	output reg FATAL
	);

integer i,i0,i1;

// instruction RAM and his resources
reg [128:0] RAM [0:4095];
reg [20:0] ARAM [0:255];
reg [255:0] VFlags;
reg [128:0] RamReg;
reg [63:0] DITempReg;
reg [34:0] PrefIP, RealIP;			// IP registers
reg [7:0] TMOReg;					// timeout register
reg [4:0] LoadCntr, DataCntr;			// reload counter
reg [28:0] LoadPage;
reg [3:0] VFReg, LockWire, LockReg;
reg [28:0] CBUSReg;
reg [34:0] JumpBus;

reg RamValidFlag, LoadPageFlag, LockFlag, HaltFlag, DelayedCEXECFlag, CFErrorStateFlag, DRDYReg, JccTrueInstFlag,
	JccFalseInstFlag, JNearInstFlag, LoopInstFlag, JumpInstFlag, CallInstFlag, RetInstFlag, RetConditionFlag,
	CEXECFlag, CFErrorFlag, DNearJumpFlag, SMSGFlag, RetFlag, EndLoadFlag, CallRFlag, CallIFlag, CallIInstFlag,
	CallRInstFlag, ValidWire, EmptyFlag, ContextCEXECFlag, IPLoadFlag;
	
logic RestartWire;
logic [128:0] DBus;

logic [20:0] ABus;
/*
 bus format
63:0	Instructions
65:64		lowest two bits of the instruction pointer
66		fetch error flag
*/

logic NearJumpFlag, ContinueFlag, StartLoadFlag;
	

assign RIP=RealIP;
assign CALL=CallIInstFlag | CallRInstFlag;
assign RET=RetInstFlag;
assign ERST=NearJumpFlag;
assign OFFSET[2:0]=3'd0;
// empty flag
assign EMPTY=(((RealIP==PrefIP) | CFErrorStateFlag) & ~RamValidFlag & (~(~LockFlag & ~HaltFlag)) & ~DNearJumpFlag & HaltFlag) | EmptyFlag;
assign HALT=HaltFlag;
assign SMSGBKPT=SMSGFlag;
assign OFFSET={LoadPage, LoadCntr, 3'd0};
assign TAGo={&LoadCntr,2'd0};
assign IBUS=RamReg[127:0];
assign IRDY=RamValidFlag;
assign VF[0]=VFReg[0];
assign VF[1]=VFReg[1] & ~LockReg[0];
assign VF[2]=VFReg[2] & ~LockReg[1] & ~LockReg[0];
assign VF[3]=VFReg[3] & ~LockReg[2] & ~LockReg[1] & ~LockReg[0];

/*
===================================================================================================
		Asynchronous part
===================================================================================================
*/
always @*
	begin
				
	// reading address ram
	ABus=ARAM[PrefIP[13:6]];
	
	// reading data ram
	DBus=RAM[PrefIP[13:2]];

	// instruction valid in the register
	ValidWire=(RamValidFlag & ~IFETCH) | (ContinueFlag & (|LockReg[2:0])) |
			((~LockFlag | (ContinueFlag & LockReg[3])) & ~HaltFlag & (VFlags[PrefIP[13:6]] | ((PrefIP[5:2]<DataCntr[4:1])&(LoadPage[7:0]==PrefIP[13:6]))) & (ABus==PrefIP[34:14]));

	// instruction lock nodes JC, LOOP, MEMALLOC and GETPAR only
	LockWire[0]=DBus[7] & DBus[6] & ~DBus[5] & ~DBus[4] & ~DBus[128] & ~PrefIP[1] & ~PrefIP[0]; 
	LockWire[1]=DBus[39] & DBus[38] & ~DBus[37] & ~DBus[36] & ~DBus[128] & ~PrefIP[1]; 
	LockWire[2]=DBus[71] & DBus[70] & ~DBus[69] & ~DBus[68] & ~DBus[128] & (~PrefIP[1] | ~PrefIP[0]); 
	LockWire[3]=DBus[103] & DBus[102] & ~DBus[101] & ~DBus[100] & ~DBus[128]; 
	
	// generation request to load page
	StartLoadFlag=(~VFlags[PrefIP[13:6]] | (ABus!=PrefIP[34:14])) & ~HaltFlag;
						
	RestartWire=(|LockReg[2:0]) & ContinueFlag;
	
	end

/*
===================================================================================================
		Synchronous part
===================================================================================================
*/
always @(negedge RESET or posedge CLK)
	if (!RESET) begin
				VFReg<=0;
				LockReg<=0;
				ACT<=0;
				SMSG<=0;
				MALLOC<=0;
				GPAR<=0;
				EMSG<=0;
				BKPT<=0;
				SLEEP<=0;
				CFERROR<=0;
				RamValidFlag<=0;
				LoadPageFlag<=0;
				DRDYReg<=0;
				PrefIP<=0;
				RealIP<=0;
				TMOReg<=0;
				LoadCntr<=0;
				DataCntr<=0;
				LockFlag<=0;
				if (Mode==0) HaltFlag<=0;
					else HaltFlag<=1'b1;
				DelayedCEXECFlag<=0;
				CFErrorStateFlag<=0;
				JccTrueInstFlag<=0;
				JccFalseInstFlag<=0;
				JNearInstFlag<=0;
				LoopInstFlag<=0;
				JumpInstFlag<=0;
				CallRInstFlag<=0;
				CallIInstFlag<=0;
				RetInstFlag<=0;
				RetConditionFlag<=0;
				CEXECFlag<=0;
				CFErrorFlag<=0;
				DNearJumpFlag<=0;
				SMSGFlag<=0;
				RetFlag<=0;
				VFlags<=0;
				EndLoadFlag<=0;
				CallIFlag<=0;
				CallRFlag<=0;
				ContinueFlag<=0;
				NearJumpFlag<=0;
				EmptyFlag<=0;
				ContextCEXECFlag<=0;
				IPLoadFlag<=0;
				end
	else begin
	
	// valid flags 
	if (((~IRDY | IFETCH) & ~LockFlag) | ContinueFlag | NearJumpFlag)
		begin
		VFReg[0]<=(RestartWire ? 1'b0 : ~DBus[128] & ~PrefIP[1] & ~PrefIP[0]) & ~NearJumpFlag;
		VFReg[1]<=(RestartWire ? VFReg[1] & (VFReg[0] & LockReg[0]) : ~DBus[128] & ~PrefIP[1]) & ~NearJumpFlag;
		VFReg[2]<=(RestartWire ? VFReg[2] & ((VFReg[0] & LockReg[0])|(VFReg[1] & LockReg[1])) : ~DBus[128] & (~PrefIP[1] | ~PrefIP[0])) & ~NearJumpFlag;
		VFReg[3]<=(RestartWire ? VFReg[3] & ((VFReg[0] & LockReg[0])|(VFReg[1] & LockReg[1])|(VFReg[2] & LockReg[2])) : ~DBus[128]) & ~NearJumpFlag;
	
		// instruction lock nodes 
		LockReg[0]<=(RestartWire ? 1'b0 : LockWire[0]) & ~NearJumpFlag; 
		LockReg[1]<=(RestartWire ? LockReg[1] & LockReg[0] : LockWire[1]) & ~NearJumpFlag; 
		LockReg[2]<=(RestartWire ? LockReg[2] & (LockReg[1] | LockReg[0]) : LockWire[2]) & ~NearJumpFlag; 
		LockReg[3]<=(RestartWire ? LockReg[3] & (LockReg[2] | LockReg[1] | LockReg[0]) : LockWire[3]) & ~NearJumpFlag; 
		end
	
	// send message state flag
	//                          BKPT & SENDMSG
	EmptyFlag<=(EmptyFlag | (CBUS[0] & ((~CBUS[1] &  ~CBUS[2] & ((~CBUS[3] & ~CBUS[4]) | (CBUS[3] & CBUS[4])))|(CBUS[4:1]==4'hD)))) & ~CONTINUE & ~ESMSG & ~CEXEC & ~IPLoadFlag;
	//		BKPT, SMSG, EMSG, MALLOC, GETPAR
	SMSGFlag<=(SMSGFlag | (CBUS[0] & ((CBUS[4:2]==3'd0)|(CBUS[4:1]==4'h7)|(CBUS[4:1]==4'h9)|(CBUS[4:1]==4'hC)))) & ~CONTINUE & ~ESMSG & ~CEXEC & ~IPLoadFlag;

	// transaction timeout
	TMOReg<=(TMOReg+8'd1) & ~HaltFlag & (~IRDY | ~IFETCH);
	// generate FATAL error signal if instruction timeout expired
	FATAL<=&TMOReg;
	
	// instruction register and data from GPR
	if ((~CallRFlag)&(~RetFlag)&(~CallIFlag)) CBUSReg<=CBUS;
	if (CBUS[0]) PARAM<=GPRBUS;
	
	// data ready to the instruction cache
	DRDYReg<=DRDY & (TAGi[8:5]==4'hA) & ~TAGi[3];
	EndLoadFlag<=DRDY & (TAGi[8:5]==4'hA) & ~TAGi[3] & TAGi[2];
	
	// Code fetch error flag
	CFErrorFlag<=TAGi[4];
	
	// Code fetch error reporting
	CFERROR<=~CFErrorStateFlag & RamValidFlag & RamReg[128] & (~LockFlag | ContinueFlag);
	CFErrorStateFlag<=(CFErrorStateFlag | CFERROR) & ~CEXEC & ~IPLoadFlag;
	
	// return condition
	RetConditionFlag<=(DRDY & (TAGi[8:3]==6'h29)) | CEXEC | ESMSG;
	CEXECFlag<=CEXEC | ESMSG;
	
	// restart core by write IP from context controller
	IPLoadFlag<=DRDY & TAGi[8] & ~TAGi[7] & TAGi[6] & ~TAGi[5] & ~TAGi[4] & TAGi[3] & TAGi[0];

	ContextCEXECFlag<=CEXEC;

	DelayedCEXECFlag<=ContextCEXECFlag | IPLoadFlag;
	
	// setting the LockFlag
	if (~IRDY | IFETCH | ContinueFlag | NearJumpFlag) LockFlag<=ContinueFlag ? (~VF[3] & LockReg[3])|(~VF[2] & LockReg[2])|(~VF[1] & LockReg[1])|
									((|LockWire) & ValidWire & ~(|LockReg[2:0])) : (LockFlag | ((|LockWire) & ValidWire)) & ~NearJumpFlag;
								
	// stop execution flag
	HaltFlag<=(HaltFlag | STOP) & ~DelayedCEXECFlag;
		
	
	//===================================================================================================================================
	// reading data from instruction memory
	
	// processing pre-load program counter
	if (NearJumpFlag) PrefIP<=JumpBus;
			else if ((((~RamValidFlag | IFETCH) & ~LockFlag) | (ContinueFlag & ~LockReg[2] & ~LockReg[1] & ~LockReg[0])) &
						~HaltFlag & (VFlags[PrefIP[13:6]] | ((PrefIP[5:2]<DataCntr[4:1])&(LoadPage[7:0]==PrefIP[13:6]))) & (ABus==PrefIP[34:14])) PrefIP<={PrefIP[34:2]+33'd1, 2'd0};

	if (((~RamValidFlag | IFETCH) & ~LockFlag) | (ContinueFlag & ~LockReg[2] & ~LockReg[1] & ~LockReg[0])) RamReg<=DBus;
		
	// creating ram valid flag
	RamValidFlag<=ValidWire;
						
	// forming jump address
	if (JccTrueInstFlag | LoopInstFlag) JumpBus<=RealIP+{{19{CBUSReg[20]}}, CBUSReg[20:5]} + {35{1'b1}};
			else if (JNearInstFlag | CallIInstFlag) JumpBus<=RealIP+{{11{CBUSReg[28]}}, CBUSReg[28:5]} + {35{1'b1}};
					else if (JumpInstFlag | CallRInstFlag) JumpBus<=PARAM[36:2];
							else if (RetConditionFlag) JumpBus<=CEXECFlag ? RealIP : DTi[36:2];
					
	
	//===================================================================================================================================
		
	
	// real program counter
	if (NearJumpFlag) RealIP<=JumpBus;
			else if (IFETCH & IRDY) RealIP<=RealIP+{34'd0, VF[0]}+{34'd0, VF[1]}+{34'd0, VF[2]}+{34'd0, VF[3]};
	
	// delayed jump flag
	DNearJumpFlag<=NearJumpFlag;
	

	// Jcc instruction when condition true
	JccTrueInstFlag<=CBUS[0] & (CBUS[4:2]==3'b010) & CC;
	// Jcc instruction when condition false
	JccFalseInstFlag<=CBUS[0] & (((CBUS[4:2]==3'b010) & ~CC)|((CBUS[4:1]==4'h6) & ~(|GPRBUS[31:1]) & GPRBUS[0]));
	// JUMPI instruction flag
	JNearInstFlag<=CBUS[0] & (CBUS[4:1]==4'hA);
	// CALLI instruction flag
	CallIInstFlag<=CallIFlag & ~MOVFLAG;
	CallIFlag<=(CallIFlag & MOVFLAG) | (CBUS[0] & (CBUS[4:1]==4'hB));
	// LOOP Instruction flag
	LoopInstFlag<=CBUS[0] & (CBUS[4:1]==4'h6) & ((|GPRBUS[31:1]) | ~GPRBUS[0]);
	// JUMPR instruction flag
	JumpInstFlag<=CBUS[0] & (CBUS[4:1]==4'h2);
	// CALLR instruction flag
	CallRInstFlag<=CallRFlag & ~MOVFLAG;
	CallRFlag<=(CallRFlag & MOVFLAG) | (CBUS[0] & (CBUS[4:1]==4'h3));
	// RET instruction flag
	RetInstFlag<=RetFlag & ~MOVFLAG;
	RetFlag<=(RetFlag & MOVFLAG) | (CBUS[0] & (CBUS[4:1]==4'h8));
	// flag for ALL near jump's
	NearJumpFlag<=JccTrueInstFlag | JNearInstFlag | LoopInstFlag | JumpInstFlag | CallIInstFlag | CallRInstFlag | RetConditionFlag;
	ContinueFlag<=JccFalseInstFlag | CONTINUE;
	
	//
	// Control signals to high-level instructions
	//
	// register index
	if (CBUS[0]) GPINDX<=CBUS[25:21];
	// send message request
	SMSG<=CBUS[0] & (CBUS[4:1]==4'h0);
	// memory allocation request
	MALLOC<=CBUS[0] & (CBUS[4:1]==4'h7);
	// get message params request
	GPAR<=CBUS[0] & (CBUS[4:1]==4'h1);
	// end message processign
	EMSG<=CBUS[0] & (CBUS[4:1]==4'h9);
	// breakpoint request
	BKPT<=CBUS[0] & (CBUS[4:1]==4'hC);
	// sleep request
	SLEEP<=CBUS[0] & (CBUS[4:1]==4'hD);
	
	
	//=============================================================================================================
	//				ram preload system
	
	// valid flags
	for (i=0; i<256; i=i+1)
		if (CSELCHG) VFlags[i]<=0;
			else if (i==LoadPage[7:0]) VFlags[i]<=VFlags[i] | EndLoadFlag;
	
	// reload line counter
	LoadCntr<=LoadCntr+{4'd0,ACT & NEXT};
	
	// page loading
	LoadPageFlag<=(LoadPageFlag | StartLoadFlag) & ~EndLoadFlag;
	
	// page register
	if (~LoadPageFlag) LoadPage<=PrefIP[34:6];
	
	// transaction generation
	ACT<=(ACT & ~(NEXT & (&LoadCntr))) | (StartLoadFlag & ~LoadPageFlag);
	
	// write to the address ram
	if (LoadPageFlag & ~(|LoadCntr)) ARAM[LoadPage[7:0]]<=LoadPage[28:8];
	
	// temporary data register
	if (DRDYReg) DITempReg<=DTi;
	
	// write data to the RAM
	if (DRDYReg & DataCntr[0]) RAM[{LoadPage,DataCntr[4:1]}]<={CFErrorFlag, DTi, DITempReg};
	
	// data counter
	DataCntr<=(DataCntr+{4'd0,DRDYReg}) & {5{LoadPageFlag}};

	end

endmodule
