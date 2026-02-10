module ErrorFIFOL (
	input wire CLK, RESET,
	input wire [23:0] CPSR,
	// read fifo interface
	input wire ERD,
	output reg VALID,
	output wire [63:0] ECD,
	// error interface from core
	input wire CoreSTB,
	input wire [28:0] CoreECD,
	// error report from context controller
	input wire ContSTB,
	input wire [31:0] ContECD
	);

// error registers
reg CoreFlag, ContextFlag;
reg [28:0] CoreReg;
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
	CoreFlag<=1'b0;
	ContextFlag<=1'b0;
	WriteFlag<=1'b0;
	WPtr<=6'd0;
	VALID<=1'b0;
	ValidSetFlag<=1'b0;
	RPtr<=6'd0;
	end
	else begin
		// register input error requests
		if (CoreSTB) CoreReg<=CoreECD;
		CoreFlag<=CoreSTB & ~CoreFlag;

		if (ContSTB) ContextReg<=ContECD;
		ContextFlag<=(ContextFlag & CoreFlag) | ContSTB;

		// write to ram signal
		WriteFlag<=CoreFlag | ContextFlag;
		// selecting data to be writen to the ram
		casez ({ContextFlag, CoreFlag})
			2'b?1: WDReg<={CoreReg[28:24], 3'd1, CPSR, 8'd0, CoreReg[23:0]};
			2'b10: WDReg<={ContextReg, 32'd0};
			default: WDReg<=64'd0;
			endcase

		// write data into the RAM
		if (WriteFlag) ErrorRAM[WAReg]<=WDReg;
		WAReg<=WPtr;

		// write pointer
		WPtr<=WPtr+{5'd0, CoreFlag | ContextFlag};

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

