
module dc_fifo #(parameter WIDTH=16, NUMWORDS=16, WIDTHU=4)
							(
							input wire resetn, wrclk, wren,
							input wire [WIDTH-1:0] data,
							output reg [WIDTHU-1:0] wrused,
							input wire rdclk, rden,
							output reg [WIDTH-1:0] q,
							output reg [WIDTHU-1:0] rdused
							);


reg [WIDTH-1:0] mem [0:NUMWORDS-1];

reg [WIDTHU-1:0] wrptr [0:2];
reg [WIDTHU-1:0] wrptr_gray [0:1];
reg [WIDTHU-1:0] rdptr [0:2];
reg [WIDTHU-1:0] rdptr_gray [0:1];

// write clock domain
always_ff @(posedge wrclk or negedge resetn)
if (~resetn)
	begin
	wrptr[0]<='0;
	wrptr_gray[0]<='0;
	rdptr[1]<='0;
	rdptr[2]<='0;
	rdptr_gray[1]<='0;
	wrused<='0;
	end
else begin

if (wren & ~wrused[WIDTHU-1])
		begin
		mem[wrptr[0]]<=data;
		wrptr[0]<=wrptr[0]+1'b1;
		wrptr_gray[0]<=(wrptr[0]+1'b1)^((wrptr[0]+1'b1)>>1);
		end

// read pointers resynchronization
rdptr[1]<=rdptr[0];
rdptr_gray[1]<=rdptr_gray[0];
if (rdptr_gray[1]==(rdptr[1] ^ (rdptr[1]>>1))) rdptr[2]<=rdptr[1];

wrused<=wrptr[0]-rdptr[2]+(wren & ~wrused[WIDTHU-1]);

end


// read clock domain
always_ff @(posedge rdclk or negedge resetn)
if (~resetn)
	begin
	rdptr[0]<='0;
	rdptr_gray[0]<='0;
	wrptr[1]<='0;
	wrptr[2]<='0;
	wrptr_gray[1]<='0;
	rdused<='0;
	end
else begin

// write pointers resynchronization
wrptr[1]<=wrptr[0];
wrptr_gray[1]<=wrptr_gray[0];
if (wrptr_gray[1]==(wrptr[1] ^ (wrptr[1]>>1))) wrptr[2]<=wrptr[1];

q<=mem[rdptr[0]+(rden & |rdused)];

if (rden & |rdused)
	begin
	rdptr[0]<=rdptr[0]+1'b1;
	rdptr_gray[0]<=(rdptr[0]+1'b1)^((rdptr[0]+1'b1)>>1);
	end
	
rdused<=wrptr[2]-rdptr[0]-(rden & |rdused);

end


endmodule
