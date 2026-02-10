module ErrorFIFODT (
	input wire CLK, RESET,
	input wire [23:0] CPSR [1:0],
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire [1:0] CoreSTB,
	input wire [28:0] CoreECD [1:0],
	// error interface from FFT coprocessor
	input wire FFTSTB,
	input wire [28:0] FFTECD,
	input wire [23:0] FFTCPSR,
	// error report from network
	input wire NetSTB,
	input wire [13:0] NetECD,
	// error report from messenger
	input wire MsgrSTB,
	input wire [63:0] MsgrECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);

// error registers
reg [1:0] CoreFlag;
reg FFTFlag, NetworkFlag, MsgrFlag, ContextFlag;
reg [28:0] CoreReg [1:0];
reg [52:0] FFTReg;
reg [13:0] NetworkReg;
reg [63:0] MsgrReg;
reg [31:0] ContextReg;

reg	[63:0] ErrorRAM [0:63];

reg [5:0] WAReg, RAReg, WPtr, RPtr;
reg [63:0] WDReg, RDReg;
reg WriteFlag, ValidSetFlag;

assign ECD=RDReg;

always_ff @(negedge RESET or posedge CLK)
begin
if (!RESET)
	begin
	CoreFlag<=0;
	FFTFlag<=1'b0;
	NetworkFlag<=1'b0;
	MsgrFlag<=1'b0;
	ContextFlag<=1'b0;
	WriteFlag<=1'b0;
	WPtr<=6'd0;
	VALID<=1'b0;
	ValidSetFlag<=1'b0;
	RPtr<=6'd0;
	end
	else begin
		// register input error requests
		if (CoreSTB[0]) CoreReg[0]<=CoreECD[0];
		CoreFlag[0]<=CoreSTB[0] & ~CoreFlag[0];

		if (CoreSTB[1]) CoreReg[1]<=CoreECD[1];
		CoreFlag[1]<=(CoreFlag[1] & CoreFlag[0]) | CoreSTB[1];
		
		if (FFTSTB) FFTReg<={FFTCPSR, FFTECD};
		FFTFlag<=(FFTFlag & (|CoreFlag)) | FFTSTB;

		if (NetSTB) NetworkReg<=NetECD;
		NetworkFlag<=(NetworkFlag & ((|CoreFlag) | FFTFlag)) | NetSTB;

		if (MsgrSTB) MsgrReg<=MsgrECD;
		MsgrFlag<=(MsgrFlag & ((|CoreFlag) | FFTFlag | NetworkFlag)) | MsgrSTB;

		if (ContSTB) ContextReg<=ContECD;
		ContextFlag<=(ContextFlag & ((|CoreFlag) | FFTFlag | NetworkFlag | MsgrFlag)) | ContSTB;

		// write to ram signal
		WriteFlag<=(|CoreFlag) | FFTFlag | NetworkFlag | MsgrFlag | ContextFlag;
		// selecting data to be writen to the ram
		casez ({ContextFlag, MsgrFlag, NetworkFlag, FFTFlag, CoreFlag[1], CoreFlag[0]})
			6'b?????1: WDReg<={CoreReg[0][28:24], 3'd1, CPSR[0], 8'd0, CoreReg[0][23:0]};
			6'b????10: WDReg<={CoreReg[1][28:24], 3'd1, CPSR[1], 8'd0, CoreReg[1][23:0]};
			6'b???100: WDReg<={FFTReg[28:24], 3'd1, FFTReg[52:29], 8'd0, FFTReg[23:0]};
			6'b??1000: WDReg<={NetworkReg[12:8], 3'd1, NetworkReg[13] ? CPSR[1] : CPSR[0], NetworkReg[7:0], 24'd0};
			6'b?10000: WDReg<=MsgrReg;
			6'b100000: WDReg<={ContextReg, 32'd0};
			default: WDReg<=64'd0;
			endcase

		// write data into the RAM
		if (WriteFlag) ErrorRAM[WAReg]<=WDReg;
		WAReg<=WPtr;

		// write pointer
		WPtr<=WPtr+{5'd0, (|CoreFlag) | FFTFlag | NetworkFlag | MsgrFlag | ContextFlag};

		// read data from the RAM
		if (~VALID | ERD) RDReg<=ErrorRAM[RAReg];
		// valid flag
		VALID<=(VALID & ~ERD) | ValidSetFlag;
		// read data stage
		ValidSetFlag<=(ValidSetFlag & VALID & ~ERD) | (WPtr!=RPtr);
		// read pointer
		RPtr<=RPtr+{5'd0, (~ValidSetFlag | ~VALID | ERD) & (WPtr!=RPtr)};
		if (~ValidSetFlag | ~VALID | ERD) RAReg<=RPtr;
		end

end


endmodule

