module Sequencer32 (
		input wire CLK, RESET,
		input wire IRDY,
		input wire [3:0] VF,
		input wire [127:0] IBUS,
		output wire IRD,
		input wire [31:0] GPRVF,
		output wire [31:0] GPRINVD,
		output wire EMPTY,
		output wire MOVFLAG,
		input wire FDIVRDY,
		input wire FMULACCRDY,
		input wire MEMRDY,
		// instructions to the execute units
		output wire [26:0] FADDBus,
		output wire [26:0] FMULBus,
		output wire [25:0] FMULACCBus,
		output wire [26:0] FDIVBus,
		output wire [27:0] ALUBus,
		output wire [28:0] ShiftBus,
		output wire [27:0] MiscBus,
		output wire [27:0] MovBus,
		output wire [28:0] MemBus,
		output wire [28:0] CtrlBus
		);

integer i0,i1,i2,i3,i4,i5,i6,i7,i8,i9,i10,i11,i12,i13,i14,i15,i16,i17,i18,i19;
integer j0,j1;

reg [31:0] InstReg [7:0];	// instruction register
reg [10:0] TypeReg [7:0]; 	// instruction types
reg [31:0] GPRInvdR [7:0];		// invalidation flags
reg [7:0] VFReg;

logic [26:0] FADDBusWire;		// 0-ACT, 1-CMD[0], 6:2-SRC1, 9:7-Size1, 14:10-SRC2, 17:15-Size2, 22:18-DST, 25:23-SizeDST, 26-CMD[1]
logic [26:0] FMULBusWire;		// 0-ACT, 2:1-CMD, 7:3-SRC1, 10:8-Size1, 15:11-SRC2, 18:16-Size2, 23:19-DST, 26:24-SizeDST
logic [25:0] FMULACCBusWire;	// 0-ACT, 1-CMD, 6:2-SRCC, 9:7-MARC, 14:10-SRCD, 17:15-MARD, 22:18-DST, 25:23-Format
logic [26:0] FDIVBusWire;		// 0-ACT, 2:1-CMD, 7:3-SRC1, 10:8-Size1, 15:11-SRC2, 18:16-Size2, 23:19-DST, 26:24-SizeDST
logic [27:0] ALUBusWire;		// 0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
logic [28:0] ShiftBusWire;		// 0-ACT, 4:1-CMD, 9:5-SRC1, 12:10-Size1, 17:13-SRC2, 20:18-Size2, 25:21-DST, 28:26-SizeDST
logic [27:0] MiscBusWire;		// 0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
logic [27:0] MovBusWire;		// 0-ACT, 3:1-CMD, 8:4-SRC1, 11:9-Size1, 16:12-SRC2, 19:17-Size2, 24:20-DST, 27:25-SizeDST
logic [28:0] MemBusWire;		// 0-ACT, 4:1-CMD, 9:5-Aditional offset, 12:10-AMODE, 17:13-Offset Register, 20:18-MAR, 25:21-DST/SRC, 28:26-Format
logic [28:0] CtrlBusWire;		// 0-ACT, 4:1-CMD, 20:5-Displacement, 25:21-DSTR/SRC, 28:26-CC

logic [255:0] InvdVector = {32'hFFFFFFFF, 32'hFFFFFF3D, 32'hFFFFFFFF, 32'hFFFCFDDD, 32'hFFFFFFFF, 32'hFF008000, 32'hFFFFFFFF, 32'hF0000000};
logic [255:0] NopVector = {32'hFFFFFFFF, 32'hFFFFC000, 32'hFFFFFFFF, 32'hFFFCE000, 32'hFFFFFFFF, 32'hFF008000, 32'hFFFFFFFF, 32'hF0000000};
logic [255:0] Op0Vector = {32'h00000000, 32'h00000000, 32'h00000000, 32'h00030000, 32'h00000000, 32'h002F7BFF, 32'h00000000, 32'h0DEFFFFF};
logic [255:0] Op1Vector = {32'h00000000, 32'h00000000, 32'h00000000, 32'h00031103, 32'h00000000, 32'h00000080, 32'h00000000, 32'h05EFFFFF};
logic [255:0] Op2Vector = {32'h00000000, 32'h000000FF, 32'h00000000, 32'h00030233, 32'h00000000, 32'h002F7FFF, 32'h00000000, 32'h0DEFFFFF};

logic [2:0] OpReg [7:0];
logic InstReloadWire, HalfReloadWire;
logic [7:0] LockNode, VFResetWire;
logic [31:0] InvdBus;

reg I1SRC1_I0DST, I1SRC2_I0DST, I1DST_I0SRC1, I1DST_I0SRC2, I1DST_I0DST;

reg I2SRC1_I1DST, I2SRC2_I1DST, I2DST_I1SRC1, I2DST_I1SRC2, I2DST_I1DST,
	I2SRC1_I0DST, I2SRC2_I0DST, I2DST_I0SRC1, I2DST_I0SRC2, I2DST_I0DST;

reg	I3SRC1_I2DST, I3SRC2_I2DST, I3DST_I2SRC1, I3DST_I2SRC2, I3DST_I2DST,
	I3SRC1_I1DST, I3SRC2_I1DST, I3DST_I1SRC1, I3DST_I1SRC2, I3DST_I1DST,
	I3SRC1_I0DST, I3SRC2_I0DST, I3DST_I0SRC1, I3DST_I0SRC2, I3DST_I0DST;

reg	I4SRC1_I3DST, I4SRC2_I3DST, I4DST_I3SRC1, I4DST_I3SRC2, I4DST_I3DST,
	I4SRC1_I2DST, I4SRC2_I2DST, I4DST_I2SRC1, I4DST_I2SRC2, I4DST_I2DST,
	I4SRC1_I1DST, I4SRC2_I1DST, I4DST_I1SRC1, I4DST_I1SRC2, I4DST_I1DST,
	I4SRC1_I0DST, I4SRC2_I0DST, I4DST_I0SRC1, I4DST_I0SRC2, I4DST_I0DST;

reg	I5SRC1_I4DST, I5SRC2_I4DST, I5DST_I4SRC1, I5DST_I4SRC2, I5DST_I4DST,
	I5SRC1_I3DST, I5SRC2_I3DST, I5DST_I3SRC1, I5DST_I3SRC2, I5DST_I3DST,
	I5SRC1_I2DST, I5SRC2_I2DST, I5DST_I2SRC1, I5DST_I2SRC2, I5DST_I2DST,
	I5SRC1_I1DST, I5SRC2_I1DST, I5DST_I1SRC1, I5DST_I1SRC2, I5DST_I1DST,
	I5SRC1_I0DST, I5SRC2_I0DST, I5DST_I0SRC1, I5DST_I0SRC2, I5DST_I0DST;

reg	I6SRC1_I5DST, I6SRC2_I5DST, I6DST_I5SRC1, I6DST_I5SRC2, I6DST_I5DST,
	I6SRC1_I4DST, I6SRC2_I4DST, I6DST_I4SRC1, I6DST_I4SRC2, I6DST_I4DST,
	I6SRC1_I3DST, I6SRC2_I3DST, I6DST_I3SRC1, I6DST_I3SRC2, I6DST_I3DST,
	I6SRC1_I2DST, I6SRC2_I2DST, I6DST_I2SRC1, I6DST_I2SRC2, I6DST_I2DST,
	I6SRC1_I1DST, I6SRC2_I1DST, I6DST_I1SRC1, I6DST_I1SRC2, I6DST_I1DST,
	I6SRC1_I0DST, I6SRC2_I0DST, I6DST_I0SRC1, I6DST_I0SRC2, I6DST_I0DST;

reg	I7SRC1_I6DST, I7SRC2_I6DST, I7DST_I6SRC1, I7DST_I6SRC2, I7DST_I6DST,
	I7SRC1_I5DST, I7SRC2_I5DST, I7DST_I5SRC1, I7DST_I5SRC2, I7DST_I5DST,
	I7SRC1_I4DST, I7SRC2_I4DST, I7DST_I4SRC1, I7DST_I4SRC2, I7DST_I4DST,
	I7SRC1_I3DST, I7SRC2_I3DST, I7DST_I3SRC1, I7DST_I3SRC2, I7DST_I3DST, 
	I7SRC1_I2DST, I7SRC2_I2DST, I7DST_I2SRC1, I7DST_I2SRC2, I7DST_I2DST,
	I7SRC1_I1DST, I7SRC2_I1DST, I7DST_I1SRC1, I7DST_I1SRC2, I7DST_I1DST,
	I7SRC1_I0DST, I7SRC2_I0DST, I7DST_I0SRC1, I7DST_I0SRC2, I7DST_I0DST;


/*
====================================================================================================
				 	Asynchronous part
====================================================================================================
*/

assign FADDBus=FADDBusWire;
assign FMULBus=FMULBusWire;
assign FMULACCBus=FMULACCBusWire;
assign FDIVBus=FDIVBusWire;
assign ALUBus=ALUBusWire;
assign ShiftBus=ShiftBusWire;
assign MiscBus=MiscBusWire;
assign MovBus=MovBusWire;
assign MemBus=MemBusWire;
assign CtrlBus=CtrlBusWire;
assign GPRINVD=InvdBus;
assign IRD=InstReloadWire | HalfReloadWire;
// empty flag
assign EMPTY=~(|VFReg);
// movement present
assign MOVFLAG=TypeReg[0][7] | TypeReg[1][7] | TypeReg[2][7] | TypeReg[3][7] | TypeReg[4][7] | TypeReg[5][7] | TypeReg[6][7] | TypeReg[7][7];

always_comb
	begin

	// Lock nodes
	LockNode[0]=(~GPRVF[InstReg[0][12:8]] & OpReg[0][0])|
				(~GPRVF[InstReg[0][20:16]] & OpReg[0][1])|
				(~GPRVF[InstReg[0][28:24]] & OpReg[0][2]);

	LockNode[1]=(~GPRVF[InstReg[1][12:8]] & OpReg[1][0])|
				(~GPRVF[InstReg[1][20:16]] & OpReg[1][1])|
				(~GPRVF[InstReg[1][28:24]] & OpReg[1][2])|				
				(I1SRC1_I0DST & OpReg[1][0] & OpReg[0][2] & VFReg[0])|
				(I1SRC2_I0DST & OpReg[1][1] & OpReg[0][2] & VFReg[0])|
				(I1DST_I0SRC1 & OpReg[1][2] & OpReg[0][0] & VFReg[0])|
				(I1DST_I0SRC2 & OpReg[1][2] & OpReg[0][1] & VFReg[0])|
				(I1DST_I0DST & OpReg[1][2] & OpReg[0][2] & VFReg[0]);

	LockNode[2]=(~GPRVF[InstReg[2][12:8]] & OpReg[2][0])|
				(~GPRVF[InstReg[2][20:16]] & OpReg[2][1])|
				(~GPRVF[InstReg[2][28:24]] & OpReg[2][2])|
				(I2SRC1_I1DST & OpReg[2][0] & OpReg[1][2] & VFReg[1])|
				(I2SRC2_I1DST & OpReg[2][1] & OpReg[1][2] & VFReg[1])|
				(I2DST_I1SRC1 & OpReg[2][2] & OpReg[1][0] & VFReg[1])|
				(I2DST_I1SRC2 & OpReg[2][2] & OpReg[1][1] & VFReg[1])|
				(I2DST_I1DST & OpReg[2][2] & OpReg[1][2] & VFReg[1])|
				(I2SRC1_I0DST & OpReg[2][0] & OpReg[0][2] & VFReg[0])|
				(I2SRC2_I0DST & OpReg[2][1] & OpReg[0][2] & VFReg[0])|
				(I2DST_I0SRC1 & OpReg[2][2] & OpReg[0][0] & VFReg[0])|
				(I2DST_I0SRC2 & OpReg[2][2] & OpReg[0][1] & VFReg[0])|
				(I2DST_I0DST & OpReg[2][2] & OpReg[0][2] & VFReg[0]);

	LockNode[3]=(~GPRVF[InstReg[3][12:8]] & OpReg[3][0])|
				(~GPRVF[InstReg[3][20:16]] & OpReg[3][1])|
				(~GPRVF[InstReg[3][28:24]] & OpReg[3][2])|
				(I3SRC1_I2DST & OpReg[3][0] & OpReg[2][2] & VFReg[2])|
				(I3SRC2_I2DST & OpReg[3][1] & OpReg[2][2] & VFReg[2])|
				(I3DST_I2SRC1 & OpReg[3][2] & OpReg[2][0] & VFReg[2])|
				(I3DST_I2SRC2 & OpReg[3][2] & OpReg[2][1] & VFReg[2])|
				(I3DST_I2DST & OpReg[3][2] & OpReg[2][2] & VFReg[2])|
				(I3SRC1_I1DST & OpReg[3][0] & OpReg[1][2] & VFReg[1])|
				(I3SRC2_I1DST & OpReg[3][1] & OpReg[1][2] & VFReg[1])|
				(I3DST_I1SRC1 & OpReg[3][2] & OpReg[1][0] & VFReg[1])|
				(I3DST_I1SRC2 & OpReg[3][2] & OpReg[1][1] & VFReg[1])|
				(I3DST_I1DST & OpReg[3][2] & OpReg[1][2] & VFReg[1])|
				(I3SRC1_I0DST & OpReg[3][0] & OpReg[0][2] & VFReg[0])|
				(I3SRC2_I0DST & OpReg[3][1] & OpReg[0][2] & VFReg[0])|
				(I3DST_I0SRC1 & OpReg[3][2] & OpReg[0][0] & VFReg[0])|
				(I3DST_I0SRC2 & OpReg[3][2] & OpReg[0][1] & VFReg[0])|
				(I3DST_I0DST & OpReg[3][2] & OpReg[0][2] & VFReg[0]);

	LockNode[4]=(~GPRVF[InstReg[4][12:8]] & OpReg[4][0])|
				(~GPRVF[InstReg[4][20:16]] & OpReg[4][1])|
				(~GPRVF[InstReg[4][28:24]] & OpReg[4][2])|
				(I4SRC1_I3DST & OpReg[4][0] & OpReg[3][2] & VFReg[3])|
				(I4SRC2_I3DST & OpReg[4][1] & OpReg[3][2] & VFReg[3])|
				(I4DST_I3SRC1 & OpReg[4][2] & OpReg[3][0] & VFReg[3])|
				(I4DST_I3SRC2 & OpReg[4][2] & OpReg[3][1] & VFReg[3])|
				(I4DST_I3DST & OpReg[4][2] & OpReg[3][2] & VFReg[3])|
				(I4SRC1_I2DST & OpReg[4][0] & OpReg[2][2] & VFReg[2])|
				(I4SRC2_I2DST & OpReg[4][1] & OpReg[2][2] & VFReg[2])|
				(I4DST_I2SRC1 & OpReg[4][2] & OpReg[2][0] & VFReg[2])|
				(I4DST_I2SRC2 & OpReg[4][2] & OpReg[2][1] & VFReg[2])|
				(I4DST_I2DST & OpReg[4][2] & OpReg[2][2] & VFReg[2])|
				(I4SRC1_I1DST & OpReg[4][0] & OpReg[1][2] & VFReg[1])|
				(I4SRC2_I1DST & OpReg[4][1] & OpReg[1][2] & VFReg[1])|
				(I4DST_I1SRC1 & OpReg[4][2] & OpReg[1][0] & VFReg[1])|
				(I4DST_I1SRC2 & OpReg[4][2] & OpReg[1][1] & VFReg[1])|
				(I4DST_I1DST & OpReg[4][2] & OpReg[1][2] & VFReg[1])|
				(I4SRC1_I0DST & OpReg[4][0] & OpReg[0][2] & VFReg[0])|
				(I4SRC2_I0DST & OpReg[4][1] & OpReg[0][2] & VFReg[0])|
				(I4DST_I0SRC1 & OpReg[4][2] & OpReg[0][0] & VFReg[0])|
				(I4DST_I0SRC2 & OpReg[4][2] & OpReg[0][1] & VFReg[0])|
				(I4DST_I0DST & OpReg[4][2] & OpReg[0][2] & VFReg[0]);

	LockNode[5]=(~GPRVF[InstReg[5][12:8]] & OpReg[5][0])|
				(~GPRVF[InstReg[5][20:16]] & OpReg[5][1])|
				(~GPRVF[InstReg[5][28:24]] & OpReg[5][2])|
				(I5SRC1_I4DST & OpReg[5][0] & OpReg[4][2] & VFReg[4])|
				(I5SRC2_I4DST & OpReg[5][1] & OpReg[4][2] & VFReg[4])|
				(I5DST_I4SRC1 & OpReg[5][2] & OpReg[4][0] & VFReg[4])|
				(I5DST_I4SRC2 & OpReg[5][2] & OpReg[4][1] & VFReg[4])|
				(I5DST_I4DST & OpReg[5][2] & OpReg[4][2] & VFReg[4])|
				(I5SRC1_I3DST & OpReg[5][0] & OpReg[3][2] & VFReg[3])|
				(I5SRC2_I3DST & OpReg[5][1] & OpReg[3][2] & VFReg[3])|
				(I5DST_I3SRC1 & OpReg[5][2] & OpReg[3][0] & VFReg[3])|
				(I5DST_I3SRC2 & OpReg[5][2] & OpReg[3][1] & VFReg[3])|
				(I5DST_I3DST & OpReg[5][2] & OpReg[3][2] & VFReg[3])|
				(I5SRC1_I2DST & OpReg[5][0] & OpReg[2][2] & VFReg[2])|
				(I5SRC2_I2DST & OpReg[5][1] & OpReg[2][2] & VFReg[2])|
				(I5DST_I2SRC1 & OpReg[5][2] & OpReg[2][0] & VFReg[2])|
				(I5DST_I2SRC2 & OpReg[5][2] & OpReg[2][1] & VFReg[2])|
				(I5DST_I2DST & OpReg[5][2] & OpReg[2][2] & VFReg[2])|
				(I5SRC1_I1DST & OpReg[5][0] & OpReg[1][2] & VFReg[1])|
				(I5SRC2_I1DST & OpReg[5][1] & OpReg[1][2] & VFReg[1])|
				(I5DST_I1SRC1 & OpReg[5][2] & OpReg[1][0] & VFReg[1])|
				(I5DST_I1SRC2 & OpReg[5][2] & OpReg[1][1] & VFReg[1])|
				(I5DST_I1DST & OpReg[5][2] & OpReg[1][2] & VFReg[1])|
				(I5SRC1_I0DST & OpReg[5][0] & OpReg[0][2] & VFReg[0])|
				(I5SRC2_I0DST & OpReg[5][1] & OpReg[0][2] & VFReg[0])|
				(I5DST_I0SRC1 & OpReg[5][2] & OpReg[0][0] & VFReg[0])|
				(I5DST_I0SRC2 & OpReg[5][2] & OpReg[0][1] & VFReg[0])|
				(I5DST_I0DST & OpReg[5][2] & OpReg[0][2] & VFReg[0]);

	LockNode[6]=(~GPRVF[InstReg[6][12:8]] & OpReg[6][0])|
				(~GPRVF[InstReg[6][20:16]] & OpReg[6][1])|
				(~GPRVF[InstReg[6][28:24]] & OpReg[6][2])|
				(I6SRC1_I5DST & OpReg[6][0] & OpReg[5][2] & VFReg[5])|
				(I6SRC2_I5DST & OpReg[6][1] & OpReg[5][2] & VFReg[5])|
				(I6DST_I5SRC1 & OpReg[6][2] & OpReg[5][0] & VFReg[5])|
				(I6DST_I5SRC2 & OpReg[6][2] & OpReg[5][1] & VFReg[5])|
				(I6DST_I5DST & OpReg[6][2] & OpReg[5][2] & VFReg[5])|
				(I6SRC1_I4DST & OpReg[6][0] & OpReg[4][2] & VFReg[4])|
				(I6SRC2_I4DST & OpReg[6][1] & OpReg[4][2] & VFReg[4])|
				(I6DST_I4SRC1 & OpReg[6][2] & OpReg[4][0] & VFReg[4])|
				(I6DST_I4SRC2 & OpReg[6][2] & OpReg[4][1] & VFReg[4])|
				(I6DST_I4DST & OpReg[6][2] & OpReg[4][2] & VFReg[4])|
				(I6SRC1_I3DST & OpReg[6][0] & OpReg[3][2] & VFReg[3])|
				(I6SRC2_I3DST & OpReg[6][1] & OpReg[3][2] & VFReg[3])|
				(I6DST_I3SRC1 & OpReg[6][2] & OpReg[3][0] & VFReg[3])|
				(I6DST_I3SRC2 & OpReg[6][2] & OpReg[3][1] & VFReg[3])|
				(I6DST_I3DST & OpReg[6][2] & OpReg[3][2] & VFReg[3])|
				(I6SRC1_I2DST & OpReg[6][0] & OpReg[2][2] & VFReg[2])|
				(I6SRC2_I2DST & OpReg[6][1] & OpReg[2][2] & VFReg[2])|
				(I6DST_I2SRC1 & OpReg[6][2] & OpReg[2][0] & VFReg[2])|
				(I6DST_I2SRC2 & OpReg[6][2] & OpReg[2][1] & VFReg[2])|
				(I6DST_I2DST & OpReg[6][2] & OpReg[2][2] & VFReg[2])|
				(I6SRC1_I1DST & OpReg[6][0] & OpReg[1][2] & VFReg[1])|
				(I6SRC2_I1DST & OpReg[6][1] & OpReg[1][2] & VFReg[1])|
				(I6DST_I1SRC1 & OpReg[6][2] & OpReg[1][0] & VFReg[1])|
				(I6DST_I1SRC2 & OpReg[6][2] & OpReg[1][1] & VFReg[1])|
				(I6DST_I1DST & OpReg[6][2] & OpReg[1][2] & VFReg[1])|
				(I6SRC1_I0DST & OpReg[6][0] & OpReg[0][2] & VFReg[0])|
				(I6SRC2_I0DST & OpReg[6][1] & OpReg[0][2] & VFReg[0])|
				(I6DST_I0SRC1 & OpReg[6][2] & OpReg[0][0] & VFReg[0])|
				(I6DST_I0SRC2 & OpReg[6][2] & OpReg[0][1] & VFReg[0])|
				(I6DST_I0DST & OpReg[6][2] & OpReg[0][2] & VFReg[0]);

	LockNode[7]=(~GPRVF[InstReg[7][12:8]] & OpReg[7][0])|
				(~GPRVF[InstReg[7][20:16]] & OpReg[7][1])|
				(~GPRVF[InstReg[7][28:24]] & OpReg[7][2])|
				(I7SRC1_I6DST & OpReg[7][0] & OpReg[6][2] & VFReg[6])|
				(I7SRC2_I6DST & OpReg[7][1] & OpReg[6][2] & VFReg[6])|
				(I7DST_I6SRC1 & OpReg[7][2] & OpReg[6][0] & VFReg[6])|
				(I7DST_I6SRC2 & OpReg[7][2] & OpReg[6][1] & VFReg[6])|
				(I7DST_I6DST & OpReg[7][2] & OpReg[6][2] & VFReg[6])|
				(I7SRC1_I5DST & OpReg[7][0] & OpReg[5][2] & VFReg[5])|
				(I7SRC2_I5DST & OpReg[7][1] & OpReg[5][2] & VFReg[5])|
				(I7DST_I5SRC1 & OpReg[7][2] & OpReg[5][0] & VFReg[5])|
				(I7DST_I5SRC2 & OpReg[7][2] & OpReg[5][1] & VFReg[5])|
				(I7DST_I5DST & OpReg[7][2] & OpReg[5][2] & VFReg[5])|
				(I7SRC1_I4DST & OpReg[7][0] & OpReg[4][2] & VFReg[4])|
				(I7SRC2_I4DST & OpReg[7][1] & OpReg[4][2] & VFReg[4])|
				(I7DST_I4SRC1 & OpReg[7][2] & OpReg[4][0] & VFReg[4])|
				(I7DST_I4SRC2 & OpReg[7][2] & OpReg[4][1] & VFReg[4])|
				(I7DST_I4DST & OpReg[7][2] & OpReg[4][2] & VFReg[4])|
				(I7SRC1_I3DST & OpReg[7][0] & OpReg[3][2] & VFReg[3])|
				(I7SRC2_I3DST & OpReg[7][1] & OpReg[3][2] & VFReg[3])|
				(I7DST_I3SRC1 & OpReg[7][2] & OpReg[3][0] & VFReg[3])|
				(I7DST_I3SRC2 & OpReg[7][2] & OpReg[3][1] & VFReg[3])|
				(I7DST_I3DST & OpReg[7][2] & OpReg[3][2] & VFReg[3])|
				(I7SRC1_I2DST & OpReg[7][0] & OpReg[2][2] & VFReg[2])|
				(I7SRC2_I2DST & OpReg[7][1] & OpReg[2][2] & VFReg[2])|
				(I7DST_I2SRC1 & OpReg[7][2] & OpReg[2][0] & VFReg[2])|
				(I7DST_I2SRC2 & OpReg[7][2] & OpReg[2][1] & VFReg[2])|
				(I7DST_I2DST & OpReg[7][2] & OpReg[2][2] & VFReg[2])|
				(I7SRC1_I1DST & OpReg[7][0] & OpReg[1][2] & VFReg[1])|
				(I7SRC2_I1DST & OpReg[7][1] & OpReg[1][2] & VFReg[1])|
				(I7DST_I1SRC1 & OpReg[7][2] & OpReg[1][0] & VFReg[1])|
				(I7DST_I1SRC2 & OpReg[7][2] & OpReg[1][1] & VFReg[1])|
				(I7DST_I1DST & OpReg[7][2] & OpReg[1][2] & VFReg[1])|
				(I7SRC1_I0DST & OpReg[7][0] & OpReg[0][2] & VFReg[0])|
				(I7SRC2_I0DST & OpReg[7][1] & OpReg[0][2] & VFReg[0])|
				(I7DST_I0SRC1 & OpReg[7][2] & OpReg[0][0] & VFReg[0])|
				(I7DST_I0SRC2 & OpReg[7][2] & OpReg[0][1] & VFReg[0])|
				(I7DST_I0DST & OpReg[7][2] & OpReg[0][2] & VFReg[0]);
	//=============================================================================================
	//
	// Instruction patch for FADD unit
	//
	FADDBusWire[0]=(TypeReg[0][0] & ~LockNode[0])|(TypeReg[1][0] & ~LockNode[1])|
					(TypeReg[2][0] & ~LockNode[2])|(TypeReg[3][0] & ~LockNode[3])|
					(TypeReg[4][0] & ~LockNode[4])|(TypeReg[5][0] & ~LockNode[5])|
					(TypeReg[6][0] & ~LockNode[6])|(TypeReg[7][0] & ~LockNode[7]);
	FADDBusWire[1]=(InstReg[0][0] & TypeReg[0][0] & ~LockNode[0])|
					(InstReg[1][0] & TypeReg[1][0] & ~LockNode[1] & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[2][0] & TypeReg[2][0] & ~LockNode[2] & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[3][0] & TypeReg[3][0] & ~LockNode[3] & (~TypeReg[2][0] | LockNode[2]) &
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[4][0] & TypeReg[4][0] & ~LockNode[4] & (~TypeReg[3][0] | LockNode[3]) &
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[5][0] & TypeReg[5][0] & ~LockNode[5] & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[6][0] & TypeReg[6][0] & ~LockNode[6] & (~TypeReg[5][0] | LockNode[5]) &
							(~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) & 
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[7][0] & TypeReg[7][0] & ~LockNode[7] & (~TypeReg[6][0] | LockNode[6]) &
							(~TypeReg[5][0] | LockNode[5]) & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]));
	FADDBusWire[26]=(InstReg[0][1] & TypeReg[0][0] & ~LockNode[0])|
					(InstReg[1][1] & TypeReg[1][0] & ~LockNode[1] & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[2][1] & TypeReg[2][0] & ~LockNode[2] & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[3][1] & TypeReg[3][0] & ~LockNode[3] & (~TypeReg[2][0] | LockNode[2]) &
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[4][1] & TypeReg[4][0] & ~LockNode[4] & (~TypeReg[3][0] | LockNode[3]) &
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[5][1] & TypeReg[5][0] & ~LockNode[5] & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[6][1] & TypeReg[6][0] & ~LockNode[6] & (~TypeReg[5][0] | LockNode[5]) &
							(~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) & 
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[7][1] & TypeReg[7][0] & ~LockNode[7] & (~TypeReg[6][0] | LockNode[6]) &
							(~TypeReg[5][0] | LockNode[5]) & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]));
	for (i0=0; i0<24; i0=i0+1)
		begin
		FADDBusWire[i0+2]=(InstReg[0][i0+8] & TypeReg[0][0] & ~LockNode[0])|
					(InstReg[1][i0+8] & TypeReg[1][0] & ~LockNode[1] & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[2][i0+8] & TypeReg[2][0] & ~LockNode[2] & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[3][i0+8] & TypeReg[3][0] & ~LockNode[3] & (~TypeReg[2][0] | LockNode[2]) &
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[4][i0+8] & TypeReg[4][0] & ~LockNode[4] & (~TypeReg[3][0] | LockNode[3]) &
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[5][i0+8] & TypeReg[5][0] & ~LockNode[5] & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(InstReg[6][i0+8] & TypeReg[6][0] & ~LockNode[6] & (~TypeReg[5][0] | LockNode[5]) &
							(~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) & 
							(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & 
							(~TypeReg[0][0] | LockNode[0]))|
					(InstReg[7][i0+8] & TypeReg[7][0] & ~LockNode[7] & (~TypeReg[6][0] | LockNode[6]) &
							(~TypeReg[5][0] | LockNode[5]) & (~TypeReg[4][0] | LockNode[4]) &
							(~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & 
							(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]));
		end

	//=============================================================================================
	//
	// Instruction patch for FMUL unit
	//
	FMULBusWire[0]=(TypeReg[0][1] & ~LockNode[0])|(TypeReg[1][1] & ~LockNode[1])|(TypeReg[2][1] & ~LockNode[2])|
					(TypeReg[3][1] & ~LockNode[3])|(TypeReg[4][1] & ~LockNode[4])|(TypeReg[5][1] & ~LockNode[5])|
					(TypeReg[6][1] & ~LockNode[6])|(TypeReg[7][1] & ~LockNode[7]);
	// instruction
	FMULBusWire[1]=(InstReg[0][0] & TypeReg[0][1] & ~LockNode[0])|
					(InstReg[1][0] & TypeReg[1][1] & ~LockNode[1] & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[2][0] & TypeReg[2][1] & ~LockNode[2] & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[3][0] & TypeReg[3][1] & ~LockNode[3] & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[4][0] & TypeReg[4][1] & ~LockNode[4] & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & 
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[5][0] & TypeReg[5][1] & ~LockNode[5] & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[6][0] & TypeReg[6][1] & ~LockNode[6] & (~TypeReg[5][1] | LockNode[5]) &
						(~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[7][0] & TypeReg[7][1] & ~LockNode[7] & (~TypeReg[6][1] | LockNode[6]) &
						(~TypeReg[5][1] | LockNode[5]) & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]));
	FMULBusWire[2]=(InstReg[0][4] & TypeReg[0][1] & ~LockNode[0])|
					(InstReg[1][4] & TypeReg[1][1] & ~LockNode[1] & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[2][4] & TypeReg[2][1] & ~LockNode[2] & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[3][4] & TypeReg[3][1] & ~LockNode[3] & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[4][4] & TypeReg[4][1] & ~LockNode[4] & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & 
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[5][4] & TypeReg[5][1] & ~LockNode[5] & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[6][4] & TypeReg[6][1] & ~LockNode[6] & (~TypeReg[5][1] | LockNode[5]) &
						(~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[7][4] & TypeReg[7][1] & ~LockNode[7] & (~TypeReg[6][1] | LockNode[6]) &
						(~TypeReg[5][1] | LockNode[5]) & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]));
	// parameters
	for (i1=0; i1<24; i1=i1+1)
		FMULBusWire[i1+3]=(InstReg[0][i1+8] & TypeReg[0][1] & ~LockNode[0])|
					(InstReg[1][i1+8] & TypeReg[1][1] & ~LockNode[1] & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[2][i1+8] & TypeReg[2][1] & ~LockNode[2] & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[3][i1+8] & TypeReg[3][1] & ~LockNode[3] & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[4][i1+8] & TypeReg[4][1] & ~LockNode[4] & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & 
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[5][i1+8] & TypeReg[5][1] & ~LockNode[5] & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(InstReg[6][i1+8] & TypeReg[6][1] & ~LockNode[6] & (~TypeReg[5][1] | LockNode[5]) &
						(~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) &
						(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) &
						(~TypeReg[0][1] | LockNode[0]))|
					(InstReg[7][i1+8] & TypeReg[7][1] & ~LockNode[7] & (~TypeReg[6][1] | LockNode[6]) &
						(~TypeReg[5][1] | LockNode[5]) & (~TypeReg[4][1] | LockNode[4]) &
						(~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
						(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]));
	
	//=============================================================================================
	//
	// Instruction patch for FDIV unit
	// 
	FDIVBusWire[0]=(TypeReg[0][2] & ~LockNode[0])|(TypeReg[1][2] & ~LockNode[1])|(TypeReg[2][2] & ~LockNode[2])|
					(TypeReg[3][2] & ~LockNode[3])|(TypeReg[4][2] & ~LockNode[4])|(TypeReg[5][2] & ~LockNode[5])|
					(TypeReg[6][2] & ~LockNode[6])|(TypeReg[7][2] & ~LockNode[7]);
	FDIVBusWire[1]=(InstReg[0][0] & TypeReg[0][2] & ~LockNode[0])|
					(InstReg[1][0] & TypeReg[1][2] & ~LockNode[1] & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[2][0] & TypeReg[2][2] & ~LockNode[2] & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[3][0] & TypeReg[3][2] & ~LockNode[3] & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[4][0] & TypeReg[4][2] & ~LockNode[4] & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & 
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[5][0] & TypeReg[5][2] & ~LockNode[5] & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[6][0] & TypeReg[6][2] & ~LockNode[6] & (~TypeReg[5][2] | LockNode[5]) &
						(~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[7][0] & TypeReg[7][2] & ~LockNode[7] & (~TypeReg[6][2] | LockNode[6]) &
						(~TypeReg[5][2] | LockNode[5]) & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]));
	FDIVBusWire[2]=(InstReg[0][4] & TypeReg[0][2] & ~LockNode[0])|
					(InstReg[1][4] & TypeReg[1][2] & ~LockNode[1] & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[2][4] & TypeReg[2][2] & ~LockNode[2] & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[3][4] & TypeReg[3][2] & ~LockNode[3] & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[4][4] & TypeReg[4][2] & ~LockNode[4] & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & 
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[5][4] & TypeReg[5][2] & ~LockNode[5] & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[6][4] & TypeReg[6][2] & ~LockNode[6] & (~TypeReg[5][2] | LockNode[5]) &
						(~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[7][4] & TypeReg[7][2] & ~LockNode[7] & (~TypeReg[6][2] | LockNode[6]) &
						(~TypeReg[5][2] | LockNode[5]) & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]));
	
	for (i3=0; i3<24; i3=i3+1) 
		FDIVBusWire[i3+3]=(InstReg[0][i3+8] & TypeReg[0][2] & ~LockNode[0])|
					(InstReg[1][i3+8] & TypeReg[1][2] & ~LockNode[1] & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[2][i3+8] & TypeReg[2][2] & ~LockNode[2] & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[3][i3+8] & TypeReg[3][2] & ~LockNode[3] & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[4][i3+8] & TypeReg[4][2] & ~LockNode[4] & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & 
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[5][i3+8] & TypeReg[5][2] & ~LockNode[5] & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]))|
					(InstReg[6][i3+8] & TypeReg[6][2] & ~LockNode[6] & (~TypeReg[5][2] | LockNode[5]) &
						(~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) &
						(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) &
						(~TypeReg[0][2] | LockNode[0]))|
					(InstReg[7][i3+8] & TypeReg[7][2] & ~LockNode[7] & (~TypeReg[6][2] | LockNode[6]) &
						(~TypeReg[5][2] | LockNode[5]) & (~TypeReg[4][2] | LockNode[4]) &
						(~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
						(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]));

	//=============================================================================================
	//
	// Instruction patch for ALU
	// 0 - ADDZX
	// 1 - ADDSX
	// 2 - SUBZX
	// 3 - SUBSX
	// 4 - AND
	// 5 - OR
	// 6 - XOR
	// 7 - MASKCOPY
	ALUBusWire[0]=(TypeReg[0][3] & ~LockNode[0])|(TypeReg[1][3] & ~LockNode[1])|
					(TypeReg[2][3] & ~LockNode[2])|(TypeReg[3][3] & ~LockNode[3])|
					(TypeReg[4][3] & ~LockNode[4])|(TypeReg[5][3] & ~LockNode[5])|
					(TypeReg[6][3] & ~LockNode[6])|(TypeReg[7][3] & ~LockNode[7]);
	for (i4=0; i4<3; i4=i4+1)
		ALUBusWire[i4+1]=(InstReg[0][i4] & TypeReg[0][3] & ~LockNode[0])|
						(InstReg[1][i4] & TypeReg[1][3] & ~LockNode[1] & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[2][i4] & TypeReg[2][3] & ~LockNode[2] & (~TypeReg[1][3] | LockNode[1]) &
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[3][i4] & TypeReg[3][3] & ~LockNode[3] & (~TypeReg[2][3] | LockNode[2]) &
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[4][i4] & TypeReg[4][3] & ~LockNode[4] & (~TypeReg[3][3] | LockNode[3]) &
										(~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) &
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[5][i4] & TypeReg[5][3] & ~LockNode[5] & (~TypeReg[4][3] | LockNode[4]) &
										(~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) &
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[6][i4] & TypeReg[6][3] & ~LockNode[6] & (~TypeReg[5][3] | LockNode[5]) &
										(~TypeReg[4][3] | LockNode[4]) & (~TypeReg[3][3] | LockNode[3]) &
										(~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) & 
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[7][i4] & TypeReg[7][3] & ~LockNode[7] & (~TypeReg[6][3] | LockNode[6]) &
										(~TypeReg[5][3] | LockNode[5]) & (~TypeReg[4][3] | LockNode[4]) &
										(~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) & 
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]));
	for (i5=0; i5<24; i5=i5+1)
		ALUBusWire[i5+4]=(InstReg[0][i5+8] & TypeReg[0][3] & ~LockNode[0])|
						(InstReg[1][i5+8] & TypeReg[1][3] & ~LockNode[1] & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[2][i5+8] & TypeReg[2][3] & ~LockNode[2] & (~TypeReg[1][3] | LockNode[1]) &
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[3][i5+8] & TypeReg[3][3] & ~LockNode[3] & (~TypeReg[2][3] | LockNode[2]) &
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[4][i5+8] & TypeReg[4][3] & ~LockNode[4] & (~TypeReg[3][3] | LockNode[3]) &
										(~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) &
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[5][i5+8] & TypeReg[5][3] & ~LockNode[5] & (~TypeReg[4][3] | LockNode[4]) &
										(~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) &
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
						(InstReg[6][i5+8] & TypeReg[6][3] & ~LockNode[6] & (~TypeReg[5][3] | LockNode[5]) &
										(~TypeReg[4][3] | LockNode[4]) & (~TypeReg[3][3] | LockNode[3]) &
										(~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) & 
										(~TypeReg[0][3] | LockNode[0]))|
						(InstReg[7][i5+8] & TypeReg[7][3] & ~LockNode[7] & (~TypeReg[6][3] | LockNode[6]) &
										(~TypeReg[5][3] | LockNode[5]) & (~TypeReg[4][3] | LockNode[4]) &
										(~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) & 
										(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0])); 

	//=============================================================================================
	//
	// Instruction patch for shifter
	// 
	ShiftBusWire[0]=(TypeReg[0][4] & ~LockNode[0])|(TypeReg[1][4] & ~LockNode[1])|
					(TypeReg[2][4] & ~LockNode[2])|(TypeReg[3][4] & ~LockNode[3])|
					(TypeReg[4][4] & ~LockNode[4])|(TypeReg[5][4] & ~LockNode[5])|
					(TypeReg[6][4] & ~LockNode[6])|(TypeReg[7][4] & ~LockNode[7]);
	for (i6=0; i6<3; i6=i6+1)
		ShiftBusWire[i6+1]=(InstReg[0][i6] & TypeReg[0][4] & ~LockNode[0])|
							(InstReg[1][i6] & TypeReg[1][4] & ~LockNode[1] & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[2][i6] & TypeReg[2][4] & ~LockNode[2] & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[3][i6] & TypeReg[3][4] & ~LockNode[3] & (~TypeReg[2][4] | LockNode[2]) &
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[4][i6] & TypeReg[4][4] & ~LockNode[4] & (~TypeReg[3][4] | LockNode[3]) &
											(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[5][i6] & TypeReg[5][4] & ~LockNode[5] & (~TypeReg[4][4] | LockNode[4]) &
											(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) &
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[6][i6] & TypeReg[6][4] & ~LockNode[6] & (~TypeReg[5][4] | LockNode[5]) &
											(~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) &
											(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[7][i6] & TypeReg[7][4] & ~LockNode[7] & (~TypeReg[6][4] | LockNode[6]) &
											(~TypeReg[5][4] | LockNode[5]) & (~TypeReg[4][4] | LockNode[4]) &
											(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) & 
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]));
	ShiftBusWire[4]=(InstReg[0][6] & TypeReg[0][4] & ~LockNode[0])|
					(InstReg[1][6] & TypeReg[1][4] & ~LockNode[1] & (~TypeReg[0][4] | LockNode[0]))|
					(InstReg[2][6] & TypeReg[2][4] & ~LockNode[2] & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
					(InstReg[3][6] & TypeReg[3][4] & ~LockNode[3] & (~TypeReg[2][4] | LockNode[2]) &
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(InstReg[4][6] & TypeReg[4][4] & ~LockNode[4] & (~TypeReg[3][4] | LockNode[3]) &
											(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
					(InstReg[5][6] & TypeReg[5][4] & ~LockNode[5] & (~TypeReg[4][4] | LockNode[4]) &
											(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) &
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(InstReg[6][6] & TypeReg[6][4] & ~LockNode[6] & (~TypeReg[5][4] | LockNode[5]) &
											(~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) &
											(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
											(~TypeReg[0][4] | LockNode[0]))|
					(InstReg[7][6] & TypeReg[7][4] & ~LockNode[7] & (~TypeReg[6][4] | LockNode[6]) &
											(~TypeReg[5][4] | LockNode[5]) & (~TypeReg[4][4] | LockNode[4]) &
											(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) & 
											(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]));
	for (i7=0; i7<24; i7=i7+1)
		ShiftBusWire[i7+5]=(InstReg[0][i7+8] & TypeReg[0][4] & ~LockNode[0])|
							(InstReg[1][i7+8] & TypeReg[1][4] & ~LockNode[1] & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[2][i7+8] & TypeReg[2][4] & ~LockNode[2] & (~TypeReg[1][4] | LockNode[1]) &
												(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[3][i7+8] & TypeReg[3][4] & ~LockNode[3] & (~TypeReg[2][4] | LockNode[2]) &
												(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[4][i7+8] & TypeReg[4][4] & ~LockNode[4] & (~TypeReg[3][4] | LockNode[3]) &
												(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
												(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[5][i7+8] & TypeReg[5][4] & ~LockNode[5] & (~TypeReg[4][4] | LockNode[4]) &
												(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) &
												(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
							(InstReg[6][i7+8] & TypeReg[6][4] & ~LockNode[6] & (~TypeReg[5][4] | LockNode[5]) &
												(~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) &
												(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
												(~TypeReg[0][4] | LockNode[0]))|
							(InstReg[7][i7+8] & TypeReg[7][4] & ~LockNode[7] & (~TypeReg[6][4] | LockNode[6]) &
												(~TypeReg[5][4] | LockNode[5]) & (~TypeReg[4][4] | LockNode[4]) &
												(~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) &
												(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]));

	//=============================================================================================
	//
	// Instruction patch for miscellaneous operations
	//
	/*
	000 - NOT
	001 - NEG
	010 - DAA
	011 - DAS
	100 - BSWAP
	101 - POS
	110 - SFR
	111 - LFR
	*/
	MiscBusWire[0]=(TypeReg[0][5] & ~LockNode[0])|(TypeReg[1][5] & ~LockNode[1])|
					(TypeReg[2][5] & ~LockNode[2])|(TypeReg[3][5] & ~LockNode[3])|
					(TypeReg[4][5] & ~LockNode[4])|(TypeReg[5][5] & ~LockNode[5])|
					(TypeReg[6][5] & ~LockNode[6])|(TypeReg[7][5] & ~LockNode[7]);
	for (i9=0; i9<3; i9=i9+1)
		MiscBusWire[i9+1]=(InstReg[0][i9] & TypeReg[0][5] & ~LockNode[0])|
							(InstReg[1][i9] & TypeReg[1][5] & ~LockNode[1] & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[2][i9] & TypeReg[2][5] & ~LockNode[2] & (~TypeReg[1][5] | LockNode[1]) &
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[3][i9] & TypeReg[3][5] & ~LockNode[3] & (~TypeReg[2][5] | LockNode[2]) &
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[4][i9] & TypeReg[4][5] & ~LockNode[4] & (~TypeReg[3][5] | LockNode[3]) &
											(~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) & 
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[5][i9] & TypeReg[5][5] & ~LockNode[5] & (~TypeReg[4][5] | LockNode[4]) &
											(~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) &
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[6][i9] & TypeReg[6][5] & ~LockNode[6] & (~TypeReg[5][5] | LockNode[5]) &
											(~TypeReg[4][5] | LockNode[4]) & (~TypeReg[3][5] | LockNode[3]) & 
											(~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) &
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[7][i9] & TypeReg[7][5] & ~LockNode[7] & (~TypeReg[6][5] | LockNode[6]) &
											(~TypeReg[5][5] | LockNode[5]) & (~TypeReg[4][5] | LockNode[4]) &
											(~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) & 
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]));
	for (i10=0; i10<24; i10=i10+1)
		MiscBusWire[i10+4]=(InstReg[0][i10+8] & TypeReg[0][5] & ~LockNode[0])|
							(InstReg[1][i10+8] & TypeReg[1][5] & ~LockNode[1] & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[2][i10+8] & TypeReg[2][5] & ~LockNode[2] & (~TypeReg[1][5] | LockNode[1]) &
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[3][i10+8] & TypeReg[3][5] & ~LockNode[3] & (~TypeReg[2][5] | LockNode[2]) &
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[4][i10+8] & TypeReg[4][5] & ~LockNode[4] & (~TypeReg[3][5] | LockNode[3]) &
											(~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) &
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[5][i10+8] & TypeReg[5][5] & ~LockNode[5] & (~TypeReg[4][5] | LockNode[4]) &
											(~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) &
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
							(InstReg[6][i10+8] & TypeReg[6][5] & ~LockNode[6] & (~TypeReg[5][5] | LockNode[5]) &
											(~TypeReg[4][5] | LockNode[4]) & (~TypeReg[3][5] | LockNode[3]) &
											(~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) &
											(~TypeReg[0][5] | LockNode[0]))|
							(InstReg[7][i10+8] & TypeReg[7][5] & ~LockNode[7] & (~TypeReg[6][5] | LockNode[6]) &
											(~TypeReg[5][5] | LockNode[5]) & (~TypeReg[4][5] | LockNode[4]) &
											(~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) &
											(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]));

	//=============================================================================================
	//
	// Instruction patch for register movement and data conversion operations
	//
	MovBusWire[0]=(TypeReg[0][6] & ~LockNode[0])|(TypeReg[1][6] & ~LockNode[1])|
					(TypeReg[2][6] & ~LockNode[2])|(TypeReg[3][6] & ~LockNode[3])|
					(TypeReg[4][6] & ~LockNode[4])|(TypeReg[5][6] & ~LockNode[5])|
					(TypeReg[6][6] & ~LockNode[6])|(TypeReg[7][6] & ~LockNode[7]);
	for (i11=0; i11<3; i11=i11+1)
		MovBusWire[i11+1]=(InstReg[0][i11] &  TypeReg[0][6] & ~LockNode[0])|
						(InstReg[1][i11] & TypeReg[1][6] & ~LockNode[1] & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[2][i11] & TypeReg[2][6] & ~LockNode[2] & (~TypeReg[1][6] | LockNode[1]) &
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[3][i11] & TypeReg[3][6] & ~LockNode[3] & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[4][i11] & TypeReg[4][6] & ~LockNode[4] & (~TypeReg[3][6] | LockNode[3]) &
											(~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) &
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[5][i11] & TypeReg[5][6] & ~LockNode[5] & (~TypeReg[4][6] | LockNode[4]) &
											(~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[6][i11] & TypeReg[6][6] & ~LockNode[6] & (~TypeReg[5][6] | LockNode[5]) &
											(~TypeReg[4][6] | LockNode[4]) & (~TypeReg[3][6] | LockNode[3]) &
											(~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) & 
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[7][i11] & TypeReg[7][6] & ~LockNode[7] & (~TypeReg[6][6] | LockNode[6]) &
											(~TypeReg[5][6] | LockNode[5]) & (~TypeReg[4][6] | LockNode[4]) &
											(~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]));
	for (i12=0; i12<24; i12=i12+1)
		MovBusWire[i12+4]=(InstReg[0][i12+8] & TypeReg[0][6] & ~LockNode[0])|
						(InstReg[1][i12+8] & TypeReg[1][6] & ~LockNode[1] & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[2][i12+8] & TypeReg[2][6] & ~LockNode[2] & (~TypeReg[1][6] | LockNode[1]) &
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[3][i12+8] & TypeReg[3][6] & ~LockNode[3] & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[4][i12+8] & TypeReg[4][6] & ~LockNode[4] & (~TypeReg[3][6] | LockNode[3]) &
											(~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) &
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[5][i12+8] & TypeReg[5][6] & ~LockNode[5] & (~TypeReg[4][6] | LockNode[4]) &
											(~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
						(InstReg[6][i12+8] & TypeReg[6][6] & ~LockNode[6] & (~TypeReg[5][6] | LockNode[5]) &
											(~TypeReg[4][6] | LockNode[4]) & (~TypeReg[3][6] | LockNode[3]) &
											(~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) &
											(~TypeReg[0][6] | LockNode[0]))|
						(InstReg[7][i12+8] & TypeReg[7][6] & ~LockNode[7] & (~TypeReg[6][6] | LockNode[6]) &
											(~TypeReg[5][6] | LockNode[5]) & (~TypeReg[4][6] | LockNode[4]) &
											(~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) &
											(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]));

	//=============================================================================================
	//
	// LD/ST/POP/PUSH instructions
	//
	MemBusWire[0]=(TypeReg[0][7] & ~LockNode[0])|
					(TypeReg[1][7] & ~LockNode[1] & ~TypeReg[0][7])|
					(TypeReg[2][7] & ~LockNode[2] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(TypeReg[3][7] & ~LockNode[3] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(TypeReg[4][7] & ~LockNode[4] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(TypeReg[5][7] & ~LockNode[5] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(TypeReg[6][7] & ~LockNode[6] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(TypeReg[7][7] & ~LockNode[7] & ~TypeReg[6][7] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7]);
	for (i13=0; i13<4; i13=i13+1)
		MemBusWire[1+i13]=(InstReg[0][i13] & TypeReg[0][7] & ~LockNode[0])|
					(InstReg[1][i13] & TypeReg[1][7] & ~LockNode[1] & ~TypeReg[0][7])|
					(InstReg[2][i13] & TypeReg[2][7] & ~LockNode[2] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[3][i13] & TypeReg[3][7] & ~LockNode[3] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[4][i13] & TypeReg[4][7] & ~LockNode[4] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[5][i13] & TypeReg[5][7] & ~LockNode[5] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[6][i13] & TypeReg[6][7] & ~LockNode[6] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[7][i13] & TypeReg[7][7] & ~LockNode[7] & ~TypeReg[6][7] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7]);
	for (i14=0; i14<24; i14=i14+1)
		MemBusWire[i14+5]=(InstReg[0][i14+8] & TypeReg[0][7] & ~LockNode[0])|
					(InstReg[1][i14+8] & TypeReg[1][7] & ~LockNode[1] & ~TypeReg[0][7])|
					(InstReg[2][i14+8] & TypeReg[2][7] & ~LockNode[2] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[3][i14+8] & TypeReg[3][7] & ~LockNode[3] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[4][i14+8] & TypeReg[4][7] & ~LockNode[4] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[5][i14+8] & TypeReg[5][7] & ~LockNode[5] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[6][i14+8] & TypeReg[6][7] & ~LockNode[6] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7])|
					(InstReg[7][i14+8] & TypeReg[7][7] & ~LockNode[7] & ~TypeReg[6][7] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7]);

	//=============================================================================================
	//
	// Flow control instructions
	//
	CtrlBusWire[0]=(TypeReg[0][8] & ~LockNode[0])|
				(TypeReg[1][8] & ~LockNode[1] & ~TypeReg[0][8])|
				(TypeReg[2][8] & ~LockNode[2] & ~TypeReg[1][8] & ~TypeReg[0][8])|
				(TypeReg[3][8] & ~LockNode[3] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
				(TypeReg[4][8] & ~LockNode[4] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
				(TypeReg[5][8] & ~LockNode[5] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
				(TypeReg[6][8] & ~LockNode[6] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
				(TypeReg[7][8] & ~LockNode[7] & ~TypeReg[6][8] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]);
	for (i15=0; i15<4; i15=i15+1)
		CtrlBusWire[i15+1]=(InstReg[0][i15] & TypeReg[0][8] & ~LockNode[0])|
					(InstReg[1][i15] & TypeReg[1][8] & ~LockNode[1] & ~TypeReg[0][8])|
					(InstReg[2][i15] & TypeReg[2][8] & ~LockNode[2] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[3][i15] & TypeReg[3][8] & ~LockNode[3] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[4][i15] & TypeReg[4][8] & ~LockNode[4] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[5][i15] & TypeReg[5][8] & ~LockNode[5] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[6][i15] & TypeReg[6][8] & ~LockNode[6] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[7][i15] & TypeReg[7][8] & ~LockNode[7] & ~TypeReg[6][8] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]);
	for (i16=0; i16<24; i16=i16+1)
		CtrlBusWire[i16+5]=(InstReg[0][i16+8] & TypeReg[0][8] & ~LockNode[0])|
					(InstReg[1][i16+8] & TypeReg[1][8] & ~LockNode[1] & ~TypeReg[0][8])|
					(InstReg[2][i16+8] & TypeReg[2][8] & ~LockNode[2] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[3][i16+8] & TypeReg[3][8] & ~LockNode[3] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[4][i16+8] & TypeReg[4][8] & ~LockNode[4] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[5][i16+8] & TypeReg[5][8] & ~LockNode[5] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[6][i16+8] & TypeReg[6][8] & ~LockNode[6] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(InstReg[7][i16+8] & TypeReg[7][8] & ~LockNode[7] & ~TypeReg[6][8] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]);

	//=============================================================================================
	//
	// Instruction patch for FMULACC or FFT unit
	// 
	FMULACCBusWire[0]=(TypeReg[0][9] & ~LockNode[0])|(TypeReg[1][9] & ~LockNode[1])|
						(TypeReg[2][9] & ~LockNode[2])|(TypeReg[3][9] & ~LockNode[3])|
						(TypeReg[4][9] & ~LockNode[4])|(TypeReg[5][9] & ~LockNode[5])|
						(TypeReg[6][9] & ~LockNode[6])|(TypeReg[7][9] & ~LockNode[7]);
			
	FMULACCBusWire[1]=(InstReg[0][0] & TypeReg[0][9] & ~LockNode[0])|
						(InstReg[1][0] & TypeReg[1][9] & ~LockNode[1] & (~TypeReg[0][9] | LockNode[0]))|
						(InstReg[2][0] & TypeReg[2][9] & ~LockNode[2] & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
						(InstReg[3][0] & TypeReg[3][9] & ~LockNode[3] & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) &
											(~TypeReg[0][9] | LockNode[0]))|
						(InstReg[4][0] & TypeReg[4][9] & ~LockNode[4] & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) &
											(~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
						(InstReg[5][0] & TypeReg[5][9] & ~LockNode[5] & (~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) &
											(~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
						(InstReg[6][0] & TypeReg[6][9] & ~LockNode[6] & (~TypeReg[5][9] | LockNode[5]) & (~TypeReg[4][9] | LockNode[4]) &
											(~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) &
											(~TypeReg[0][9] | LockNode[0]))|
						(InstReg[7][0] & TypeReg[7][9] & ~LockNode[7] & (~TypeReg[6][9] | LockNode[6]) & (~TypeReg[5][9] | LockNode[5]) &
											(~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) &
											(~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]));

	for (i2=0; i2<24; i2=i2+1)
		begin
		FMULACCBusWire[i2+2]=(InstReg[0][i2+8] & TypeReg[0][9] & ~LockNode[0])|
							(InstReg[1][i2+8] & TypeReg[1][9] & ~LockNode[1] & (~TypeReg[0][9] | LockNode[0]))|
							(InstReg[2][i2+8] & TypeReg[2][9] & ~LockNode[2] & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
							(InstReg[3][i2+8] & TypeReg[3][9] & ~LockNode[3] & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) &
												(~TypeReg[0][9] | LockNode[0]))|
							(InstReg[4][i2+8] & TypeReg[4][9] & ~LockNode[4] & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) &
												(~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
							(InstReg[5][i2+8] & TypeReg[5][9] & ~LockNode[5] & (~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) &
												(~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]))|
							(InstReg[6][i2+8] & TypeReg[6][9] & ~LockNode[6] & (~TypeReg[5][9] | LockNode[5]) & (~TypeReg[4][9] | LockNode[4]) &
												(~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) &
												(~TypeReg[0][9] | LockNode[0]))|
							(InstReg[7][i2+8] & TypeReg[7][9] & ~LockNode[7] & (~TypeReg[6][9] | LockNode[6]) & (~TypeReg[5][9] | LockNode[5]) &
												(~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) &
												(~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]));
		end
					
	//=============================================================================================
	// VF reset nodes
	VFResetWire[0]=((TypeReg[0][0] | TypeReg[0][1] | (TypeReg[0][2] & FDIVRDY) | TypeReg[0][3] | TypeReg[0][4] | TypeReg[0][5] | TypeReg[0][6] | 
					(TypeReg[0][7] & MEMRDY) | TypeReg[0][8] | (TypeReg[0][9] & FMULACCRDY))
				& ~LockNode[0]) | TypeReg[0][10];

	VFResetWire[1]=(((TypeReg[1][0] & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[1][1] & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[1][2] & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[1][3] & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[1][4] & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[1][5] & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[1][6] & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[1][8] & ~TypeReg[0][8]) |
					(TypeReg[1][9] & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY))
				& ~LockNode[1]) | TypeReg[1][10];

	VFResetWire[2]=(((TypeReg[2][0] & (~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[2][1] & (~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[2][2] & (~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[2][3] & (~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[2][4] & (~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[2][5] & (~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[2][6] & (~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]) |
					(TypeReg[2][9] & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY))
				& ~LockNode[2]) | TypeReg[2][10];

	VFResetWire[3]=(((TypeReg[3][0] & (~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[3][1] & (~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[3][2] & (~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[3][3] & (~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[3][4] & (~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[3][5] & (~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[3][6] & (~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(TypeReg[3][9] & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY)) &
				~LockNode[3]) | TypeReg[3][10];

	VFResetWire[4]=(((TypeReg[4][0] & (~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[4][1] & (~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[4][2] & (~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[4][3] & (~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[4][4] & (~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[4][5] & (~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[4][6] & (~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]) |
					(TypeReg[4][9] & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY))
				& ~LockNode[4]) | TypeReg[4][10];

	VFResetWire[5]=(((TypeReg[5][0] & (~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) &
									(~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[5][1] & (~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) &
									(~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[5][2] & (~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) &
									(~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[5][3] & (~TypeReg[4][3] | LockNode[4]) & (~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) &
									(~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[5][4] & (~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) &
									(~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[5][5] & (~TypeReg[4][5] | LockNode[4]) & (~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) &
									(~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[5][6] & (~TypeReg[4][6] | LockNode[4]) & (~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) &
									(~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(TypeReg[5][9] & (~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) &
									(~TypeReg[0][9] | LockNode[0]) & FMULACCRDY)) & ~LockNode[5])| TypeReg[5][10];

	VFResetWire[6]=(((TypeReg[6][0] & (~TypeReg[5][0] | LockNode[5]) & (~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) & (~TypeReg[2][0] | LockNode[2]) &
									(~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[6][1] & (~TypeReg[5][1] | LockNode[5]) & (~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) & (~TypeReg[2][1] | LockNode[2]) &
									(~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[6][2] & (~TypeReg[5][2] | LockNode[5]) & (~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) & (~TypeReg[2][2] | LockNode[2]) &
									(~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[6][3] & (~TypeReg[5][3] | LockNode[5]) & (~TypeReg[4][3] | LockNode[4]) & (~TypeReg[3][3] | LockNode[3]) & (~TypeReg[2][3] | LockNode[2]) &
									(~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[6][4] & (~TypeReg[5][4] | LockNode[5]) & (~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) & (~TypeReg[2][4] | LockNode[2]) &
									(~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[6][5] & (~TypeReg[5][5] | LockNode[5]) & (~TypeReg[4][5] | LockNode[4]) & (~TypeReg[3][5] | LockNode[3]) & (~TypeReg[2][5] | LockNode[2]) &
									(~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[6][6] & (~TypeReg[5][6] | LockNode[5]) & (~TypeReg[4][6] | LockNode[4]) & (~TypeReg[3][6] | LockNode[3]) & (~TypeReg[2][6] | LockNode[2]) &
									(~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[6][7] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[6][8] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8]) |
					(TypeReg[6][9] & (~TypeReg[5][9] | LockNode[5]) & (~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) & (~TypeReg[2][9] | LockNode[2]) &
									(~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY)) & ~LockNode[6])| TypeReg[6][10];

	VFResetWire[7]=(((TypeReg[7][0] & (~TypeReg[6][0] | LockNode[6]) & (~TypeReg[5][0] | LockNode[5]) & (~TypeReg[4][0] | LockNode[4]) & (~TypeReg[3][0] | LockNode[3]) &
									(~TypeReg[2][0] | LockNode[2]) & (~TypeReg[1][0] | LockNode[1]) & (~TypeReg[0][0] | LockNode[0]))|
					(TypeReg[7][1] & (~TypeReg[6][1] | LockNode[6]) & (~TypeReg[5][1] | LockNode[5]) & (~TypeReg[4][1] | LockNode[4]) & (~TypeReg[3][1] | LockNode[3]) &
									(~TypeReg[2][1] | LockNode[2]) & (~TypeReg[1][1] | LockNode[1]) & (~TypeReg[0][1] | LockNode[0]))|
					(TypeReg[7][2] & (~TypeReg[6][2] | LockNode[6]) & (~TypeReg[5][2] | LockNode[5]) & (~TypeReg[4][2] | LockNode[4]) & (~TypeReg[3][2] | LockNode[3]) &
									(~TypeReg[2][2] | LockNode[2]) & (~TypeReg[1][2] | LockNode[1]) & (~TypeReg[0][2] | LockNode[0]) & FDIVRDY)|
					(TypeReg[7][3] & (~TypeReg[6][3] | LockNode[6]) & (~TypeReg[5][3] | LockNode[5]) & (~TypeReg[4][3] | LockNode[4]) & (~TypeReg[3][3] | LockNode[3]) &
									(~TypeReg[2][3] | LockNode[2]) & (~TypeReg[1][3] | LockNode[1]) & (~TypeReg[0][3] | LockNode[0]))|
					(TypeReg[7][4] & (~TypeReg[6][4] | LockNode[6]) & (~TypeReg[5][4] | LockNode[5]) & (~TypeReg[4][4] | LockNode[4]) & (~TypeReg[3][4] | LockNode[3]) &
									(~TypeReg[2][4] | LockNode[2]) & (~TypeReg[1][4] | LockNode[1]) & (~TypeReg[0][4] | LockNode[0]))|
					(TypeReg[7][5] & (~TypeReg[6][5] | LockNode[6]) & (~TypeReg[5][5] | LockNode[5]) & (~TypeReg[4][5] | LockNode[4]) & (~TypeReg[3][5] | LockNode[3]) &
									(~TypeReg[2][5] | LockNode[2]) & (~TypeReg[1][5] | LockNode[1]) & (~TypeReg[0][5] | LockNode[0]))|
					(TypeReg[7][6] & (~TypeReg[6][6] | LockNode[6]) & (~TypeReg[5][6] | LockNode[5]) & (~TypeReg[4][6] | LockNode[4]) & (~TypeReg[3][6] | LockNode[3]) &
									(~TypeReg[2][6] | LockNode[2]) & (~TypeReg[1][6] | LockNode[1]) & (~TypeReg[0][6] | LockNode[0]))|
					(TypeReg[7][7] & ~TypeReg[6][7] & ~TypeReg[5][7] & ~TypeReg[4][7] & ~TypeReg[3][7] & ~TypeReg[2][7] & ~TypeReg[1][7] & ~TypeReg[0][7] & MEMRDY)|
					(TypeReg[7][8] & ~TypeReg[6][8] & ~TypeReg[5][8] & ~TypeReg[4][8] & ~TypeReg[3][8] & ~TypeReg[2][8] & ~TypeReg[1][8] & ~TypeReg[0][8])|
					(TypeReg[7][9] & (~TypeReg[6][9] | LockNode[6]) & (~TypeReg[5][9] | LockNode[5]) & (~TypeReg[4][9] | LockNode[4]) & (~TypeReg[3][9] | LockNode[3]) &
									(~TypeReg[2][9] | LockNode[2]) & (~TypeReg[1][9] | LockNode[1]) & (~TypeReg[0][9] | LockNode[0]) & FMULACCRDY)) & ~LockNode[7]) | TypeReg[7][10];
	
	// invalidation bus
	for (i17=0; i17<32; i17=i17+1)
		InvdBus[i17]=(GPRInvdR[0][i17] | LockNode[0] | ~VFReg[0] | ~VFResetWire[0]) &
					(GPRInvdR[1][i17] | LockNode[1] | ~VFReg[1] | ~VFResetWire[1]) &
					(GPRInvdR[2][i17] | LockNode[2] | ~VFReg[2] | ~VFResetWire[2]) &
					(GPRInvdR[3][i17] | LockNode[3] | ~VFReg[3] | ~VFResetWire[3]) &
					(GPRInvdR[4][i17] | LockNode[4] | ~VFReg[4] | ~VFResetWire[4]) &
					(GPRInvdR[5][i17] | LockNode[5] | ~VFReg[5] | ~VFResetWire[5]) &
					(GPRInvdR[6][i17] | LockNode[6] | ~VFReg[6] | ~VFResetWire[6]) &
					(GPRInvdR[7][i17] | LockNode[7] | ~VFReg[7] | ~VFResetWire[7]);

	// reloading instruction registers
	InstReloadWire=(~VFReg[3] | VFResetWire[3])  & (~VFReg[2] | VFResetWire[2]) & (~VFReg[1] | VFResetWire[1]) & (~VFReg[0] | VFResetWire[0]);
	HalfReloadWire=(~VFReg[7] | VFResetWire[7])  & (~VFReg[6] | VFResetWire[6]) & (~VFReg[5] | VFResetWire[5]) & (~VFReg[4] | VFResetWire[4]) & ~InstReloadWire;

	end


/*
====================================================================================================
					Synchronous part
====================================================================================================
*/
always @(negedge RESET or posedge CLK)
	begin
	if (!RESET) begin
					InstReg[0]<=0;
					InstReg[1]<=0;
					InstReg[2]<=0;
					InstReg[3]<=0;
					InstReg[4]<=0;
					InstReg[5]<=0;
					InstReg[6]<=0;
					InstReg[7]<=0;
					VFReg<=8'd0;
					TypeReg[0]<=0;
					TypeReg[1]<=0;
					TypeReg[2]<=0;
					TypeReg[3]<=0;
					TypeReg[4]<=0;
					TypeReg[5]<=0;
					TypeReg[6]<=0;
					TypeReg[7]<=0;
					GPRInvdR[0]<=32'hFFFFFFFF;
					GPRInvdR[1]<=32'hFFFFFFFF;
					GPRInvdR[2]<=32'hFFFFFFFF;
					GPRInvdR[3]<=32'hFFFFFFFF;
					GPRInvdR[4]<=32'hFFFFFFFF;
					GPRInvdR[5]<=32'hFFFFFFFF;
					GPRInvdR[6]<=32'hFFFFFFFF;
					GPRInvdR[7]<=32'hFFFFFFFF;
					OpReg[0]<=0;
					OpReg[1]<=0;
					OpReg[2]<=0;
					OpReg[3]<=0;
					OpReg[4]<=0;
					OpReg[5]<=0;
					OpReg[6]<=0;
					OpReg[7]<=0;
					end
	else begin
	// instruction register
	if (InstReloadWire)
		begin
		InstReg[0]<=InstReg[4];
		InstReg[1]<=InstReg[5];
		InstReg[2]<=InstReg[6];
		InstReg[3]<=InstReg[7];

		I1SRC1_I0DST<=I5SRC1_I4DST;
		I1SRC2_I0DST<=I5SRC2_I4DST;
		I1DST_I0SRC1<=I5DST_I4SRC1;
		I1DST_I0SRC2<=I5DST_I4SRC2;
		I1DST_I0DST<=I5DST_I4DST;

		I2SRC1_I1DST<=I6SRC1_I5DST;
		I2SRC2_I1DST<=I6SRC2_I5DST;
		I2DST_I1SRC1<=I6DST_I5SRC1;
		I2DST_I1SRC2<=I6DST_I5SRC2;
		I2DST_I1DST<=I6DST_I5DST;
		I2SRC1_I0DST<=I6SRC1_I4DST;
		I2SRC2_I0DST<=I6SRC2_I4DST;
		I2DST_I0SRC1<=I6DST_I4SRC1;
		I2DST_I0SRC2<=I6DST_I4SRC2;
		I2DST_I0DST<=I6DST_I4DST;

		I3SRC1_I2DST<=I7SRC1_I6DST;
		I3SRC2_I2DST<=I7SRC2_I6DST;
		I3DST_I2SRC1<=I7DST_I6SRC1;
		I3DST_I2SRC2<=I7DST_I6SRC2;
		I3DST_I2DST<=I7DST_I6DST;
		I3SRC1_I1DST<=I7SRC1_I5DST;
		I3SRC2_I1DST<=I7SRC2_I5DST;
		I3DST_I1SRC1<=I7DST_I5SRC1;
		I3DST_I1SRC2<=I7DST_I5SRC2;
		I3DST_I1DST<=I7DST_I5DST;
		I3SRC1_I0DST<=I7SRC1_I4DST;
		I3SRC2_I0DST<=I7SRC2_I4DST;
		I3DST_I0SRC1<=I7DST_I4SRC1;
		I3DST_I0SRC2<=I7DST_I4SRC2;
		I3DST_I0DST<=I7DST_I4DST;
		end

	if (InstReloadWire | HalfReloadWire)
		begin
		InstReg[4]<=IBUS[31:0];
		InstReg[5]<=IBUS[63:32];
		InstReg[6]<=IBUS[95:64];
		InstReg[7]<=IBUS[127:96];

		I4SRC1_I3DST<=HalfReloadWire ? (IBUS[12:8]==InstReg[3][28:24]) : (IBUS[12:8]==InstReg[7][28:24]);
		I4SRC2_I3DST<=HalfReloadWire ? (IBUS[20:16]==InstReg[3][28:24]) : (IBUS[20:16]==InstReg[7][28:24]);
		I4DST_I3SRC1<=HalfReloadWire ? (IBUS[28:24]==InstReg[3][12:8]) : (IBUS[28:24]==InstReg[7][12:8]);
		I4DST_I3SRC2<=HalfReloadWire ? (IBUS[28:24]==InstReg[3][20:16]) : (IBUS[28:24]==InstReg[7][20:16]);
		I4DST_I3DST<=HalfReloadWire ? (IBUS[28:24]==InstReg[3][28:24]) : (IBUS[28:24]==InstReg[7][28:24]);
		I4SRC1_I2DST<=HalfReloadWire ? (IBUS[12:8]==InstReg[2][28:24]) : (IBUS[12:8]==InstReg[6][28:24]);
		I4SRC2_I2DST<=HalfReloadWire ? (IBUS[20:16]==InstReg[2][28:24]) : (IBUS[20:16]==InstReg[6][28:24]);
		I4DST_I2SRC1<=HalfReloadWire ? (IBUS[28:24]==InstReg[2][12:8]) : (IBUS[28:24]==InstReg[6][12:8]);
		I4DST_I2SRC2<=HalfReloadWire ? (IBUS[28:24]==InstReg[2][20:16]) : (IBUS[28:24]==InstReg[6][20:16]);
		I4DST_I2DST<=HalfReloadWire ? (IBUS[28:24]==InstReg[2][28:24]) : (IBUS[28:24]==InstReg[6][28:24]);
		I4SRC1_I1DST<=HalfReloadWire ? (IBUS[12:8]==InstReg[1][28:24]) : (IBUS[12:8]==InstReg[5][28:24]);
		I4SRC2_I1DST<=HalfReloadWire ? (IBUS[20:16]==InstReg[1][28:24]) : (IBUS[20:16]==InstReg[5][28:24]);
		I4DST_I1SRC1<=HalfReloadWire ? (IBUS[28:24]==InstReg[1][12:8]) : (IBUS[28:24]==InstReg[5][12:8]);
		I4DST_I1SRC2<=HalfReloadWire ? (IBUS[28:24]==InstReg[1][20:16]) : (IBUS[28:24]==InstReg[5][20:16]);
		I4DST_I1DST<=HalfReloadWire ? (IBUS[28:24]==InstReg[1][28:24]) : (IBUS[28:24]==InstReg[5][28:24]);
		I4SRC1_I0DST<=HalfReloadWire ? (IBUS[12:8]==InstReg[0][28:24]) : (IBUS[12:8]==InstReg[4][28:24]);
		I4SRC2_I0DST<=HalfReloadWire ? (IBUS[20:16]==InstReg[0][28:24]) : (IBUS[20:16]==InstReg[4][28:24]);
		I4DST_I0SRC1<=HalfReloadWire ? (IBUS[28:24]==InstReg[0][12:8]) : (IBUS[28:24]==InstReg[4][12:8]);
		I4DST_I0SRC2<=HalfReloadWire ? (IBUS[28:24]==InstReg[0][20:16]) : (IBUS[28:24]==InstReg[4][20:16]);
		I4DST_I0DST<=HalfReloadWire ? (IBUS[28:24]==InstReg[0][28:24]) : (IBUS[28:24]==InstReg[4][28:24]);

		I5SRC1_I4DST<=(IBUS[44:40]==IBUS[28:24]);
		I5SRC2_I4DST<=(IBUS[52:48]==IBUS[28:24]);
		I5DST_I4SRC1<=(IBUS[60:56]==IBUS[12:8]);
		I5DST_I4SRC2<=(IBUS[60:56]==IBUS[20:16]);
		I5DST_I4DST<=(IBUS[60:56]==IBUS[28:24]);
		I5SRC1_I3DST<=HalfReloadWire ? (IBUS[44:40]==InstReg[3][28:24]) : (IBUS[44:40]==InstReg[7][28:24]);
		I5SRC2_I3DST<=HalfReloadWire ? (IBUS[52:48]==InstReg[3][28:24]) : (IBUS[52:48]==InstReg[7][28:24]);
		I5DST_I3SRC1<=HalfReloadWire ? (IBUS[60:56]==InstReg[3][12:8]) : (IBUS[60:56]==InstReg[7][12:8]);
		I5DST_I3SRC2<=HalfReloadWire ? (IBUS[60:56]==InstReg[3][20:16]) : (IBUS[60:56]==InstReg[7][20:16]);
		I5DST_I3DST<=HalfReloadWire ? (IBUS[60:56]==InstReg[3][28:24]) : (IBUS[60:56]==InstReg[7][28:24]);
		I5SRC1_I2DST<=HalfReloadWire ? (IBUS[44:40]==InstReg[2][28:24]) : (IBUS[44:40]==InstReg[6][28:24]);
		I5SRC2_I2DST<=HalfReloadWire ? (IBUS[52:48]==InstReg[2][28:24]) : (IBUS[52:48]==InstReg[6][28:24]);
		I5DST_I2SRC1<=HalfReloadWire ? (IBUS[60:56]==InstReg[2][12:8]) : (IBUS[60:56]==InstReg[6][12:8]);
		I5DST_I2SRC2<=HalfReloadWire ? (IBUS[60:56]==InstReg[2][20:16]) : (IBUS[60:56]==InstReg[6][20:16]);
		I5DST_I2DST<=HalfReloadWire ? (IBUS[60:56]==InstReg[2][28:24]) : (IBUS[60:56]==InstReg[6][28:24]);
		I5SRC1_I1DST<=HalfReloadWire ? (IBUS[44:40]==InstReg[1][28:24]) : (IBUS[44:40]==InstReg[5][28:24]);
		I5SRC2_I1DST<=HalfReloadWire ? (IBUS[52:48]==InstReg[1][28:24]) : (IBUS[52:48]==InstReg[5][28:24]);
		I5DST_I1SRC1<=HalfReloadWire ? (IBUS[60:56]==InstReg[1][12:8]) : (IBUS[60:56]==InstReg[5][12:8]);
		I5DST_I1SRC2<=HalfReloadWire ? (IBUS[60:56]==InstReg[1][20:16]) : (IBUS[60:56]==InstReg[5][20:16]);
		I5DST_I1DST<=HalfReloadWire ? (IBUS[60:56]==InstReg[1][28:24]) : (IBUS[60:56]==InstReg[5][28:24]);
		I5SRC1_I0DST<=HalfReloadWire ? (IBUS[44:40]==InstReg[0][28:24]) : (IBUS[44:40]==InstReg[4][28:24]);
		I5SRC2_I0DST<=HalfReloadWire ? (IBUS[52:48]==InstReg[0][28:24]) : (IBUS[52:48]==InstReg[4][28:24]);
		I5DST_I0SRC1<=HalfReloadWire ? (IBUS[60:56]==InstReg[0][12:8]) : (IBUS[60:56]==InstReg[4][12:8]);
		I5DST_I0SRC2<=HalfReloadWire ? (IBUS[60:56]==InstReg[0][20:16]) : (IBUS[60:56]==InstReg[4][20:16]);
		I5DST_I0DST<=HalfReloadWire ? (IBUS[60:56]==InstReg[0][28:24]) : (IBUS[60:56]==InstReg[4][28:24]);

		I6SRC1_I5DST<=(IBUS[76:72]==IBUS[60:56]);
		I6SRC2_I5DST<=(IBUS[84:80]==IBUS[60:56]);
		I6DST_I5SRC1<=(IBUS[92:88]==IBUS[44:40]);
		I6DST_I5SRC2<=(IBUS[92:88]==IBUS[52:48]);
		I6DST_I5DST<=(IBUS[92:88]==IBUS[60:56]);
		I6SRC1_I4DST<=(IBUS[76:72]==IBUS[28:24]);
		I6SRC2_I4DST<=(IBUS[84:80]==IBUS[28:24]);
		I6DST_I4SRC1<=(IBUS[92:88]==IBUS[12:8]);
		I6DST_I4SRC2<=(IBUS[92:88]==IBUS[20:16]);
		I6DST_I4DST<=(IBUS[92:88]==IBUS[28:24]);
		I6SRC1_I3DST<=HalfReloadWire ? (IBUS[76:72]==InstReg[3][28:24]) : (IBUS[76:72]==InstReg[7][28:24]);
		I6SRC2_I3DST<=HalfReloadWire ? (IBUS[76:72]==InstReg[3][28:24]) : (IBUS[84:80]==InstReg[7][28:24]);
		I6DST_I3SRC1<=HalfReloadWire ? (IBUS[92:88]==InstReg[3][12:8]) : (IBUS[92:88]==InstReg[7][12:8]);
		I6DST_I3SRC2<=HalfReloadWire ? (IBUS[92:88]==InstReg[3][20:16]) : (IBUS[92:88]==InstReg[7][20:16]);
		I6DST_I3DST<=HalfReloadWire ? (IBUS[92:88]==InstReg[3][28:24]) : (IBUS[92:88]==InstReg[7][28:24]);
		I6SRC1_I2DST<=HalfReloadWire ? (IBUS[76:72]==InstReg[2][28:24]) : (IBUS[76:72]==InstReg[6][28:24]);
		I6SRC2_I2DST<=HalfReloadWire ? (IBUS[84:80]==InstReg[2][28:24]) : (IBUS[84:80]==InstReg[6][28:24]);
		I6DST_I2SRC1<=HalfReloadWire ? (IBUS[92:88]==InstReg[2][12:8]) : (IBUS[92:88]==InstReg[6][12:8]);
		I6DST_I2SRC2<=HalfReloadWire ? (IBUS[92:88]==InstReg[2][20:16]) : (IBUS[92:88]==InstReg[6][20:16]);
		I6DST_I2DST<=HalfReloadWire ? (IBUS[92:88]==InstReg[2][28:24]) : (IBUS[92:88]==InstReg[6][28:24]);
		I6SRC1_I1DST<=HalfReloadWire ? (IBUS[76:72]==InstReg[1][28:24]) : (IBUS[76:72]==InstReg[5][28:24]);
		I6SRC2_I1DST<=HalfReloadWire ? (IBUS[84:80]==InstReg[1][28:24]) : (IBUS[84:80]==InstReg[5][28:24]);
		I6DST_I1SRC1<=HalfReloadWire ? (IBUS[92:88]==InstReg[1][12:8]) : (IBUS[92:88]==InstReg[5][12:8]);
		I6DST_I1SRC2<=HalfReloadWire ? (IBUS[92:88]==InstReg[1][20:16]) : (IBUS[92:88]==InstReg[5][20:16]);
		I6DST_I1DST<=HalfReloadWire ? (IBUS[92:88]==InstReg[1][28:24]) : (IBUS[92:88]==InstReg[5][28:24]);
		I6SRC1_I0DST<=HalfReloadWire ? (IBUS[76:72]==InstReg[0][28:24]) : (IBUS[76:72]==InstReg[4][28:24]);
		I6SRC2_I0DST<=HalfReloadWire ? (IBUS[84:80]==InstReg[0][28:24]) : (IBUS[84:80]==InstReg[4][28:24]);
		I6DST_I0SRC1<=HalfReloadWire ? (IBUS[92:88]==InstReg[0][12:8]) : (IBUS[92:88]==InstReg[4][12:8]);
		I6DST_I0SRC2<=HalfReloadWire ? (IBUS[92:88]==InstReg[0][20:16]) : (IBUS[92:88]==InstReg[4][20:16]);
		I6DST_I0DST<=HalfReloadWire ? (IBUS[92:88]==InstReg[0][28:24]) : (IBUS[92:88]==InstReg[4][28:24]);

		I7SRC1_I6DST<=(IBUS[108:104]==IBUS[92:88]);
		I7SRC2_I6DST<=(IBUS[116:112]==IBUS[92:88]);
		I7DST_I6SRC1<=(IBUS[124:120]==IBUS[76:72]);
		I7DST_I6SRC2<=(IBUS[124:120]==IBUS[84:80]);
		I7DST_I6DST<=(IBUS[124:120]==IBUS[92:88]);
		I7SRC1_I5DST<=(IBUS[108:104]==IBUS[60:56]);
		I7SRC2_I5DST<=(IBUS[116:112]==IBUS[60:56]);
		I7DST_I5SRC1<=(IBUS[124:120]==IBUS[44:40]);
		I7DST_I5SRC2<=(IBUS[124:120]==IBUS[52:48]);
		I7DST_I5DST<=(IBUS[124:120]==IBUS[60:56]);
		I7SRC1_I4DST<=(IBUS[108:104]==IBUS[28:24]);
		I7SRC2_I4DST<=(IBUS[116:112]==IBUS[28:24]);
		I7DST_I4SRC1<=(IBUS[124:120]==IBUS[12:8]);
		I7DST_I4SRC2<=(IBUS[124:120]==IBUS[20:16]);
		I7DST_I4DST<=(IBUS[124:120]==IBUS[28:24]);
		I7SRC1_I3DST<=HalfReloadWire ? (IBUS[108:104]==InstReg[3][28:24]) : (IBUS[108:104]==InstReg[7][28:24]);
		I7SRC2_I3DST<=HalfReloadWire ? (IBUS[116:112]==InstReg[3][28:24]) : (IBUS[116:112]==InstReg[7][28:24]);
		I7DST_I3SRC1<=HalfReloadWire ? (IBUS[124:120]==InstReg[3][12:8]) : (IBUS[124:120]==InstReg[7][12:8]);
		I7DST_I3SRC2<=HalfReloadWire ? (IBUS[124:120]==InstReg[3][20:16]) : (IBUS[124:120]==InstReg[7][20:16]);
		I7DST_I3DST<=HalfReloadWire ? (IBUS[124:120]==InstReg[3][28:24]) : (IBUS[124:120]==InstReg[7][28:24]);
		I7SRC1_I2DST<=HalfReloadWire ? (IBUS[108:104]==InstReg[2][28:24]) : (IBUS[108:104]==InstReg[6][28:24]);
		I7SRC2_I2DST<=HalfReloadWire ? (IBUS[116:112]==InstReg[2][28:24]) : (IBUS[116:112]==InstReg[6][28:24]);
		I7DST_I2SRC1<=HalfReloadWire ? (IBUS[124:120]==InstReg[2][12:8]) : (IBUS[124:120]==InstReg[6][12:8]);
		I7DST_I2SRC2<=HalfReloadWire ? (IBUS[124:120]==InstReg[2][20:16]) : (IBUS[124:120]==InstReg[6][20:16]);
		I7DST_I2DST<=HalfReloadWire ? (IBUS[124:120]==InstReg[2][28:24]) : (IBUS[124:120]==InstReg[6][28:24]);
		I7SRC1_I1DST<=HalfReloadWire ? (IBUS[108:104]==InstReg[1][28:24]) : (IBUS[108:104]==InstReg[5][28:24]);
		I7SRC2_I1DST<=HalfReloadWire ? (IBUS[116:112]==InstReg[1][28:24]) : (IBUS[116:112]==InstReg[5][28:24]);
		I7DST_I1SRC1<=HalfReloadWire ? (IBUS[124:120]==InstReg[1][12:8]) : (IBUS[124:120]==InstReg[5][12:8]);
		I7DST_I1SRC2<=HalfReloadWire ? (IBUS[124:120]==InstReg[1][20:16]) : (IBUS[124:120]==InstReg[5][20:16]);
		I7DST_I1DST<=HalfReloadWire ? (IBUS[124:120]==InstReg[1][28:24]) : (IBUS[124:120]==InstReg[5][28:24]);
		I7SRC1_I0DST<=HalfReloadWire ? (IBUS[108:104]==InstReg[0][28:24]) : (IBUS[108:104]==InstReg[4][28:24]);
		I7SRC2_I0DST<=HalfReloadWire ? (IBUS[116:112]==InstReg[0][28:24]) : (IBUS[116:112]==InstReg[4][28:24]);
		I7DST_I0SRC1<=HalfReloadWire ? (IBUS[124:120]==InstReg[0][12:8]) : (IBUS[124:120]==InstReg[4][12:8]);
		I7DST_I0SRC2<=HalfReloadWire ? (IBUS[124:120]==InstReg[0][20:16]) : (IBUS[124:120]==InstReg[4][20:16]);
		I7DST_I0DST<=HalfReloadWire ? (IBUS[124:120]==InstReg[0][28:24]) : (IBUS[124:120]==InstReg[4][28:24]);
		end	
	// instruction valid flags
	for (i18=0; i18<4; i18=i18+1)
			if (InstReloadWire)
					begin
					VFReg[i18]<=VFReg[i18+4] & ~VFResetWire[i18+4];
					VFReg[i18+4]<=IRDY & VF[i18];
					end
					else begin
					if (HalfReloadWire)
							begin
							VFReg[i18]<=VFReg[i18] & ~VFResetWire[i18];
							VFReg[i18+4]<=IRDY & VF[i18];						
							end
							else begin
								VFReg[i18]<=VFReg[i18] & ~VFResetWire[i18];
								VFReg[i18+4]<=VFReg[i18+4] & ~VFResetWire[i18+4];
								end
					end
	// instruction type flags and operand verify flags
	for (i19=0; i19<4; i19=i19+1) 
		if (InstReloadWire)
			begin
			// Invalidation register
			GPRInvdR[i19]<=GPRInvdR[i19+4];
			// type regs
			TypeReg[i19]<=TypeReg[i19+4] & {11{~VFResetWire[i19+4]}};
			// Operand flags
			OpReg[i19]<=OpReg[i19+4];

			for (j0=0; j0<32; j0=j0+1)
				GPRInvdR[i19+4][j0]<=~IRDY | ~VF[i19] |
										~({IBUS[28+(i19<<5)],IBUS[27+(i19<<5)],IBUS[26+(i19<<5)],IBUS[25+(i19<<5)],IBUS[24+(i19<<5)]}==j0) |
										InvdVector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
													IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
			// FADD Flags
			TypeReg[i19+4][0]<=IRDY & VF[i19] &
				({IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],IBUS[3+(i19<<5)],IBUS[2+(i19<<5)]}==6'b000011);
			// FMUL Flags
			TypeReg[i19+4][1]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[3+(i19<<5)] & ~IBUS[2+(i19<<5)] & ~IBUS[1+(i19<<5)];
			// FDIV Flags
			TypeReg[i19+4][2]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[3+(i19<<5)] & ~IBUS[2+(i19<<5)] & IBUS[1+(i19<<5)];
			// ALU Flags
			TypeReg[i19+4][3]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
			// Shift Flags
			TypeReg[i19+4][4]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
			// Miscellaneous flags
			TypeReg[i19+4][5]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
			// Movement flags COPY, SETSIZE/AMODE, LI, XCHG
			TypeReg[i19+4][6]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & IBUS[3+(i19<<5)] &
													(~IBUS[2+(i19<<5)] | ~IBUS[1+(i19<<5)] | ~IBUS[0+(i19<<5)]);
			// LD/ST/PUSH/POP/LAR/SAR operations
			TypeReg[i19+4][7]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & 
													(~IBUS[3+(i19<<5)] | ~IBUS[2+(i19<<5)] | ~(IBUS[1+(i19<<5)] | IBUS[0+(i19<<5)]));
			//Flow control instructions
			TypeReg[i19+4][8]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & (~IBUS[3+(i19<<5)] | ~IBUS[2+(i19<<5)] | ~IBUS[1+(i19<<5)]);
			// FMULACC instruction
			TypeReg[i19+4][9]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[4+(i19<<5)] &
												~IBUS[3+(i19<<5)] & ~IBUS[2+(i19<<5)] & ~IBUS[1+(i19<<5)];
			// Invalid instruction
			TypeReg[i19+4][10]<=IRDY & VF[i19] & NopVector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
															IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
			// verification request for SRC_A  operand
			OpReg[i19+4][0]<=IRDY & VF[i19] & Op0Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
														IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
			// verification request for SRC B operand
			OpReg[i19+4][1]<=IRDY & VF[i19] & Op1Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
														IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
			// verification request for DST field as destination
			OpReg[i19+4][2]<=IRDY & VF[i19] & Op2Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
														IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
			end
			else begin
			if (HalfReloadWire)
				begin
				TypeReg[i19]<=TypeReg[i19] & {11{~VFResetWire[i19]}};
				for (j1=0; j1<32; j1=j1+1)
					GPRInvdR[i19+4][j1]<=~IRDY | ~VF[i19] |
										~({IBUS[28+(i19<<5)],IBUS[27+(i19<<5)],IBUS[26+(i19<<5)],IBUS[25+(i19<<5)],IBUS[24+(i19<<5)]}==j1) |
										InvdVector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
													IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
				// FADD Flags
				TypeReg[i19+4][0]<=IRDY & VF[i19] &
					({IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],IBUS[3+(i19<<5)],IBUS[2+(i19<<5)]}==6'b000011);
				// FMUL Flags
				TypeReg[i19+4][1]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[3+(i19<<5)] &
									~IBUS[2+(i19<<5)] & ~IBUS[1+(i19<<5)];
				// FDIV Flags
				TypeReg[i19+4][2]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[3+(i19<<5)] &
									~IBUS[2+(i19<<5)] & IBUS[1+(i19<<5)];
				// ALU Flags
				TypeReg[i19+4][3]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
				// Shift Flags
				TypeReg[i19+4][4]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
				// Miscellaneous flags
				TypeReg[i19+4][5]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & ~IBUS[3+(i19<<5)];
				// Movement flags COPY, SETSIZE/AMODE, LI, XCHG
				TypeReg[i19+4][6]<=IRDY & VF[i19] & ~IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & IBUS[3+(i19<<5)] &
													(~IBUS[2+(i19<<5)] | ~IBUS[1+(i19<<5)] | ~IBUS[0+(i19<<5)]);
				// LD/ST/PUSH/POP/LAR/SAR operations
				TypeReg[i19+4][7]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & 
													(~IBUS[3+(i19<<5)] | ~IBUS[2+(i19<<5)] | ~(IBUS[1+(i19<<5)] | IBUS[0+(i19<<5)]));
				//Flow control instructions
				TypeReg[i19+4][8]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & ~IBUS[4+(i19<<5)] & (~IBUS[3+(i19<<5)] | ~IBUS[2+(i19<<5)] | ~IBUS[1+(i19<<5)]);
				// FMULACC instruction
				TypeReg[i19+4][9]<=IRDY & VF[i19] & IBUS[7+(i19<<5)] & ~IBUS[6+(i19<<5)] & ~IBUS[5+(i19<<5)] & IBUS[4+(i19<<5)] &
													~IBUS[3+(i19<<5)] & ~IBUS[2+(i19<<5)] & ~IBUS[1+(i19<<5)];
				// Invalid instruction
				TypeReg[i19+4][10]<=IRDY & VF[i19] & NopVector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
																IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
				// verification request for SRC_A  operand
				OpReg[i19+4][0]<=IRDY & VF[i19] & Op0Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
															IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
				// verification request for SRC B operand
				OpReg[i19+4][1]<=IRDY & VF[i19] & Op1Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
															IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
				// verification request for DST field as destination
				OpReg[i19+4][2]<=IRDY & VF[i19] & Op2Vector[{IBUS[7+(i19<<5)],IBUS[6+(i19<<5)],IBUS[5+(i19<<5)],IBUS[4+(i19<<5)],
															IBUS[3+(i19<<5)],IBUS[2+(i19<<5)],IBUS[1+(i19<<5)],IBUS[0+(i19<<5)]}];
				end
				else begin
					TypeReg[i19]<=TypeReg[i19] & {11{~VFResetWire[i19]}};
					TypeReg[i19+4]<=TypeReg[i19+4] & {11{~VFResetWire[i19+4]}};
					end
			end
	end
	end

endmodule
