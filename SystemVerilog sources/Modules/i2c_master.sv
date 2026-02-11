module i2c_master(
				input wire RST, CLK, TCK, ACT, CMD,
				input wire [7:0] BE,
				input wire [63:0] DI,
				output reg [7:0] DO,
				output reg [3:0] SO,
				output reg SCL,
				inout wire SDA
				);
				
reg TransFlag, StartFlag, ReadFlag;
reg [3:0] tmr, sreg;
reg [4:0] cntr;
reg [24:0] shr;
reg [7:0] sir;
reg [3:0] sm;
reg [2:0] psc;
localparam WS=0, SS=1, ADS=2, AS1=3, DS1=4, AS2=5, DS2=6, AS3=7, ES=14, ESS=15;

assign SDA=TransFlag ? shr[24] : (((sm==AS1)|(sm==AS2)|(sm==AS3)) ? 1'bz : 1'b1);

always_ff @(posedge CLK or negedge RST)
if (~RST)
	begin
	tmr<=0;
	psc<=0;
	cntr<=0;
	sm<=WS;
	SCL<=1'b1;
	TransFlag<=0;
	StartFlag<=0;
	ReadFlag<=0;
	end
else begin

// prtescaler
if (TCK) psc<=psc+1'b1;

//cycle counter
if (TCK & &psc) tmr<=(tmr+1'b1)&{4{sm!=WS}};

// shift register
if ((sm==ES)|(sm==ESS)) shr[24]<=0;
	else if (ACT & ~CMD & ~BE[0]) shr[24:16]<={1'b0,DI[7:0]};
		else if (ACT & ~CMD & ~BE[1]) shr[15:8]<=DI[15:8];
			else if (ACT & ~CMD & ~BE[2]) shr [7:0]<=DI[23:16];
				else if (TCK & ~tmr[3] & &tmr[2:0] & &psc & (sm!=AS1) & (sm!=AS2)) shr<={shr[23:0],1'b0};

if (TCK &(tmr==4'd2) & &psc) sir<={sir[6:0],SDA};

if (ACT & ~CMD & ~BE[0]) ReadFlag<=DI[0];

if (ACT & ~CMD & ~BE[0]) SO<=0;
	else if (~tmr[3] & &tmr[2:0] & &psc & (sm==AS1)) SO[0]<=~sir[0];
		else if (~tmr[3] & &tmr[2:0] & &psc & (sm==AS2)) SO[1]<=~sir[0];
			else if (~tmr[3] & &tmr[2:0] & &psc & (sm==AS3)) SO[2]<=~sir[0];
				else if ((sm==ESS)&(tmr==4'd1) & &psc) SO[3]<=1'b1;

StartFlag<=(StartFlag | (ACT & ~CMD & ~BE[0])) & (sm==WS);

// bit counter
if (sm==WS) cntr<=0;
	else if (TCK & ~tmr[3] & &tmr[2:0] & &psc & ((sm==ADS)|(sm==DS1)|(sm==DS2))) cntr<=cntr+1'b1;

if (TCK & &psc)
	case (sm)
		WS:		if (StartFlag) sm<=SS;
					else sm<=WS;
		// start transmission state
		SS:		if (&tmr) sm<=ADS;
					else sm<=SS;
		// transmit device address
		ADS:	if (~tmr[3] & &tmr[2:0] & (cntr==5'd7)) sm<=AS1;
					else sm<=ADS;
		// check first acknowledge
		AS1:	if (~(~tmr[3] & &tmr[2:0])) sm<=AS1;
					//else if (sir[0]) sm<=ES;
							else sm<=DS1;
		// transfer 1-st data byte 
		DS1:	if (~tmr[3] & &tmr[2:0] & (cntr==5'd15)) sm<=AS2;
					else sm<=DS1;
		// check second acknowledge
		AS2:	if (~(~tmr[3] & &tmr[2:0])) sm<=AS2;
					//else if (sir[0]) sm<=ES;
							else sm<=DS2;
		// data byte transfer
		DS2:	if (~tmr[3] & &tmr[2:0] & (cntr==5'd23)) sm<=AS3;
					else sm<=DS2;
		// check thrid acknowledge
		AS3:	if (~(~tmr[3] & &tmr[2:0])) sm<=AS3;
					else sm<=ES;
		// stop bit state
		ES:		if ((tmr==4'd11)) sm<=ESS;
					else sm<=ES;
		ESS:	if ((tmr==4'd1)) sm<=WS;
					else sm<=ESS;
		endcase

// clock
if (TCK & &psc) sreg<={sreg[2:0],tmr[3]};
SCL<=(sm==WS) | sreg[3] | ((sm==SS)& ~|tmr[3:2]) | (sm==ESS);

// output enable
TransFlag<=(sm==SS)|(sm==ADS)|(sm==DS1)|((sm==DS2) & ~ReadFlag)|(sm==ES)|(sm==ESS);

// data output
if ((tmr==4'd4)&(sm==DS2) & &psc) DO<=sir;

end

endmodule
