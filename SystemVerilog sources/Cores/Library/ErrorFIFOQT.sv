module ErrorFIFOQT (
	input wire CLK, RESET,
	input wire [23:0] CPSR [3:0],
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire [3:0] CoreSTB,
	input wire [28:0] CoreECD [3:0],
	// error interface from FFT coprocessor
	input wire [3:0] FFTSTB,
	input wire [28:0] FFTECD [3:0],
	input wire [23:0] FFTCPSR [3:0],
	// error report from network
	input wire NetSTB,
	input wire [12:0] NetECD,
	input wire [1:0] NetCPSRSel,
	// error report from messenger
	input wire MsgrSTB,
	input wire [63:0] MsgrECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);

// error registers
reg [3:0] CoreFlag, FFTFlag;
reg NetworkFlag, MsgrFlag, ContextFlag;
reg [28:0] CoreReg [3:0];
reg [52:0] FFTReg [3:0];
reg [12:0] NetworkReg;
reg [63:0] MsgrReg;
reg [31:0] ContextReg;
reg [1:0] NCSEL;

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
	FFTFlag<=0;
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
		CoreFlag[0]<=CoreSTB[0];
		if (CoreSTB[1]) CoreReg[1]<=CoreECD[1];
		CoreFlag[1]<=(CoreFlag[1] & CoreFlag[0]) | CoreSTB[1];
		if (CoreSTB[2]) CoreReg[2]<=CoreECD[2];
		CoreFlag[2]<=(CoreFlag[2] & (|CoreFlag[1:0])) | CoreSTB[2];
		if (CoreSTB[3]) CoreReg[3]<=CoreECD[3];
		CoreFlag[3]<=(CoreFlag[3] & (|CoreFlag[2:0])) | CoreSTB[3];
		
		// FFT channel
		if (FFTSTB[0]) FFTReg[0]<={FFTCPSR[0], FFTECD[0]};
		FFTFlag[0]<=(FFTFlag[0] & (|CoreFlag)) | FFTSTB[0];
		if (FFTSTB[1]) FFTReg[1]<={FFTCPSR[1], FFTECD[1]};
		FFTFlag[1]<=(FFTFlag[1] & (FFTFlag[0] | (|CoreFlag))) | FFTSTB[1];
		if (FFTSTB[2]) FFTReg[2]<={FFTCPSR[2], FFTECD[2]};
		FFTFlag[2]<=(FFTFlag[2] & ((|FFTFlag[1:0])|(|CoreFlag))) | FFTSTB[2];
		if (FFTSTB[3]) FFTReg[3]<={FFTCPSR[3], FFTECD[3]};
		FFTFlag[3]<=(FFTFlag[3] & ((|FFTFlag[2:0])|(|CoreFlag))) | FFTSTB[3];

		// Network channel
		if (NetSTB) 
			begin
			NetworkReg<=NetECD;
			NCSEL<=NetCPSRSel;
			end
		NetworkFlag<=(NetworkFlag & ((|CoreFlag) | (|FFTFlag))) | NetSTB;

		if (MsgrSTB) MsgrReg<=MsgrECD;
		MsgrFlag<=(MsgrFlag & ((|CoreFlag) | (|FFTFlag) | NetworkFlag)) | MsgrSTB;

		if (ContSTB) ContextReg<=ContECD;
		ContextFlag<=(ContextFlag & ((|CoreFlag) | (|FFTFlag) | NetworkFlag | MsgrFlag)) | ContSTB;

		// write to ram signal
		WriteFlag<=(|CoreFlag) | (|FFTFlag) | NetworkFlag | MsgrFlag | ContextFlag;
		// selecting data to be writen to the ram
		casez ({ContextFlag, MsgrFlag, NetworkFlag, FFTFlag, CoreFlag})
			11'b??????????1: WDReg<={CoreReg[0][28:24], 3'd1, CPSR[0], 8'd0, CoreReg[0][23:0]};
			11'b?????????10: WDReg<={CoreReg[1][28:24], 3'd1, CPSR[1], 8'd0, CoreReg[1][23:0]};
			11'b????????100: WDReg<={CoreReg[2][28:24], 3'd1, CPSR[2], 8'd0, CoreReg[2][23:0]};
			11'b???????1000: WDReg<={CoreReg[3][28:24], 3'd1, CPSR[3], 8'd0, CoreReg[3][23:0]};
			11'b??????10000: WDReg<={FFTReg[0][28:24], 3'd1, FFTReg[0][52:29], 8'd0, FFTReg[0][23:0]};
			11'b?????100000: WDReg<={FFTReg[1][28:24], 3'd1, FFTReg[1][52:29], 8'd0, FFTReg[1][23:0]};
			11'b????1000000: WDReg<={FFTReg[2][28:24], 3'd1, FFTReg[2][52:29], 8'd0, FFTReg[2][23:0]};
			11'b???10000000: WDReg<={FFTReg[3][28:24], 3'd1, FFTReg[3][52:29], 8'd0, FFTReg[3][23:0]};
			11'b??100000000: WDReg<={NetworkReg[12:8], 3'd1, NCSEL[1] ? (NCSEL[0] ? CPSR[3]:CPSR[2]):(NCSEL[0] ? CPSR[1]:CPSR[0]), NetworkReg[7:0], 24'd0};
			11'b?1000000000: WDReg<=MsgrReg;
			11'b10000000000: WDReg<={ContextReg, 32'd0};
			default: WDReg<=64'd0;
			endcase

		// write data into the RAM
		if (WriteFlag) ErrorRAM[WAReg]<=WDReg;
		WAReg<=WPtr;

		// write pointer
		if ((|CoreFlag) | (|FFTFlag) | NetworkFlag | MsgrFlag | ContextFlag) WPtr<=WPtr+6'd1;

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

