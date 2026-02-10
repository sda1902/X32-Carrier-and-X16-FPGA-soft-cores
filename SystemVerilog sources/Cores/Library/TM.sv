module TM (
			input wire CLK, RST,
			// interface to CPU
			input wire [31:0] CTRL,
			input wire [7:0] RESTART,
			output reg [29:0] STATS,
			// monitored inputs
			input wire [7:0] MNEXT, MACT, MCMD
			);
			
/*
CTRL[1:0], CTRL[3:2], CTRL[5:4], CTRL[7:6], CTRL[9:8], CTRL[11:10], CTRL[13:12], CTRL[15:14]
selection statistic mode:
00	- total channel loading
01	- read transactions loading
10	- write transactions loading
11	- channel's throughput

CTRL[29:16] time interval setup

CTRL[31:30] output MUX control
*/

reg [13:0] ptr [0:7];
reg [7:0] ClrFlag;
reg [13:0] StatCntr [0:7];
logic [7:0] NewData, OldData, CanWrite;
reg [7:0] OldReg, NewReg, NewR;
reg [1:0] CanWR [0:7];

integer i0, i1;

altsyncram	sram0 (.address_a(ptr[0]), .address_b(ptr[0]), .clock0(CLK), .data_a(NewData[0] & ClrFlag[0]), .wren_a(~ClrFlag[0] | CanWrite[0]), .q_b (OldData[0]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram0.address_aclr_b = "NONE",
		sram0.address_reg_b = "CLOCK0",
		sram0.clock_enable_input_a = "BYPASS",
		sram0.clock_enable_input_b = "BYPASS",
		sram0.clock_enable_output_b = "BYPASS",
		sram0.lpm_type = "altsyncram",
		sram0.numwords_a = 16384,
		sram0.numwords_b = 16384,
		sram0.operation_mode = "DUAL_PORT",
		sram0.outdata_aclr_b = "NONE",
		sram0.outdata_reg_b = "UNREGISTERED",
		sram0.power_up_uninitialized = "FALSE",
		sram0.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram0.widthad_a = 14,
		sram0.widthad_b = 14,
		sram0.width_a = 1,
		sram0.width_b = 1,
		sram0.width_byteena_a = 1;

altsyncram	sram1 (.address_a(ptr[1]), .address_b(ptr[1]), .clock0(CLK), .data_a(NewData[1] & ClrFlag[1]), .wren_a(~ClrFlag[1] | CanWrite[1]), .q_b (OldData[1]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram1.address_aclr_b = "NONE",
		sram1.address_reg_b = "CLOCK0",
		sram1.clock_enable_input_a = "BYPASS",
		sram1.clock_enable_input_b = "BYPASS",
		sram1.clock_enable_output_b = "BYPASS",
		sram1.lpm_type = "altsyncram",
		sram1.numwords_a = 16384,
		sram1.numwords_b = 16384,
		sram1.operation_mode = "DUAL_PORT",
		sram1.outdata_aclr_b = "NONE",
		sram1.outdata_reg_b = "UNREGISTERED",
		sram1.power_up_uninitialized = "FALSE",
		sram1.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram1.widthad_a = 14,
		sram1.widthad_b = 14,
		sram1.width_a = 1,
		sram1.width_b = 1,
		sram1.width_byteena_a = 1;

altsyncram	sram2 (.address_a(ptr[2]), .address_b(ptr[2]), .clock0(CLK), .data_a(NewData[2] & ClrFlag[2]), .wren_a(~ClrFlag[2] | CanWrite[2]), .q_b (OldData[2]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram2.address_aclr_b = "NONE",
		sram2.address_reg_b = "CLOCK0",
		sram2.clock_enable_input_a = "BYPASS",
		sram2.clock_enable_input_b = "BYPASS",
		sram2.clock_enable_output_b = "BYPASS",
		sram2.lpm_type = "altsyncram",
		sram2.numwords_a = 16384,
		sram2.numwords_b = 16384,
		sram2.operation_mode = "DUAL_PORT",
		sram2.outdata_aclr_b = "NONE",
		sram2.outdata_reg_b = "UNREGISTERED",
		sram2.power_up_uninitialized = "FALSE",
		sram2.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram2.widthad_a = 14,
		sram2.widthad_b = 14,
		sram2.width_a = 1,
		sram2.width_b = 1,
		sram2.width_byteena_a = 1;

altsyncram	sram3 (.address_a(ptr[3]), .address_b(ptr[3]), .clock0(CLK), .data_a(NewData[3] & ClrFlag[3]), .wren_a(~ClrFlag[3] | CanWrite[3]), .q_b (OldData[3]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram3.address_aclr_b = "NONE",
		sram3.address_reg_b = "CLOCK0",
		sram3.clock_enable_input_a = "BYPASS",
		sram3.clock_enable_input_b = "BYPASS",
		sram3.clock_enable_output_b = "BYPASS",
		sram3.lpm_type = "altsyncram",
		sram3.numwords_a = 16384,
		sram3.numwords_b = 16384,
		sram3.operation_mode = "DUAL_PORT",
		sram3.outdata_aclr_b = "NONE",
		sram3.outdata_reg_b = "UNREGISTERED",
		sram3.power_up_uninitialized = "FALSE",
		sram3.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram3.widthad_a = 14,
		sram3.widthad_b = 14,
		sram3.width_a = 1,
		sram3.width_b = 1,
		sram3.width_byteena_a = 1;

altsyncram	sram4 (.address_a(ptr[4]), .address_b(ptr[4]), .clock0(CLK), .data_a(NewData[4] & ClrFlag[4]), .wren_a(~ClrFlag[4] | CanWrite[4]), .q_b (OldData[4]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram4.address_aclr_b = "NONE",
		sram4.address_reg_b = "CLOCK0",
		sram4.clock_enable_input_a = "BYPASS",
		sram4.clock_enable_input_b = "BYPASS",
		sram4.clock_enable_output_b = "BYPASS",
		sram4.lpm_type = "altsyncram",
		sram4.numwords_a = 16384,
		sram4.numwords_b = 16384,
		sram4.operation_mode = "DUAL_PORT",
		sram4.outdata_aclr_b = "NONE",
		sram4.outdata_reg_b = "UNREGISTERED",
		sram4.power_up_uninitialized = "FALSE",
		sram4.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram4.widthad_a = 14,
		sram4.widthad_b = 14,
		sram4.width_a = 1,
		sram4.width_b = 1,
		sram4.width_byteena_a = 1;

altsyncram	sram5 (.address_a(ptr[5]), .address_b(ptr[5]), .clock0(CLK), .data_a(NewData[5] & ClrFlag[5]), .wren_a(~ClrFlag[5] | CanWrite[5]), .q_b (OldData[5]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram5.address_aclr_b = "NONE",
		sram5.address_reg_b = "CLOCK0",
		sram5.clock_enable_input_a = "BYPASS",
		sram5.clock_enable_input_b = "BYPASS",
		sram5.clock_enable_output_b = "BYPASS",
		sram5.lpm_type = "altsyncram",
		sram5.numwords_a = 16384,
		sram5.numwords_b = 16384,
		sram5.operation_mode = "DUAL_PORT",
		sram5.outdata_aclr_b = "NONE",
		sram5.outdata_reg_b = "UNREGISTERED",
		sram5.power_up_uninitialized = "FALSE",
		sram5.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram5.widthad_a = 14,
		sram5.widthad_b = 14,
		sram5.width_a = 1,
		sram5.width_b = 1,
		sram5.width_byteena_a = 1;

altsyncram	sram6 (.address_a(ptr[6]), .address_b(ptr[6]), .clock0(CLK), .data_a(NewData[6] & ClrFlag[6]), .wren_a(~ClrFlag[6] | CanWrite[6]), .q_b (OldData[6]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram6.address_aclr_b = "NONE",
		sram6.address_reg_b = "CLOCK0",
		sram6.clock_enable_input_a = "BYPASS",
		sram6.clock_enable_input_b = "BYPASS",
		sram6.clock_enable_output_b = "BYPASS",
		sram6.lpm_type = "altsyncram",
		sram6.numwords_a = 16384,
		sram6.numwords_b = 16384,
		sram6.operation_mode = "DUAL_PORT",
		sram6.outdata_aclr_b = "NONE",
		sram6.outdata_reg_b = "UNREGISTERED",
		sram6.power_up_uninitialized = "FALSE",
		sram6.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram6.widthad_a = 14,
		sram6.widthad_b = 14,
		sram6.width_a = 1,
		sram6.width_b = 1,
		sram6.width_byteena_a = 1;

altsyncram	sram7 (.address_a(ptr[7]), .address_b(ptr[7]), .clock0(CLK), .data_a(NewData[7] & ClrFlag[7]), .wren_a(~ClrFlag[7] | CanWrite[7]), .q_b (OldData[7]), 
				.aclr0 (1'b0), .aclr1 (1'b0), .addressstall_a (1'b0), .addressstall_b(1'b0), .byteena_a(1'b1), .byteena_b (1'b1), .clock1 (1'b1), .clocken0 (1'b1),
				.clocken1 (1'b1), .clocken2 (1'b1), .clocken3 (1'b1), .data_b (1'b1), .eccstatus (), .q_a (), .rden_a (1'b1), .rden_b (1'b1), .wren_b (1'b0));
	defparam
		sram7.address_aclr_b = "NONE",
		sram7.address_reg_b = "CLOCK0",
		sram7.clock_enable_input_a = "BYPASS",
		sram7.clock_enable_input_b = "BYPASS",
		sram7.clock_enable_output_b = "BYPASS",
		sram7.lpm_type = "altsyncram",
		sram7.numwords_a = 16384,
		sram7.numwords_b = 16384,
		sram7.operation_mode = "DUAL_PORT",
		sram7.outdata_aclr_b = "NONE",
		sram7.outdata_reg_b = "UNREGISTERED",
		sram7.power_up_uninitialized = "FALSE",
		sram7.read_during_write_mode_mixed_ports = "OLD_DATA",
		sram7.widthad_a = 14,
		sram7.widthad_b = 14,
		sram7.width_a = 1,
		sram7.width_b = 1,
		sram7.width_byteena_a = 1;


always_comb
begin

for (i1=0; i1<8; i1=i1+1)
	case ({CTRL[1+i1*2],CTRL[i1*2]})
		2'd0:	begin
				NewData[i1]=MNEXT[i1] & MACT[i1];
				CanWrite[i1]=1'b1;
				end
		2'd1:	begin
				NewData[i1]=MNEXT[i1] & MACT[i1] & MCMD[i1];
				CanWrite[i1]=1'b1;
				end
		2'd2:	begin
				NewData[i1]=MNEXT[i1] & MACT[i1] & ~MCMD[i1];
				CanWrite[i1]=1'b1;
				end
		2'd3:	begin
				NewData[i1]=MNEXT[i1] & MACT[i1];
				CanWrite[i1]=MACT[i1];
				end
		endcase

end

always_ff @(posedge CLK or negedge RST)
if (~RST)
	begin
	ptr[0]<=0;
	ptr[1]<=0;
	ptr[2]<=0;
	ptr[3]<=0;
	ptr[4]<=0;
	ptr[5]<=0;
	ptr[6]<=0;
	ptr[7]<=0;
	ClrFlag<=0;
	StatCntr[0]<=0;
	StatCntr[1]<=0;
	StatCntr[2]<=0;
	StatCntr[3]<=0;
	StatCntr[4]<=0;
	StatCntr[5]<=0;
	StatCntr[6]<=0;
	StatCntr[7]<=0;
	OldReg[i0]<=0;
	NewReg[i0]<=0;
	end
else begin

for (i0=0; i0<8; i0=i0+1)
	begin
	// clear flag
	ClrFlag[i0]<=(ClrFlag[i0] & ~RESTART[i0]) | &ptr[i0];
	// pointer
	if (~ClrFlag[i0] | CanWrite[i0]) ptr[i0]<=(ptr[i0]+1'b1)&{14{((ptr[i0]!=CTRL[29:16])| ~ClrFlag[i0]) & ~RESTART[i0]}};
	// counting registers
	OldReg[i0]<=OldData[i0];
	NewR[i0]<=NewData[i0];
	NewReg[i0]<=NewR[i0];
	CanWR[i0]<={CanWR[i0][0],CanWrite[i0]};
	// statistic counters
	if (CanWR[i0][1]) StatCntr[i0]<=(StatCntr[i0]-OldReg[i0]+NewReg[i0])&{14{ClrFlag[i0]}};
	end
	
case(CTRL[31:30])
	2'd0:	STATS<={ClrFlag[1],StatCntr[1],ClrFlag[0],StatCntr[0]};
	2'd1:	STATS<={ClrFlag[3],StatCntr[3],ClrFlag[2],StatCntr[2]};
	2'd2:	STATS<={ClrFlag[5],StatCntr[5],ClrFlag[4],StatCntr[4]};
	2'd3:	STATS<={ClrFlag[7],StatCntr[7],ClrFlag[6],StatCntr[6]};
	endcase

end

endmodule
