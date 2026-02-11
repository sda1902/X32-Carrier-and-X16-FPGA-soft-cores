module Interrupt #(parameter TagWidth=4)(
				input wire CLK, RESET,
				input wire [15:0] IRQ,
				// control interface
				input wire ACT, CMD,
				input wire [2:0] ADDR,
				input wire [7:0] BE,
				input wire [63:0] DI,
				input wire [TagWidth-1:0] TI,
				output reg DRDY,
				output reg [63:0] DO,
				output reg [TagWidth-1:0] TO,
				// interrupt interface
				output wire INTR,
				output wire [15:0] ICODE,
				input wire IACK
				);

integer i1, i2;

reg [63:0] CodeRam [3:0];
reg [15:0] IRQReg, MaskReg;
logic IFifoEmpty, IFifoFull;
logic [15:0] IBus;

sc_fifo IFifo (.data(IBus), .wrreq(~IFifoFull & (|IRQReg)), .rdreq(~IFifoEmpty & IACK), .clock(CLK), .sclr(~RESET),
				.q(ICODE), .empty(IFifoEmpty), .full(IFifoFull));
defparam IFifo.LPM_WIDTH=16, IFifo.LPM_NUMWORDS=16, IFifo.LPM_WIDTHU=4;

assign INTR=~IFifoEmpty;

always_comb
begin

// interrupt code selection
casez (IRQReg)
	16'b???????????????1:	IBus=CodeRam[0][15:0];
	16'b??????????????10:	IBus=CodeRam[0][31:16];
	16'b?????????????100:	IBus=CodeRam[0][47:32];
	16'b????????????1000:	IBus=CodeRam[0][63:48];
	16'b???????????10000:	IBus=CodeRam[1][15:0];
	16'b??????????100000:	IBus=CodeRam[1][31:16];
	16'b?????????1000000:	IBus=CodeRam[1][47:32];
	16'b????????10000000:	IBus=CodeRam[1][63:48];
	16'b???????100000000:	IBus=CodeRam[2][15:0];
	16'b??????1000000000:	IBus=CodeRam[2][31:16];
	16'b?????10000000000:	IBus=CodeRam[2][47:32];
	16'b????100000000000:	IBus=CodeRam[2][63:48];
	16'b???1000000000000:	IBus=CodeRam[3][15:0];
	16'b??10000000000000:	IBus=CodeRam[3][31:16];
	16'b?100000000000000:	IBus=CodeRam[3][47:32];
	16'b1000000000000000:	IBus=CodeRam[3][63:48];
	default: IBus=16'd0;
	endcase

end

always_ff @(posedge CLK)
begin
if (~RESET)
	begin
	IRQReg<=0;
	MaskReg<=0;
	DRDY<=0;
	CodeRam[0]<=0;
	CodeRam[1]<=0;
	CodeRam[2]<=0;
	CodeRam[3]<=0;
	end
else begin

// Interrupt registering
IRQReg[0]<=(IRQReg[0] | (IRQ[0] & MaskReg[0])) & (~IRQReg[0] | IFifoFull);
IRQReg[1]<=(IRQReg[1] | (IRQ[1] & MaskReg[1])) & (~IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[2]<=(IRQReg[2] | (IRQ[2] & MaskReg[2])) & (~IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[3]<=(IRQReg[3] | (IRQ[3] & MaskReg[3])) & (~IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[4]<=(IRQReg[4] | (IRQ[4] & MaskReg[4])) & (~IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[5]<=(IRQReg[5] | (IRQ[5] & MaskReg[5])) & (~IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[6]<=(IRQReg[6] | (IRQ[6] & MaskReg[6])) & (~IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[7]<=(IRQReg[7] | (IRQ[7] & MaskReg[7])) & (~IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] | IFifoFull);
IRQReg[8]<=(IRQReg[8] | (IRQ[8] & MaskReg[8])) & (~IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] | IRQReg[0] |
			IFifoFull);
IRQReg[9]<=(IRQReg[9] | (IRQ[9] & MaskReg[9])) & (~IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] | IRQReg[1] |
			IRQReg[0] | IFifoFull);
IRQReg[10]<=(IRQReg[10] | (IRQ[10] & MaskReg[10])) & (~IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] | IRQReg[2] |
			IRQReg[1] |	IRQReg[0] | IFifoFull);
IRQReg[11]<=(IRQReg[11] | (IRQ[11] & MaskReg[11])) & (~IRQReg[11] | IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] | IRQReg[3] |
			IRQReg[2] |	IRQReg[1] |	IRQReg[0] | IFifoFull);
IRQReg[12]<=(IRQReg[12] | (IRQ[12] & MaskReg[12])) & (~IRQReg[12] | IRQReg[11] | IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] | IRQReg[4] |
			IRQReg[3] | IRQReg[2] |	IRQReg[1] |	IRQReg[0] | IFifoFull);
IRQReg[13]<=(IRQReg[13] | (IRQ[13] & MaskReg[13])) & (~IRQReg[13] | IRQReg[12] | IRQReg[11] | IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] | IRQReg[5] |
			IRQReg[4] |	IRQReg[3] | IRQReg[2] |	IRQReg[1] |	IRQReg[0] | IFifoFull);
IRQReg[14]<=(IRQReg[14] | (IRQ[14] & MaskReg[14])) & (~IRQReg[14] | IRQReg[13] | IRQReg[12] | IRQReg[11] | IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] | IRQReg[6] |
			IRQReg[5] |	IRQReg[4] |	IRQReg[3] | IRQReg[2] |	IRQReg[1] |	IRQReg[0] | IFifoFull);
IRQReg[15]<=(IRQReg[15] | (IRQ[15] & MaskReg[15])) & (~IRQReg[15] | IRQReg[14] | IRQReg[13] | IRQReg[12] | IRQReg[11] | IRQReg[10] | IRQReg[9] | IRQReg[8] | IRQReg[7] |
			IRQReg[6] | IRQReg[5] |	IRQReg[4] |	IRQReg[3] | IRQReg[2] |	IRQReg[1] |	IRQReg[0] | IFifoFull);

// Mask Register and interrupt codes
for (i1=0; i1<16; i1=i1+1)
	if (i1<8) begin
				MaskReg[i1]<=(MaskReg[i1] | (ACT & ~CMD & ADDR[2] & ~BE[2] & DI[i1+16])) & ~IRQReg[i1] & (~ACT | CMD | ~ADDR[2] | BE[0] | ~DI[i1]);
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[0]) CodeRam[0][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[2]) CodeRam[0][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[4]) CodeRam[0][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[6]) CodeRam[0][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[0]) CodeRam[1][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[2]) CodeRam[1][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[4]) CodeRam[1][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[6]) CodeRam[1][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[0]) CodeRam[2][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[2]) CodeRam[2][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[4]) CodeRam[2][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[6]) CodeRam[2][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[0]) CodeRam[3][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[2]) CodeRam[3][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[4]) CodeRam[3][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[6]) CodeRam[3][48+i1]<=DI[48+i1];
				end
		else  begin
				MaskReg[i1]<=(MaskReg[i1] | (ACT & ~CMD & ADDR[2] & ~BE[3] & DI[i1+16])) & ~IRQReg[i1] & (~ACT | CMD | ~ADDR[2] | BE[1] | ~DI[i1]);
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[1]) CodeRam[0][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[3]) CodeRam[0][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[5]) CodeRam[0][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ~ADDR[0] & ~BE[7]) CodeRam[0][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[1]) CodeRam[1][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[3]) CodeRam[1][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[5]) CodeRam[1][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ~ADDR[1] & ADDR[0] & ~BE[7]) CodeRam[1][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[1]) CodeRam[2][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[3]) CodeRam[2][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[5]) CodeRam[2][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ~ADDR[0] & ~BE[7]) CodeRam[2][48+i1]<=DI[48+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[1]) CodeRam[3][i1]<=DI[i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[3]) CodeRam[3][16+i1]<=DI[16+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[5]) CodeRam[3][32+i1]<=DI[32+i1];
				if (ACT & ~CMD & ~ADDR[2] & ADDR[1] & ADDR[0] & ~BE[7]) CodeRam[3][48+i1]<=DI[48+i1];
				end

// Data output
DRDY<=ACT & CMD;

casez (ADDR)
	3'd0: DO<=CodeRam[0];
	3'd1: DO<=CodeRam[1];
	3'd2: DO<=CodeRam[2];
	3'd3: DO<=CodeRam[3];
	3'b1??: DO<={48'd0,MaskReg};
	endcase

TO<=TI;
				
end
end

endmodule
