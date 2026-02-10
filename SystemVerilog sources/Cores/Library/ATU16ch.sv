module ATU16ch  #(parameter TagWidth=8)	(
					// global control
					input wire RESETn, CLK,
					input wire [7:0] CPU,
					input wire [39:0] DTBASE,
					input wire [23:0] DTLIMIT,
					// access selectors
					input wire [31:0] SELECTORS00, SELECTORS01, SELECTORS02, SELECTORS03, SELECTORS04, SELECTORS05, SELECTORS06, SELECTORS07,
											SELECTORS08, SELECTORS09, SELECTORS10, SELECTORS11, SELECTORS12, SELECTORS13, SELECTORS14, SELECTORS15,
					input wire [15:0] SELINVD,
					// ISI
					output wire INEXT,
					input wire IACT, ICMD, ICPLMASK, ITIDMASK,
					input wire [3:0] ISEL,
					input wire [1:0] ICPL,
					input wire [15:0] ITID,
					input wire [36:0] IOFFSET,
					input wire [1:0] ISZO,
					input wire [63:0] IDTO,
					input wire [TagWidth-1:0] ITGO,
					output reg IDRDY,
					output reg [63:0] IDTI,
					output reg [1:0] ISZI,
					output reg [TagWidth-1:0] ITGI,
					// interfaces to the bus subsystem
					input wire LNEXT, NNEXT, SNEXT,
					output reg LACT, NACT, SACT, CMD,
					output reg [1:0] SZO,
					output reg [44:0] ADDRESS,
					output reg [36:0] OFFSET,
					output reg [31:0] SELECTOR,
					output reg [63:0] DTO,
					output reg [TagWidth:0] TGO,
					input wire LDRDY, NDRDY, SDRDY,
					input wire [63:0] LDTI, NDTI, SDTI,
					input wire [1:0] LSZI, NSZI, SSZI,
					input wire [TagWidth:0] LTGI,
					input wire [TagWidth-1:0] NTGI, STGI,
					// error report
					input wire EENA,
					output reg ESTB,
					output reg [4:0] ECD,
					output reg [TagWidth-1:0] ETAG
					);

logic InACT, OutNext, NewSelRequest, BadTypeRequest, LLRequest, ULRequest, InTDIMask, TIDReqest, CPLRequest, InNext,
		InCMD, LocalRead, NetworkRead, StreamRead, InCPLMask, ErrorBypass, LocalEmpty, NetworkEmpty, StreamEmpty;
logic [1:0] InCPL, InSize, ErrSize;
logic [3:0] InSelIndex, LocalUsed, NetworkUsed, StreamUsed;
logic [4:0] ReadCnt;
logic [15:0] InTaskID;
logic [23:0] NewSelValue;
logic [31:0] InSel;
logic [31:0] SELECTORS [0:15];
logic [36:0] InOffset;
logic [63:0] InData;
logic [TagWidth-1:0] InTAG;
logic [65+TagWidth:0] LocalBus, NetworkBus, StreamBus;
	
reg InDescriptor_WE, InDescriptor_RE;
reg [1:0] InDescriptor_DPL, InDescriptor_Type;
reg [23:0] InDescriptor_ULSel, InDescriptor_LLSel;
reg [31:0] InDescriptor_ULimit, InDescriptor_LLimit;
reg [15:0] InDescriptor_TaskID;
reg [39:0] InDescriptor_Base;

reg [15:0] Descriptors_WE, Descriptors_RE;
reg [1:0] Descriptors_DPL [0:15];
reg [1:0] Descriptors_Type [0:15];
reg [23:0] Descriptors_ULSel [0:15];
reg [23:0] Descriptors_LLSel [0:15];
reg [31:0] Descriptors_ULimit [0:15];
reg [31:0] Descriptors_LLimit [0:15];
reg [15:0] Descriptors_TaskID [0:15];
reg [39:0] Descriptors_Base [0:15];

enum reg [3:0] {Ws, Lds0, Lds1, Lds2, Lds3, Rds0, Rds1, Rds2, Lls, Uls, Errs0, Errs1, Errs2, Errs3, Errs4, Crs} sm=Ws;

integer i0;

assign	SELECTORS[00]=SELECTORS00, SELECTORS[01]=SELECTORS01, SELECTORS[02]=SELECTORS02, SELECTORS[03]=SELECTORS03,
		SELECTORS[04]=SELECTORS04, SELECTORS[05]=SELECTORS05, SELECTORS[06]=SELECTORS06, SELECTORS[07]=SELECTORS07,
		SELECTORS[08]=SELECTORS08, SELECTORS[09]=SELECTORS09, SELECTORS[10]=SELECTORS10, SELECTORS[11]=SELECTORS11,
		SELECTORS[12]=SELECTORS12, SELECTORS[13]=SELECTORS13, SELECTORS[14]=SELECTORS14, SELECTORS[15]=SELECTORS15;

// local channel fifo
//sc_fifo #(.LPM_WIDTH(66+TagWidth), .LPM_NUMWORDS(16), .LPM_WIDTHU(4)) LFifo (.data({LTGI[TagWidth-1:0], LSZI, LDTI}), .wrreq(LDRDY & ~LTGI[TagWidth]), .rdreq(LocalRead), .clock(CLK), .sclr(~RESETn),
//																						.q(LocalBus), .empty(LocalEmpty), .full(), .almost_empty(), .usedw(LocalUsed));
ATUfifo LFifo(.clock(CLK), .data({LTGI[TagWidth-1:0], LSZI, LDTI}), .rdreq(LocalRead), .sclr(~RESETn), .wrreq(LDRDY & ~LTGI[TagWidth]), .empty(LocalEmpty), .q(LocalBus), .usedw(LocalUsed));

// network channel fifo
//sc_fifo #(.LPM_WIDTH(66+TagWidth), .LPM_NUMWORDS(16), .LPM_WIDTHU(4)) NFifo (.data({NTGI, NSZI, NDTI}), .wrreq(NDRDY), .rdreq(NetworkRead), .clock(CLK), .sclr(~RESETn),
//																						.q(NetworkBus), .empty(NetworkEmpty), .full(), .almost_empty(), .usedw(NetworkUsed));
ATUfifo NFifo(.clock(CLK), .data({NTGI, NSZI, NDTI}), .rdreq(NetworkRead), .sclr(~RESETn), .wrreq(NDRDY), .empty(NetworkEmpty), .q(NetworkBus), .usedw(NetworkUsed));
// stream channel fifo
//sc_fifo #(.LPM_WIDTH(66+TagWidth), .LPM_NUMWORDS(16), .LPM_WIDTHU(4)) SFifo (.data({STGI, SSZI, SDTI}), .wrreq(SDRDY), .rdreq(StreamRead), .clock(CLK), .sclr(~RESETn),
//																						.q(StreamBus), .empty(StreamEmpty), .full(), .almost_empty(), .usedw(StreamUsed));
ATUfifo SFifo(.clock(CLK), .data({STGI, SSZI, SDTI}), .rdreq(StreamRead), .sclr(~RESETn), .wrreq(SDRDY), .empty(StreamEmpty), .q(StreamBus), .usedw(StreamUsed));



assign INEXT=InNext;



always_comb begin

OutNext=(~LACT & ~NACT & ~SACT)|(LACT & LNEXT)|(NACT & NNEXT)|(SACT & SNEXT);
InNext=~InACT;

LocalRead=~LocalEmpty & ((LocalUsed>=NetworkUsed) | NetworkEmpty) & ((LocalUsed>=StreamUsed) | StreamEmpty);
NetworkRead=~NetworkEmpty & ((NetworkUsed>LocalUsed) | LocalEmpty) & ((NetworkUsed>=StreamUsed) | StreamEmpty);
StreamRead=~StreamEmpty & ((StreamUsed>LocalUsed) | LocalEmpty) & ((StreamUsed>NetworkUsed) | NetworkEmpty);

end



always_ff @(posedge CLK or negedge RESETn)
if (~RESETn)
	begin
	InACT<='0;
	LACT<='0;
	NACT<='0;
	SACT<='0;
	sm<=Ws;
	NewSelRequest<='0;
	BadTypeRequest<='0;
	LLRequest<='0;
	ULRequest<='0;
	TIDReqest<='0;
	CPLRequest<='0;
	ESTB<='0;
	ReadCnt<='0;
	IDRDY<='0;
	
	InDescriptor_WE<='0;
	InDescriptor_RE<='0;
	InDescriptor_DPL<='0;
	InDescriptor_Type<='0;
	InDescriptor_ULSel<='0;
	InDescriptor_LLSel<='0;
	InDescriptor_ULimit<='0;
	InDescriptor_LLimit<='0;
	InDescriptor_TaskID<='0;
	InDescriptor_Base<='0;
	
	{Descriptors_WE[00], Descriptors_RE[00], Descriptors_DPL[00], Descriptors_Type[00], Descriptors_ULSel[00], Descriptors_LLSel[00], Descriptors_ULimit[00], Descriptors_LLimit[00], Descriptors_TaskID[00], Descriptors_Base[00]}<='0;
	{Descriptors_WE[01], Descriptors_RE[01], Descriptors_DPL[01], Descriptors_Type[01], Descriptors_ULSel[01], Descriptors_LLSel[01], Descriptors_ULimit[01], Descriptors_LLimit[01], Descriptors_TaskID[01], Descriptors_Base[01]}<='0;
	{Descriptors_WE[02], Descriptors_RE[02], Descriptors_DPL[02], Descriptors_Type[02], Descriptors_ULSel[02], Descriptors_LLSel[02], Descriptors_ULimit[02], Descriptors_LLimit[02], Descriptors_TaskID[02], Descriptors_Base[02]}<='0;
	{Descriptors_WE[03], Descriptors_RE[03], Descriptors_DPL[03], Descriptors_Type[03], Descriptors_ULSel[03], Descriptors_LLSel[03], Descriptors_ULimit[03], Descriptors_LLimit[03], Descriptors_TaskID[03], Descriptors_Base[03]}<='0;
	{Descriptors_WE[04], Descriptors_RE[04], Descriptors_DPL[04], Descriptors_Type[04], Descriptors_ULSel[04], Descriptors_LLSel[04], Descriptors_ULimit[04], Descriptors_LLimit[04], Descriptors_TaskID[04], Descriptors_Base[04]}<='0;
	{Descriptors_WE[05], Descriptors_RE[05], Descriptors_DPL[05], Descriptors_Type[05], Descriptors_ULSel[05], Descriptors_LLSel[05], Descriptors_ULimit[05], Descriptors_LLimit[05], Descriptors_TaskID[05], Descriptors_Base[05]}<='0;
	{Descriptors_WE[06], Descriptors_RE[06], Descriptors_DPL[06], Descriptors_Type[06], Descriptors_ULSel[06], Descriptors_LLSel[06], Descriptors_ULimit[06], Descriptors_LLimit[06], Descriptors_TaskID[06], Descriptors_Base[06]}<='0;
	{Descriptors_WE[07], Descriptors_RE[07], Descriptors_DPL[07], Descriptors_Type[07], Descriptors_ULSel[07], Descriptors_LLSel[07], Descriptors_ULimit[07], Descriptors_LLimit[07], Descriptors_TaskID[07], Descriptors_Base[07]}<='0;
	{Descriptors_WE[08], Descriptors_RE[08], Descriptors_DPL[08], Descriptors_Type[08], Descriptors_ULSel[08], Descriptors_LLSel[08], Descriptors_ULimit[08], Descriptors_LLimit[08], Descriptors_TaskID[08], Descriptors_Base[08]}<='0;
	{Descriptors_WE[09], Descriptors_RE[09], Descriptors_DPL[09], Descriptors_Type[09], Descriptors_ULSel[09], Descriptors_LLSel[09], Descriptors_ULimit[09], Descriptors_LLimit[09], Descriptors_TaskID[09], Descriptors_Base[09]}<='0;
	{Descriptors_WE[10], Descriptors_RE[10], Descriptors_DPL[10], Descriptors_Type[10], Descriptors_ULSel[10], Descriptors_LLSel[10], Descriptors_ULimit[10], Descriptors_LLimit[10], Descriptors_TaskID[10], Descriptors_Base[10]}<='0;
	{Descriptors_WE[11], Descriptors_RE[11], Descriptors_DPL[11], Descriptors_Type[11], Descriptors_ULSel[11], Descriptors_LLSel[11], Descriptors_ULimit[11], Descriptors_LLimit[11], Descriptors_TaskID[11], Descriptors_Base[11]}<='0;
	{Descriptors_WE[12], Descriptors_RE[12], Descriptors_DPL[12], Descriptors_Type[12], Descriptors_ULSel[12], Descriptors_LLSel[12], Descriptors_ULimit[12], Descriptors_LLimit[12], Descriptors_TaskID[12], Descriptors_Base[12]}<='0;
	{Descriptors_WE[13], Descriptors_RE[13], Descriptors_DPL[13], Descriptors_Type[13], Descriptors_ULSel[13], Descriptors_LLSel[13], Descriptors_ULimit[13], Descriptors_LLimit[13], Descriptors_TaskID[13], Descriptors_Base[13]}<='0;
	{Descriptors_WE[14], Descriptors_RE[14], Descriptors_DPL[14], Descriptors_Type[14], Descriptors_ULSel[14], Descriptors_LLSel[14], Descriptors_ULimit[14], Descriptors_LLimit[14], Descriptors_TaskID[14], Descriptors_Base[14]}<='0;
	{Descriptors_WE[15], Descriptors_RE[15], Descriptors_DPL[15], Descriptors_Type[15], Descriptors_ULSel[15], Descriptors_LLSel[15], Descriptors_ULimit[15], Descriptors_LLimit[15], Descriptors_TaskID[15], Descriptors_Base[15]}<='0;
	
	ErrorBypass<='0;
	end
else begin

// input activation
InACT<=(InACT | IACT) & ~(OutNext & InACT & ((CPU!=InSel[31:24])|(InDescriptor_Type[1] & ((InCPL<=InDescriptor_DPL) | InCPLMask) & ((InTaskID==InDescriptor_TaskID) | ~|InDescriptor_TaskID | InTDIMask) &
																			(InDescriptor_Type[0] | ((InOffset[36:5]>=InDescriptor_LLimit) & (InOffset[36:5]<InDescriptor_ULimit))) &
																			(~InCMD | InDescriptor_RE) & (InCMD | InDescriptor_WE)))) &
							(sm!=Errs0) & (sm!=Errs1) & (sm!=Errs2) & (sm!=Errs3) & (sm!=Errs4);

// input stage registers
if (InNext)
	begin
	InCMD<=ICMD;
	InSelIndex<=ISEL;
	InSel[23:0]<=SELECTORS[ISEL][23:0];
	InSel[31:24]<=|CPU ? (|SELECTORS[ISEL][31:24] ? SELECTORS[ISEL][31:24] : CPU) : 8'd0;
	InOffset<=IOFFSET;
	InCPL<=ICPL;
	InTaskID<=ITID;
	InSize<=ISZO;
	InTAG<=ITGO;
	InTDIMask<=ITIDMASK;
	InCPLMask<=ICPLMASK;
	InData<=IDTO;
	end

if (InNext | (sm==Rds1))
	begin
	InDescriptor_WE<=Descriptors_WE[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_RE<=Descriptors_RE[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_DPL<=Descriptors_DPL[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_Type<=Descriptors_Type[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_ULSel<=Descriptors_ULSel[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_LLSel<=Descriptors_LLSel[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_ULimit<=Descriptors_ULimit[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_LLimit<=Descriptors_LLimit[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_TaskID<=Descriptors_TaskID[(sm==Rds1) ? InSelIndex : ISEL];
	InDescriptor_Base<=Descriptors_Base[(sm==Rds1) ? InSelIndex : ISEL];	
	end


// output transaction stage
LACT<=(LACT & ~LNEXT) | (((InACT & (CPU==InSel[31:24]) & (InDescriptor_Type==2'd2) & ((InCPL<=InDescriptor_DPL) | InCPLMask) & ((InTaskID==InDescriptor_TaskID) | ~|InDescriptor_TaskID | InTDIMask) &
								(~InCMD | InDescriptor_RE) & (InCMD | InDescriptor_WE) & (InOffset[36:5]>=InDescriptor_LLimit) & (InOffset[36:5]<InDescriptor_ULimit)) |
						(sm==Lds1) | (sm==Lds2) | (sm==Lds3)) & (~NACT | NNEXT) & (~SACT | SNEXT)) ;
NACT<=(NACT & ~NNEXT) | (InACT & (CPU!=InSel[31:24]) & (~LACT | LNEXT) & (~SACT | SNEXT));
SACT<=(SACT & ~SNEXT) | (InACT & (CPU==InSel[31:24]) & (InDescriptor_Type==2'd3) & ((InCPL<=InDescriptor_DPL) | InCPLMask) & ((InTaskID==InDescriptor_TaskID) | ~|InDescriptor_TaskID | InTDIMask) &
								(~InCMD | InDescriptor_RE) & (InCMD | InDescriptor_WE) & (~LACT | LNEXT) & (~NACT | SNEXT));
if (OutNext)
	begin
	CMD<=InCMD | (sm==Lds1) | (sm==Lds2) | (sm==Lds3);
	ADDRESS[4:0]<=((sm==Ws)|(sm==Rds2)) ? InOffset[4:0] : {(sm==Lds3),(sm==Lds2),3'd0};
	ADDRESS[44:5]<=((sm==Ws)|(sm==Rds2)) ? InDescriptor_Base+InOffset[36:5]-InDescriptor_LLimit : DTBASE+NewSelValue;
	SZO<=InSize | {(sm!=Ws)&(sm!=Rds2), (sm!=Ws)&(sm!=Rds2)};
	TGO<=((sm==Ws)|(sm==Rds2)) ? {1'b0,InTAG} : {1'b1,{TagWidth-2{1'b0}},(sm==Lds3),(sm==Lds2)};
	DTO<=InData;
	OFFSET<=InOffset;
	SELECTOR<=InSel;
	end

// request to load new descriptor
NewSelRequest<=InACT & ~InDescriptor_Type[1] & ~InDescriptor_Type[0] & (CPU==InSel[31:24]);
// inaccessible object
BadTypeRequest<=InACT & ((~InCMD & ~InDescriptor_WE) | (InCMD & ~InDescriptor_RE)) & (CPU==InSel[31:24]) & InDescriptor_Type[1];
// lower limit violation
LLRequest<=InACT & (InOffset[36:5]<InDescriptor_LLimit) & (CPU==InSel[31:24]) & (InDescriptor_Type==2'd2);
// upper limit violation
ULRequest<=InACT & (InOffset[36:5]>=InDescriptor_ULimit) & (CPU==InSel[31:24]) & (InDescriptor_Type==2'd2);
// TaskID violation
TIDReqest<=InACT & (InTaskID!=InDescriptor_TaskID) & |InDescriptor_TaskID & ~InTDIMask & (CPU==InSel[31:24]) & InDescriptor_Type[1];
// CPL violation
CPLRequest<=InACT & (InCPL>InDescriptor_DPL) & ~InCPLMask & (CPU==InSel[31:24]) & InDescriptor_Type[1];

// new selector
if (sm==Ws) NewSelValue<=InSel[23:0];
	else if (sm==Lls) NewSelValue<=InDescriptor_LLSel;
			else if (sm==Uls) NewSelValue<=InDescriptor_ULSel;

// descriptor load machine
case (sm)
	Ws:		if (NewSelRequest) sm<=Lds0;
				else if (BadTypeRequest | TIDReqest | CPLRequest) sm<=Errs1;
						else if (LLRequest) sm<=Lls;
								else if (ULRequest) sm<=Uls;
										else sm<=Ws;
	// load new descriptor
	// check selector
	Lds0:	if (~|NewSelValue | (NewSelValue>=DTLIMIT)) sm<=Errs0;
				else sm<=Lds1;
	// load base address and control word
	Lds1:	if (OutNext) sm<=Lds2;
				else sm<=Lds1;
	// load link selectors
	Lds2:	if (OutNext) sm<=Lds3;
				else sm<=Lds2;
	// load limits
	Lds3:	if (OutNext) sm<=Rds0;
				else sm<=Lds3;
	// waiting for descriptor
	Rds0:	if (LDRDY & LTGI[TagWidth] & (LTGI[1:0]==2'd2)) sm<=Rds1;
				else sm<=Rds0;
	// Reload descriptor InDSC
	Rds1:	if (~Descriptors_Type[InSelIndex][1]) sm<=Errs4;
				else sm<=Rds2;
	// waiting for renew transaction status
	Rds2:	sm<=Ws;
	
	// load lower selector
	Lls:	if (|InDescriptor_LLSel) sm<=Lds0;
				else sm<=Errs2;
				
	// load upper selector
	Uls:	if (|InDescriptor_ULSel) sm<=Lds0;
				else sm<=Errs3;
	
	// invalid selector
	Errs0:	if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// read\write eror
	Errs1:	if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// lower limit error
	Errs2: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// upper limit error
	Errs3: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
	// descriptor type error
	Errs4: if (~InCMD) sm<=Rds2;
				else sm<=Crs;
				
	// invalid read request processng
	Crs:	if (|{ReadCnt, ~LocalEmpty, ~NetworkEmpty, ~StreamEmpty}) sm<=Crs;
				else sm<=Rds2;
	endcase


// descriptor registers
for (i0=0; i0<16; i0=i0+1)
	if (SELINVD[i0]) {Descriptors_WE[i0], Descriptors_RE[i0], Descriptors_DPL[i0], Descriptors_Type[i0], Descriptors_ULSel[i0], Descriptors_LLSel[i0], Descriptors_ULimit[i0], Descriptors_LLimit[i0], Descriptors_TaskID[i0], Descriptors_Base[i0]}<='0;
		else if ((i0[3:0]==InSelIndex) & LDRDY & LTGI[TagWidth] & (LTGI[1:0]==2'd0)) {Descriptors_WE[i0], Descriptors_RE[i0], Descriptors_DPL[i0], Descriptors_Type[i0], Descriptors_TaskID[i0], Descriptors_Base[i0]}<=LDTI[61:0];
				else if ((i0[3:0]==InSelIndex) & LDRDY & LTGI[TagWidth] & (LTGI[1:0]==2'd1)) {Descriptors_ULSel[i0], Descriptors_LLSel[i0]}<={LDTI[55:32], LDTI[23:00]};
						else if ((i0[3:0]==InSelIndex) & LDRDY & LTGI[TagWidth] & (LTGI[1:0]==2'd2)) {Descriptors_ULimit[i0], Descriptors_LLimit[i0]}<=LDTI;


// error strobe
ESTB<=((sm==Errs0) | (sm==Errs1) | (sm==Errs2) | (sm==Errs3) | (sm==Errs4)) & EENA;
// error code register
if (sm==Errs0) ECD<=5'h0;																															// invalid selector
	else if (sm==Errs4) ECD<=5'h10;																												// descriptor type error
			else if ((sm==Errs1)|(sm==Errs2)|(sm==Errs3)) ECD<={1'b0, TIDReqest, CPLRequest, BadTypeRequest, LLRequest | ULRequest};	// read or write error or CPL violation or TaskID violation


// read transactions counter
if ((((LACT & LNEXT) | (NACT & NNEXT) | (SACT & SNEXT)) & CMD & ~TGO[TagWidth]) & ~IDRDY) ReadCnt<=ReadCnt+1'b1;
	else if (~(((LACT & LNEXT) | (NACT & NNEXT) | (SACT & SNEXT)) & CMD & ~TGO[TagWidth]) & IDRDY & ~ErrorBypass) ReadCnt<=ReadCnt-1'b1;

// error parameter registers
if (((sm==Errs0) | (sm==Errs1) | (sm==Errs2) | (sm==Errs3) | (sm==Errs4)))
	begin
	ETAG<=InTAG;
	ErrSize<=InSize;
	end


// read channel
IDRDY<=(~LocalEmpty | ~NetworkEmpty | ~StreamEmpty) | ((sm==Crs) & ~|ReadCnt);
if (LocalEmpty & NetworkEmpty & StreamEmpty) {ITGI, ISZI, IDTI}<={ETAG, ErrSize, 59'd0, ECD};
	else if (~LocalEmpty & ((LocalUsed>=NetworkUsed) | NetworkEmpty) & ((LocalUsed>=StreamUsed) | StreamEmpty)) {ITGI, ISZI, IDTI}<=LocalBus;
			else if (~NetworkEmpty & ((NetworkUsed>LocalUsed) | LocalEmpty) & ((NetworkUsed>=StreamUsed) | StreamEmpty)) {ITGI, ISZI, IDTI}<=NetworkBus;
					else if (~StreamEmpty & ((StreamUsed>LocalUsed) | LocalEmpty) & ((StreamUsed>NetworkUsed) | NetworkEmpty)) {ITGI, ISZI, IDTI}<=StreamBus;
// bypass violated read operation
ErrorBypass<=((sm==Crs) & ~|ReadCnt);

end

endmodule
