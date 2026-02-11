module MAC2G5(
			input wire CLK, RST, ENA,
			// RTE TX interface
			input wire TXSTB,
			input wire [32:0] TXD,
			// RTE RX interface
			output reg RXSTB,
			output reg [32:0] RXD,
			// Transceiver interface
			input wire Tclk, Rclk,
			input wire [31:0] Rdata,
			output reg [31:0] Tdata,
			// status
			output reg STATUS, TX, RX,
			output wire [31:0] Aligned
			);

reg TEnaFlag, ERxWSFlag, ERxWWFlag, StatReg;
reg [4:0] SPar=0;
reg [2:0] Tcntr=0, Rcntr=0;
reg [3:0] ERxSM;
localparam ERxRS=0, ERxS0=1, ERxS1=2, ERxWS=3, ERxRX0=4, ERxRX1=5, ERxCS=6;
reg [31:0] Dreg, Rreg, RRreg;

logic TxFIFOEmpty, RxFIFOEmpty;
logic [2:0] Tlength;
logic [7:0] TxUsed, RxUsed;
logic [24:0] StatCnt;
logic [32:0] TXbus;
logic [35:0] RXbus;


assign Aligned=Rreg;
//1010_1101_1101_1110_0111_1011_1011_0101
//ADDE7BB5
//ADDF00B5

dcfifo_mixed_widths	TxFIFO(.aclr(~RST | ~ENA), .data(TXD), .rdclk(Tclk), .rdreq(TEnaFlag), .wrclk(CLK), .wrreq(TXSTB), .q(TXbus),
							.eccstatus(), .rdempty(TxFIFOEmpty), .rdfull(), .rdusedw(TxUsed), .wrempty(), .wrfull(), .wrusedw());
	defparam
		TxFIFO.lpm_numwords = 256,
		TxFIFO.lpm_showahead = "ON",
		TxFIFO.lpm_type = "dcfifo",
		TxFIFO.lpm_width = 33,
		TxFIFO.lpm_widthu = 8,
		TxFIFO.lpm_widthu_r = 8,
		TxFIFO.lpm_width_r = 33,
		TxFIFO.overflow_checking = "ON",
		TxFIFO.rdsync_delaypipe = 4,
		TxFIFO.read_aclr_synch = "ON",
		TxFIFO.underflow_checking = "ON",
		TxFIFO.use_eab = "ON",
		TxFIFO.write_aclr_synch = "ON",
		TxFIFO.wrsync_delaypipe = 4;

dcfifo_mixed_widths	RxFIFO(.aclr(~RST | ~ENA), .data({Rcntr+1'b1,ERxWSFlag,RRreg}), .rdclk(CLK),
							.rdreq((RXSTB & (~RxFIFOEmpty & ~(~RxFIFOEmpty & RXbus[32] & (RxUsed<={5'd0,RXbus[35:33]})))) | (~RxFIFOEmpty & RXbus[32] & (RxUsed>{5'd0,RXbus[35:33]}))),
							.wrclk(Rclk), .wrreq(ERxWWFlag|ERxWSFlag), .q(RXbus), .eccstatus(), .rdempty(RxFIFOEmpty), .rdfull(), .rdusedw(RxUsed), .wrempty(), .wrfull(), .wrusedw());
	defparam
		RxFIFO.lpm_numwords = 256,
		RxFIFO.lpm_showahead = "ON",
		RxFIFO.lpm_type = "dcfifo",
		RxFIFO.lpm_width = 36,
		RxFIFO.lpm_widthu = 8,
		RxFIFO.lpm_widthu_r = 8,
		RxFIFO.lpm_width_r = 36,
		RxFIFO.overflow_checking = "ON",
		RxFIFO.rdsync_delaypipe = 4,
		RxFIFO.read_aclr_synch = "ON",
		RxFIFO.underflow_checking = "ON",
		RxFIFO.use_eab = "ON",
		RxFIFO.write_aclr_synch = "ON",
		RxFIFO.wrsync_delaypipe = 4;
		
always_comb
begin

case (TXbus[18:16])
	3'd0:	case (TXbus[23:22])
				2'd0:	Tlength=3'd3;
				2'd1:	Tlength=3'd3;
				2'd2:	Tlength=3'd4;
				2'd3:	Tlength=3'd5;
				endcase
	3'd1:	Tlength=3'd3;
	3'd2:	case (TXbus[23:22])
				2'd0:	Tlength=3'd1;
				2'd1:	Tlength=3'd1;
				2'd2:	Tlength=3'd2;
				2'd3:	Tlength=3'd3;
				endcase
	3'd3:	Tlength=3'd1;
	3'd4:	Tlength=3'd4;
	3'd5:	Tlength=3'd1;
	3'd6:	case (TXbus[23:22])
				2'd0:	Tlength=3'd1;
				2'd1:	Tlength=3'd1;
				2'd2:	Tlength=3'd1;
				2'd3:	Tlength=3'd2;
				endcase
	3'd7:	Tlength=0;
	endcase

end


/*
				Internal clock
*/
always_ff @(posedge CLK or negedge RST)
if (~RST)
	begin
	RXSTB<=0;
	RXD<=0;
	STATUS<=0;
	end
else begin

RXSTB<=(RXSTB & (~RxFIFOEmpty & ~(~RxFIFOEmpty & RXbus[32] & (RxUsed<={5'd0,RXbus[35:33]})))) | (~RxFIFOEmpty & RXbus[32] & (RxUsed>{5'd0,RXbus[35:33]}));
RXD<=RXbus[32:0];

STATUS<=StatReg;

end


/*
			Receive clock domain
*/
always_ff @(posedge Rclk or negedge RST)
if (~RST)
	begin
	SPar<=0;
	ERxSM<=ERxRS;
	Rcntr<=0;
	ERxWSFlag<=0;
	StatReg<=0;
	StatCnt<=0;
	RX<=1'b0;
	end
else begin

if ((ERxSM==ERxS0)&(Rreg!=32'hADDF00B5)) SPar<=SPar+1'b1;

Dreg<=Rdata;
case (SPar)
	5'd0:	Rreg<=Rdata;
	5'd1:	Rreg<={Rdata[30:0],Dreg[31]};
	5'd2:	Rreg<={Rdata[29:0],Dreg[31:30]};
	5'd3:	Rreg<={Rdata[28:0],Dreg[31:29]};
	5'd4:	Rreg<={Rdata[27:0],Dreg[31:28]};
	5'd5:	Rreg<={Rdata[26:0],Dreg[31:27]};
	5'd6:	Rreg<={Rdata[25:0],Dreg[31:26]};
	5'd7:	Rreg<={Rdata[24:0],Dreg[31:25]};
	5'd8:	Rreg<={Rdata[23:0],Dreg[31:24]};
	5'd9:	Rreg<={Rdata[22:0],Dreg[31:23]};
	5'd10:	Rreg<={Rdata[21:0],Dreg[31:22]};
	5'd11:	Rreg<={Rdata[20:0],Dreg[31:21]};
	5'd12:	Rreg<={Rdata[19:0],Dreg[31:20]};
	5'd13:	Rreg<={Rdata[18:0],Dreg[31:19]};
	5'd14:	Rreg<={Rdata[17:0],Dreg[31:18]};
	5'd15:	Rreg<={Rdata[16:0],Dreg[31:17]};
	5'd16:	Rreg<={Rdata[15:0],Dreg[31:16]};
	5'd17:	Rreg<={Rdata[14:0],Dreg[31:15]};
	5'd18:	Rreg<={Rdata[13:0],Dreg[31:14]};
	5'd19:	Rreg<={Rdata[12:0],Dreg[31:13]};
	5'd20:	Rreg<={Rdata[11:0],Dreg[31:12]};
	5'd21:	Rreg<={Rdata[10:0],Dreg[31:11]};
	5'd22:	Rreg<={Rdata[09:0],Dreg[31:10]};
	5'd23:	Rreg<={Rdata[08:0],Dreg[31:09]};
	5'd24:	Rreg<={Rdata[07:0],Dreg[31:08]};
	5'd25:	Rreg<={Rdata[06:0],Dreg[31:07]};
	5'd26:	Rreg<={Rdata[05:0],Dreg[31:06]};
	5'd27:	Rreg<={Rdata[04:0],Dreg[31:05]};
	5'd28:	Rreg<={Rdata[03:0],Dreg[31:04]};
	5'd29:	Rreg<={Rdata[02:0],Dreg[31:03]};
	5'd30:	Rreg<={Rdata[01:0],Dreg[31:02]};
	5'd31:	Rreg<={Rdata[0],Dreg[31:01]};
	endcase

// state machine
if (~ENA) ERxSM<=ERxRS;
	else case (ERxSM)
			ERxRS:		ERxSM<=ERxS0;
			// search synchro
			ERxS0:		if (Rreg==32'hADDF00B5) ERxSM<=ERxWS;
							else ERxSM<=ERxS1;
			ERxS1:		ERxSM<=ERxS0;
			// if synchro found then check for packets
			ERxWS:		if (Rreg==32'hADDF00B5) ERxSM<=ERxWS;
							else if (Rreg==32'hADDF004A) ERxSM<=ERxRX0;
								else ERxSM<=ERxS0;
			// receive frame
			ERxRX0:		if (&Rreg[18:16]) ERxSM<=ERxCS;
							else ERxSM<=ERxRX1;
			ERxRX1:		if (|Rcntr) ERxSM<=ERxRX1;
							else ERxSM<=ERxCS;
			// check end state
			ERxCS:		if (Rreg==32'hADDF00B5) ERxSM<=ERxWS;
							else if (Rreg==32'hADDF004A) ERxSM<=ERxRX0;
									else ERxSM<=ERxS0;
			endcase

// status
StatReg<=(ERxSM!=ERxRS)&(ERxSM!=ERxS0)&(ERxSM!=ERxS1) & &StatCnt;

if ((ERxSM==ERxS1)|(ERxSM==ERxRS)|(ERxSM==ERxS0)) StatCnt<=0;
	else if (~&StatCnt) StatCnt<=StatCnt+1'b1;

RRreg<=Rreg;
ERxWSFlag<=ERxSM==ERxRX0;
ERxWWFlag<=ERxSM==ERxRX1;

if ((ERxSM==ERxRX1)&(|Rcntr)) Rcntr<=Rcntr-1'b1;
	else case (Rreg[18:16])
			3'd0:	case (Rreg[23:22])
						2'd0:	Rcntr<=3'd2;
						2'd1:	Rcntr<=3'd2;
						2'd2:	Rcntr<=3'd3;
						2'd3:	Rcntr<=3'd4;
						endcase
			3'd1:	Rcntr<=3'd2;
			3'd2:	case (Rreg[23:22])
						2'd0:	Rcntr<=3'd0;
						2'd1:	Rcntr<=3'd0;
						2'd2:	Rcntr<=3'd1;
						2'd3:	Rcntr<=3'd2;
						endcase
			3'd3:	Rcntr<=3'd0;
			3'd4:	Rcntr<=3'd3;
			3'd5:	Rcntr<=3'd0;
			3'd6:	case (Rreg[23:22])
						2'd0:	Rcntr<=3'd0;
						2'd1:	Rcntr<=3'd0;
						2'd2:	Rcntr<=3'd0;
						2'd3:	Rcntr<=3'd1;
						endcase
			3'd7:	Rcntr<=0;
			endcase

// create receive state
RX<=(RX & ~((ERxSM==ERxRX0) & &Rreg[18:16]) & ~((ERxSM==ERxRX1) & ~|Rcntr)) | (((ERxSM==ERxWS)|(ERxSM==ERxCS)) & (Rreg==32'hADDF004A));

end


/*
			Transmit clock domain
*/
always_ff @(posedge Tclk or negedge RST)
if (~RST)
	begin
	Tdata<=32'hADDF00B5;
	Tcntr<=0;
	TEnaFlag<=0;
	TX<=1'b0;
	end
else begin

if (~TxFIFOEmpty & TXbus[32] & (TxUsed>{5'd0,Tlength}) & ~TEnaFlag) Tcntr<=Tlength;
	else if (|Tcntr) Tcntr<=Tcntr-1'b1;

TEnaFlag<=(TEnaFlag & |Tcntr)|(~TxFIFOEmpty & TXbus[32] & (TxUsed>{5'd0,Tlength}) & ~TEnaFlag);

Tdata<=TEnaFlag ? TXbus[31:0] : {24'hADDF00, 8'hB5^{8{~TxFIFOEmpty & TXbus[32] & (TxUsed>{5'd0,Tlength}) & ~TEnaFlag}}};

// create transmit flag
TX<=TEnaFlag;

end

endmodule
