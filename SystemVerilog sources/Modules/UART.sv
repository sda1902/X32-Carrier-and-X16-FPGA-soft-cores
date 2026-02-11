module UART #(parameter TagWidth=16, FifoLength=512, FifoUsedW=9)(
	input wire CLK, RESET, ACT, CMD,
	input wire [7:0] BE,
	input wire [63:0] DI,
	input wire [TagWidth-1:0] TI,
	output wire DRDY, INTR,
	output wire [63:0] DO,
	output wire [TagWidth-1:0] TO,
	// UART
	input wire RX,
	output reg TX
	);
	
integer i1, i2;

logic RXEmpty, RXFull, TXEmpty, TXFull, OutShifterEna, RXin, InEna, OutEna, OutShifterReload, RXFlag, IntReg;
logic [3:0] RXBitReg, TXBitReg;
logic [7:0] TXFifoData, InShiftReg;
logic [8:0] OutShiftReg;
logic [15:0] ScaleReg, TXCntReg, RXCntReg;
logic [FifoUsedW-1:0] TXUsed, RXUsed, RXThresh, TXThresh;

sc_fifo #(.LPM_WIDTH(8), .LPM_NUMWORDS(FifoLength), .LPM_WIDTHU(FifoUsedW)) TXFifo(.data(DI[7:0]), .wrreq(ACT & ~CMD & ~TXFull & ~BE[0]), .rdreq(~TXEmpty & OutShifterReload),
																					.clock(CLK), .sclr(~RESET), .q(TXFifoData), .empty(TXEmpty), .full(TXFull), .usedw(TXUsed));

sc_fifo #(.LPM_WIDTH(8), .LPM_NUMWORDS(FifoLength), .LPM_WIDTHU(FifoUsedW)) RXFifo(.data(InShiftReg), .wrreq(InEna & RXFlag & (RXBitReg==4'd9) & ~RXFull), .rdreq(ACT & CMD & ~BE[0] & ~RXEmpty),
																					.clock(CLK), .sclr(~RESET), .q(DO[7:0]), .empty(RXEmpty), .full(RXFull), .usedw(RXUsed));

assign DO[63:48]={{(16-FifoUsedW){1'b0}}, TXUsed};
assign DO[47:32]={{(16-FifoUsedW){1'b0}}, RXUsed};
assign DO[31:16]=ScaleReg;
assign DO[8]=~RXEmpty;
assign DO[15:9]=0;
assign TO=TI;
assign DRDY=ACT & CMD;
assign INTR=IntReg;

always_comb
begin

OutShifterEna=~(|TXCntReg);

end

always_ff @(posedge CLK or negedge RESET)
begin
if (~RESET)
	begin
	ScaleReg<=0;
	TXCntReg<=0;
	RXCntReg<=0;
	OutShiftReg<=9'h1FF;
	TXBitReg<=4'd9;
	RXBitReg<=0;
	RXFlag<=0;
	InEna<=0;
	IntReg<=0;
	RXThresh<=0;
	TXThresh<=0;
	OutShifterReload<=0;
	OutEna<=0;
	RXin<=1'b1;
	TX<=1'b1;
	end
else begin

//=================================================================================================
//					TX part

// scale register
if (ACT & ~CMD & ~BE[2]) ScaleReg[7:0]<=DI[23:16];
if (ACT & ~CMD & ~BE[3]) ScaleReg[15:8]<=DI[31:24];

// TX scale register
TXCntReg<=(TXCntReg+16'd1) & {16{TXCntReg!=ScaleReg}};
// Output shifter reload
OutShifterReload<=OutShifterEna & (TXBitReg==4'd9);
OutEna<=OutShifterEna;
// Output shifter
if (OutEna)
	for (i1=0; i1<9; i1=i1+1)
		if (i1==0) OutShiftReg[i1]<=OutShiftReg[i1+1] & (~OutShifterReload | TXEmpty);
			else if (i1<8) OutShiftReg[i1]<=(OutShifterReload & ~TXEmpty) ? TXFifoData[i1-1] : OutShiftReg[i1+1];
					else OutShiftReg[i1]<=TXFifoData[i1-1] | ~OutShifterReload | TXEmpty;
// out bit counter
if (OutEna & ((TXBitReg!=4'd9) | ~TXEmpty)) TXBitReg<=(TXBitReg+4'd1) & {4{(TXBitReg!=4'd9)}};

TX<=OutShiftReg[0];


//=================================================================================================
//					RX part

// RX input register
RXin<=RX;

// RX scale register
RXCntReg<=(RXCntReg+16'd1) & {16{RXFlag}} & {16{RXCntReg!=ScaleReg}};

// Bit Counter
if (InEna & RXFlag) RXBitReg<=(RXBitReg+4'd1) & {4{(RXBitReg!=4'd9)}};

// bit ena nodes
InEna<=(RXCntReg=={1'b0,ScaleReg>>1});

// RX Flag
RXFlag<=(RXFlag | (~(|RXBitReg) & ~RXin & ~(|RXCntReg))) & (~InEna | (RXBitReg!=4'd9));

// input shift register
if (InEna & RXFlag)
	for (i2=0; i2<8; i2=i2+1)
		if (i2==7) InShiftReg[i2]<=RXin;
			else InShiftReg[i2]<=InShiftReg[i2+1];

//=================================================================================================
//					interrupt generation by threshold's

// threshold registers
if (FifoUsedW<9)
		begin
		if (ACT & ~CMD & ~BE[4]) RXThresh<=DI[32+FifoUsedW-1:32];
		if (ACT & ~CMD & ~BE[6]) TXThresh<=DI[48+FifoUsedW-1:48];
		end
	else begin
		if (ACT & ~CMD & ~BE[4]) RXThresh[7:0]<=DI[39:32];
		if (ACT & ~CMD & ~BE[5]) RXThresh[FifoUsedW-1:8]<=DI[40+FifoUsedW-9:40];
		if (ACT & ~CMD & ~BE[6]) TXThresh[7:0]<=DI[55:48];
		if (ACT & ~CMD & ~BE[7]) TXThresh[FifoUsedW-1:8]<=DI[56+FifoUsedW-9:56];
		end

IntReg<=(InEna & RXFlag & (RXBitReg==4'd9) & (RXThresh==RXUsed) & (|RXThresh)) | (~TXEmpty & OutShifterReload & (TXThresh==TXUsed) & (|TXThresh));

end
end

endmodule
