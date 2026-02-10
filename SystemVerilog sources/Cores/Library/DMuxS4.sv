module DMuxS4 #(parameter TagWidth=11)(
		input wire CLK, RESET,
		// datapatch from local memory (lowest priority)
		input wire LocalDRDY,
		input wire [TagWidth+63:0] LocalDATA,
		output wire LocalRD,
		// datapatch form stream controller (middle priority)
		input wire StreamDRDY,
		input wire [TagWidth+63:0] StreamDATA,
		// datapatch from network controller (highest priority)
		input wire NetDRDY,
		input wire [TagWidth+63:0] NetDATA,
		// data patches from neighbourhood
		input wire DRDYH, DRDYV, DRDYD,
		input wire [TagWidth+63:0] DATAH, DATAV, DATAD,
		// output to the EU resources
		output reg DRDY,
		output reg [TagWidth-1:0] TAG,
		output reg [63:0] DATA
);

integer i, j;

logic RDV, RDD, VFlag, DFlag, NetRD, StreamRD, StreamFlag, NetFlag;
logic [TagWidth+63:0] VBus, DBus, StreamBus, NetBus;

reg [63:0] DataReg;

sc_fifo NetFIFO(.data(NetDATA), .wrreq(NetDRDY), .rdreq(NetRD), .clock(CLK), .sclr(~RESET),
				.q(NetBus), .empty(NetFlag));
defparam NetFIFO.LPM_WIDTH=TagWidth+64, NetFIFO.LPM_NUMWORDS=16, NetFIFO.LPM_WIDTHU=4;

sc_fifo StreamFIFO(.data(StreamDATA), .wrreq(StreamDRDY), .rdreq(StreamRD), .clock(CLK), .sclr(~RESET),
				.q(StreamBus), .empty(StreamFlag));
defparam StreamFIFO.LPM_WIDTH=TagWidth+64, StreamFIFO.LPM_NUMWORDS=16, StreamFIFO.LPM_WIDTHU=4;

sc_fifo VFIFO(.data(DATAV), .wrreq(DRDYV), .rdreq(RDV), .clock(CLK), .sclr(~RESET),
				.q(VBus), .empty(VFlag));
defparam VFIFO.LPM_WIDTH=TagWidth+64, VFIFO.LPM_NUMWORDS=16, VFIFO.LPM_WIDTHU=4;

sc_fifo DFIFO(.data(DATAD), .wrreq(DRDYD), .rdreq(RDD), .clock(CLK), .sclr(~RESET),
				.q(DBus), .empty(DFlag));
defparam DFIFO.LPM_WIDTH=TagWidth+64, DFIFO.LPM_NUMWORDS=16, DFIFO.LPM_WIDTHU=4;

// assign values for read signals
assign RDV=~VFlag & ~DRDYH;
assign RDD=~DFlag & VFlag & ~DRDYH;
assign NetRD=~NetFlag & DFlag & VFlag & ~DRDYH;
assign StreamRD=~StreamFlag & NetFlag & DFlag & VFlag & ~DRDYH;
assign LocalRD=LocalDRDY & StreamFlag & NetFlag & DFlag & VFlag & ~DRDYH;

always_ff @(posedge CLK)
begin

// data ready signal
DRDY<=RESET & (LocalDRDY | ~StreamFlag | ~NetFlag | DRDYH | ~VFlag | ~DFlag);

// data, delayed by one clock period
DATA<=DataReg;

for (i=0; i<TagWidth; i=i+1)
	TAG[i]<=(DATAH[i+64] & DRDYH) | (VBus[i+64] & RDV) | (DBus[i+64] & RDD) |
			(NetBus[i+64] & NetRD) | (StreamBus[i+64] & StreamRD) | (LocalDATA[i+64] & LocalRD);

// multiplexing data
for (j=0; j<64; j=j+1)
	DataReg[j]<=(DATAH[j] & DRDYH) | (VBus[j] & RDV) | (DBus[j] & RDD) |
				(NetBus[j] & NetRD) | (StreamBus[j] & StreamRD) | (LocalDATA[j] & LocalRD);

end

endmodule
