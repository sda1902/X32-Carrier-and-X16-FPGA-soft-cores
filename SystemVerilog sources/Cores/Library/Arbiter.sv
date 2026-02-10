module Arbiter(
			input wire CLK, RESET, NEXT,
			input wire [3:0] REQ,
			output wire [3:0] SEL
			);

reg [1:0] Pcnt;
logic [3:0] S;

assign SEL=S;

always_comb
begin
casez ({Pcnt,REQ})
	6'b000000:	S=4'b0000;
	6'b00???1:	S=4'b0001;
	6'b00??10:	S=4'b0010;
	6'b00?100:	S=4'b0100;
	6'b001000:	S=4'b1000;
	
	6'b010000:	S=4'b0000;
	6'b01??1?:	S=4'b0010;
	6'b01?10?:	S=4'b0100;
	6'b01100?:	S=4'b1000;
	6'b010001:	S=4'b0001;
	
	6'b100000:	S=4'b0000;
	6'b10?1??:	S=4'b0100;
	6'b1010??:	S=4'b1000;
	6'b1000?1:	S=4'b0001;
	6'b100010:	S=4'b0010;
	
	6'b110000:	S=4'b0000;
	6'b111???:	S=4'b1000;
	6'b110??1:	S=4'b0001;
	6'b110?10:	S=4'b0010;
	6'b110100:	S=4'b0100;
	endcase
end

always_ff @(posedge CLK or negedge RESET)
begin
if (~RESET) Pcnt<=0;
else begin

if (NEXT & (|SEL)) Pcnt<=Pcnt+2'd1;

end
end

endmodule
