module i2c_slave #(parameter DeviceAddress=7'h55)(
				// global
				input wire CLK, RST,
				// i2c
				input wire SCL,
				inout wire SDA,
				// internal bus
				output wire WR, RD, AS,
				output reg [7:0] DO,
				input wire [7:0] DI
				);


reg RWflag, WRflag='0, OEflag='0, FirstFlag='0, WRreg='0, RDreg='0, ASreg='0;
reg [2:0] SCLreg=3'b111;
reg [2:0] bcntr='0;
reg [15:0] SDAreg=16'b1111_1111_1111_1111;
enum reg [3:0] {ws, scs, ars, achs, acks, sds, wacks, rds, wss} sm=ws;
reg [7:0] SIreg, SOreg;

assign WR=WRreg, RD=RDreg, AS=ASreg;
assign SDA=OEflag ? SOreg[7] : 1'bz;


always_ff @(posedge CLK or negedge RST)
if (!RST)
	begin
	sm<=ws;
	SCLreg<=3'b111;
	SDAreg<=16'b1111_1111_1111_1111;
	bcntr<='0;
	WRflag<='0;
	WRreg<='0;
	RDreg<='0;
	ASreg<='0;
	OEflag<='0;
	FirstFlag<='0;
	end
else begin

SCLreg<={SCLreg[1:0],SCL};
SDAreg<={SDAreg[14:0],SDA};

case (sm)
	ws:		if (SDAreg[2] & ~SDAreg[1] & SCLreg[1]) sm<=scs;
				else sm<=ws;
	// start condition state
	scs:	if (~SCLreg[2] & SCLreg[1]) sm<=ars;
				else sm<=scs;
	// receive address state
	ars:	if (SCLreg[2] & ~SCLreg[1] & &bcntr) sm<=achs;
	// check address
	achs: 	if (SIreg[7:1]!=DeviceAddress) sm<=wss;
				else sm<=acks;
	// send acknowledge 
	acks:	if (~SCLreg[2] | SCLreg[1]) sm<=acks;
				else if (RWflag) sm<=sds;
						else sm<=rds;
	// send data byte state
	sds:	if (SCLreg[2] & ~SCLreg[1] & &bcntr) sm<=wacks;
				else sm<=sds;
	// waiting for ACK or NACK from master
	wacks:	if (~SCLreg[2] | SCLreg[1]) sm<=wacks;
				else if (SDAreg[1]) sm<=wss;
						else sm<=sds;
	// receive data state
	rds:	if (SCLreg[2] & SCLreg[1] & SDAreg[2] & ~SDAreg[1]) sm<=scs;
				else if (SCLreg[2] & SCLreg[1] & ~SDAreg[2] & SDAreg[1]) sm<=ws;
						else if (~SCLreg[2] | SCLreg[1] | ~&bcntr) sm<=rds;
								else sm<=acks;
	// waiting for stop state or repeated start state
	wss:	if (~&SCLreg) sm<=wss;
				else if (SDAreg[2] & ~SDAreg[1]) sm<=scs;
						else if (~SDAreg[2] & SDAreg[1]) sm<=ws;
								else sm<=wss;
	endcase

// bit counter
bcntr<=(bcntr+(((sm==ars)|(sm==sds)|(sm==rds))& SCLreg[2] & ~SCLreg[1]))&{3{(sm==ars)|(sm==sds)|(sm==rds)}};

// input data register
if (SCLreg[2] & ~SCLreg[1] & ((sm==ars)|(sm==rds))) SIreg<={SIreg[6:0],SDAreg[15]};

WRflag<=SCLreg[2] & ~SCLreg[1] & (sm==rds) & &bcntr;
// data output
WRreg<=WRflag & FirstFlag;
if (WRflag) DO<=SIreg;

// address strobe
ASreg<=WRflag & ~FirstFlag;

// first byte flag
FirstFlag<=(FirstFlag | ASreg) & (sm!=ws);

// read|write flag
if (SCLreg[2] & ~SCLreg[1] & (sm==ars) & &bcntr) RWflag<=SDAreg[15];

// output shift register
if (RWflag & ((sm==acks)|(sm==wacks)) & SCLreg[2] & ~SCLreg[1]) SOreg<=DI;
	else if ((sm==sds) & SCLreg[2] & ~SCLreg[1]) SOreg<={SOreg[6:0],1'b0};
			else if ((sm!=acks)&(sm!=sds)) SOreg<=0;
		
// read signal
RDreg<=RWflag & ((sm==acks)|((sm==wacks) & ~SDAreg[15])) & SCLreg[2] & ~SCLreg[1];

OEflag<=(sm==acks)|(sm==sds);

end

endmodule
