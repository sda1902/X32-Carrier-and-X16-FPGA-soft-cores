module VDMA4ch #(parameter TagWidth=8)(
				// global
				input wire RESETn, CLK, DTCLR,
				input wire [7:0] CPU,
				input wire [39:0] DTBASE,
				input wire [23:0] DTLIMIT,
				input wire DSELSTB,
				input wire [23:0] DSEL,
				// programming interface
				input wire CACT, CCMD,
				input wire [1:0] CADDR,
				input wire [7:0] CBE,
				input wire [63:0] CDTI,
				input wire [TagWidth-1:0] CTI,
				output reg CDRDY,
				output reg [63:0] CDTO,
				output reg [TagWidth-1:0] CTO,
				// system ISI 
				input wire LNEXT, NNEXT, SNEXT,
				output reg LACT, NACT, SACT, CMD,
				output reg [1:0] SZO,
				output reg [44:0] ADDRESS,
				output reg [31:0] SELECTOR,
				output reg [36:0] OFFSET,
				output reg [63:0] DTO,
				output reg [8:0] TGO,
				input wire LDRDY, NDRDY, SDRDY,
				input wire [63:0] LDTI, NDTI, SDTI,
				input wire [8:0] LTGI,
				input wire [7:0] NTGI, STGI,
				input wire [1:0] LSZI, NSZI, SSZI,
				// IO input channels 
				input wire [1:0] IOSIZE0, IOSIZE1, IOSIZE2, IOSIZE3,
				output wire [3:0] IOWRDY,
				input wire [3:0] IOWR, IOWLAST,
				input wire [63:0] IOWD0, IOWD1, IOWD2, IOWD3,
				// IO output channels
				input wire [3:0] IORRDY,
				output reg [3:0] IORSTB, IORSTRT, IORLAST,
				output reg [63:0] IORD0, IORD1, IORD2, IORD3
				);

/*

channel parameters
1. Channel's control
	autorestart flag
		input channel uses a special pin
		output channel uses data elements counter.
	enable cyclic transfer flag
	data size (for transfer out of system to the IO device)
	data counter for cyclic IO output or data counter of received data
	data output timer (for output data rate regulation)
	register pair selection flag
	channel selection
2. receive objects list. (Offset and Selector) It relocates in the special object. Data from the input channel puts into the objects. If a restart event occurs, data begins to be stored in the first object.
3. transmit objects list. (offset and selector) It relocates in the special object.
5. current write offset and selector
6. current read offset and selector


control register 01
[3:0]	channel number
		List pointer selection | current pointer selection 1 bit
		read / write counters selection 1 bit
		read data size 2 bits
		write data size 2 bits
		cyclic read operation 1 bit
		cyclic write operation 1 bit
		data output timer 16 bit
		channel valid flag 1 bit
read/write counter - 32 bit

control register 10
read object offset / read list offset
read object selector / read list selector

control register 11
write object offset / write list offset
write object selector / write list selector
*/


logic PairFlag, ESTB, CmdMux, SelMux, DRDY, ATUNext;
logic [1:0] SizeIN;
logic [1:0] IOSIZE [0:3];
logic [1:0] TxSize [0:3];
logic [1:0] RxSize [0:3];
logic [2:0] InByteCnt [0:3];
logic [2:0] OutByteCnt [0:3];
logic [2:0] ChanSel, ChannelReg, PrioritySel, CoderBus;
logic [3:0] InFifoEmpty, InFifoFull, InFifoWENA, CounterSelFlag, PtrSelFlag, CycleRx, Bypass, RSelReg,
				WCmdReg, WSelReg, CycleTx, RxEna='0, TxEna, WriteNext, WDRDY, RDRDY, TxReadEna, ReadNext, OutFifoRead,
				RACT, WACT, InFifoRead, RDRDY_D, WDRDY_L, OutFifoEmpty, RDRDY_L, StartFlag, LastMux;
logic [3:0] RLastReg [0:3];
logic [4:0] ECD;
logic [4:0] Tcnt [0:3];
logic [4:0] OutFifoUsed [0:3];
logic [7:0] ReqBus, TagIN, ETAG;
logic [15:0] SelInvd;
logic [15:0] TxTimer [0:3];
logic [15:0] TxTmr [0:3];
logic [28:0] RxListOffset [0:3];
logic [28:0] RxListBaseOffset [0:3];
logic [28:0] RxOffset [0:3];
logic [28:0] TxOffset [0:3];
logic [28:0] OffsetMux;
logic [28:0] ROffsetReg [0:3];
logic [28:0] WListOffset [0:3];
logic [28:0] WOffsetReg [0:3];
logic [28:0] TxListOffset [0:3];
logic [28:0] TxListBaseOffset [0:3];
logic [28:0] RListOffset [0:3];
logic [28:0] RCntr [0:3];
logic [31:0] WListSelector [0:3];
logic [31:0] RListSelector [0:3];
logic [31:0] RxSelector [0:3];
logic [31:0] TxListSelector [0:3];
logic [31:0] TxSelector [0:3];
logic [31:0] TCntr [0:3];
logic [31:0] WSelector [0:3];
logic [31:0] WOffset [0:3];
logic [31:0] RxListSelector [0:3];
logic [31:0] SELECTORS [0:15];
logic [55:0] IOWTempReg [0:3];
logic [63:0] DataMux, DataIN, NetFifoBus, StreamFifoBus, DTI;
logic [63:0] IOWD [0:3];
logic [63:0] IORD [0:3];
logic [63:0] WDataReg [0:3];
logic [64:0] InBus [0:3];
logic [64:0] InFifoBus [0:3];
logic [67:0] OutFifoBus [0:3];

enum reg [3:0] {rxws, rxrdlist0, rxrdlist1} rxsm0=rxws, rxsm1=rxws, rxsm2=rxws, rxsm3=rxws;
enum reg [3:0] {txws, txrdlist0, txrdlist1, txrd0} txsm0=txws, txsm1=txws, txsm2=txws, txsm3=txws;

integer i0, i1, i2;

assign IOWRDY=~InFifoFull;
assign IOSIZE[0]=IOSIZE0, IOSIZE[1]=IOSIZE1, IOSIZE[2]=IOSIZE2, IOSIZE[3]=IOSIZE3;
assign IOWD[0]=IOWD0, IOWD[1]=IOWD1, IOWD[2]=IOWD2, IOWD[3]=IOWD3;
assign IORD0=IORD[0], IORD1=IORD[1], IORD2=IORD[2], IORD3=IORD[3];

// data input FIFO's
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifo0 (.data(InBus[0]), .wrreq(InFifoWENA[0]), .rdreq(InFifoRead[0]), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBus[0]), .empty(InFifoEmpty[0]), .full(InFifoFull[0]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifo1 (.data(InBus[1]), .wrreq(InFifoWENA[1]), .rdreq(InFifoRead[1]), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBus[1]), .empty(InFifoEmpty[1]), .full(InFifoFull[1]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifo2 (.data(InBus[2]), .wrreq(InFifoWENA[2]), .rdreq(InFifoRead[2]), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBus[2]), .empty(InFifoEmpty[2]), .full(InFifoFull[2]), .almost_empty(), .usedw());
sc_fifo #(.LPM_WIDTH(65), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) InFifo3 (.data(InBus[3]), .wrreq(InFifoWENA[3]), .rdreq(InFifoRead[3]), .clock(CLK), .sclr(~RESETn),
																	.q(InFifoBus[3]), .empty(InFifoEmpty[3]), .full(InFifoFull[3]), .almost_empty(), .usedw());

// data output FIFO's
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifo0 (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_D[0]), .rdreq(OutFifoRead[0]), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBus[0]), .empty(OutFifoEmpty[0]), .full(), .almost_empty(), .usedw(OutFifoUsed[0]));
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifo1 (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_D[1]), .rdreq(OutFifoRead[1]), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBus[1]), .empty(OutFifoEmpty[1]), .full(), .almost_empty(), .usedw(OutFifoUsed[1]));
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifo2 (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_D[2]), .rdreq(OutFifoRead[2]), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBus[2]), .empty(OutFifoEmpty[2]), .full(), .almost_empty(), .usedw(OutFifoUsed[2]));
sc_fifo #(.LPM_WIDTH(68), .LPM_NUMWORDS(32), .LPM_WIDTHU(5)) OutFifo3 (.data({TagIN[7:4], DataIN}), .wrreq(RDRDY_D[3]), .rdreq(OutFifoRead[3]), .clock(CLK), .sclr(~RESETn),
																	.q(OutFifoBus[3]), .empty(OutFifoEmpty[3]), .full(), .almost_empty(), .usedw(OutFifoUsed[3]));


// address translation unit
ATU16ch  #(.TagWidth(8))	 ATU	(
									// global control
									.RESETn(RESETn), .CLK(CLK), .CPU(CPU), .DTBASE(DTBASE), .DTLIMIT(DTLIMIT),
									// access selectors
									.SELECTORS00(SELECTORS[00]), .SELECTORS01(SELECTORS[01]), .SELECTORS02(SELECTORS[02]), .SELECTORS03(SELECTORS[03]),
									.SELECTORS04(SELECTORS[04]), .SELECTORS05(SELECTORS[05]), .SELECTORS06(SELECTORS[06]), .SELECTORS07(SELECTORS[07]),
									.SELECTORS08(SELECTORS[08]), .SELECTORS09(SELECTORS[09]), .SELECTORS10(SELECTORS[10]), .SELECTORS11(SELECTORS[11]),
									.SELECTORS12(SELECTORS[12]), .SELECTORS13(SELECTORS[13]), .SELECTORS14(SELECTORS[14]), .SELECTORS15(SELECTORS[15]),
									.SELINVD(SelInvd),
									// ISI
									.INEXT(ATUNext), .IACT(|WACT | |RACT), .ICMD(CmdMux), .ICPLMASK(1'b1), .ITIDMASK(1'b1),
									.ISEL({ChanSel, SelMux}), .ICPL('0), .ITID('0), .IOFFSET({5'd0,OffsetMux,3'd0}), .ISZO(2'b11), .IDTO(DataMux), .ITGO({LastMux, ChanSel, SelMux}),
									.IDRDY(DRDY), .IDTI(DataIN), .ISZI(SizeIN), .ITGI(TagIN),
									// interfaces to the bus subsystem
									.LNEXT(LNEXT), .NNEXT(NNEXT), .SNEXT(SNEXT), .LACT(LACT), .NACT(NACT), .SACT(SACT), .CMD(CMD), .SZO(SZO), .ADDRESS(ADDRESS),
									.OFFSET(OFFSET), .SELECTOR(SELECTOR), .DTO(DTO), .TGO(TGO), .LDRDY(LDRDY), .NDRDY(NDRDY), .SDRDY(SDRDY),
									.LDTI(LDTI), .NDTI(NDTI), .SDTI(SDTI), .LSZI(LSZI), .NSZI(NSZI), .SSZI(SSZI), .LTGI(LTGI), .NTGI(NTGI), .STGI(STGI),
									// error report
									.EENA(1'b1), .ESTB(ESTB), .ECD(ECD), .ETAG(ETAG)
									);


always_comb
begin

// rotate priority
case (PrioritySel)
	3'b000:	ReqBus={WACT[3], WACT[2], WACT[1], WACT[0], RACT[3], RACT[2], RACT[1], RACT[0]};
	3'b001:	ReqBus={WACT[2], WACT[1], WACT[0], RACT[3], RACT[2], RACT[1], RACT[0], WACT[3]};
	3'b010:	ReqBus={WACT[1], WACT[0], RACT[3], RACT[2], RACT[1], RACT[0], WACT[3], WACT[2]};
	3'b011:	ReqBus={WACT[0], RACT[3], RACT[2], RACT[1], RACT[0], WACT[3], WACT[2], WACT[1]};
	3'b100:	ReqBus={RACT[3], RACT[2], RACT[1], RACT[0], WACT[3], WACT[2], WACT[1], WACT[0]};
	3'b101:	ReqBus={RACT[2], RACT[1], RACT[0], WACT[3], WACT[2], WACT[1], WACT[0], RACT[3]};
	3'b110:	ReqBus={RACT[1], RACT[0], WACT[3], WACT[2], WACT[1], WACT[0], RACT[3], RACT[2]};
	3'b111:	ReqBus={RACT[0], WACT[3], WACT[2], WACT[1], WACT[0], RACT[3], RACT[2], RACT[1]};
	endcase
	
// channel selection
casez (ReqBus[7:1])
	7'b0000_000:	CoderBus=3'd0;
	7'b0000_001:	CoderBus=3'd1;
	7'b0000_01?:	CoderBus=3'd2;
	7'b0000_1??:	CoderBus=3'd3;
	7'b0001_???:	CoderBus=3'd4;
	7'b001?_???:	CoderBus=3'd5;
	7'b01??_???:	CoderBus=3'd6;
	7'b1???_???:	CoderBus=3'd7;
	endcase
	
// create channel selection bus
ChanSel=CoderBus-PrioritySel;

// muxing transactions
case (ChanSel)
	3'd0:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetReg[0];
			SelMux=RSelReg[0];
			DataMux='0;
			LastMux=RLastReg[0];
			end
	3'd1:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetReg[1];
			SelMux=RSelReg[1];
			DataMux='0;
			LastMux=RLastReg[1];
			end
	3'd2:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetReg[2];
			SelMux=RSelReg[2];
			DataMux='0;
			LastMux=RLastReg[2];
			end
	3'd3:	begin
			CmdMux=1'b1;
			OffsetMux=ROffsetReg[3];
			SelMux=RSelReg[3];
			DataMux='0;
			LastMux=RLastReg[3];
			end
	3'd4:	begin
			CmdMux=WCmdReg[0];
			OffsetMux=WOffsetReg[0];
			SelMux=WSelReg[0];
			DataMux=WDataReg[0];
			LastMux='0;
			end
	3'd5:	begin
			CmdMux=WCmdReg[1];
			OffsetMux=WOffsetReg[1];
			SelMux=WSelReg[1];
			DataMux=WDataReg[1];
			LastMux='0;
			end
	3'd6:	begin
			CmdMux=WCmdReg[2];
			OffsetMux=WOffsetReg[2];
			SelMux=WSelReg[2];
			DataMux=WDataReg[2];
			LastMux='0;
			end
	3'd7:	begin
			CmdMux=WCmdReg[3];
			OffsetMux=WOffsetReg[3];
			SelMux=WSelReg[3];
			DataMux=WDataReg[3];
			LastMux='0;
			end
	endcase


// next nodes
ReadNext[0]=~RACT[0];
ReadNext[1]=~RACT[1];
ReadNext[2]=~RACT[2];
ReadNext[3]=~RACT[3];
WriteNext[0]=~WACT[0];
WriteNext[1]=~WACT[1];
WriteNext[2]=~WACT[2];
WriteNext[3]=~WACT[3];

// fifo read nodes
InFifoRead[0]=WriteNext[0] & ~InFifoEmpty[0] & RxEna[0] & |RxSelector[0] & (rxsm0!=rxrdlist0);
InFifoRead[1]=WriteNext[1] & ~InFifoEmpty[1] & RxEna[1] & |RxSelector[1] & (rxsm1!=rxrdlist0);
InFifoRead[2]=WriteNext[2] & ~InFifoEmpty[2] & RxEna[2] & |RxSelector[2] & (rxsm2!=rxrdlist0);
InFifoRead[3]=WriteNext[3] & ~InFifoEmpty[3] & RxEna[3] & |RxSelector[3] & (rxsm3!=rxrdlist0);

// data ready 
RDRDY_D[0]=DRDY & (TagIN[3:0]==4'h0);
RDRDY_L[0]=DRDY & (TagIN[3:0]==4'h1);
RDRDY_D[1]=DRDY & (TagIN[3:0]==4'h2);
RDRDY_L[1]=DRDY & (TagIN[3:0]==4'h3);
RDRDY_D[2]=DRDY & (TagIN[3:0]==4'h4);
RDRDY_L[2]=DRDY & (TagIN[3:0]==4'h5);
RDRDY_D[3]=DRDY & (TagIN[3:0]==4'h6);
RDRDY_L[3]=DRDY & (TagIN[3:0]==4'h7);

WDRDY_L[0]=DRDY & (TagIN[3:0]==4'h9);
WDRDY_L[1]=DRDY & (TagIN[3:0]==4'hB);
WDRDY_L[2]=DRDY & (TagIN[3:0]==4'hD);
WDRDY_L[3]=DRDY & (TagIN[3:0]==4'hF);

// TX request
TxReadEna[0]=((Tcnt[0]+OutFifoUsed[0])<5'd28);
TxReadEna[1]=((Tcnt[1]+OutFifoUsed[1])<5'd28);
TxReadEna[2]=((Tcnt[2]+OutFifoUsed[2])<5'd28);
TxReadEna[3]=((Tcnt[3]+OutFifoUsed[3])<5'd28);

// read output queue 
for (i2=0; i2<4; i2=i2+1)
	if (~(IORRDY[i2] & ~OutFifoEmpty[i2] & ~|TxTmr[i2])) OutFifoRead[i2]='0;
		else if (IORRDY[i2] & ~OutFifoEmpty[i2] & ~|TxTmr[i2])
				begin case (TxSize[i2])
							2'b00:	OutFifoRead[i2]=OutFifoBus[i2][67] ? (OutFifoBus[i2][66:64]==(OutByteCnt[i2]+1'b1)) : &OutByteCnt[i2];
							2'b01:	OutFifoRead[i2]=OutFifoBus[i2][67] ? (OutFifoBus[i2][66:65]==(OutByteCnt[i2][2:1]+1'b1)) : &OutByteCnt[i2][2:1];
							2'b10:	OutFifoRead[i2]=OutFifoBus[i2][67] ? (OutFifoBus[i2][66]==(~OutByteCnt[i2][2])) : OutByteCnt[i2][2];
							2'b11:	OutFifoRead[i2]=1'b1;
							endcase
				end
				else OutFifoRead[i2]='0;

end



always_ff @(posedge CLK or negedge RESETn)
if (~RESETn)
	begin
	InFifoWENA<='0;
	InByteCnt[0]<='0;
	InByteCnt[1]<='0;
	InByteCnt[2]<='0;
	InByteCnt[3]<='0;
	CDRDY<='0;
	Bypass<='0;
	PrioritySel<='0;
	RACT<='0;
	WACT<='0;
	RxEna<='0;
	TxEna<='0;
	RxSelector[0]<='0;
	RxSelector[1]<='0;
	RxSelector[2]<='0;
	RxSelector[3]<='0;
	TxSelector[0]<='0;
	TxSelector[1]<='0;
	TxSelector[2]<='0;
	TxSelector[3]<='0;
	RCntr[0]<='0;
	RCntr[1]<='0;
	RCntr[2]<='0;
	RCntr[3]<='0;
	TCntr[0]<='0;
	TCntr[1]<='0;
	TCntr[2]<='0;
	TCntr[3]<='0;
	SelInvd<='0;
	Tcnt[0]<='0;
	Tcnt[1]<='0;
	Tcnt[2]<='0;
	Tcnt[3]<='0;
	StartFlag<='0;
	IORSTB<='0;
	IORSTRT<='0;
	IORLAST<='0;
	end
else begin

// read transaction counters
if (ATUNext & (ChanSel==3'd0) & RACT[0] & ~SelMux & ~RDRDY_D[0] & ~&Tcnt[0]) Tcnt[0]<=Tcnt[0]+1'b1;
	else if (RDRDY_D[0] & ~(ATUNext & (ChanSel==3'd0) & RACT[0] & ~SelMux) & |Tcnt[0]) Tcnt[0]<=Tcnt[0]-1'b1;
if (ATUNext & (ChanSel==3'd1) & RACT[1] & ~SelMux & ~RDRDY_D[1] & ~&Tcnt[1]) Tcnt[1]<=Tcnt[1]+1'b1;
	else if (RDRDY_D[1] & ~(ATUNext & (ChanSel==3'd1) & RACT[1] & ~SelMux) & |Tcnt[1]) Tcnt[1]<=Tcnt[1]-1'b1;
if (ATUNext & (ChanSel==3'd2) & RACT[2] & ~SelMux & ~RDRDY_D[2] & ~&Tcnt[2]) Tcnt[2]<=Tcnt[2]+1'b1;
	else if (RDRDY_D[2] & ~(ATUNext & (ChanSel==3'd2) & RACT[2] & ~SelMux) & |Tcnt[2]) Tcnt[2]<=Tcnt[2]-1'b1;
if (ATUNext & (ChanSel==3'd3) & RACT[3] & ~SelMux & ~RDRDY_D[3] & ~&Tcnt[3]) Tcnt[3]<=Tcnt[3]+1'b1;
	else if (RDRDY_D[3] & ~(ATUNext & (ChanSel==3'd3) & RACT[3] & ~SelMux) & |Tcnt[3]) Tcnt[3]<=Tcnt[3]-1'b1;





// cahhnel's priority rotation
if ((|WACT | |RACT) & ATUNext) PrioritySel<=PrioritySel+1'b1;

// data reading on programming interface
CDRDY<=CACT & CCMD & |CADDR;
CTO<=CTI;

if (IOWR[0]) RxSize[0]<=IOSIZE0;
if (IOWR[1]) RxSize[1]<=IOSIZE1;
if (IOWR[2]) RxSize[2]<=IOSIZE2;
if (IOWR[3]) RxSize[3]<=IOSIZE3;

casez ({CADDR, ChannelReg})
	5'b00_???:	CDTO<='0;
	// control register group                   [63:32]         [31:16]    [15:14]    [13:12]      [11]         [10]         [09]            [08]            [07:00]
	5'b01_000: CDTO<={CounterSelFlag[0] ? TCntr[0] : {RCntr[0], 3'd0}, TxTimer[0], TxSize[0], RxSize[0], CycleTx[0], CycleRx[0], PtrSelFlag[0], CounterSelFlag[0], 4'd8, 4'd0};
	5'b01_001: CDTO<={CounterSelFlag[1] ? TCntr[1] : {RCntr[1], 3'd0}, TxTimer[1], TxSize[1], RxSize[1], CycleTx[1], CycleRx[1], PtrSelFlag[1], CounterSelFlag[1], 4'd8, 4'd1};
	5'b01_010: CDTO<={CounterSelFlag[2] ? TCntr[2] : {RCntr[2], 3'd0}, TxTimer[2], TxSize[2], RxSize[2], CycleTx[2], CycleRx[2], PtrSelFlag[2], CounterSelFlag[2], 4'd8, 4'd2};
	5'b01_011: CDTO<={CounterSelFlag[3] ? TCntr[3] : {RCntr[3], 3'd0}, TxTimer[3], TxSize[3], RxSize[3], CycleTx[3], CycleRx[3], PtrSelFlag[3], CounterSelFlag[3], 4'd8, 4'd3};
	5'b01_1??: CDTO<='0;
	// read selectors and offsets
	5'b10_000: CDTO<=PtrSelFlag[0] ? {RxListSelector[0], RxListOffset[0], 1'b0, Bypass[0], RxEna[0]} : {RxSelector[0],RxOffset[0],3'd0};
	5'b10_001: CDTO<=PtrSelFlag[1] ? {RxListSelector[1], RxListOffset[1], 1'b0, Bypass[1], RxEna[1]} : {RxSelector[1],RxOffset[1],3'd0};
	5'b10_010: CDTO<=PtrSelFlag[2] ? {RxListSelector[2], RxListOffset[2], 1'b0, Bypass[2], RxEna[2]} : {RxSelector[2],RxOffset[2],3'd0};
	5'b10_011: CDTO<=PtrSelFlag[3] ? {RxListSelector[3], RxListOffset[3], 1'b0, Bypass[3], RxEna[3]} : {RxSelector[3],RxOffset[3],3'd0};
	5'b10_1??: CDTO<='0;
	// write selectors and offsets
	7'b11_000: CDTO<=PtrSelFlag[0] ? {TxListSelector[0], TxListOffset[0], 2'd0, TxEna[0]} : {TxSelector[0],TxOffset[0],3'd0};
	7'b11_001: CDTO<=PtrSelFlag[1] ? {TxListSelector[1], TxListOffset[1], 2'd0, TxEna[1]} : {TxSelector[1],TxOffset[1],3'd0};
	7'b11_010: CDTO<=PtrSelFlag[2] ? {TxListSelector[2], TxListOffset[2], 2'd0, TxEna[2]} : {TxSelector[2],TxOffset[2],3'd0};
	7'b11_011: CDTO<=PtrSelFlag[3] ? {TxListSelector[3], TxListOffset[3], 2'd0, TxEna[3]} : {TxSelector[3],TxOffset[3],3'd0};
	7'b11_1??: CDTO<='0;
	endcase

// channel selection register
if (CACT & ~CCMD & (CADDR==2'd1) & ~CBE[0]) ChannelReg<={|CDTI[6:2], CDTI[1:0]};

// write to the control fields and address registers
if (CACT & ~CCMD & (CADDR==2'd1) & ~ChannelReg[2] & ~CBE[1])
	begin
	CounterSelFlag[ChannelReg[1:0]]<=CDTI[08];
	PtrSelFlag[ChannelReg[1:0]]<=CDTI[09];
	CycleRx[ChannelReg[1:0]]<=CDTI[10];
	CycleTx[ChannelReg[1:0]]<=CDTI[11];
	TxSize[ChannelReg[1:0]]<=CDTI[15:14];
	end

// transmit timers
if (CACT & ~CCMD & (CADDR==2'd1) & ~ChannelReg[2] & ~CBE[2]) TxTimer[ChannelReg[1:0]][7:0]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd1) & ~ChannelReg[2] & ~CBE[3]) TxTimer[ChannelReg[1:0]][15:8]<=CDTI[31:24];

// current RX offset
if (WDRDY_L[0]) RxOffset[0]<='0;
	else if (InFifoRead[0]) RxOffset[0]<=RxOffset[0]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[0]) RxOffset[0][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[1]) RxOffset[0][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[2]) RxOffset[0][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[3]) RxOffset[0][28:21]<=CDTI[31:24];
			end
if (WDRDY_L[1]) RxOffset[1]<='0;
	else if (InFifoRead[1]) RxOffset[1]<=RxOffset[1]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[0]) RxOffset[1][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[1]) RxOffset[1][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[2]) RxOffset[1][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[3]) RxOffset[1][28:21]<=CDTI[31:24];
			end
if (WDRDY_L[2]) RxOffset[2]<='0;
	else if (InFifoRead[2]) RxOffset[2]<=RxOffset[2]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[0]) RxOffset[2][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[1]) RxOffset[2][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[2]) RxOffset[2][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[3]) RxOffset[2][28:21]<=CDTI[31:24];
			end
if (WDRDY_L[3]) RxOffset[3]<='0;
	else if (InFifoRead[3]) RxOffset[3]<=RxOffset[3]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[0]) RxOffset[3][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[1]) RxOffset[3][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[2]) RxOffset[3][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[3]) RxOffset[3][28:21]<=CDTI[31:24];
			end

// current RX counter
if (WDRDY_L[0]) RCntr[0]<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd4) & WACT[0] & |RCntr[0] & ~WSelReg[0]) RCntr[0]<=RCntr[0]-1'b1;
			else begin
			if (~CounterSelFlag[0] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[4]) RCntr[0][04:00]<=CDTI[39:35];
			if (~CounterSelFlag[0] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[5]) RCntr[0][12:05]<=CDTI[47:40];
			if (~CounterSelFlag[0] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[6]) RCntr[0][20:13]<=CDTI[55:48];
			if (~CounterSelFlag[0] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & ~CBE[7]) RCntr[0][28:21]<=CDTI[63:56];
			end
if (WDRDY_L[1]) RCntr[1]<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd5) & WACT[1] & |RCntr[1] & ~WSelReg[1]) RCntr[1]<=RCntr[1]-1'b1;
			else begin
			if (~CounterSelFlag[1] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[4]) RCntr[1][04:00]<=CDTI[39:35];
			if (~CounterSelFlag[1] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[5]) RCntr[1][12:05]<=CDTI[47:40];
			if (~CounterSelFlag[1] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[6]) RCntr[1][20:13]<=CDTI[55:48];
			if (~CounterSelFlag[1] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & ~CBE[7]) RCntr[1][28:21]<=CDTI[63:56];
			end
if (WDRDY_L[2]) RCntr[2]<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd6) & WACT[2] & |RCntr[2] & ~WSelReg[2]) RCntr[2]<=RCntr[2]-1'b1;
			else begin
			if (~CounterSelFlag[2] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[4]) RCntr[2][04:00]<=CDTI[39:35];
			if (~CounterSelFlag[2] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[5]) RCntr[2][12:05]<=CDTI[47:40];
			if (~CounterSelFlag[2] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[6]) RCntr[2][20:13]<=CDTI[55:48];
			if (~CounterSelFlag[2] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & ~CBE[7]) RCntr[2][28:21]<=CDTI[63:56];
			end
if (WDRDY_L[3]) RCntr[3]<=DataIN[31:03];
	else if (ATUNext & (ChanSel==3'd7) & WACT[3] & |RCntr[3] & ~WSelReg[3]) RCntr[3]<=RCntr[3]-1'b1;
			else begin
			if (~CounterSelFlag[3] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[4]) RCntr[3][04:00]<=CDTI[39:35];
			if (~CounterSelFlag[3] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[5]) RCntr[3][12:05]<=CDTI[47:40];
			if (~CounterSelFlag[3] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[6]) RCntr[3][20:13]<=CDTI[55:48];
			if (~CounterSelFlag[3] & CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & ~CBE[7]) RCntr[3][28:21]<=CDTI[63:56];
			end

// current RX selector
if (WDRDY_L[0]) RxSelector[0]<=DataIN[63:32];
	else if ((ATUNext & (ChanSel==3'd4) & WACT[0] & ~|RCntr[0][28:1] & ~WSelReg[0])|(InFifoRead[0] & InFifoBus[0][64])) RxSelector[0]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[4]) RxSelector[0][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[5]) RxSelector[0][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[6]) RxSelector[0][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[7]) RxSelector[0][31:24]<=CDTI[63:56];
			end
if (WDRDY_L[1]) RxSelector[1]<=DataIN[63:32];
	else if ((ATUNext & (ChanSel==3'd5) & WACT[1] & ~|RCntr[1][28:1] & ~WSelReg[1])|(InFifoRead[1] & InFifoBus[1][64])) RxSelector[1]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[4]) RxSelector[1][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[5]) RxSelector[1][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[6]) RxSelector[1][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[7]) RxSelector[1][31:24]<=CDTI[63:56];
			end
if (WDRDY_L[2]) RxSelector[2]<=DataIN[63:32];
	else if ((ATUNext & (ChanSel==3'd6) & WACT[2] & ~|RCntr[2][28:1] & ~WSelReg[2])|(InFifoRead[2] & InFifoBus[2][64])) RxSelector[2]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[4]) RxSelector[2][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[5]) RxSelector[2][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[6]) RxSelector[2][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[7]) RxSelector[2][31:24]<=CDTI[63:56];
			end
if (WDRDY_L[3]) RxSelector[3]<=DataIN[63:32];
	else if ((ATUNext & (ChanSel==3'd7) & WACT[3] & ~|RCntr[3][28:1] & ~WSelReg[3])|(InFifoRead[3] & InFifoBus[3][64])) RxSelector[3]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[4]) RxSelector[3][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[5]) RxSelector[3][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[6]) RxSelector[3][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[7]) RxSelector[3][31:24]<=CDTI[63:56];
			end

// RX list offset and control flags
if ((ESTB & (ETAG[3:1]==3'd4))|(WDRDY_L[0] & ~|DataIN[63:32])) RxEna[0]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[0]) RxEna[0]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd5))|(WDRDY_L[1] & ~|DataIN[63:32])) RxEna[1]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[0]) RxEna[1]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd6))|(WDRDY_L[2] & ~|DataIN[63:32])) RxEna[2]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[0]) RxEna[2]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd7))|(WDRDY_L[3] & ~|DataIN[63:32])) RxEna[3]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[0]) RxEna[3]<=CDTI[0];
	
if (CACT & ~CCMD & (CADDR==2'd2) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[0]) Bypass[ChannelReg[1:0]]<=CDTI[1];

if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[ChannelReg[1:0]] & ~ChannelReg[2] & ~CBE[0]) RxListBaseOffset[ChannelReg[1:0]][04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[ChannelReg[1:0]] & ~ChannelReg[2] & ~CBE[1]) RxListBaseOffset[ChannelReg[1:0]][12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[ChannelReg[1:0]] & ~ChannelReg[2] & ~CBE[2]) RxListBaseOffset[ChannelReg[1:0]][20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[ChannelReg[1:0]] & ~ChannelReg[2] & ~CBE[3]) RxListBaseOffset[ChannelReg[1:0]][28:21]<=CDTI[31:24];

if ((rxsm0==rxrdlist0) & WriteNext[0]) RxListOffset[0]<=RxListOffset[0]+1'b1;
	else if (InFifoRead[0] & InFifoBus[0][64]) RxListOffset[0]<=RxListBaseOffset[0];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[0]) RxListOffset[0][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[1]) RxListOffset[0][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[2]) RxListOffset[0][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[3]) RxListOffset[0][28:21]<=CDTI[31:24];
			end
if ((rxsm1==rxrdlist0) & WriteNext[1]) RxListOffset[1]<=RxListOffset[1]+1'b1;
	else if (InFifoRead[1] & InFifoBus[1][64]) RxListOffset[1]<=RxListBaseOffset[1];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[0]) RxListOffset[1][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[1]) RxListOffset[1][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[2]) RxListOffset[1][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[3]) RxListOffset[1][28:21]<=CDTI[31:24];
			end
if ((rxsm2==rxrdlist0) & WriteNext[2]) RxListOffset[2]<=RxListOffset[2]+1'b1;
	else if (InFifoRead[2] & InFifoBus[2][64]) RxListOffset[2]<=RxListBaseOffset[2];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[0]) RxListOffset[2][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[1]) RxListOffset[2][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[2]) RxListOffset[2][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[3]) RxListOffset[2][28:21]<=CDTI[31:24];
			end
if ((rxsm3==rxrdlist0) & WriteNext[3]) RxListOffset[3]<=RxListOffset[3]+1'b1;
	else if (InFifoRead[3] & InFifoBus[3][64]) RxListOffset[3]<=RxListBaseOffset[3];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[0]) RxListOffset[3][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[1]) RxListOffset[3][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[2]) RxListOffset[3][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[3]) RxListOffset[3][28:21]<=CDTI[31:24];
			end

// RX list selector
if (CACT & ~CCMD & (CADDR==2'd2) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[4]) RxListSelector[ChannelReg[1:0]][07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd2) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[5]) RxListSelector[ChannelReg[1:0]][15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd2) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[6]) RxListSelector[ChannelReg[1:0]][23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd2) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[7]) RxListSelector[ChannelReg[1:0]][31:24]<=CDTI[63:56];

// current TX offset 
if (RDRDY_L[0]) TxOffset[0]<='0;
	else if ((txsm0==txrd0) & ReadNext[0]) TxOffset[0]<=TxOffset[0]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[0]) TxOffset[0][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[1]) TxOffset[0][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[2]) TxOffset[0][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[3]) TxOffset[0][28:21]<=CDTI[31:24];
			end
if (RDRDY_L[1]) TxOffset[1]<='0;
	else if ((txsm1==txrd0) & ReadNext[1]) TxOffset[1]<=TxOffset[1]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[0]) TxOffset[1][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[1]) TxOffset[1][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[2]) TxOffset[1][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[3]) TxOffset[1][28:21]<=CDTI[31:24];
			end
if (RDRDY_L[2]) TxOffset[2]<='0;
	else if ((txsm2==txrd0) & ReadNext[2]) TxOffset[2]<=TxOffset[2]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[0]) TxOffset[2][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[1]) TxOffset[2][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[2]) TxOffset[2][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[3]) TxOffset[2][28:21]<=CDTI[31:24];
			end
if (RDRDY_L[3]) TxOffset[3]<='0;
	else if ((txsm3==txrd0) & ReadNext[3]) TxOffset[3]<=TxOffset[3]+1'b1;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[0]) TxOffset[3][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[1]) TxOffset[3][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[2]) TxOffset[3][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[3]) TxOffset[3][28:21]<=CDTI[31:24];
			end

// transmit counter
if (RDRDY_L[0]) TCntr[0]<=DataIN[31:00];
	else if ((txsm0==txrd0) & ReadNext[0]) TCntr[0]<=|TCntr[0][31:3] ? TCntr[0]-4'b1000 : '0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlag[0] & ~CBE[4]) TCntr[0][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlag[0] & ~CBE[5]) TCntr[0][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlag[0] & ~CBE[6]) TCntr[0][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd0) & CounterSelFlag[0] & ~CBE[7]) TCntr[0][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[1]) TCntr[1]<=DataIN[31:00];
	else if ((txsm1==txrd0) & ReadNext[1]) TCntr[1]<=|TCntr[1][31:3] ? TCntr[1]-4'b1000 : '0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlag[1] & ~CBE[4]) TCntr[1][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlag[1] & ~CBE[5]) TCntr[1][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlag[1] & ~CBE[6]) TCntr[1][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd1) & CounterSelFlag[1] & ~CBE[7]) TCntr[1][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[2]) TCntr[2]<=DataIN[31:00];
	else if ((txsm2==txrd0) & ReadNext[2]) TCntr[2]<=|TCntr[2][31:3] ? TCntr[2]-4'b1000 : '0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlag[2] & ~CBE[4]) TCntr[2][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlag[2] & ~CBE[5]) TCntr[2][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlag[2] & ~CBE[6]) TCntr[2][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd2) & CounterSelFlag[2] & ~CBE[7]) TCntr[2][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[3]) TCntr[3]<=DataIN[31:00];
	else if ((txsm3==txrd0) & ReadNext[3]) TCntr[3]<=|TCntr[3][31:3] ? TCntr[3]-4'b1000 : '0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlag[3] & ~CBE[4]) TCntr[3][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlag[3] & ~CBE[5]) TCntr[3][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlag[3] & ~CBE[6]) TCntr[3][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd1) & (ChannelReg==3'd3) & CounterSelFlag[3] & ~CBE[7]) TCntr[3][31:24]<=CDTI[63:56];
			end

// current TX selector
if (RDRDY_L[0]) TxSelector[0]<=DataIN[63:32];
	else if ((txsm0==txrd0) & ReadNext[0] & (~|TCntr[0][31:3] | (TCntr[0]==32'd8))) TxSelector[0]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[4]) TxSelector[0][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[5]) TxSelector[0][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[6]) TxSelector[0][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & ~PtrSelFlag[0] & ~CBE[7]) TxSelector[0][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[1]) TxSelector[1]<=DataIN[63:32];
	else if ((txsm1==txrd0) & ReadNext[1] & (~|TCntr[1][31:3] | (TCntr[1]==32'd8))) TxSelector[1]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[4]) TxSelector[1][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[5]) TxSelector[1][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[6]) TxSelector[1][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & ~PtrSelFlag[1] & ~CBE[7]) TxSelector[1][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[2]) TxSelector[2]<=DataIN[63:32];
	else if ((txsm2==txrd0) & ReadNext[2] & (~|TCntr[2][31:3] | (TCntr[2]==32'd8))) TxSelector[2]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[4]) TxSelector[2][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[5]) TxSelector[2][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[6]) TxSelector[2][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & ~PtrSelFlag[2] & ~CBE[7]) TxSelector[2][31:24]<=CDTI[63:56];
			end
if (RDRDY_L[3]) TxSelector[3]<=DataIN[63:32];
	else if ((txsm3==txrd0) & ReadNext[3] & (~|TCntr[3][31:3] | (TCntr[3]==32'd8))) TxSelector[3]<='0;
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[4]) TxSelector[3][07:00]<=CDTI[39:32];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[5]) TxSelector[3][15:08]<=CDTI[47:40];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[6]) TxSelector[3][23:16]<=CDTI[55:48];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & ~PtrSelFlag[3] & ~CBE[7]) TxSelector[3][31:24]<=CDTI[63:56];
			end

// TX list offset and enable flag
if ((ESTB & (ETAG[3:1]==3'd0))|(RDRDY_L[0] & ~|DataIN[63:32] & ~CycleTx[0])) TxEna[0]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~CBE[0]) TxEna[0]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd1))|(RDRDY_L[1] & ~|DataIN[63:32] & ~CycleTx[1])) TxEna[1]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~CBE[0]) TxEna[1]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd2))|(RDRDY_L[2] & ~|DataIN[63:32] & ~CycleTx[2])) TxEna[2]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~CBE[0]) TxEna[2]<=CDTI[0];
if ((ESTB & (ETAG[3:1]==3'd3))|(RDRDY_L[3] & ~|DataIN[63:32] & ~CycleTx[3])) TxEna[3]<='0;
	else if (CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~CBE[0]) TxEna[3]<=CDTI[0];

if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[0]) TxListBaseOffset[ChannelReg[1:0]][04:00]<=CDTI[07:03];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[1]) TxListBaseOffset[ChannelReg[1:0]][12:05]<=CDTI[15:08];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[2]) TxListBaseOffset[ChannelReg[1:0]][20:13]<=CDTI[23:16];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[3]) TxListBaseOffset[ChannelReg[1:0]][28:21]<=CDTI[31:24];

if ((txsm0==txrdlist0) & ReadNext[0]) TxListOffset[0]<=TxListOffset[0]+1'b1;
	else if (RDRDY_L[0] & ~|DataIN[63:32]) TxListOffset[0]<=TxListBaseOffset[0];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlag[0] & ~CBE[0]) TxListOffset[0][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlag[0] & ~CBE[1]) TxListOffset[0][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlag[0] & ~CBE[2]) TxListOffset[0][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd0) & PtrSelFlag[0] & ~CBE[3]) TxListOffset[0][28:21]<=CDTI[31:24];
			end
if ((txsm1==txrdlist0) & ReadNext[1]) TxListOffset[1]<=TxListOffset[1]+1'b1;
	else if (RDRDY_L[1] & ~|DataIN[63:32]) TxListOffset[1]<=TxListBaseOffset[1];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlag[1] & ~CBE[0]) TxListOffset[1][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlag[1] & ~CBE[1]) TxListOffset[1][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlag[1] & ~CBE[2]) TxListOffset[1][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd1) & PtrSelFlag[1] & ~CBE[3]) TxListOffset[1][28:21]<=CDTI[31:24];
			end
if ((txsm2==txrdlist0) & ReadNext[2]) TxListOffset[2]<=TxListOffset[2]+1'b1;
	else if (RDRDY_L[2] & ~|DataIN[63:32]) TxListOffset[2]<=TxListBaseOffset[2];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlag[2] & ~CBE[0]) TxListOffset[2][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlag[2] & ~CBE[1]) TxListOffset[2][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlag[2] & ~CBE[2]) TxListOffset[2][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd2) & PtrSelFlag[2] & ~CBE[3]) TxListOffset[2][28:21]<=CDTI[31:24];
			end
if ((txsm3==txrdlist0) & ReadNext[3]) TxListOffset[3]<=TxListOffset[3]+1'b1;
	else if (RDRDY_L[3] & ~|DataIN[63:32]) TxListOffset[3]<=TxListBaseOffset[3];
			else begin
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlag[3] & ~CBE[0]) TxListOffset[3][04:00]<=CDTI[07:03];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlag[3] & ~CBE[1]) TxListOffset[3][12:05]<=CDTI[15:08];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlag[3] & ~CBE[2]) TxListOffset[3][20:13]<=CDTI[23:16];
			if (CACT & ~CCMD & (CADDR==2'd3) & (ChannelReg==3'd3) & PtrSelFlag[3] & ~CBE[3]) TxListOffset[3][28:21]<=CDTI[31:24];
			end

// TX list selector
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[4]) TxListSelector[ChannelReg[1:0]][07:00]<=CDTI[39:32];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[5]) TxListSelector[ChannelReg[1:0]][15:08]<=CDTI[47:40];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[6]) TxListSelector[ChannelReg[1:0]][23:16]<=CDTI[55:48];
if (CACT & ~CCMD & (CADDR==2'd3) & ~ChannelReg[2] & PtrSelFlag[ChannelReg[1:0]] & ~CBE[7]) TxListSelector[ChannelReg[1:0]][31:24]<=CDTI[63:56];


// selectors invalidation in the ATU
SelInvd[00]<=RDRDY_L[0] | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~&CBE[7:4]);
SelInvd[01]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~&CBE[7:4];
SelInvd[02]<=RDRDY_L[1] | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~&CBE[7:4]);
SelInvd[03]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~&CBE[7:4];
SelInvd[04]<=RDRDY_L[2] | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~&CBE[7:4]);
SelInvd[05]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~&CBE[7:4];
SelInvd[06]<=RDRDY_L[3] | (CACT & ~CCMD & (CADDR==2'd3) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~&CBE[7:4]);
SelInvd[07]<=CACT & ~CCMD & (CADDR==2'd3) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~&CBE[7:4];
SelInvd[08]<=WDRDY_L[0] | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[0] & (ChannelReg==3'd0) & ~&CBE[7:4]);
SelInvd[09]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[0] & (ChannelReg==3'd0) & ~&CBE[7:4];
SelInvd[10]<=WDRDY_L[1] | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[1] & (ChannelReg==3'd1) & ~&CBE[7:4]);
SelInvd[11]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[1] & (ChannelReg==3'd1) & ~&CBE[7:4];
SelInvd[12]<=WDRDY_L[2] | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[2] & (ChannelReg==3'd2) & ~&CBE[7:4]);
SelInvd[13]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[2] & (ChannelReg==3'd2) & ~&CBE[7:4];
SelInvd[14]<=WDRDY_L[3] | (CACT & ~CCMD & (CADDR==2'd2) & ~PtrSelFlag[3] & (ChannelReg==3'd3) & ~&CBE[7:4]);
SelInvd[15]<=CACT & ~CCMD & (CADDR==2'd2) & PtrSelFlag[3] & (ChannelReg==3'd3) & ~&CBE[7:4];


// input data from io buses
for (i0=0; i0<4; i0=i0+1)
casez ({Bypass[i0] ? TxSize[i0] : IOSIZE[i0], InByteCnt[i0]})
	// byte data
	5'b00_000:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 56'h000000_00000000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][7:0]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_001:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 48'h0000_00000000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][7:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][15:8]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_010:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 40'h00_00000000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][15:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][23:16]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_011:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 32'h00000000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][23:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][31:24]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_100:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 24'h000000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][31:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][39:32]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_101:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 16'h0000, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][39:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][47:40]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_110:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 8'h00, Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][47:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][55:48]<=Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0];
				end
	5'b00_111:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], Bypass[i0] ? IORD[i0][7:0] : IOWD[i0][7:0], IOWTempReg[i0][55:0]};
				InFifoWENA[i0]<=Bypass[i0] ? IORSTB[i0] : IOWR[i0];
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+1'b1)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+1'b1)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				end
	// word data
	5'b01_00?:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 48'h0000_00000000, Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+2'b10)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+2'b10)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][15:0]<=Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0];
				end
	5'b01_01?:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 32'h00000000, Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0], IOWTempReg[i0][15:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+2'b10)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+2'b10)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][31:16]<=Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0];
				end
	5'b01_10?:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 16'h0000, Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0], IOWTempReg[i0][31:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+2'b10)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+2'b10)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][47:32]<=Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0];
				end
	5'b01_11?:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], Bypass[i0] ? IORD[i0][15:0] : IOWD[i0][15:0], IOWTempReg[i0][47:0]};
				InFifoWENA[i0]<=Bypass[i0] ? IORSTB[i0] : IOWR[i0];
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+2'b10)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+2'b10)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				end
	// dword data
	5'b10_0??:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], 32'h00000000, Bypass[i0] ? IORD[i0][31:0] : IOWD[i0][31:0]};
				InFifoWENA[i0]<=Bypass[i0] ? (IORSTB[i0] & IORLAST[i0]):(IOWR[i0] & IOWLAST[i0]);
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+3'b100)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+3'b100)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				IOWTempReg[i0][31:0]<=Bypass[i0] ? IORD[i0][31:0] : IOWD[i0][31:0];
				end
	5'b10_1??:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], Bypass[i0] ? IORD[i0][31:0] : IOWD[i0][31:0],IOWTempReg[i0][31:0]};
				InFifoWENA[i0]<=Bypass[i0] ? IORSTB[i0]:IOWR[i0];
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? (InByteCnt[i0]+3'b100)&{3{~IORLAST[i0]}} : InByteCnt[i0]) : (IOWR[i0] ? (InByteCnt[i0]+3'b100)&{3{~IOWLAST[i0]}} : InByteCnt[i0]);
				end
	// qword data
	5'b11_???:	begin
				InBus[i0]<={Bypass[i0] ? 1'b0 : IOWLAST[i0], Bypass[i0] ? IORD[i0] : IOWD[i0]};
				InFifoWENA[i0]<=Bypass[i0] ? IORSTB[i0]:IOWR[i0];
				InByteCnt[i0]<=Bypass[i0] ? (IORSTB[i0] ? 3'd0 : InByteCnt[i0]) : (IOWR[i0] ? 3'd0 : InByteCnt[i0]);
				end
	endcase


/*

Receiving machines

*/
case (rxsm0)
	rxws:			if (~InFifoEmpty[0] & RxEna[0] & ~|RxSelector[0] & |RxListSelector[0]) rxsm0<=rxrdlist0;
						else rxsm0<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNext[0]) rxsm0<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_L[0]) rxsm0<=rxws;
						else rxsm0<=rxrdlist1;
	endcase

case (rxsm1)
	rxws:			if (~InFifoEmpty[1] & RxEna[1] & ~|RxSelector[1] & |RxListSelector[1]) rxsm1<=rxrdlist0;
						else rxsm1<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNext[1]) rxsm1<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_L[1]) rxsm1<=rxws;
						else rxsm1<=rxrdlist1;
	endcase

case (rxsm2)
	rxws:			if (~InFifoEmpty[2] & RxEna[2] & ~|RxSelector[2] & |RxListSelector[2]) rxsm2<=rxrdlist0;
						else rxsm2<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNext[2]) rxsm2<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_L[2]) rxsm2<=rxws;
						else rxsm2<=rxrdlist1;
	endcase

case (rxsm3)
	rxws:			if (~InFifoEmpty[3] & RxEna[3] & ~|RxSelector[3] & |RxListSelector[3]) rxsm3<=rxrdlist0;
						else rxsm3<=rxws;
	// reading object's list
	rxrdlist0:		if (WriteNext[3]) rxsm3<=rxrdlist1;
	// waiting for a new object selector
	rxrdlist1:		if (WDRDY_L[3]) rxsm3<=rxws;
						else rxsm3<=rxrdlist1;
	endcase

/*

Transmitting machines

*/
case (txsm0)
	txws:			if (~TxEna[0]) txsm0<=txws;
						else if (~|TxSelector[0] & |TxListSelector[0] & OutFifoEmpty[0] & ~|Tcnt[0]) txsm0<=txrdlist0;
								else if (|TxSelector[0] & |TCntr[0] & TxReadEna[0]) txsm0<=txrd0;
										else txsm0<=txws;
	// read objects list
	txrdlist0:		if (ReadNext[0]) txsm0<=txrdlist1;
						else txsm0<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_L[0]) txsm0<=txrdlist1;
						else txsm0<=txws;
	// reading data from memory
	txrd0:			if (ReadNext[0]) txsm0<=txws;
						else txsm0<=txrd0;
	endcase

case (txsm1)
	txws:			if (~TxEna[1]) txsm1<=txws;
						else if (~|TxSelector[1] & |TxListSelector[1] & OutFifoEmpty[1] & ~|Tcnt[1]) txsm1<=txrdlist0;
								else if (|TxSelector[1] & |TCntr[1] & TxReadEna[1]) txsm1<=txrd0;
										else txsm1<=txws;
	// read objects list
	txrdlist0:		if (ReadNext[1]) txsm1<=txrdlist1;
						else txsm1<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_L[1]) txsm1<=txrdlist1;
						else txsm1<=txws;
	// reading data from memory
	txrd0:			if (ReadNext[1]) txsm1<=txws;
						else txsm1<=txrd0;
	endcase

case (txsm2)
	txws:			if (~TxEna[2]) txsm2<=txws;
						else if (~|TxSelector[2] & |TxListSelector[2] & OutFifoEmpty[2] & ~|Tcnt[2]) txsm2<=txrdlist0;
								else if (|TxSelector[2] & |TCntr[2] & TxReadEna[2]) txsm2<=txrd0;
										else txsm2<=txws;
	// read objects list
	txrdlist0:		if (ReadNext[2]) txsm2<=txrdlist1;
						else txsm2<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_L[2]) txsm2<=txrdlist1;
						else txsm2<=txws;
	// reading data from memory
	txrd0:			if (ReadNext[2]) txsm2<=txws;
						else txsm2<=txrd0;
	endcase

case (txsm3)
	txws:			if (~TxEna[3]) txsm3<=txws;
						else if (~|TxSelector[3] & |TxListSelector[3] & OutFifoEmpty[3] & ~|Tcnt[3]) txsm3<=txrdlist0;
								else if (|TxSelector[3] & |TCntr[3] & TxReadEna[3]) txsm3<=txrd0;
										else txsm3<=txws;
	// read objects list
	txrdlist0:		if (ReadNext[3]) txsm3<=txrdlist1;
						else txsm3<=txrdlist0;
	// waiting for a new object selector
	txrdlist1:		if (~RDRDY_L[3]) txsm3<=txrdlist1;
						else txsm3<=txws;
	// reading data from memory
	txrd0:			if (ReadNext[3]) txsm3<=txws;
						else txsm3<=txrd0;
	endcase

		
		
		
		

/*

read memory channels

*/
RACT[0]<=(RACT[0] | (txsm0==txrdlist0) | (txsm0==txrd0)) & ~(ATUNext & (ChanSel==3'd0) & RACT[0]);
if (ReadNext[0])
	begin
	ROffsetReg[0]<=(txsm0==txrd0) ? TxOffset[0] : TxListOffset[0];
	RSelReg[0]<=(txsm0!=txrd0);
	RLastReg[0]<={(txsm0==txrd0) & ReadNext[0] & ~|TCntr[0][31:4] & (|TCntr[0][2:0] ? ~TCntr[0][3] : 1'b1), TCntr[0][2:0]};
	SELECTORS[00]<=TxSelector[0];
	SELECTORS[01]<=TxListSelector[0];
	end

RACT[1]<=(RACT[1] | (txsm1==txrdlist0) | (txsm1==txrd0)) & ~(ATUNext & (ChanSel==3'd1) & RACT[1]);
if (ReadNext[1])
	begin
	ROffsetReg[1]<=(txsm1==txrd0) ? TxOffset[1] : TxListOffset[1];
	RSelReg[1]<=(txsm1!=txrd0);
	RLastReg[1]<={(txsm1==txrd0) & ReadNext[1] & ~|TCntr[1][31:4] & (|TCntr[1][2:0] ? ~TCntr[1][3] : 1'b1), TCntr[1][2:0]};
	SELECTORS[02]<=TxSelector[1];
	SELECTORS[03]<=TxListSelector[1];
	end

RACT[2]<=(RACT[2] | (txsm2==txrdlist0) | (txsm2==txrd0)) & ~(ATUNext & (ChanSel==3'd2) & RACT[2]);
if (ReadNext[2])
	begin
	ROffsetReg[2]<=(txsm2==txrd0) ? TxOffset[2] : TxListOffset[2];
	RSelReg[2]<=(txsm2!=txrd0);
	RLastReg[2]<={(txsm2==txrd0) & ReadNext[2] & ~|TCntr[2][31:4] & (|TCntr[2][2:0] ? ~TCntr[2][3] : 1'b1), TCntr[2][2:0]};
	SELECTORS[04]<=TxSelector[2];
	SELECTORS[05]<=TxListSelector[2];
	end

RACT[3]<=(RACT[3] | (txsm3==txrdlist0) | (txsm3==txrd0)) & ~(ATUNext & (ChanSel==3'd3) & RACT[3]);
if (ReadNext[3])
	begin
	ROffsetReg[3]<=(txsm3==txrd0) ? TxOffset[3] : TxListOffset[3];
	RSelReg[3]<=(txsm3!=txrd0);
	RLastReg[3]<={(txsm3==txrd0) & ReadNext[3] & ~|TCntr[3][31:4] & (|TCntr[3][2:0] ? ~TCntr[3][3] : 1'b1), TCntr[3][2:0]};
	SELECTORS[06]<=TxSelector[3];
	SELECTORS[07]<=TxListSelector[3];
	end

/*

write to the memory channels request registers

*/

WACT[0]<=(WACT[0] | (~InFifoEmpty[0] & RxEna[0] & |RxSelector[0]) | (rxsm0==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd4) & WACT[0]);
if (WriteNext[0])
	begin
	WOffsetReg[0]<=(rxsm0==rxws) ? RxOffset[0] : RxListOffset[0];
	WSelReg[0]<=(rxsm0!=rxws);
	WDataReg[0]<=InFifoBus[0][63:0];
	WCmdReg[0]<=(rxsm0!=rxws);
	SELECTORS[08]<=RxSelector[0];
	SELECTORS[09]<=RxListSelector[0];
	end

WACT[1]<=(WACT[1] | (~InFifoEmpty[1] & RxEna[1] & |RxSelector[1]) | (rxsm1==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd5) & WACT[1]);
if (WriteNext[1])
	begin
	WOffsetReg[1]<=(rxsm1==rxws) ? RxOffset[1] : RxListOffset[1];
	WSelReg[1]<=(rxsm1!=rxws);
	WDataReg[1]<=InFifoBus[1][63:0];
	WCmdReg[1]<=(rxsm1!=rxws);
	SELECTORS[10]<=RxSelector[1];
	SELECTORS[11]<=RxListSelector[1];
	end

WACT[2]<=(WACT[2] | (~InFifoEmpty[2] & RxEna[2] & |RxSelector[2]) | (rxsm2==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd6) & WACT[2]);
if (WriteNext[2])
	begin
	WOffsetReg[2]<=(rxsm2==rxws) ? RxOffset[2] : RxListOffset[2];
	WSelReg[2]<=(rxsm2!=rxws);
	WDataReg[2]<=InFifoBus[2][63:0];
	WCmdReg[2]<=(rxsm2!=rxws);
	SELECTORS[12]<=RxSelector[2];
	SELECTORS[13]<=RxListSelector[2];
	end

WACT[3]<=(WACT[3] | (~InFifoEmpty[3] & RxEna[3] & |RxSelector[3]) | (rxsm3==rxrdlist0)) & ~(ATUNext & (ChanSel==3'd7) & WACT[3]);
if (WriteNext[3])
	begin
	WOffsetReg[3]<=(rxsm3==rxws) ? RxOffset[3] : RxListOffset[3];
	WSelReg[3]<=(rxsm3!=rxws);
	WDataReg[3]<=InFifoBus[3][63:0];
	WCmdReg[3]<=(rxsm3!=rxws);
	SELECTORS[14]<=RxSelector[3];
	SELECTORS[15]<=RxListSelector[3];
	end

/*
		data output to the channels
*/
for (i1=0; i1<4; i1=i1+1)
	begin
	// data strobe
	IORSTB[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1];
	IORSTRT[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1] & StartFlag[i1];
	// start flag
	StartFlag[i1]<=(StartFlag[i1] & ~IORSTB[i1]) | RDRDY_L[i1];
	
	casez ({TxSize[i1], OutByteCnt[i1]})
		5'b00_000:	IORD[i1]<={56'd0, OutFifoBus[i1][07:00]};
		5'b00_001:	IORD[i1]<={56'd0, OutFifoBus[i1][15:08]};
		5'b00_010:	IORD[i1]<={56'd0, OutFifoBus[i1][23:16]};
		5'b00_011:	IORD[i1]<={56'd0, OutFifoBus[i1][31:24]};
		5'b00_100:	IORD[i1]<={56'd0, OutFifoBus[i1][39:32]};
		5'b00_101:	IORD[i1]<={56'd0, OutFifoBus[i1][47:40]};
		5'b00_110:	IORD[i1]<={56'd0, OutFifoBus[i1][55:48]};
		5'b00_111:	IORD[i1]<={56'd0, OutFifoBus[i1][63:56]};
		
		5'b01_00?:	IORD[i1]<={48'd0, OutFifoBus[i1][15:00]};
		5'b01_01?:	IORD[i1]<={48'd0, OutFifoBus[i1][31:16]};
		5'b01_10?:	IORD[i1]<={48'd0, OutFifoBus[i1][47:32]};
		5'b01_11?:	IORD[i1]<={48'd0, OutFifoBus[i1][63:48]};
		
		5'b10_0??:	IORD[i1]<={32'd0, OutFifoBus[i1][31:00]};
		5'b10_1??:	IORD[i1]<={32'd0, OutFifoBus[i1][63:32]};
		
		5'b11_???:	IORD[i1]<=OutFifoBus[i1][63:00];
		endcase

	case (TxSize[i1])
		2'b00:		IORLAST[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1] & OutFifoBus[i1][67] & ((OutByteCnt[i1]+1'b1)==OutFifoBus[i1][66:64]);
		2'b01:		IORLAST[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1] & OutFifoBus[i1][67] & ((OutByteCnt[i1][2:1]+1'b1)==OutFifoBus[i1][66:65]);
		2'b10:		IORLAST[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1] & OutFifoBus[i1][67] & ((~OutByteCnt[i1][2])==OutFifoBus[i1][66]);
		2'b11:		IORLAST[i1]<=IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1] & OutFifoBus[i1][67];
		endcase

	// data element counter
	if (RDRDY_L[i1]) OutByteCnt[i1]<='0;
		else if (IORRDY[i1] & ~OutFifoEmpty[i1] & ~|TxTmr[i1])
				case (TxSize[i1])
						2'b00:	OutByteCnt[i1]<=OutByteCnt[i1]+1'b1;
						2'b01:	OutByteCnt[i1]<=OutByteCnt[i1]+2'd2;
						2'b10:	OutByteCnt[i1]<=OutByteCnt[i1]+3'd4;
						2'b11:	OutByteCnt[i1]<='0;
						endcase
	// data interval counter
	if (RDRDY_L[i1]) TxTmr[i1]<='0;
		else if (|TxTmr[i1]) TxTmr[i1]<=TxTmr[i1]-1'b1;
				else if (IORRDY[i1] & ~OutFifoEmpty[i1]) TxTmr[i1]<=TxTimer[i1];
	end


end


endmodule
