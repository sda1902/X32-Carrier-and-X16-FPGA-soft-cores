module Timer (
	input wire CLK, RESET,
	output reg INTR,
	// ISI
	input wire ACT,
	input wire [7:0] BE,
	input wire [63:0] DI,
	// output
	output reg ENA, AR, SEL,
	output reg [23:0] Sclr,
	output reg [31:0] TCNTR
	);

reg [23:0] CCntr;
reg [23:0] Scaler;
logic [31:0] TBus;

always_comb
begin

TBus=TCNTR+31'd1;

end

always_ff @(posedge CLK or negedge RESET)
begin
if (~RESET)
	begin
	// system reset
	CCntr<=0;
	Scaler<=0;
	Sclr<=0;
	TCNTR<=0;
	SEL<=0;
	ENA<=0;
	AR<=0;
	INTR<=0;
	end
else begin

Sclr<=SEL ? Scaler : CCntr;

// main counter
if (ENA & ((CCntr!=Scaler) | AR)) CCntr<=(CCntr+24'd1) & {24{(CCntr!=Scaler) & (~ACT | (&BE[2:0]))}};

// scaler
if (ACT & ~BE[0]) Scaler[7:0]<=DI[7:0];
if (ACT & ~BE[1]) Scaler[15:8]<=DI[15:8];
if (ACT & ~BE[2]) Scaler[23:16]<=DI[23:16];

// enable and autoreload flags
if (ACT & ~BE[3])
	begin
	SEL<=DI[29];
	AR<=DI[30];
	ENA<=DI[31];
	end

// tick counter
if ((ACT & ~BE[4]) | ((CCntr==Scaler) & AR)) TCNTR[7:0]<=(ACT & ~BE[4]) ? DI[39:32] : TBus[7:0];
if ((ACT & ~BE[5]) | ((CCntr==Scaler) & AR)) TCNTR[15:8]<=(ACT & ~BE[5]) ? DI[47:40] : TBus[15:8];
if ((ACT & ~BE[6]) | ((CCntr==Scaler) & AR)) TCNTR[23:16]<=(ACT & ~BE[6]) ? DI[55:48] : TBus[23:16];
if ((ACT & ~BE[7]) | ((CCntr==Scaler) & AR)) TCNTR[31:24]<=(ACT & ~BE[7]) ? DI[63:56] : TBus[31:24];

// interrupt generation
INTR<=(CCntr==(Scaler-24'd1)) & (&TCNTR[6:0]);

end
end

endmodule
