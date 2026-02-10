module PortalMCL(
				// global control
				input wire CLK, RST, DTCLR, DIS,
				input wire [39:0] DTBASE,
				input wire [23:0] DTLIMIT,
				input wire [7:0] CPU,
				input wire CFGSTB,
				input wire [7:0] CFG,
				input wire [15:0] TASKID,
				input wire [1:0] CPL,
				input wire [23:0] PSO,
				input wire DSELSTB,
				input wire [23:0] DSEL,
				// portal interface
				output reg PortalNEXT,
				output wire PortalERROR,
				output wire [7:0] PortalERRORTag,
				input wire PortalACT, PortalCMD,
				input wire [31:0] PortalSelector,
				input wire [36:0] PortalOffset,
				input wire [63:0] PortalDO,
				input wire [1:0] PortalSO,
				input wire [7:0] PortalTO,
				output reg PortalDRDY,
				output reg [63:0] PortalDI,
				output reg [1:0] PortalSI,
				output reg [7:0] PortalTI,
				// system interface
				input wire LNEXT, SNEXT,
				output reg LACT, SACT, CMD,
				output reg [1:0] OS,
				output reg [44:0] ADDRESS,
				output reg [31:0] SELECTOR,
				output reg [36:0] OFFSET,
				output reg [63:0] DO,
				output reg [8:0] TO,
				input wire LDRDY, SDRDY,
				input wire [63:0] LDI, SDI,
				input wire [8:0] LTI,
				input wire [7:0] STI,
				input wire [1:0] LSI, SSI,
				// error report interface				
				output wire ESTB,
				output reg [63:0] ECD
				);
/*

			Portal options:
1. lock network accesses
2. lock stream accesses
3. suppress error reporting
4. 

*/

// state registers
reg [7:0] CFGReg;

// descriptor registers
reg [23:0] Sel [0:7];
reg [39:0] Base [0:7];
reg [31:0] LLimit [0:7];
reg [31:0] ULimit [0:7];
reg [23:0] LSel [0:7];
reg [23:0] USel [0:7];
reg [15:0] Task [0:7];
reg [1:0] DPL [0:7];
reg [7:0] Type, REna, WEna, Valid;
reg [3:0] LRU [0:7];

reg InCMDReg;
reg [31:0] InSelReg;
reg [36:0] InOffReg;
reg [63:0] InDataReg;
reg [1:0] InOSReg;
reg [7:0] InTagReg;

reg DescSelNext, DescCMDReg, DescTypeReg, DescREnaReg, DescWEnaReg, DescCheckFlag;
reg [39:0] DescBaseReg;
reg [31:0] DescLLReg, DescULReg, DescSelReg;
reg [23:0] DescLSelReg, DescUSelReg;
reg [36:0] DescOffReg;
reg [15:0] DescTaskReg;
reg [7:0] DescTagReg, DescValidFlag, DescLRUFlag;
reg [63:0] DescDataReg;
reg [1:0] DescOSReg, DescDPLReg;
reg [2:0] DSelReg;

reg [3:0] WSCntr;

reg OutEna, SkipFlag;

// descriptor load machine
reg [3:0] Mach;
localparam Wait=4'd0, Load1=4'd1, Load2=4'd2, Load3=4'd3, Load4=4'd4, LoadNew=4'd5, LoadLower=4'd6, LoadUpper=4'd7, Error1=4'd8, Error2=4'd9;

logic NewRequest, LowerRequest, UpperRequest, AccessEnable, StreamAccessEnable, SkipFifoEmpty, SFifoEmpty;
logic [73:0] SFifoOut;
logic [7:0] SkipFifoOut;

integer i0, i1;

//-------------------------------------------------------------------------------------------------
//								data fifos
sc_fifo_thr	#(.LPM_WIDTH(74), .LPM_NUMWORDS(16), .LPM_WIDTHU(4))SFifo(.data({SSI,STI,SDI}), .wrreq(SDRDY),
							.rdreq(~SFifoEmpty & (~LDRDY | LTI[8])), .clock(CLK), .sclr(~RST),
							.q(SFifoOut), .empty(SFifoEmpty), .full(), .almost_empty(), .usedw());

//-------------------------------------------------------------------------------------------------
//								Skip read fifo
sc_fifo	#(.LPM_WIDTH(8), .LPM_NUMWORDS(16), .LPM_WIDTHU(4))SkipFifo(.data(DescTagReg), .wrreq(SkipFlag & DescCMDReg),
							.rdreq(~SkipFifoEmpty & (~LDRDY | LTI[8]) & SFifoEmpty), .clock(CLK), .sclr(~RST),
							.q(SkipFifoOut), .empty(SkipFifoEmpty), .full(), .almost_empty(), .usedw());
							
assign ESTB=SkipFlag, PortalERROR=SkipFlag, PortalERRORTag=DescTagReg;


always_comb
begin

// enable local access
AccessEnable=|DescValidFlag & (~|DescTaskReg | (DescTaskReg==TASKID)) & (~DescCMDReg | DescREnaReg) & (DescCMDReg | DescWEnaReg) &
							(DescDPLReg>=CPL) & (DescLLReg<=DescOffReg[36:5]) & (DescULReg>DescOffReg[36:5]) & ~DescTypeReg;
StreamAccessEnable=|DescValidFlag & (~|DescTaskReg | (DescTaskReg==TASKID)) & (~DescCMDReg | DescREnaReg) & (DescCMDReg | DescWEnaReg) &
							(DescDPLReg>=CPL) & DescTypeReg;
NewRequest=~DescSelNext & ~|DescValidFlag;
LowerRequest=~DescSelNext & |DescValidFlag & (~|DescTaskReg | (DescTaskReg==TASKID)) & (~DescCMDReg | DescREnaReg) & (DescCMDReg | DescWEnaReg) &
							(DescDPLReg>=CPL) & ((DescLLReg>DescOffReg[36:5])& ~DescTypeReg) & |DescLSelReg;
UpperRequest=~DescSelNext & |DescValidFlag & (~|DescTaskReg | (DescTaskReg==TASKID)) & (~DescCMDReg | DescREnaReg) & (DescCMDReg | DescWEnaReg) &
							(DescDPLReg>=CPL) & ((DescULReg<=DescOffReg[36:5])& ~DescTypeReg) & |DescUSelReg;

end

always_ff @(posedge CLK or negedge RST)
if (~RST)
	begin
	Valid<=0;
	Mach<=Wait;
	PortalNEXT<=1'b1;
	DescSelNext<=1'b1;
	OutEna<=1'b1;
	PortalDRDY<=0;
	LACT<=0;
	SACT<=0;
	LRU[0]<=4'b1111;
	LRU[1]<=4'b1111;
	LRU[2]<=4'b1111;
	LRU[3]<=4'b1111;
	LRU[4]<=4'b1111;
	LRU[5]<=4'b1111;
	LRU[6]<=4'b1111;
	LRU[7]<=4'b1111;
	SkipFlag<=0;
	CFGReg<=0;
	WSCntr<=0;
	end
else begin

//-------------------------------------------------------------------------------------------------
// 								configuration
// config
if (CFGSTB) CFGReg<=CFG;

//-------------------------------------------------------------------------------------------------
// 								Input transaction stage
PortalNEXT<=(PortalNEXT & (~PortalACT | DIS))|(DescSelNext & ~PortalNEXT);
if (PortalNEXT)
	begin
	InCMDReg<=PortalCMD;
	InSelReg<=PortalSelector;
	InOffReg<=PortalOffset;
	InDataReg<=PortalDO;
	InOSReg<=PortalSO;
	InTagReg<=PortalTO;
	end
	
//-------------------------------------------------------------------------------------------------
// 								Descriptor selection stage
DescSelNext<=(DescSelNext & PortalNEXT)|(~|WSCntr & ~DescSelNext & OutEna & (DescTypeReg ? StreamAccessEnable : AccessEnable))| SkipFlag;
if (DescSelNext)
	begin

	DescCMDReg<=InCMDReg;
	DescOffReg<=InOffReg;
	DescDataReg<=InDataReg;
	DescOSReg<=InOSReg;
	DescTagReg<=InTagReg;
	
	DescLRUFlag[0]<=~Valid[0] | (((LRU[0]<=LRU[1])|(LRU[0]<=LRU[2])|(LRU[0]<=LRU[3])|(LRU[0]<=LRU[4])|(LRU[0]<=LRU[5])|(LRU[0]<=LRU[6])|(LRU[0]<=LRU[7]))& &Valid);
	DescLRUFlag[1]<=(~Valid[1] & Valid[0])|((LRU[1]<LRU[0])&((LRU[1]<=LRU[2])|(LRU[1]<=LRU[3])|(LRU[1]<=LRU[4])|(LRU[1]<=LRU[5])|(LRU[1]<=LRU[6])|(LRU[1]<=LRU[7]))& &Valid);
	DescLRUFlag[2]<=(~Valid[2] & &Valid[1:0])|((LRU[2]<LRU[0])&(LRU[2]<LRU[1])&((LRU[2]<=LRU[3])|(LRU[2]<=LRU[4])|(LRU[2]<=LRU[5])|(LRU[2]<=LRU[6])|(LRU[2]<=LRU[7]))& &Valid);
	DescLRUFlag[3]<=(~Valid[3] & &Valid[2:0])|((LRU[3]<LRU[0])&(LRU[3]<LRU[1])&(LRU[3]<LRU[2])&((LRU[3]<=LRU[4])|(LRU[3]<=LRU[5])|(LRU[3]<=LRU[6])|(LRU[3]<=LRU[7]))& &Valid);
	DescLRUFlag[4]<=(~Valid[4] & &Valid[3:0])|((LRU[4]<LRU[0])&(LRU[4]<LRU[1])&(LRU[4]<LRU[2])&(LRU[4]<LRU[3])&((LRU[4]<=LRU[5])|(LRU[4]<=LRU[6])|(LRU[4]<=LRU[7]))& &Valid);
	DescLRUFlag[5]<=(~Valid[5] & &Valid[4:0])|((LRU[5]<LRU[0])&(LRU[5]<LRU[1])&(LRU[5]<LRU[2])&(LRU[5]<LRU[3])&(LRU[5]<LRU[4])&((LRU[5]<=LRU[6])|(LRU[5]<=LRU[7]))& &Valid);
	DescLRUFlag[6]<=(~Valid[6] & &Valid[5:0])|((LRU[6]<LRU[0])&(LRU[6]<LRU[1])&(LRU[6]<LRU[2])&(LRU[6]<LRU[3])&(LRU[6]<LRU[4])&(LRU[6]<LRU[5])&(LRU[6]<=LRU[7])& &Valid);
	DescLRUFlag[7]<=(~Valid[7] & &Valid[6:0])|((LRU[7]<LRU[0])&(LRU[7]<LRU[1])&(LRU[7]<LRU[2])&(LRU[7]<LRU[3])&(LRU[7]<LRU[4])&(LRU[7]<LRU[5])&(LRU[7]<LRU[6])& &Valid);
	end

if (LDRDY & LTI[8] & ~LTI[1] & ~LTI[0]) DescCheckFlag<=LDI[57];

if (DescSelNext | (LDRDY & LTI[8] & LTI[1] & ~LTI[0]))
	for (i0=0; i0<8; i0=i0+1)
		begin
		DescValidFlag[i0]<=(LDRDY & LTI[8]) ? DescValidFlag[i0] | ((LTI[7:2]==i0[5:0])& DescCheckFlag):((InSelReg[23:0]==Sel[i0]) & Valid[i0]);
		end

if (DescSelNext | (LDRDY & LTI[8] & ~LTI[1] & ~LTI[0]))
	begin
	DescBaseReg<=(LDRDY & LTI[8]) ? LDI[39:0] : (Base[0] & {40{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(Base[1] & {40{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
				(Base[2] & {40{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(Base[3] & {40{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
				(Base[4] & {40{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(Base[5] & {40{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
				(Base[6] & {40{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(Base[7] & {40{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	DescTaskReg<=(LDRDY & LTI[8]) ? LDI[55:40] : (Task[0] & {16{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(Task[1] & {16{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
				(Task[2] & {16{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(Task[3] & {16{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
				(Task[4] & {16{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(Task[5] & {16{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
				(Task[6] & {16{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(Task[7] & {16{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	DescTypeReg<=(LDRDY & LTI[8]) ? LDI[56] : (Type[0] & (InSelReg[23:0]==Sel[0]) & Valid[0])|(Type[1] & (InSelReg[23:0]==Sel[1]) & Valid[1])|
				(Type[2] & (InSelReg[23:0]==Sel[2]) & Valid[2])|(Type[3] & (InSelReg[23:0]==Sel[3]) & Valid[3])|
				(Type[4] & (InSelReg[23:0]==Sel[4]) & Valid[4])|(Type[5] & (InSelReg[23:0]==Sel[5]) & Valid[5])|
				(Type[6] & (InSelReg[23:0]==Sel[6]) & Valid[6])|(Type[7] & (InSelReg[23:0]==Sel[7]) & Valid[7]);
	DescDPLReg<=(LDRDY & LTI[8]) ? LDI[59:58] : (DPL[0] & {2{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(DPL[1] & {2{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
				(DPL[2] & {2{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(DPL[3] & {2{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
				(DPL[4] & {2{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(DPL[5] & {2{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
				(DPL[6] & {2{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(DPL[7] & {2{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	DescREnaReg<=(LDRDY & LTI[8]) ? LDI[60] : (REna[0] & (InSelReg[23:0]==Sel[0]) & Valid[0])|(REna[1] & (InSelReg[23:0]==Sel[1]) & Valid[1])|
				(REna[2] & (InSelReg[23:0]==Sel[2]) & Valid[2])|(REna[3] & (InSelReg[23:0]==Sel[3]) & Valid[3])|
				(REna[4] & (InSelReg[23:0]==Sel[4]) & Valid[4])|(REna[5] & (InSelReg[23:0]==Sel[5]) & Valid[5])|
				(REna[6] & (InSelReg[23:0]==Sel[6]) & Valid[6])|(REna[7] & (InSelReg[23:0]==Sel[7]) & Valid[7]);
	DescWEnaReg<=(LDRDY & LTI[8]) ? LDI[61] : (WEna[0] & (InSelReg[23:0]==Sel[0]) & Valid[0])|(WEna[1] & (InSelReg[23:0]==Sel[1]) & Valid[1])|
				(WEna[2] & (InSelReg[23:0]==Sel[2]) & Valid[2])|(WEna[3] & (InSelReg[23:0]==Sel[3]) & Valid[3])|
				(WEna[4] & (InSelReg[23:0]==Sel[4]) & Valid[4])|(WEna[5] & (InSelReg[23:0]==Sel[5]) & Valid[5])|
				(WEna[6] & (InSelReg[23:0]==Sel[6]) & Valid[6])|(WEna[7] & (InSelReg[23:0]==Sel[7]) & Valid[7]);
	end

if (DescSelNext | (LDRDY & LTI[8] & ~LTI[1] & LTI[0]))
	begin
	DescLSelReg<=(LDRDY & LTI[8]) ? LDI[23:0] : (LSel[0] & {24{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(LSel[1] & {24{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
				(LSel[2] & {24{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(LSel[3] & {24{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
				(LSel[4] & {24{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(LSel[5] & {24{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
				(LSel[6] & {24{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(LSel[7] & {24{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	DescUSelReg<=(LDRDY & LTI[8]) ? LDI[55:32] : (USel[0] & {24{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(USel[1] & {24{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
				(USel[2] & {24{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(USel[3] & {24{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
				(USel[4] & {24{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(USel[5] & {24{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
				(USel[6] & {24{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(USel[7] & {24{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	end
				
if (DescSelNext | (LDRDY & LTI[8] & LTI[1] & ~LTI[0]))
	begin
	DescLLReg<=(LDRDY & LTI[8]) ? LDI[31:0] : (LLimit[0] & {32{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(LLimit[1] & {32{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
			(LLimit[2] & {32{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(LLimit[3] & {32{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
			(LLimit[4] & {32{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(LLimit[5] & {32{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
			(LLimit[6] & {32{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(LLimit[7] & {32{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	DescULReg<=(LDRDY & LTI[8]) ? LDI[63:32] : (ULimit[0] & {32{(InSelReg[23:0]==Sel[0]) & Valid[0]}})|(ULimit[1] & {32{(InSelReg[23:0]==Sel[1]) & Valid[1]}})|
			(ULimit[2] & {32{(InSelReg[23:0]==Sel[2]) & Valid[2]}})|(ULimit[3] & {32{(InSelReg[23:0]==Sel[3]) & Valid[3]}})|
			(ULimit[4] & {32{(InSelReg[23:0]==Sel[4]) & Valid[4]}})|(ULimit[5] & {32{(InSelReg[23:0]==Sel[5]) & Valid[5]}})|
			(ULimit[6] & {32{(InSelReg[23:0]==Sel[6]) & Valid[6]}})|(ULimit[7] & {32{(InSelReg[23:0]==Sel[7]) & Valid[7]}});
	end
	
if (DescSelNext) DescSelReg<=InSelReg;
	else if (Mach==LoadLower) DescSelReg<={8'd0,LSel[DSelReg]};
		else if (Mach==LoadUpper) DescSelReg<={8'd0,USel[DSelReg]};
	

//-------------------------------------------------------------------------------------------------
// 								output stage registers
LACT<=((LACT | (~|WSCntr & ~DescSelNext & ~DescTypeReg & AccessEnable)) & (~LNEXT | ~LACT))|(Mach==Load1)|(Mach==Load2)|(Mach==Load3);
SACT<=(SACT | (~|WSCntr & ~DescSelNext & DescTypeReg & StreamAccessEnable))&(~SACT | ~SACT);
OutEna<=(OutEna & (|WSCntr | DescSelNext | ((DescTypeReg ? ~StreamAccessEnable : ~AccessEnable))))|(((LACT & LNEXT)|(SACT & SNEXT))&(Mach==Wait));
if (OutEna)
	begin
	SELECTOR<=DescSelReg;
	OFFSET<=DescOffReg;
	DO<=DescDataReg;
	end
if (((Mach==Load1)|(Mach==Load2)|(Mach==Load3)|(Mach==Load4)) ? (~LACT | LNEXT):OutEna)
	begin
	CMD<=DescCMDReg | (Mach==Load1)|(Mach==Load2)|(Mach==Load3);
	ADDRESS[2:0]<=DescOffReg[2:0] & {3{(Mach!=Load1)&(Mach!=Load2)&(Mach!=Load3)}};
	ADDRESS[3]<=(DescOffReg[3] & (Mach!=Load1) & (Mach!=Load3))|(Mach==Load2);
	ADDRESS[4]<=(DescOffReg[4] & (Mach!=Load1) & (Mach!=Load2))|(Mach==Load3);
	ADDRESS[44:5]<=(Mach==Wait)?(DescBaseReg+{8'd0,DescOffReg[36:5]-DescLLReg}):(DTBASE+{16'd0,DescSelReg[23:0]});
	OS<=DescOSReg | {2{(Mach==Load1)|(Mach==Load2)|(Mach==Load3)}};
	TO<=(Mach==Wait)?{1'b0,DescTagReg}:{1'b1,3'd0,DSelReg,(Mach==Load3),(Mach==Load2)};
	end

// additional wait states control
if (|WSCntr) WSCntr<=WSCntr-4'd1;
	else if (~|WSCntr & ~DescSelNext & OutEna & (Mach==Wait)) WSCntr<=CFGReg[3:0];
	
//-------------------------------------------------------------------------------------------------
// descriptor register selection
if (Mach==Wait)
	begin
	DSelReg[2]<=NewRequest ? |DescLRUFlag[7:4] : |DescValidFlag[7:4];
	DSelReg[1]<=NewRequest ? |DescLRUFlag[7:6] | |DescLRUFlag[3:2] : |DescValidFlag[7:6] | |DescValidFlag[3:2];
	DSelReg[0]<=NewRequest ? DescLRUFlag[7] | DescLRUFlag[5] | DescLRUFlag[3] | DescLRUFlag[1] : DescValidFlag[7] | DescValidFlag[5] | DescValidFlag[3] | DescValidFlag[1];
	end
	
// Descrip[tor loading machine
case (Mach)
	Wait:		if (NewRequest) Mach<=LoadNew;
					else if (LowerRequest) Mach<=LoadLower;
						else if (UpperRequest) Mach<=LoadUpper;
							else Mach<=Wait;
	// load new descriptor
	Load1:		if (~LACT | LNEXT) Mach<=Load2;					// read base address, TaskID and control byte
					else Mach<=Load1;
	Load2:		if (~LACT | LNEXT) Mach<=Load3;					// read link selectors
					else Mach<=Load2;
	Load3:		if (~LACT | LNEXT) Mach<=Load4;					// read limits
					else Mach<=Load3;
	Load4:		if (LDRDY & LTI[8] & LTI[1] & ~LTI[0]) Mach<=Wait;
					else Mach<=Load4;
	// load new descriptor
	LoadNew:	if ((DTLIMIT>DescSelReg[23:0])& |DescSelReg[23:0]) Mach<=Load1;
					else Mach<=Error1;
	// load lower link descriptor
	LoadLower:	if (DTLIMIT>LSel[DSelReg]) Mach<=Load1;
					else Mach<=Error1;
	// load Upper link descriptor
	LoadUpper:	if (DTLIMIT>USel[DSelReg]) Mach<=Load1;
					else Mach<=Error1;
	// error report and skip transaction
	Error1:		Mach<=Error2;
	Error2:		Mach<=Wait;
	endcase
	
//-------------------------------------------------------------------------------------------------
// 								descriptor registers

for (i1=0; i1<8; i1=i1+1)
	begin
	if ((Mach==LoadNew)&(DSelReg==i1[2:0])) Sel[i1]<=DescSelReg[23:0];
	if (LDRDY & LTI[8] & (LTI[7:2]==i1[5:0]) & ~LTI[1] & ~LTI[0])
		begin
		Base[i1]<=LDI[39:0];
		Task[i1]<=LDI[55:40];
		
		DPL[i1]<=LDI[59:58];
		Type[i1]<=LDI[56];
		REna[i1]<=LDI[60];
		WEna[i1]<=LDI[61];
		end
	if (LDRDY & LTI[8] & (LTI[7:2]==i1[5:0]) & ~LTI[1] & ~LTI[0]) Valid[i1]<=LDI[57];
		else if (DTCLR | CFGSTB | (DSELSTB & (DSEL==Sel[i1]) & Valid[i1])) Valid[i1]<=0;
	if (LDRDY & LTI[8] & (LTI[7:2]==i1[5:0]) & ~LTI[1] & LTI[0])
		begin
		LSel[i1]<=LDI[23:0];
		USel[i1]<=LDI[55:32];
		end
	if (LDRDY & LTI[8] & (LTI[7:2]==i1[5:0]) & LTI[1] & ~LTI[0])
		begin
		LLimit[i1]<=LDI[31:0];
		ULimit[i1]<=LDI[63:32];
		end
	if (DescSelNext & ~PortalNEXT) LRU[i1]<=(LRU[i1]-{3'd0,Valid[i1] & |LRU[i1]})|{4{Type[i1] & (InSelReg[23:0]==Sel[i1]) & Valid[i1]}};
		else if ((LDRDY & LTI[8] & (LTI[7:2]==i1[5:0]) & LTI[1] & ~LTI[0])|(~DescSelNext & DescValidFlag[i1])) LRU[i1]<=4'b1111;
	end
	
// skip transaction due to access errors
SkipFlag<=(~SkipFlag & ~DescSelNext & |DescValidFlag & 
			((DescCMDReg & ~DescREnaReg)|(~DescCMDReg & ~DescWEnaReg)|(DescDPLReg<CPL)|(|DescTaskReg & (DescTaskReg!=TASKID))|
			(~DescTypeReg & (DescLLReg>DescOffReg[36:5])& ~|DescLSelReg)|(~DescTypeReg & (DescULReg<=DescOffReg[36:5])& ~|DescUSelReg)))|(Mach==Error1)|
			(LDRDY & LTI[8] & ~LTI[1] & ~LTI[0] & ~LDI[57]);

//-------------------------------------------------------------------------------------------------
//								Data output to the portal
PortalDRDY<=~SkipFifoEmpty | (LDRDY & ~LTI[8]) | ~SFifoEmpty;
PortalDI<=(LDI & {64{LDRDY & ~LTI[8]}})|(SFifoOut[63:0] & {64{~SFifoEmpty & (~LDRDY | LTI[8])}});
PortalTI<=(LTI[7:0] & {8{LDRDY & ~LTI[8]}})|(SFifoOut[71:64] & {8{~SFifoEmpty & (~LDRDY | LTI[8])}})|(SkipFifoOut & {8{(~LDRDY | LTI[8]) & SFifoEmpty}});
PortalSI<=(LSI & {2{LDRDY & ~LTI[8]}})|(SFifoOut[73:72] & {2{~SFifoEmpty & (~LDRDY | LTI[8])}})|{2{(~LDRDY | LTI[8]) & SFifoEmpty}};

//-------------------------------------------------------------------------------------------------
// 								error reporting
ECD[31:0]<=DescSelReg;
ECD[55:32]<=PSO;
ECD[58:56]<=3'd4;
ECD[59]<=(~DescTypeReg & (DescLLReg>DescOffReg[36:5])& ~|DescLSelReg)|(~DescTypeReg & (DescULReg<=DescOffReg[36:5])& ~|DescUSelReg);
ECD[60]<=(DescCMDReg & ~DescREnaReg)|(~DescCMDReg & ~DescWEnaReg);
ECD[61]<=(DescDPLReg<CPL);
ECD[62]<=(|DescTaskReg & (DescTaskReg!=TASKID));
ECD[63]<=LDRDY & LTI[8] & ~LTI[1] & ~LTI[0] & ~LDI[57];


end

endmodule
