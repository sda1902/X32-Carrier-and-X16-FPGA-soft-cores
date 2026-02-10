module rpcd	(
				input wire CLK, RST, ENA,
				input wire [7:0] REQ,
				output wire [2:0] CSEL
				);

logic [7:0] ReqBus;
logic [2:0] ReqBusSelection, Csel;
logic [2:0] cregs [0:7];

integer i0, i1, i2, i3;

assign CSEL=Csel;

always_comb begin

// create requests bus
for (i2=0; i2<8; i2=i2+1) ReqBus[i2]=REQ[cregs[i2]];

// create request selection
casez (ReqBus)
	8'b0000_0000:	ReqBusSelection=3'd0;
	8'b????_???1:	ReqBusSelection=3'd0;
	8'b????_??10:	ReqBusSelection=3'd1;
	8'b????_?100:	ReqBusSelection=3'd2;
	8'b????_1000:	ReqBusSelection=3'd3;
	8'b???1_0000:	ReqBusSelection=3'd4;
	8'b??10_0000:	ReqBusSelection=3'd5;
	8'b?100_0000:	ReqBusSelection=3'd6;
	8'b1000_0000:	ReqBusSelection=3'd7;
	endcase

Csel=cregs[ReqBusSelection];

end


always_ff @(posedge CLK or negedge RST)
if (~RST)
	begin
	cregs[0]<=3'd0;
	cregs[1]<=3'd1;
	cregs[2]<=3'd2;
	cregs[3]<=3'd3;
	cregs[4]<=3'd4;
	cregs[5]<=3'd5;
	cregs[6]<=3'd6;
	cregs[7]<=3'd7;
	end
else begin

if (ENA & |REQ)
	case (ReqBusSelection)
		3'd0:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[0], cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1]};
		3'd1:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[1], cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[0]};
		3'd2:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[2], cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[1], cregs[0]};
		3'd3:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[3], cregs[7], cregs[6], cregs[5], cregs[4], cregs[2], cregs[1], cregs[0]};
		3'd4:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[4], cregs[7], cregs[6], cregs[5], cregs[3], cregs[2], cregs[1], cregs[0]};
		3'd5:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[5], cregs[7], cregs[6], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]};
		3'd6:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[6], cregs[7], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]};
		3'd7:	{cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]}<={cregs[7], cregs[6], cregs[5], cregs[4], cregs[3], cregs[2], cregs[1], cregs[0]};
		endcase

end

endmodule
