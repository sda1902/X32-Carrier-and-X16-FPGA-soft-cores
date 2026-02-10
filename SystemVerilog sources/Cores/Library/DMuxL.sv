module DMuxL #(parameter TagWidth=10)(
		input wire CLK, RESET,
		// datapatch from local memory (lowest priority)
		input wire LocalDRDY,
		input wire [TagWidth+63:0] LocalDATA,
		output wire LocalRD,
		// datapatch form stream controller (middle priority)
		input wire StreamDRDY,
		input wire [TagWidth+63:0] StreamDATA,
		output wire StreamRD,
		// output to the EU resources
		output reg DRDY,
		output reg [TagWidth-1:0] TAG,
		output reg [63:0] DATA
);

integer i;

reg [63:0] DataReg;

// assign values for read signals
assign StreamRD=StreamDRDY;
assign LocalRD=LocalDRDY & ~StreamDRDY;

always_ff @(posedge CLK)
begin

// data ready signal
DRDY<=RESET & (LocalDRDY | StreamDRDY);

// transaction tags
for (i=0; i<TagWidth; i=i+1)
	TAG[i]<=(StreamDATA[i+64] & StreamDRDY) | (LocalDATA[i+64] & LocalDRDY & ~StreamDRDY);

// data, delayed by one clock period
DATA<=DataReg;

// multiplexing data
for (i=0; i<64; i=i+1)
	DataReg[i]<=(StreamDATA[i] & StreamDRDY) | (LocalDATA[i] & LocalDRDY & ~StreamDRDY);

end

endmodule
