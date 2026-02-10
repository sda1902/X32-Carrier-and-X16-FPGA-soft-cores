module Cache4x512x1024DDR3 #(parameter TagWidth=21)(
			input wire RESET, CLK,
			// internal interface
			output wire INEXT,
			input wire IACT, ICMD,
			input wire [41:0] IADDR,
			input wire [63:0] IDATi,
			input wire [7:0] IBE,
			input wire [TagWidth-1:0] ITAGi,
			output reg IDRDY,
			output reg [63:0] IDATo,
			output reg [TagWidth-1:0] ITAGo,
			// interface to the DDR3 memory controller
			input wire avl_ready,
			output reg avl_burstbegin,
			output reg [38:0] avl_addr,
			input wire avl_rdata_valid,
			input wire [511:0] avl_rdata,
			output reg [511:0] avl_wdata,
			output reg [63:0] avl_be,
			output reg avl_read_req,
			output reg avl_write_req,
			output reg [2:0] avl_size
			);

integer i0, i1;

// control
logic IACTWire, NeedWriteCache;
reg EnaReg, InACTReg, InCMDReg, ClearFlag, ControlBypass, RamACTReg, RamCMDReg, ReadBypass, DeepReadBypass, LockLRURecycle, DeepControlBypass, RetFlag, BypassFlag;
reg [63:0] InDataReg, RamDataReg, DeepDataReg;
reg [41:0] InAddrReg, RamAddrReg;
reg [7:0] InBEReg, RamBEReg, DeepBEReg;
reg [TagWidth-1:0] InTagReg, RamTagReg;
logic [63:0] BEBus;

// fast access buffer registers
reg [511:0] BReg [0:3];
reg [38:0] BRegAddr [0:3];
reg [3:0] BRegValid, BRegMatch;
reg [63:0] DBReg [0:3];


// write buffer resources
reg [511:0] WBuff;
reg [38:0] WAddr, DWAddr;
reg [63:0] WFlags;
reg WBMatchFlag, WBInitReg, WBInWriteFlag, WriteRequest, WBResetFlag, FifoFullReg;
logic [614:0] WFifoBus;
logic WFifoEmpty, WBInWriteBus, WriteRequestWire;
logic [3:0] WFifoUsed;

logic [135:0] CMemBus, CMemInBus, CMemRegBus;
reg [135:0] CMemReg, CMemWDReg, CMemBypassReg;

reg [3:0] MatchFlag, CachedWFlag, CLRUSel, CacheValidFlag;

logic ReadRequest;

logic [511:0] DMemBus [0:3];
reg [511:0] DMemBusReg [0:3];
logic [63:0] CacheBus [0:3];
logic [511:0] ExtDataBus;


reg [63:0] DMemReg [0:3];
reg [63:0] RetReg;

reg [3:0] Machine;
localparam RS=4'd0, CLS=4'd1, WS=4'd2, CWS1=4'd3, CWS2=4'd4, CRS1=4'd5, CRS2=4'd6, RWS=4'd7, RSTS=4'd8, DBWS=4'd9, WWS=4'd10, WBAS=4'd11, UNS=4'd12;

reg [1:0] ETAGi, BurstCntr;

reg [7:0] CntReg;

reg WACTReg;
reg [41:0] WAddrReg;
reg [TagWidth-1:0] WTagReg;

logic wIACT, wICMD;
logic [41:0] wIADDR;
logic [7:0] wIBE;
logic [63:0] wIDATi;
logic [TagWidth-1:0] wITAGi;

reg BurstWriteFlag, BurstStartFlag;


// data buffers
altsyncram	DMem_0 (.addressstall_b(~(EnaReg | ((~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req)))&(Machine==CWS1)) | ((Machine==RSTS) & NeedWriteCache & InACTReg))),
				.wren_a((EnaReg & CachedWFlag[0]) | (CLRUSel[0] & avl_rdata_valid)), .clock0(CLK),
				.byteena_a(BEBus | {64{avl_rdata_valid}}), .address_a(avl_rdata_valid ? {RamAddrReg[12:5],ETAGi} : RamAddrReg[12:3]),
				.address_b((Machine==CWS1)|(Machine==CWS2) ? {RamAddrReg[12:5], BurstCntr}: (Machine==RSTS) ? InAddrReg [12:3] : wIADDR[12:3]),
				.data_a(avl_rdata_valid ? ExtDataBus : {8{RamDataReg}}), .q_b (DMemBus[0]), .aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0),
				.byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1), .clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b ({512{1'b1}}),
				.eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		DMem_0.address_aclr_b = "NONE",
		DMem_0.address_reg_b = "CLOCK0",
		DMem_0.byte_size = 8,
		DMem_0.clock_enable_input_a = "BYPASS",
		DMem_0.clock_enable_input_b = "BYPASS",
		DMem_0.clock_enable_output_b = "BYPASS",
		DMem_0.lpm_type = "altsyncram",
		DMem_0.numwords_a = 1024,
		DMem_0.numwords_b = 1024,
		DMem_0.operation_mode = "DUAL_PORT",
		DMem_0.outdata_aclr_b = "NONE",
		DMem_0.outdata_reg_b = "UNREGISTERED",
		DMem_0.power_up_uninitialized = "FALSE",
		DMem_0.read_during_write_mode_mixed_ports = "DONT_CARE",
		DMem_0.widthad_a = 10,
		DMem_0.widthad_b = 10,
		DMem_0.width_a = 512,
		DMem_0.width_b = 512,
		DMem_0.width_byteena_a = 64;
		
altsyncram	DMem_1 (.addressstall_b(~(EnaReg | ((~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req)))&(Machine==CWS1)) | ((Machine==RSTS) & NeedWriteCache & InACTReg))),
				.wren_a((EnaReg & CachedWFlag[1]) | (CLRUSel[1] & avl_rdata_valid)), .clock0(CLK),
				.byteena_a(BEBus | {64{avl_rdata_valid}}), .address_a(avl_rdata_valid ? {RamAddrReg[12:5],ETAGi} : RamAddrReg[12:3]),
				.address_b((Machine==CWS1)|(Machine==CWS2) ? {RamAddrReg[12:5], BurstCntr}: (Machine==RSTS) ? InAddrReg [12:3] : wIADDR[12:3]),
				.data_a(avl_rdata_valid ? ExtDataBus : {8{RamDataReg}}), .q_b (DMemBus[1]), .aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0),
				.byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1), .clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b ({512{1'b1}}),
				.eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		DMem_1.address_aclr_b = "NONE",
		DMem_1.address_reg_b = "CLOCK0",
		DMem_1.byte_size = 8,
		DMem_1.clock_enable_input_a = "BYPASS",
		DMem_1.clock_enable_input_b = "BYPASS",
		DMem_1.clock_enable_output_b = "BYPASS",
		DMem_1.lpm_type = "altsyncram",
		DMem_1.numwords_a = 1024,
		DMem_1.numwords_b = 1024,
		DMem_1.operation_mode = "DUAL_PORT",
		DMem_1.outdata_aclr_b = "NONE",
		DMem_1.outdata_reg_b = "UNREGISTERED",
		DMem_1.power_up_uninitialized = "FALSE",
		DMem_1.read_during_write_mode_mixed_ports = "DONT_CARE",
		DMem_1.widthad_a = 10,
		DMem_1.widthad_b = 10,
		DMem_1.width_a = 512,
		DMem_1.width_b = 512,
		DMem_1.width_byteena_a = 64;

altsyncram	DMem_2 (.addressstall_b(~(EnaReg | ((~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req)))&(Machine==CWS1)) | ((Machine==RSTS) & NeedWriteCache & InACTReg))),
				.wren_a((EnaReg & CachedWFlag[2]) | (CLRUSel[2] & avl_rdata_valid)), .clock0(CLK),
				.byteena_a(BEBus| {64{avl_rdata_valid}}), .address_a(avl_rdata_valid ? {RamAddrReg[12:5],ETAGi} : RamAddrReg[12:3]),
				.address_b((Machine==CWS1)|(Machine==CWS2) ? {RamAddrReg[12:5], BurstCntr}: (Machine==RSTS) ? InAddrReg [12:3] : wIADDR[12:3]),
				.data_a(avl_rdata_valid ? ExtDataBus : {8{RamDataReg}}), .q_b (DMemBus[2]), .aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0),
				.byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1), .clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b ({512{1'b1}}),
				.eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		DMem_2.address_aclr_b = "NONE",
		DMem_2.address_reg_b = "CLOCK0",
		DMem_2.byte_size = 8,
		DMem_2.clock_enable_input_a = "BYPASS",
		DMem_2.clock_enable_input_b = "BYPASS",
		DMem_2.clock_enable_output_b = "BYPASS",
		DMem_2.lpm_type = "altsyncram",
		DMem_2.numwords_a = 1024,
		DMem_2.numwords_b = 1024,
		DMem_2.operation_mode = "DUAL_PORT",
		DMem_2.outdata_aclr_b = "NONE",
		DMem_2.outdata_reg_b = "UNREGISTERED",
		DMem_2.power_up_uninitialized = "FALSE",
		DMem_2.read_during_write_mode_mixed_ports = "DONT_CARE",
		DMem_2.widthad_a = 10,
		DMem_2.widthad_b = 10,
		DMem_2.width_a = 512,
		DMem_2.width_b = 512,
		DMem_2.width_byteena_a = 64;

altsyncram	DMem_3 (.addressstall_b(~(EnaReg | ((~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req)))&(Machine==CWS1)) | ((Machine==RSTS) & NeedWriteCache & InACTReg))),
				.wren_a((EnaReg & CachedWFlag[3]) | (CLRUSel[3] & avl_rdata_valid)), .clock0(CLK),
				.byteena_a(BEBus | {64{avl_rdata_valid}}), .address_a(avl_rdata_valid ? {RamAddrReg[12:5],ETAGi} : RamAddrReg[12:3]),
				.address_b((Machine==CWS1)|(Machine==CWS2) ? {RamAddrReg[12:5], BurstCntr}: (Machine==RSTS) ? InAddrReg [12:3] : wIADDR[12:3]),
				.data_a(avl_rdata_valid ? ExtDataBus : {8{RamDataReg}}), .q_b (DMemBus[3]), .aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0),
				.byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1), .clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b ({512{1'b1}}),
				.eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		DMem_3.address_aclr_b = "NONE",
		DMem_3.address_reg_b = "CLOCK0",
		DMem_3.byte_size = 8,
		DMem_3.clock_enable_input_a = "BYPASS",
		DMem_3.clock_enable_input_b = "BYPASS",
		DMem_3.clock_enable_output_b = "BYPASS",
		DMem_3.lpm_type = "altsyncram",
		DMem_3.numwords_a = 1024,
		DMem_3.numwords_b = 1024,
		DMem_3.operation_mode = "DUAL_PORT",
		DMem_3.outdata_aclr_b = "NONE",
		DMem_3.outdata_reg_b = "UNREGISTERED",
		DMem_3.power_up_uninitialized = "FALSE",
		DMem_3.read_during_write_mode_mixed_ports = "DONT_CARE",
		DMem_3.widthad_a = 10,
		DMem_3.widthad_b = 10,
		DMem_3.width_a = 512,
		DMem_3.width_b = 512,
		DMem_3.width_byteena_a = 64;
		
// control memory
// control RAM with address bits [28:0], valid flag [29], modify flag [30], LRU bits [33:31],
//								[62:34]				[63]				[64]		[67:65],
//								[96:68]				[97]				[98]		[101:99],
//								[130:102]			[131]				[132]		[135:133]
altsyncram	CRAM(.addressstall_b(~EnaReg), .wren_a(((|MatchFlag) & RamACTReg & EnaReg)|ClearFlag|(Machine==UNS)), .clock0(CLK),
				.address_a(ClearFlag ? CntReg : RamAddrReg[12:5]), .address_b(wIADDR[12:5]), .data_a(CMemInBus), .q_b(CMemBus),
				.aclr0(1'b0), .aclr1(1'b0), .addressstall_a(1'b0), .byteena_a(1'b1), .byteena_b(1'b1), .clock1(1'b1),
				.clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1), .data_b({136{1'b1}}), .eccstatus(),
				.q_a(), .rden_a(1'b1), .rden_b(1'b1), .wren_b(1'b0));
	defparam
		CRAM.address_aclr_b = "NONE",
		CRAM.address_reg_b = "CLOCK0",
		CRAM.clock_enable_input_a = "BYPASS",
		CRAM.clock_enable_input_b = "BYPASS",
		CRAM.clock_enable_output_b = "BYPASS",
		CRAM.lpm_type = "altsyncram",
		CRAM.numwords_a = 256,
		CRAM.numwords_b = 256,
		CRAM.operation_mode = "DUAL_PORT",
		CRAM.outdata_aclr_b = "NONE",
		CRAM.outdata_reg_b = "UNREGISTERED",
		CRAM.power_up_uninitialized = "FALSE",
		CRAM.read_during_write_mode_mixed_ports = "OLD_DATA",
		CRAM.widthad_a = 8,
		CRAM.widthad_b = 8,
		CRAM.width_a = 136,
		CRAM.width_b = 136,
		CRAM.width_byteena_a = 1;
		
// write fifo
sc_fifo #(.LPM_WIDTH(512+64+39), .LPM_NUMWORDS(16), .LPM_WIDTHU(4)) WFifo (
			.data({DWAddr,WFlags,WBuff}), .wrreq(WriteRequest),.rdreq(((~avl_read_req & ~avl_write_req)| avl_ready) & ~WFifoEmpty & (Machine==WS)), 
			.clock(CLK), .sclr(~RESET), .q(WFifoBus), .empty(WFifoEmpty), .full(), .almost_empty(), .usedw(WFifoUsed));


assign INEXT=EnaReg & ~WACTReg;
		
//-------------------------------------------------------------------------------------------------
//								Asynchronous logic
//-------------------------------------------------------------------------------------------------
always_comb
begin

// muxing transaction on the cache input
wIACT=IACT | WACTReg;
wICMD=ICMD | WACTReg;
wIADDR=WACTReg ? WAddrReg : IADDR;
wIBE=IBE & {8{~WACTReg}};
wIDATi=IDATi;
wITAGi=WACTReg? WTagReg : ITAGi;

case (InAddrReg[2:0])
	3'd0:	begin CacheBus[0]=DMemBus[0][63:0]; CacheBus[1]=DMemBus[1][63:0]; CacheBus[2]=DMemBus[2][63:0]; CacheBus[3]=DMemBus[3][63:0]; end
	3'd1:	begin CacheBus[0]=DMemBus[0][127:64]; CacheBus[1]=DMemBus[1][127:64]; CacheBus[2]=DMemBus[2][127:64]; CacheBus[3]=DMemBus[3][127:64]; end
	3'd2:	begin CacheBus[0]=DMemBus[0][191:128]; CacheBus[1]=DMemBus[1][191:128]; CacheBus[2]=DMemBus[2][191:128]; CacheBus[3]=DMemBus[3][191:128]; end
	3'd3:	begin CacheBus[0]=DMemBus[0][255:192]; CacheBus[1]=DMemBus[1][255:192]; CacheBus[2]=DMemBus[2][255:192]; CacheBus[3]=DMemBus[3][255:192]; end
	3'd4:	begin CacheBus[0]=DMemBus[0][319:256]; CacheBus[1]=DMemBus[1][319:256]; CacheBus[2]=DMemBus[2][319:256]; CacheBus[3]=DMemBus[3][319:256]; end
	3'd5:	begin CacheBus[0]=DMemBus[0][383:320]; CacheBus[1]=DMemBus[1][383:320]; CacheBus[2]=DMemBus[2][383:320]; CacheBus[3]=DMemBus[3][383:320]; end
	3'd6:	begin CacheBus[0]=DMemBus[0][447:384]; CacheBus[1]=DMemBus[1][447:384]; CacheBus[2]=DMemBus[2][447:384]; CacheBus[3]=DMemBus[3][447:384]; end
	3'd7:	begin CacheBus[0]=DMemBus[0][511:448]; CacheBus[1]=DMemBus[1][511:448]; CacheBus[2]=DMemBus[2][511:448]; CacheBus[3]=DMemBus[3][511:448]; end
	endcase

// New value for control memory
CMemInBus={(CMemReg[135:133]-{2'd0,|CMemReg[135:133]})|{3{MatchFlag[3] | CacheValidFlag[3]}},
				CacheValidFlag[3] ? WBMatchFlag : CMemReg[132] | CachedWFlag[3], CMemReg[131] | CacheValidFlag[3],
				CacheValidFlag[3] ? RamAddrReg[41:13] : CMemReg[130:102],
			(CMemReg[101:99]-{2'd0,|CMemReg[101:99]})|{3{MatchFlag[2] | CacheValidFlag[2]}},
				CacheValidFlag[2] ? WBMatchFlag : CMemReg[98] | CachedWFlag[2], CMemReg[97] | CacheValidFlag[2],
				CacheValidFlag[2] ? RamAddrReg[41:13] : CMemReg[96:68],
			(CMemReg[67:65]-{2'd0,|CMemReg[67:65]})|{3{MatchFlag[1] | CacheValidFlag[1]}},
				CacheValidFlag[1] ? WBMatchFlag : CMemReg[64] | CachedWFlag[1], CMemReg[63] | CacheValidFlag[1],
				CacheValidFlag[1] ? RamAddrReg[41:13] : CMemReg[62:34],
			(CMemReg[33:31]-{2'd0,|CMemReg[33:31]})|{3{MatchFlag[0] | CacheValidFlag[0]}},
				CacheValidFlag[0] ? WBMatchFlag : CMemReg[30] | CachedWFlag[0], CMemReg[29] | CacheValidFlag[0],
				CacheValidFlag[0] ? RamAddrReg[41:13] : CMemReg[28:0]} & {136{~ClearFlag}};
// new value for control register
CMemRegBus=ControlBypass ? CMemInBus : (DeepControlBypass ? CMemBypassReg : CMemBus);

// create databuses for to write to the cache
ExtDataBus[7:0]=(WBMatchFlag & WFlags[0] & (ETAGi==WAddr[1:0])) ? WBuff[7:0] : avl_rdata[7:0];
ExtDataBus[15:8]=(WBMatchFlag & WFlags[1] & (ETAGi==WAddr[1:0])) ? WBuff[15:8] : avl_rdata[15:8];
ExtDataBus[23:16]=(WBMatchFlag & WFlags[2] & (ETAGi==WAddr[1:0])) ? WBuff[23:16] : avl_rdata[23:16];
ExtDataBus[31:24]=(WBMatchFlag & WFlags[3] & (ETAGi==WAddr[1:0])) ? WBuff[31:24] : avl_rdata[31:24];
ExtDataBus[39:32]=(WBMatchFlag & WFlags[4] & (ETAGi==WAddr[1:0])) ? WBuff[39:32] : avl_rdata[39:32];
ExtDataBus[47:40]=(WBMatchFlag & WFlags[5] & (ETAGi==WAddr[1:0])) ? WBuff[47:40] : avl_rdata[47:40];
ExtDataBus[55:48]=(WBMatchFlag & WFlags[6] & (ETAGi==WAddr[1:0])) ? WBuff[55:48] : avl_rdata[55:48];
ExtDataBus[63:56]=(WBMatchFlag & WFlags[7] & (ETAGi==WAddr[1:0])) ? WBuff[63:56] : avl_rdata[63:56];
ExtDataBus[71:64]=(WBMatchFlag & WFlags[8] & (ETAGi==WAddr[1:0])) ? WBuff[71:64] : avl_rdata[71:64];
ExtDataBus[79:72]=(WBMatchFlag & WFlags[9] & (ETAGi==WAddr[1:0])) ? WBuff[79:72] : avl_rdata[79:72];
ExtDataBus[87:80]=(WBMatchFlag & WFlags[10] & (ETAGi==WAddr[1:0])) ? WBuff[87:80] : avl_rdata[87:80];
ExtDataBus[95:88]=(WBMatchFlag & WFlags[11] & (ETAGi==WAddr[1:0])) ? WBuff[95:88] : avl_rdata[95:88];
ExtDataBus[103:96]=(WBMatchFlag & WFlags[12] & (ETAGi==WAddr[1:0])) ? WBuff[103:96] : avl_rdata[103:96];
ExtDataBus[111:104]=(WBMatchFlag & WFlags[13] & (ETAGi==WAddr[1:0])) ? WBuff[111:104] : avl_rdata[111:104];
ExtDataBus[119:112]=(WBMatchFlag & WFlags[14] & (ETAGi==WAddr[1:0])) ? WBuff[119:112] : avl_rdata[119:112];
ExtDataBus[127:120]=(WBMatchFlag & WFlags[15] & (ETAGi==WAddr[1:0])) ? WBuff[127:120] : avl_rdata[127:120];
ExtDataBus[135:128]=(WBMatchFlag & WFlags[16] & (ETAGi==WAddr[1:0])) ? WBuff[135:128] : avl_rdata[135:128];
ExtDataBus[143:136]=(WBMatchFlag & WFlags[17] & (ETAGi==WAddr[1:0])) ? WBuff[143:136] : avl_rdata[143:136];
ExtDataBus[151:144]=(WBMatchFlag & WFlags[18] & (ETAGi==WAddr[1:0])) ? WBuff[151:144] : avl_rdata[151:144];
ExtDataBus[159:152]=(WBMatchFlag & WFlags[19] & (ETAGi==WAddr[1:0])) ? WBuff[159:152] : avl_rdata[159:152];
ExtDataBus[167:160]=(WBMatchFlag & WFlags[20] & (ETAGi==WAddr[1:0])) ? WBuff[167:160] : avl_rdata[167:160];
ExtDataBus[175:168]=(WBMatchFlag & WFlags[21] & (ETAGi==WAddr[1:0])) ? WBuff[175:168] : avl_rdata[175:168];
ExtDataBus[183:176]=(WBMatchFlag & WFlags[22] & (ETAGi==WAddr[1:0])) ? WBuff[183:176] : avl_rdata[183:176];
ExtDataBus[191:184]=(WBMatchFlag & WFlags[23] & (ETAGi==WAddr[1:0])) ? WBuff[191:184] : avl_rdata[191:184];
ExtDataBus[199:192]=(WBMatchFlag & WFlags[24] & (ETAGi==WAddr[1:0])) ? WBuff[199:192] : avl_rdata[199:192];
ExtDataBus[207:200]=(WBMatchFlag & WFlags[25] & (ETAGi==WAddr[1:0])) ? WBuff[207:200] : avl_rdata[207:200];
ExtDataBus[215:208]=(WBMatchFlag & WFlags[26] & (ETAGi==WAddr[1:0])) ? WBuff[215:208] : avl_rdata[215:208];
ExtDataBus[223:216]=(WBMatchFlag & WFlags[27] & (ETAGi==WAddr[1:0])) ? WBuff[223:216] : avl_rdata[223:216];
ExtDataBus[231:224]=(WBMatchFlag & WFlags[28] & (ETAGi==WAddr[1:0])) ? WBuff[231:224] : avl_rdata[231:224];
ExtDataBus[239:232]=(WBMatchFlag & WFlags[29] & (ETAGi==WAddr[1:0])) ? WBuff[239:232] : avl_rdata[239:232];
ExtDataBus[247:240]=(WBMatchFlag & WFlags[30] & (ETAGi==WAddr[1:0])) ? WBuff[247:240] : avl_rdata[247:240];
ExtDataBus[255:248]=(WBMatchFlag & WFlags[31] & (ETAGi==WAddr[1:0])) ? WBuff[255:248] : avl_rdata[255:248];
ExtDataBus[263:256]=(WBMatchFlag & WFlags[32] & (ETAGi==WAddr[1:0])) ? WBuff[263:256] : avl_rdata[263:256];
ExtDataBus[271:264]=(WBMatchFlag & WFlags[33] & (ETAGi==WAddr[1:0])) ? WBuff[271:264] : avl_rdata[271:264];
ExtDataBus[279:272]=(WBMatchFlag & WFlags[34] & (ETAGi==WAddr[1:0])) ? WBuff[279:272] : avl_rdata[279:272];
ExtDataBus[287:280]=(WBMatchFlag & WFlags[35] & (ETAGi==WAddr[1:0])) ? WBuff[287:280] : avl_rdata[287:280];
ExtDataBus[295:288]=(WBMatchFlag & WFlags[36] & (ETAGi==WAddr[1:0])) ? WBuff[295:288] : avl_rdata[295:288];
ExtDataBus[303:296]=(WBMatchFlag & WFlags[37] & (ETAGi==WAddr[1:0])) ? WBuff[303:296] : avl_rdata[303:296];
ExtDataBus[311:304]=(WBMatchFlag & WFlags[38] & (ETAGi==WAddr[1:0])) ? WBuff[311:304] : avl_rdata[311:304];
ExtDataBus[319:312]=(WBMatchFlag & WFlags[39] & (ETAGi==WAddr[1:0])) ? WBuff[319:312] : avl_rdata[319:312];
ExtDataBus[327:320]=(WBMatchFlag & WFlags[40] & (ETAGi==WAddr[1:0])) ? WBuff[327:320] : avl_rdata[327:320];
ExtDataBus[335:328]=(WBMatchFlag & WFlags[41] & (ETAGi==WAddr[1:0])) ? WBuff[335:328] : avl_rdata[335:328];
ExtDataBus[343:336]=(WBMatchFlag & WFlags[42] & (ETAGi==WAddr[1:0])) ? WBuff[343:336] : avl_rdata[343:336];
ExtDataBus[351:344]=(WBMatchFlag & WFlags[43] & (ETAGi==WAddr[1:0])) ? WBuff[351:344] : avl_rdata[351:344];
ExtDataBus[359:352]=(WBMatchFlag & WFlags[44] & (ETAGi==WAddr[1:0])) ? WBuff[359:352] : avl_rdata[359:352];
ExtDataBus[367:360]=(WBMatchFlag & WFlags[45] & (ETAGi==WAddr[1:0])) ? WBuff[367:360] : avl_rdata[367:360];
ExtDataBus[375:368]=(WBMatchFlag & WFlags[46] & (ETAGi==WAddr[1:0])) ? WBuff[375:368] : avl_rdata[375:368];
ExtDataBus[383:376]=(WBMatchFlag & WFlags[47] & (ETAGi==WAddr[1:0])) ? WBuff[383:376] : avl_rdata[383:376];
ExtDataBus[391:384]=(WBMatchFlag & WFlags[48] & (ETAGi==WAddr[1:0])) ? WBuff[391:384] : avl_rdata[391:384];
ExtDataBus[399:392]=(WBMatchFlag & WFlags[49] & (ETAGi==WAddr[1:0])) ? WBuff[399:392] : avl_rdata[399:392];
ExtDataBus[407:400]=(WBMatchFlag & WFlags[50] & (ETAGi==WAddr[1:0])) ? WBuff[407:400] : avl_rdata[407:400];
ExtDataBus[415:408]=(WBMatchFlag & WFlags[51] & (ETAGi==WAddr[1:0])) ? WBuff[415:408] : avl_rdata[415:408];
ExtDataBus[423:416]=(WBMatchFlag & WFlags[52] & (ETAGi==WAddr[1:0])) ? WBuff[423:416] : avl_rdata[423:416];
ExtDataBus[431:424]=(WBMatchFlag & WFlags[53] & (ETAGi==WAddr[1:0])) ? WBuff[431:424] : avl_rdata[431:424];
ExtDataBus[439:432]=(WBMatchFlag & WFlags[54] & (ETAGi==WAddr[1:0])) ? WBuff[439:432] : avl_rdata[439:432];
ExtDataBus[447:440]=(WBMatchFlag & WFlags[55] & (ETAGi==WAddr[1:0])) ? WBuff[447:440] : avl_rdata[447:440];
ExtDataBus[455:448]=(WBMatchFlag & WFlags[56] & (ETAGi==WAddr[1:0])) ? WBuff[455:448] : avl_rdata[455:448];
ExtDataBus[463:456]=(WBMatchFlag & WFlags[57] & (ETAGi==WAddr[1:0])) ? WBuff[463:456] : avl_rdata[463:456];
ExtDataBus[471:464]=(WBMatchFlag & WFlags[58] & (ETAGi==WAddr[1:0])) ? WBuff[471:464] : avl_rdata[471:464];
ExtDataBus[479:472]=(WBMatchFlag & WFlags[59] & (ETAGi==WAddr[1:0])) ? WBuff[479:472] : avl_rdata[479:472];
ExtDataBus[487:480]=(WBMatchFlag & WFlags[60] & (ETAGi==WAddr[1:0])) ? WBuff[487:480] : avl_rdata[487:480];
ExtDataBus[495:488]=(WBMatchFlag & WFlags[61] & (ETAGi==WAddr[1:0])) ? WBuff[495:488] : avl_rdata[495:488];
ExtDataBus[503:496]=(WBMatchFlag & WFlags[62] & (ETAGi==WAddr[1:0])) ? WBuff[503:496] : avl_rdata[503:496];
ExtDataBus[511:504]=(WBMatchFlag & WFlags[63] & (ETAGi==WAddr[1:0])) ? WBuff[511:504] : avl_rdata[511:504];

// if cache line must be writed to the memory
NeedWriteCache=(CLRUSel[0] & CMemReg[30]) | (CLRUSel[1] & CMemReg[64]) | (CLRUSel[2] & CMemReg[98]) | (CLRUSel[3] & CMemReg[132]);

// write buffer flags
WBInWriteBus=InACTReg & ~InCMDReg & ((CMemRegBus[28:0]!=InAddrReg[41:13]) | ~CMemRegBus[29]) & ((CMemRegBus[62:34]!=InAddrReg[41:13]) | ~CMemRegBus[63]) &
						((CMemRegBus[96:68]!=InAddrReg[41:13]) | ~CMemRegBus[97]) & ((CMemRegBus[130:102]!=InAddrReg[41:13]) | ~CMemRegBus[131]);
						
// internal activation
IACTWire=wIACT & (~((BRegValid[0] & (BRegAddr[0]==wIADDR[41:3]))|
					(BRegValid[1] & (BRegAddr[1]==wIADDR[41:3]))|
					(BRegValid[2] & (BRegAddr[2]==wIADDR[41:3]))|
					(BRegValid[3] & (BRegAddr[3]==wIADDR[41:3]))) | ~wICMD);

WriteRequestWire=EnaReg & InACTReg & ~InCMDReg & (WAddr!=InAddrReg[41:3]) & WBInitReg &
						~(((CMemRegBus[28:0]==InAddrReg[41:13]) & CMemRegBus[29])|((CMemRegBus[62:34]==InAddrReg[41:13]) & CMemRegBus[63])|
						((CMemRegBus[96:68]==InAddrReg[41:13]) & CMemRegBus[97])|((CMemRegBus[130:102]==InAddrReg[41:13]) & CMemRegBus[131]));

//RAM write flags
BEBus={~RamBEReg & {8{RamAddrReg[2:0]==3'd7}},~RamBEReg & {8{RamAddrReg[2:0]==3'd6}},~RamBEReg & {8{RamAddrReg[2:0]==3'd5}},~RamBEReg & {8{RamAddrReg[2:0]==3'd4}},
		~RamBEReg & {8{RamAddrReg[2:0]==3'd3}},~RamBEReg & {8{RamAddrReg[2:0]==3'd2}},~RamBEReg & {8{RamAddrReg[2:0]==3'd1}},~RamBEReg & {8{RamAddrReg[2:0]==3'd0}}};

end		


//-------------------------------------------------------------------------------------------------
//								Synchronous logic
//-------------------------------------------------------------------------------------------------
always_ff @(posedge CLK or negedge RESET)
if (~RESET)
	begin
	WBInitReg<=0;
	WFlags<=64'd0;
	WBInWriteFlag<=0;
	ClearFlag<=1'b1;
	EnaReg<=1'b0;
	BRegValid<=4'd0;				// data loaded from memory
	BRegMatch<=4'd0;				// match flags
	EnaReg<=1'b0;
	Machine<=RS;
	ReadRequest<=1'b0;
	WriteRequest<=1'b0;
	avl_read_req<=1'b0;
	avl_write_req<=1'b0;
	ClearFlag<=1'b1;
	InACTReg<=1'b0;
	RamACTReg<=1'b0;
	WBMatchFlag<=0;
	RetFlag<=1'b0;
	CacheValidFlag<=4'd0;
	IDRDY<=0;
	LockLRURecycle<=0;
	DeepControlBypass<=0;
	CMemBypassReg<=0;
	WACTReg<=0;
	BypassFlag<=0;
	FifoFullReg<=0;
	BurstWriteFlag<=0;
	BurstStartFlag<=0;
	end
else begin


// stall transaction
if (EnaReg) WACTReg<=wIACT & wICMD & ((InACTReg & InCMDReg)|(RamACTReg & RamCMDReg)) & 
		((BRegValid[0] & (BRegAddr[0]==wIADDR[41:3]))|(BRegValid[1] & (BRegAddr[1]==wIADDR[41:3]))|
			(BRegValid[2] & (BRegAddr[2]==wIADDR[41:3]))|(BRegValid[3] & (BRegAddr[3]==wIADDR[41:3])));
if (~WACTReg)
	begin
	WAddrReg<=IADDR;
	WTagReg<=ITAGi;
	end

WriteRequest<=WriteRequestWire;


FifoFullReg<=(FifoFullReg | (WriteRequestWire & WFifoUsed[3])) & ~(avl_ready & avl_write_req & ~WFifoUsed[3] & FifoFullReg);

EnaReg<=(EnaReg & (~InACTReg |
					((CMemRegBus[28:0]==InAddrReg[41:13]) & CMemRegBus[29])|
					((CMemRegBus[62:34]==InAddrReg[41:13]) & CMemRegBus[63])|
					((CMemRegBus[96:68]==InAddrReg[41:13]) & CMemRegBus[97])|
					((CMemRegBus[130:102]==InAddrReg[41:13]) & CMemRegBus[131])|
					(WBInWriteBus))&
				~(WriteRequestWire & WFifoUsed[3]))| 
		(Machine==UNS)|(&CntReg & (Machine==CLS))|(avl_ready & avl_write_req & ~WFifoUsed[3] & FifoFullReg);
 
LockLRURecycle<=(Machine==UNS) & ControlBypass;

CMemBypassReg<=CMemInBus;

DeepControlBypass<=(RamAddrReg[12:5]==wIADDR[12:5]) & IACTWire & INEXT & (((|MatchFlag) & RamACTReg & EnaReg)|(Machine==UNS));

if (((Machine==UNS) & ControlBypass)|(EnaReg & ~LockLRURecycle))
	begin
	
	// control register
	CMemReg<=CMemRegBus;
	
	// Calculate LRU for cache
	CLRUSel[0]<=((CMemRegBus[33:31]<=CMemRegBus[67:65])&(CMemRegBus[33:31]<=CMemRegBus[101:99])&(CMemRegBus[33:31]<=CMemRegBus[135:133])& 
				CMemRegBus[63] & CMemRegBus[97] & CMemRegBus[131]) | ~CMemRegBus[29];
	CLRUSel[1]<=((CMemRegBus[67:65]<CMemRegBus[33:31])&(CMemRegBus[67:65]<=CMemRegBus[101:99])&(CMemRegBus[67:65]<=CMemRegBus[135:133])&
				CMemRegBus[29] & CMemRegBus[97] & CMemRegBus[131]) | (~CMemRegBus[63] & CMemRegBus[29]);
	CLRUSel[2]<=((CMemRegBus[101:99]<CMemRegBus[33:31])&(CMemRegBus[101:99]<CMemRegBus[67:65])&(CMemRegBus[101:99]<=CMemRegBus[135:133])&
				CMemRegBus[29] & CMemRegBus[63] & CMemRegBus[131]) | (~CMemRegBus[97] & CMemRegBus[29] & CMemRegBus[63]);
	CLRUSel[3]<=((CMemRegBus[135:133]<CMemRegBus[33:31])&(CMemRegBus[135:133]<CMemRegBus[67:65])&(CMemRegBus[135:133]<CMemRegBus[101:99])&
				CMemRegBus[29] & CMemRegBus[63] & CMemRegBus[97]) | (~CMemRegBus[131] & CMemRegBus[29] & CMemRegBus[63] & CMemRegBus[97]);

	end

	
// request to read new cache line
if (EnaReg | (Machine==RSTS))
	ReadRequest<=EnaReg & InACTReg & InCMDReg & ~(((CMemRegBus[28:0]==InAddrReg[41:13]) & CMemRegBus[29])|
											((CMemRegBus[62:34]==InAddrReg[41:13]) & CMemRegBus[63])|
											((CMemRegBus[96:68]==InAddrReg[41:13]) & CMemRegBus[97])|
											((CMemRegBus[130:102]==InAddrReg[41:13]) & CMemRegBus[131])) & (Machine!=RSTS);

if (EnaReg)
	begin
	InACTReg<=IACTWire;
	InCMDReg<=wICMD;
	InAddrReg<=wIADDR;
	InDataReg<=wIDATi;
	// tag
	InTagReg<=wITAGi;
	// byte enables
	InBEReg<=wIBE;
	// bypass control register
	ControlBypass<=(InAddrReg[12:5]==wIADDR[12:5]) & IACTWire & InACTReg;
	// bypass data registers flags
	ReadBypass<=(wIADDR[41:0]==InAddrReg[41:0]) & InACTReg & ~InCMDReg & IACTWire & wICMD & (Machine!=CWS1) & (Machine!=CWS2);
	// deep bypass flags
	DeepReadBypass<=(wIADDR[41:0]==RamAddrReg[41:0]) & RamACTReg & ~RamCMDReg & IACTWire & wICMD & (Machine!=CWS1) & (Machine!=CWS2);
	
	RamACTReg<=InACTReg;
	// command
	RamCMDReg<=InCMDReg;
	// input address
	RamAddrReg<=InAddrReg;
	// input data
	RamDataReg<=InDataReg;
	// write data into WBuff, if address equal
	WBInWriteFlag<=WBInWriteBus;
	// write buffer match flags set to 1 when address of write buffer equal to the read address
	WBMatchFlag<=InACTReg & InCMDReg & (WAddr[38:2]==InAddrReg[41:5]) & WBInitReg;
	// RAM output stage
	// cache match flags
	MatchFlag[0]<=(CMemRegBus[28:0]==InAddrReg[41:13]) & CMemRegBus[29] & InACTReg;
	MatchFlag[1]<=(CMemRegBus[62:34]==InAddrReg[41:13]) & CMemRegBus[63] & InACTReg;
	MatchFlag[2]<=(CMemRegBus[96:68]==InAddrReg[41:13]) & CMemRegBus[97] & InACTReg;
	MatchFlag[3]<=(CMemRegBus[130:102]==InAddrReg[41:13]) & CMemRegBus[131] & InACTReg;
	// cached write flags
	CachedWFlag[0]<=(CMemRegBus[28:0]==InAddrReg[41:13]) & CMemRegBus[29] & InACTReg & ~InCMDReg;
	CachedWFlag[1]<=(CMemRegBus[62:34]==InAddrReg[41:13]) & CMemRegBus[63] & InACTReg & ~InCMDReg;
	CachedWFlag[2]<=(CMemRegBus[96:68]==InAddrReg[41:13]) & CMemRegBus[97] & InACTReg & ~InCMDReg;
	CachedWFlag[3]<=(CMemRegBus[130:102]==InAddrReg[41:13]) & CMemRegBus[131] & InACTReg & ~InCMDReg;
	// Tag register
	RamTagReg<=InTagReg;
	// BE signals
	RamBEReg<=InBEReg;
	// delayed registers
	DeepBEReg<=RamBEReg;
	DeepDataReg<=RamDataReg;
	
	DMemReg[0]<={(~RamBEReg[7] & ReadBypass) ? RamDataReg[63:56] : (~DeepBEReg[7] & DeepReadBypass) ? DeepDataReg[63:56] : CacheBus[0][63:56],
				(~RamBEReg[6] & ReadBypass) ? RamDataReg[55:48] : (~DeepBEReg[6] & DeepReadBypass) ? DeepDataReg[55:48] : CacheBus[0][55:48],
				(~RamBEReg[5] & ReadBypass) ? RamDataReg[47:40] : (~DeepBEReg[5] & DeepReadBypass) ? DeepDataReg[47:40] : CacheBus[0][47:40],
				(~RamBEReg[4] & ReadBypass) ? RamDataReg[39:32] : (~DeepBEReg[4] & DeepReadBypass) ? DeepDataReg[39:32] : CacheBus[0][39:32],
				(~RamBEReg[3] & ReadBypass) ? RamDataReg[31:24] : (~DeepBEReg[3] & DeepReadBypass) ? DeepDataReg[31:24] : CacheBus[0][31:24],
				(~RamBEReg[2] & ReadBypass) ? RamDataReg[23:16] : (~DeepBEReg[2] & DeepReadBypass) ? DeepDataReg[23:16] : CacheBus[0][23:16],
				(~RamBEReg[1] & ReadBypass) ? RamDataReg[15:8] : (~DeepBEReg[1] & DeepReadBypass) ? DeepDataReg[15:8] : CacheBus[0][15:8],
				(~RamBEReg[0] & ReadBypass) ? RamDataReg[7:0] : (~DeepBEReg[0] & DeepReadBypass) ? DeepDataReg[7:0] : CacheBus[0][7:0]};
	DMemReg[1]<={(~RamBEReg[7] & ReadBypass) ? RamDataReg[63:56] : (~DeepBEReg[7] & DeepReadBypass) ? DeepDataReg[63:56] : CacheBus[1][63:56],
				(~RamBEReg[6] & ReadBypass) ? RamDataReg[55:48] : (~DeepBEReg[6] & DeepReadBypass) ? DeepDataReg[55:48] : CacheBus[1][55:48],
				(~RamBEReg[5] & ReadBypass) ? RamDataReg[47:40] : (~DeepBEReg[5] & DeepReadBypass) ? DeepDataReg[47:40] : CacheBus[1][47:40],
				(~RamBEReg[4] & ReadBypass) ? RamDataReg[39:32] : (~DeepBEReg[4] & DeepReadBypass) ? DeepDataReg[39:32] : CacheBus[1][39:32],
				(~RamBEReg[3] & ReadBypass) ? RamDataReg[31:24] : (~DeepBEReg[3] & DeepReadBypass) ? DeepDataReg[31:24] : CacheBus[1][31:24],
				(~RamBEReg[2] & ReadBypass) ? RamDataReg[23:16] : (~DeepBEReg[2] & DeepReadBypass) ? DeepDataReg[23:16] : CacheBus[1][23:16],
				(~RamBEReg[1] & ReadBypass) ? RamDataReg[15:8] : (~DeepBEReg[1] & DeepReadBypass) ? DeepDataReg[15:8] : CacheBus[1][15:8],
				(~RamBEReg[0] & ReadBypass) ? RamDataReg[7:0] : (~DeepBEReg[0] & DeepReadBypass) ? DeepDataReg[7:0] : CacheBus[1][7:0]};
	DMemReg[2]<={(~RamBEReg[7] & ReadBypass) ? RamDataReg[63:56] : (~DeepBEReg[7] & DeepReadBypass) ? DeepDataReg[63:56] : CacheBus[2][63:56],
				(~RamBEReg[6] & ReadBypass) ? RamDataReg[55:48] : (~DeepBEReg[6] & DeepReadBypass) ? DeepDataReg[55:48] : CacheBus[2][55:48],
				(~RamBEReg[5] & ReadBypass) ? RamDataReg[47:40] : (~DeepBEReg[5] & DeepReadBypass) ? DeepDataReg[47:40] : CacheBus[2][47:40],
				(~RamBEReg[4] & ReadBypass) ? RamDataReg[39:32] : (~DeepBEReg[4] & DeepReadBypass) ? DeepDataReg[39:32] : CacheBus[2][39:32],
				(~RamBEReg[3] & ReadBypass) ? RamDataReg[31:24] : (~DeepBEReg[3] & DeepReadBypass) ? DeepDataReg[31:24] : CacheBus[2][31:24],
				(~RamBEReg[2] & ReadBypass) ? RamDataReg[23:16] : (~DeepBEReg[2] & DeepReadBypass) ? DeepDataReg[23:16] : CacheBus[2][23:16],
				(~RamBEReg[1] & ReadBypass) ? RamDataReg[15:8] : (~DeepBEReg[1] & DeepReadBypass) ? DeepDataReg[15:8] : CacheBus[2][15:8],
				(~RamBEReg[0] & ReadBypass) ? RamDataReg[7:0] : (~DeepBEReg[0] & DeepReadBypass) ? DeepDataReg[7:0] : CacheBus[2][7:0]};
	DMemReg[3]<={(~RamBEReg[7] & ReadBypass) ? RamDataReg[63:56] : (~DeepBEReg[7] & DeepReadBypass) ? DeepDataReg[63:56] : CacheBus[3][63:56],
				(~RamBEReg[6] & ReadBypass) ? RamDataReg[55:48] : (~DeepBEReg[6] & DeepReadBypass) ? DeepDataReg[55:48] : CacheBus[3][55:48],
				(~RamBEReg[5] & ReadBypass) ? RamDataReg[47:40] : (~DeepBEReg[5] & DeepReadBypass) ? DeepDataReg[47:40] : CacheBus[3][47:40],
				(~RamBEReg[4] & ReadBypass) ? RamDataReg[39:32] : (~DeepBEReg[4] & DeepReadBypass) ? DeepDataReg[39:32] : CacheBus[3][39:32],
				(~RamBEReg[3] & ReadBypass) ? RamDataReg[31:24] : (~DeepBEReg[3] & DeepReadBypass) ? DeepDataReg[31:24] : CacheBus[3][31:24],
				(~RamBEReg[2] & ReadBypass) ? RamDataReg[23:16] : (~DeepBEReg[2] & DeepReadBypass) ? DeepDataReg[23:16] : CacheBus[3][23:16],
				(~RamBEReg[1] & ReadBypass) ? RamDataReg[15:8] : (~DeepBEReg[1] & DeepReadBypass) ? DeepDataReg[15:8] : CacheBus[3][15:8],
				(~RamBEReg[0] & ReadBypass) ? RamDataReg[7:0] : (~DeepBEReg[0] & DeepReadBypass) ? DeepDataReg[7:0] : CacheBus[3][7:0]};
	DMemBusReg[0]<=DMemBus[0];
	DMemBusReg[1]<=DMemBus[1];
	DMemBusReg[2]<=DMemBus[2];
	DMemBusReg[3]<=DMemBus[3];
	BypassFlag<=ReadBypass | DeepReadBypass;
	end
				
// buffer registers match flags
BRegMatch[0]<=EnaReg & BRegValid[0] & (BRegAddr[0]==wIADDR[41:3]) & wIACT & wICMD & (~InACTReg | ~InCMDReg) & (~RamACTReg | ~RamCMDReg);
BRegMatch[1]<=EnaReg & BRegValid[1] & (BRegAddr[1]==wIADDR[41:3]) & wIACT & wICMD & (~InACTReg | ~InCMDReg) & (~RamACTReg | ~RamCMDReg);
BRegMatch[2]<=EnaReg & BRegValid[2] & (BRegAddr[2]==wIADDR[41:3]) & wIACT & wICMD & (~InACTReg | ~InCMDReg) & (~RamACTReg | ~RamCMDReg);
BRegMatch[3]<=EnaReg & BRegValid[3] & (BRegAddr[3]==wIADDR[41:3]) & wIACT & wICMD & (~InACTReg | ~InCMDReg) & (~RamACTReg | ~RamCMDReg);

// Write buffer initialisation flags
if (EnaReg | (|WBResetFlag)) WBInitReg<=(WBInitReg | WBInWriteBus) & ~WBResetFlag;

// reset valid flag for write buffer when cache line filled from memory and address of write buffer equal to address of cached line
WBResetFlag<=((Machine==RSTS) & (WAddr==RamAddrReg[41:3]) & WBInitReg);

// Write buffer address registers
if (EnaReg & WBInWriteBus) WAddr<=InAddrReg[41:3];
DWAddr<=WAddr;
	
// write data into local write buffers
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[0]) WBuff[7:0]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[1]) WBuff[15:8]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[2]) WBuff[23:16]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[3]) WBuff[31:24]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[4]) WBuff[39:32]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[5]) WBuff[47:40]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[6]) WBuff[55:48]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[7]) WBuff[63:56]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[0]) WBuff[71:64]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[1]) WBuff[79:72]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[2]) WBuff[87:80]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[3]) WBuff[95:88]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[4]) WBuff[103:96]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[5]) WBuff[111:104]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[6]) WBuff[119:112]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[7]) WBuff[127:120]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[0]) WBuff[135:128]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[1]) WBuff[143:136]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[2]) WBuff[151:144]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[3]) WBuff[159:152]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[4]) WBuff[167:160]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[5]) WBuff[175:168]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[6]) WBuff[183:176]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[7]) WBuff[191:184]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[0]) WBuff[199:192]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[1]) WBuff[207:200]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[2]) WBuff[215:208]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[3]) WBuff[223:216]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[4]) WBuff[231:224]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[5]) WBuff[239:232]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[6]) WBuff[247:240]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[7]) WBuff[255:248]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[0]) WBuff[7+32*8:32*8]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[1]) WBuff[7+33*8:33*8]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[2]) WBuff[7+34*8:34*8]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[3]) WBuff[7+35*8:35*8]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[4]) WBuff[7+36*8:36*8]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[5]) WBuff[7+37*8:37*8]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[6]) WBuff[7+38*8:38*8]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[7]) WBuff[7+39*8:39*8]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[0]) WBuff[7+40*8:40*8]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[1]) WBuff[7+41*8:41*8]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[2]) WBuff[7+42*8:42*8]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[3]) WBuff[7+43*8:43*8]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[4]) WBuff[7+44*8:44*8]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[5]) WBuff[7+45*8:45*8]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[6]) WBuff[7+46*8:46*8]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[7]) WBuff[7+47*8:47*8]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[0]) WBuff[7+48*8:48*8]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[1]) WBuff[7+49*8:49*8]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[2]) WBuff[7+50*8:50*8]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[3]) WBuff[7+51*8:51*8]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[4]) WBuff[7+52*8:52*8]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[5]) WBuff[7+53*8:53*8]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[6]) WBuff[7+54*8:54*8]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[7]) WBuff[7+55*8:55*8]<=RamDataReg[63:56];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[0]) WBuff[7+56*8:56*8]<=RamDataReg[7:0];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[1]) WBuff[7+57*8:57*8]<=RamDataReg[15:8];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[2]) WBuff[7+58*8:58*8]<=RamDataReg[23:16];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[3]) WBuff[7+59*8:59*8]<=RamDataReg[31:24];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[4]) WBuff[7+60*8:60*8]<=RamDataReg[39:32];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[5]) WBuff[7+61*8:61*8]<=RamDataReg[47:40];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[6]) WBuff[7+62*8:62*8]<=RamDataReg[55:48];
if ((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[7]) WBuff[7+63*8:63*8]<=RamDataReg[63:56];
WFlags[0]<=((WFlags[0] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[1]<=((WFlags[1] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[2]<=((WFlags[2] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[3]<=((WFlags[3] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[4]<=((WFlags[4] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[5]<=((WFlags[5] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[6]<=((WFlags[6] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[7]<=((WFlags[7] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd0) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[8]<=((WFlags[8] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[9]<=((WFlags[9] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[10]<=((WFlags[10] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[11]<=((WFlags[11] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[12]<=((WFlags[12] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[13]<=((WFlags[13] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[14]<=((WFlags[14] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[15]<=((WFlags[15] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd1) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[16]<=((WFlags[16] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[17]<=((WFlags[17] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[18]<=((WFlags[18] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[19]<=((WFlags[19] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[20]<=((WFlags[20] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[21]<=((WFlags[21] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[22]<=((WFlags[22] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[23]<=((WFlags[23] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd2) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[24]<=((WFlags[24] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[25]<=((WFlags[25] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[26]<=((WFlags[26] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[27]<=((WFlags[27] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[28]<=((WFlags[28] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[29]<=((WFlags[29] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[30]<=((WFlags[30] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[31]<=((WFlags[31] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd3) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[32]<=((WFlags[32] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[33]<=((WFlags[33] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[34]<=((WFlags[34] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[35]<=((WFlags[35] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[36]<=((WFlags[36] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[37]<=((WFlags[37] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[38]<=((WFlags[38] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[39]<=((WFlags[39] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd4) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[40]<=((WFlags[40] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[41]<=((WFlags[41] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[42]<=((WFlags[42] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[43]<=((WFlags[43] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[44]<=((WFlags[44] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[45]<=((WFlags[45] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[46]<=((WFlags[46] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[47]<=((WFlags[47] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd5) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[48]<=((WFlags[48] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[49]<=((WFlags[49] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[50]<=((WFlags[50] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[51]<=((WFlags[51] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[52]<=((WFlags[52] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[53]<=((WFlags[53] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[54]<=((WFlags[54] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[55]<=((WFlags[55] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd6) & ~RamBEReg[7])) & ~WBResetFlag;
WFlags[56]<=((WFlags[56] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[0])) & ~WBResetFlag;
WFlags[57]<=((WFlags[57] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[1])) & ~WBResetFlag;
WFlags[58]<=((WFlags[58] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[2])) & ~WBResetFlag;
WFlags[59]<=((WFlags[59] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[3])) & ~WBResetFlag;
WFlags[60]<=((WFlags[60] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[4])) & ~WBResetFlag;
WFlags[61]<=((WFlags[61] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[5])) & ~WBResetFlag;
WFlags[62]<=((WFlags[62] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[6])) & ~WBResetFlag;
WFlags[63]<=((WFlags[63] & ~WriteRequest)|((EnaReg & WBInWriteFlag) & (RamAddrReg[2:0]==3'd7) & ~RamBEReg[7])) & ~WBResetFlag;
	
// data muxing from the BReg's
case (wIADDR[2:0])
	3'd0: 	begin
			DBReg[0]<=BReg[0][63:0];
			DBReg[1]<=BReg[1][63:0];
			DBReg[2]<=BReg[2][63:0];
			DBReg[3]<=BReg[3][63:0];
			end
	3'd1: 	begin
			DBReg[0]<=BReg[0][127:64];
			DBReg[1]<=BReg[1][127:64];
			DBReg[2]<=BReg[2][127:64];
			DBReg[3]<=BReg[3][127:64];
			end
	3'd2: 	begin
			DBReg[0]<=BReg[0][191:128];
			DBReg[1]<=BReg[1][191:128];
			DBReg[2]<=BReg[2][191:128];
			DBReg[3]<=BReg[3][191:128];
			end
	3'd3: 	begin
			DBReg[0]<=BReg[0][255:192];
			DBReg[1]<=BReg[1][255:192];
			DBReg[2]<=BReg[2][255:192];
			DBReg[3]<=BReg[3][255:192];
			end
	3'd4: 	begin
			DBReg[0]<=BReg[0][319:256];
			DBReg[1]<=BReg[1][319:256];
			DBReg[2]<=BReg[2][319:256];
			DBReg[3]<=BReg[3][319:256];
			end
	3'd5: 	begin
			DBReg[0]<=BReg[0][383:320];
			DBReg[1]<=BReg[1][383:320];
			DBReg[2]<=BReg[2][383:320];
			DBReg[3]<=BReg[3][383:320];
			end
	3'd6: 	begin
			DBReg[0]<=BReg[0][447:384];
			DBReg[1]<=BReg[1][447:384];
			DBReg[2]<=BReg[2][447:384];
			DBReg[3]<=BReg[3][447:384];
			end
	3'd7: 	begin
			DBReg[0]<=BReg[0][511:448];
			DBReg[1]<=BReg[1][511:448];
			DBReg[2]<=BReg[2][511:448];
			DBReg[3]<=BReg[3][511:448];
			end
	endcase

// data output
IDATo<=	(DBReg[0] & {64{BRegMatch[0]}})|(DBReg[1] & {64{BRegMatch[1]}})|(DBReg[2] & {64{BRegMatch[2]}})|(DBReg[3] & {64{BRegMatch[3]}})|
		(DMemReg[0] & {64{MatchFlag[0] & RamACTReg & RamCMDReg}})|(DMemReg[1] & {64{MatchFlag[1] & RamACTReg & RamCMDReg}})|
		(DMemReg[2] & {64{MatchFlag[2] & RamACTReg & RamCMDReg}})|(DMemReg[3] & {64{MatchFlag[3] & RamACTReg & RamCMDReg}})|
		(RetReg & {64{RetFlag}});

// data tag
ITAGo<=(RamACTReg & RamCMDReg) ? RamTagReg : InTagReg;

// data ready signal
IDRDY<=((|MatchFlag) & RamACTReg & RamCMDReg) | RetFlag | |BRegMatch;

// register for retrieving data when cache line filled from memory
if (avl_rdata_valid & (ETAGi==RamAddrReg[4:3]))
	case (RamAddrReg[2:0])
		3'd0: RetReg<=ExtDataBus[63:0];
		3'd1: RetReg<=ExtDataBus[127:64];
		3'd2: RetReg<=ExtDataBus[191:128];
		3'd3: RetReg<=ExtDataBus[255:192];
		3'd4: RetReg<=ExtDataBus[319:256];
		3'd5: RetReg<=ExtDataBus[383:320];
		3'd6: RetReg<=ExtDataBus[447:384];
		3'd7: RetReg<=ExtDataBus[511:448];
		endcase
RetFlag<=avl_rdata_valid & (ETAGi==RamAddrReg[4:3]);

// loading data to the buffer registers
for (i1=0; i1<4; i1=i1+1)
	begin
	if (avl_rdata_valid & (ETAGi==RamAddrReg[4:3]) & CLRUSel[i1]) BReg[i1]<=ExtDataBus;
		else if (RamACTReg & RamCMDReg & MatchFlag[i1]) BReg[i1]<=DMemBusReg[i1];
			else if (BRegValid[i1] & (BRegAddr[i1]==wIADDR[41:3]) & wIACT & ~wICMD & ~(InACTReg & InCMDReg) & ~(RamACTReg & RamCMDReg))
				case (wIADDR[2:0])
					3'd0: 	begin
							if (~wIBE[0]) BReg[i1][7:0]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][15:8]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][23:16]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][31:24]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][39:32]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][47:40]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][55:48]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][63:56]<=wIDATi[63:56];
							end
					3'd1: 	begin
							if (~wIBE[0]) BReg[i1][71:64]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][79:72]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][87:80]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][95:88]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][103:96]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][111:104]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][119:112]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][127:120]<=wIDATi[63:56];
							end
					3'd2: 	begin
							if (~wIBE[0]) BReg[i1][135:128]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][143:136]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][151:144]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][159:152]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][167:160]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][175:168]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][183:176]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][191:184]<=wIDATi[63:56];
							end
					3'd3: 	begin
							if (~wIBE[0]) BReg[i1][199:192]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][207:200]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][215:208]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][223:216]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][231:224]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][239:232]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][247:240]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][255:248]<=wIDATi[63:56];
							end
					3'd4: 	begin
							if (~wIBE[0]) BReg[i1][263:256]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][271:264]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][279:272]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][287:280]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][295:288]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][303:296]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][311:304]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][319:312]<=wIDATi[63:56];
							end
					3'd5: 	begin
							if (~wIBE[0]) BReg[i1][327:320]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][335:328]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][343:336]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][351:344]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][359:352]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][367:360]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][375:368]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][383:376]<=wIDATi[63:56];
							end
					3'd6: 	begin
							if (~wIBE[0]) BReg[i1][391:384]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][399:392]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][407:400]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][415:408]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][423:416]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][431:424]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][439:432]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][447:440]<=wIDATi[63:56];
							end
					3'd7: 	begin
							if (~wIBE[0]) BReg[i1][455:448]<=wIDATi[7:0];
							if (~wIBE[1]) BReg[i1][463:456]<=wIDATi[15:8];
							if (~wIBE[2]) BReg[i1][471:464]<=wIDATi[23:16];
							if (~wIBE[3]) BReg[i1][479:472]<=wIDATi[31:24];
							if (~wIBE[4]) BReg[i1][487:480]<=wIDATi[39:32];
							if (~wIBE[5]) BReg[i1][495:488]<=wIDATi[47:40];
							if (~wIBE[6]) BReg[i1][503:496]<=wIDATi[55:48];
							if (~wIBE[7]) BReg[i1][511:504]<=wIDATi[63:56];
							end
					endcase
	if ((avl_rdata_valid & CLRUSel[i1])|(RamACTReg & RamCMDReg & MatchFlag[i1])) BRegAddr[i1]<=RamAddrReg[41:3];
	BRegValid[i1]<=(RamACTReg & RamCMDReg & MatchFlag[i1]) ? ~BypassFlag : BRegValid[i1] | (avl_rdata_valid & CLRUSel[i1]);
	end


// counter for clearing control ram at the start
CntReg<=(CntReg+8'd1) & {8{(Machine==CLS)}};
ClearFlag<=(ClearFlag | (Machine==RS)) & ~((Machine==CLS) & &CntReg);

// burst counter
if (~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req))) BurstCntr<=(BurstCntr+2'd1) & {2{(Machine==CWS1)|(Machine==CWS2)}};

// control machine
case (Machine)
	RS:	Machine<=CLS;
	CLS: if (&CntReg) Machine<=WS;
			else Machine<=CLS;
	WS:	if (~WFifoEmpty | avl_write_req) Machine<=WS;
			else if (ReadRequest & NeedWriteCache) Machine<=CWS1;
				else if (ReadRequest & ~NeedWriteCache) Machine<=CRS1;
					else Machine<=WS;
	// write modified cache line
	CWS1: if (&BurstCntr & (~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req)))) Machine<=CWS2;
				else Machine<=CWS1;
	CWS2: if (~avl_write_req) Machine<=CRS1;
			else Machine<=CWS2;
	// load new cache line
	CRS1: Machine<=CRS2;
	CRS2: if (avl_ready) Machine<=RWS;
			else Machine<=CRS2;
	// waiting until all data readed from SDRAM
	RWS: if (avl_rdata_valid & &ETAGi) Machine<=RSTS;
			else Machine<=RWS;
	// restart transaction pipeline
	RSTS: Machine<=UNS;
	// deblocking pipeline
	UNS: Machine<=WS;
	endcase

// validation cache lines
CacheValidFlag[0]<=(Machine==RSTS) & CLRUSel[0];
CacheValidFlag[1]<=(Machine==RSTS) & CLRUSel[1];
CacheValidFlag[2]<=(Machine==RSTS) & CLRUSel[2];
CacheValidFlag[3]<=(Machine==RSTS) & CLRUSel[3];

// readed data counter
if (Machine==CRS1) ETAGi<=2'd0;
	else if (avl_rdata_valid) ETAGi<=ETAGi+2'd1;
	
BurstWriteFlag<=(BurstWriteFlag & ~(avl_ready | (~avl_read_req & ~avl_write_req))) | (Machine==CWS1);
if (~BurstWriteFlag | (avl_ready | (~avl_read_req & ~avl_write_req))) BurstStartFlag<=(Machine==CWS1) & ~|BurstCntr;

// interface to the SDRAM
avl_read_req<=(Machine==CRS1)|((Machine==CRS2) & ~avl_ready);
avl_write_req<=(avl_write_req & ~avl_ready) | BurstWriteFlag |(~WFifoEmpty & (Machine==WS));
if (avl_ready | (~avl_read_req & ~avl_write_req))
	begin
	// address
	avl_addr<=(Machine==WS) ? WFifoBus[614:576] : BurstWriteFlag ? {(CMemReg[28:0] & {29{CLRUSel[0]}})|(CMemReg[62:34] & {29{CLRUSel[1]}})|(CMemReg[96:68] & {29{CLRUSel[2]}})|(CMemReg[130:102] & {29{CLRUSel[3]}}),RamAddrReg[12:5],2'd0}:{RamAddrReg[41:5],2'd0};
	// BE signals
	avl_be<=(Machine==WS) ? WFifoBus[575:512] : 64'hFFFFFFFFFFFFFFFF;
	// data
	avl_wdata<=(Machine==WS) ? WFifoBus[511:0] : ({512{CLRUSel[0]}} & DMemBus[0])|({512{CLRUSel[1]}} & DMemBus[1])|({512{CLRUSel[2]}} & DMemBus[2])|({512{CLRUSel[3]}} & DMemBus[3]);
	avl_size<={(Machine==CRS1)|(Machine==CRS2)|(Machine==CWS1),1'd0,~((Machine==CRS1)|(Machine==CRS2)|(Machine==CWS1))};
	end
// burst begin signal
avl_burstbegin<=(Machine==CRS1)|(BurstStartFlag);
// burst size

end

endmodule
