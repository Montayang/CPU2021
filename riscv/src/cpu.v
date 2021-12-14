// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/pc.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/decoder.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/rs.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/regfile.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/ls_buffer.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/rob.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/mem_control.v"
`include "/mnt/f/Programming/CPU2021-main/riscv/src/ex.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here
wire PC_if_to_decoder;
wire PC_if_output_pc;
wire [`addrWidth-1:0] PC_pc_to_getInst;
wire [`instWidth-1:0] PC_inst_decoder;
wire [`addrWidth-1:0] PC_pc_decoder;
wire PC_if_ls;

wire [`dataWidth-1:0] REG_data_rs1;
wire [`tagWidth-1:0] REG_tag_rs1;
wire [`dataWidth-1:0] REG_data_rs2;
wire [`tagWidth-1:0] REG_tag_rs2;

wire DECODER_if_station_idle;
wire [`regWidth-1:0] DECODER_pos_rs1_to_reg;
wire [`regWidth-1:0] DECODER_pos_rs2_to_reg;
wire [`tagWidth-1:0] DECODER_tag_rd_to_reg;
wire [`regWidth-1:0] DECODER_rd_to_rename;
wire [`regWidth-1:0] DECODER_tag_rs1_to_rob;
wire [`regWidth-1:0] DECODER_tag_rs2_to_rob;
wire [`opTypeWidth-1:0] DECODER_op_to_rob;
wire [`regWidth-1:0] DECODER_rd_to_rob;
wire DECODER_if_issue_rs;
wire [`tagWidth-1:0] DECODER_dest_rs;
wire [`opTypeWidth-1:0] DECODER_op_type_to_rs;
wire [`tagWidth-1:0] DECODER_tag_rs1_to_rs;
wire [`dataWidth-1:0] DECODER_data_rs1_to_rs;
wire [`tagWidth-1:0] DECODER_tag_rs2_to_rs;
wire [`dataWidth-1:0] DECODER_data_rs2_to_rs;
wire [`immWidth-1:0] DECODER_imm_to_rs;
wire [`addrWidth-1:0] DECODER_pc_to_rs;
wire DECODER_if_issue_lsb;
wire [`tagWidth-1:0] DECODER_dest_lsb;
wire [`opTypeWidth-1:0] DECODER_op_type_to_lsb;
wire [`tagWidth-1:0] DECODER_tag_rs1_to_lsb;
wire [`dataWidth-1:0] DECODER_data_rs1_to_lsb;
wire [`tagWidth-1:0] DECODER_tag_rs2_to_lsb;
wire [`dataWidth-1:0] DECODER_data_rs2_to_lsb;
wire [`immWidth-1:0] DECODER_imm_to_lsb;

wire RS_if_idle;
wire [`opTypeWidth-1:0] RS_op_type_to_ex;
wire [`dataWidth-1:0] RS_data_rs1_to_ex;
wire [`dataWidth-1:0] RS_data_rs2_to_ex;
wire [`immWidth-1:0] RS_imm_to_ex;
wire [`addrWidth-1:0] RS_pc_to_ex;
wire [`tagWidth-1:0] RS_tag_in_rob;

wire LSB_if_idle;
wire [`addrWidth-1:0] LSB_wb_addr;
wire [`dataWidth-1:0] LSB_wb_data;
wire [`tagWidth-1:0] LSB_wb_pos_in_rob;
wire LSB_out_ioin;
wire [`addrWidth-1:0] LSB_cur_inst_addr;
wire LSB_if_out_mem;
wire [5:0] LSB_out_mem_size;
wire LSB_out_mem_signed;
wire [`addrWidth-1:0] LSB_out_mem_addr;

wire [`dataWidth-1:0] EX_wb_data;
wire [`addrWidth-1:0] EX_pc_to_jump;
wire [`tagWidth-1:0] EX_wb_pos_in_rob;

wire ROB_if_idle;
wire [`dataWidth-1:0] ROB_data_rs1_to_decoder;
wire [`dataWidth-1:0] ROB_data_rs2_to_decoder;
wire [`tagWidth-1:0] ROB_tag_to_decoder;
wire ROB_if_jump;
wire [`addrWidth-1:0] ROB_pc_to_jump;
wire [`tagWidth-1:0] ROB_tag_renew_to_rs;
wire [`dataWidth-1:0] ROB_data_renew_to_rs;
wire [`tagWidth-1:0] ROB_tag_renew_to_lsb;
wire [`dataWidth-1:0] ROB_data_renew_to_lsb;
wire ROB_if_addr_hzd_to_lsb;
wire ROB_if_commit;
wire [`regWidth-1:0] ROB_pos_commit;
wire [`dataWidth-1:0] ROB_data_commit;
wire [`tagWidth-1:0] ROB_tag_commit;
wire ROB_if_out_mem;
wire [5:0] ROB_out_mem_size;
wire [`addrWidth-1:0] ROB_out_mem_addr;
wire [`dataWidth-1:0] ROB_out_mem_data;
wire ROB_if_out_mem_io;
wire ROB_clear_reg;
wire ROB_clear_rs;
wire ROB_clear_lsb;
wire ROB_clear_mem;
wire ROB_clear_rob;

wire MEM_if_out_inst_to_pc;
wire [`instWidth-1:0] MEM_inst_out_to_pc;
wire MEM_if_out_io_to_rob;
wire [`dataWidth-1:0] MEM_data_io;
wire MEM_if_out_to_lsb;
wire [`addrWidth-1:0] MEM_data_out_to_lsb;

pc pc_unit(
  .if_to_decoder(PC_if_to_decoder),
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_output_pc(PC_if_output_pc),
  .pc_to_getInst(PC_pc_to_getInst),
  .inst_decoder(PC_inst_decoder),
  .pc_decoder(PC_pc_decoder),
  .if_station_idle(DECODER_if_station_idle),
  .if_jump(ROB_if_jump),
  .pc_to_jump(ROB_pc_to_jump),
  .if_gotInst(MEM_if_out_inst_to_pc),
  .inst_mem(MEM_inst_out_to_pc)
);

regfile regfile_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .pos_rs1(DECODER_pos_rs1_to_reg),
  .pos_rs2(DECODER_pos_rs2_to_reg),
  .tag_rename(DECODER_tag_rd_to_reg),
  .reg_to_rename(DECODER_rd_to_rename),
  .data_rs1(REG_data_rs1),
  .tag_rs1(REG_tag_rs1),
  .data_rs2(REG_data_rs2),
  .tag_rs2(REG_tag_rs2),
  .if_commit(ROB_if_commit),
  .pos_commit(ROB_pos_commit),
  .data_commit(ROB_data_commit),
  .tag_commit(ROB_tag_commit),
  .clear(ROB_clear_reg)
);

decoder decoder_unit(
  .if_get_inst(PC_if_to_decoder),
  .inst_from_pc(PC_inst_decoder),
  .pc_inst(PC_pc_decoder),
  .if_station_idle(DECODER_if_station_idle),
  .pos_rs1_to_reg(DECODER_pos_rs1_to_reg),
  .pos_rs2_to_reg(DECODER_pos_rs2_to_reg),
  .tag_rd_to_reg(DECODER_tag_rd_to_reg),
  .rd_to_rename(DECODER_rd_to_rename),
  .tag_rs1_to_rob(DECODER_tag_rs1_to_rob),
  .tag_rs2_to_rob(DECODER_tag_rs2_to_rob),
  .op_to_rob(DECODER_op_to_rob),
  .rd_to_rob(DECODER_rd_to_rob),
  .if_issue_rs(DECODER_if_issue_rs),
  .dest_rs(DECODER_dest_rs),
  .op_type_to_rs(DECODER_op_type_to_rs),
  .tag_rs1_to_rs(DECODER_tag_rs1_to_rs),
  .data_rs1_to_rs(DECODER_data_rs1_to_rs),
  .tag_rs2_to_rs(DECODER_tag_rs2_to_rs),
  .data_rs2_to_rs(DECODER_data_rs2_to_rs),
  .imm_to_rs(DECODER_imm_to_rs),
  .pc_to_rs(DECODER_pc_to_rs),
  .if_issue_lsb(DECODER_if_issue_lsb),
  .dest_lsb(DECODER_dest_lsb),
  .op_type_to_lsb(DECODER_op_type_to_lsb),
  .tag_rs1_to_lsb(DECODER_tag_rs1_to_lsb),
  .data_rs1_to_lsb(DECODER_data_rs1_to_lsb),
  .tag_rs2_to_lsb(DECODER_tag_rs2_to_lsb),
  .data_rs2_to_lsb(DECODER_data_rs2_to_lsb),
  .imm_to_lsb(DECODER_imm_to_lsb),
  .data_rs1_reg(REG_data_rs1),
  .tag_rs1_reg(REG_tag_rs1),
  .data_rs2_reg(REG_data_rs2),
  .tag_rs2_reg(REG_tag_rs2),
  .if_rs_idle(RS_if_idle),
  .if_lsb_idle(LSB_if_idle),
  .if_rob_idle(ROB_if_idle),
  .data_rs1_rob(ROB_data_rs1_to_decoder),
  .data_rs2_rob(ROB_data_rs2_to_decoder),
  .tag_rob(ROB_tag_to_decoder)
);

rs rs_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_issue_rs(DECODER_if_issue_rs),
  .dest_rs(DECODER_dest_rs),
  .op_type_to_rs(DECODER_op_type_to_rs),
  .tag_rs1_to_rs(DECODER_tag_rs1_to_rs),
  .data_rs1_to_rs(DECODER_data_rs1_to_rs),
  .tag_rs2_to_rs(DECODER_tag_rs2_to_rs),
  .data_rs2_to_rs(DECODER_data_rs2_to_rs),
  .imm_to_rs(DECODER_imm_to_rs),
  .pc_to_rs(DECODER_pc_to_rs),
  .if_idle(RS_if_idle),
  .op_type_to_ex(RS_op_type_to_ex),
  .data_rs1_to_ex(RS_data_rs1_to_ex),
  .data_rs2_to_ex(RS_data_rs2_to_ex),
  .imm_to_ex(RS_imm_to_ex),
  .pc_to_ex(RS_pc_to_ex),
  .tag_in_rob(RS_tag_in_rob),
  .tag_renew(ROB_tag_renew_to_rs),
  .data_renew(ROB_data_renew_to_rs),
  .clear(ROB_clear_rs)
);

lsb lsb_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_issue_lsb(DECODER_if_issue_lsb),
  .dest_lsb(DECODER_dest_lsb),
  .op_type_to_lsb(DECODER_op_type_to_lsb),
  .tag_rs1_to_lsb(DECODER_tag_rs1_to_lsb),
  .data_rs1_to_lsb(DECODER_data_rs1_to_lsb),
  .tag_rs2_to_lsb(DECODER_tag_rs2_to_lsb),
  .data_rs2_to_lsb(DECODER_data_rs2_to_lsb),
  .imm_to_lsb(DECODER_imm_to_lsb),
  .if_idle(LSB_if_idle),
  .wb_addr(LSB_wb_addr),
  .wb_data(LSB_wb_data),
  .wb_pos_in_rob(LSB_wb_pos_in_rob),
  .out_ioin(LSB_out_ioin),
  .cur_inst_addr(LSB_cur_inst_addr),
  .if_out_mem(LSB_if_out_mem),
  .out_mem_size(LSB_out_mem_size),
  .out_mem_signed(LSB_out_mem_signed),
  .out_mem_addr(LSB_out_mem_addr),
  .tag_renew(ROB_tag_renew_to_lsb),
  .data_renew(ROB_data_renew_to_lsb),
  .if_addr_hzd(ROB_if_addr_hzd_to_lsb),
  .clear(ROB_clear_lsb),
  .if_get_mem(MEM_if_out_to_lsb),
  .data_mem(MEM_data_out_to_lsb)
);

ex ex_unit(
  .op_type_ex(RS_op_type_to_ex),
  .data_rs1_ex(RS_data_rs1_to_ex),
  .data_rs2_ex(RS_data_rs2_to_ex),
  .imm_ex(RS_imm_to_ex),
  .pc_ex(RS_pc_to_ex),
  .tag_in_rob(RS_tag_in_rob),
  .wb_data(EX_wb_data),
  .pc_to_jump(EX_pc_to_jump),
  .wb_pos_in_rob(EX_wb_pos_in_rob)
);

rob rob_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .clear(ROB_clear_rob),
  .tag_rs1_decoder(DECODER_tag_rs1_to_rob),
  .tag_rs2_decoder(DECODER_tag_rs2_to_rob),
  .op_decoder(DECODER_op_to_rob),
  .rd_decoder(DECODER_rd_to_rob),
  .wb_addr_lsb(LSB_wb_addr),
  .wb_data_lsb(LSB_wb_data),
  .wb_pos_lsb(LSB_wb_pos_in_rob),
  .in_ioin(LSB_out_ioin),
  .cur_inst_addr_lsb(LSB_cur_inst_addr),
  .wb_data_ex(EX_wb_data),
  .pc_to_jump_ex(EX_pc_to_jump),
  .wb_pos_ex(EX_wb_pos_in_rob),
  .if_idle(ROB_if_idle),
  .data_rs1_to_decoder(ROB_data_rs1_to_decoder),
  .data_rs2_to_decoder(ROB_data_rs2_to_decoder),
  .tag_to_decoder(ROB_tag_to_decoder),
  .if_jump(ROB_if_jump),
  .pc_to_jump(ROB_pc_to_jump),
  .tag_renew_to_rs(ROB_tag_renew_to_rs),
  .data_renew_to_rs(ROB_data_renew_to_rs),
  .tag_renew_to_lsb(ROB_tag_renew_to_lsb),
  .data_renew_to_lsb(ROB_data_renew_to_lsb),
  .if_addr_hzd_to_lsb(ROB_if_addr_hzd_to_lsb),
  .if_commit(ROB_if_commit),
  .pos_commit(ROB_pos_commit),
  .data_commit(ROB_data_commit),
  .tag_commit(ROB_tag_commit),
  .if_out_mem(ROB_if_out_mem),
  .out_mem_size(ROB_out_mem_size),
  .out_mem_addr(ROB_out_mem_addr),
  .out_mem_data(ROB_out_mem_data),
  .if_out_mem_io(ROB_if_out_mem_io),
  .clear_reg(ROB_clear_reg),
  .clear_rs(ROB_clear_rs),
  .clear_lsb(ROB_clear_lsb),
  .clear_mem(ROB_clear_mem),
  .clear_rob(ROB_clear_rob),
  .if_get_mem(MEM_if_out_io_to_rob),
  .data_mem(MEM_data_io)
);

mem_control mem_ctrl_unit(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_get_pc(PC_if_output_pc),
  .pc_get(PC_pc_to_getInst),
  .if_get_lsb_to_load(LSB_if_out_mem),
  .get_load_size(LSB_out_mem_size),
  .if_load_signed(LSB_out_mem_signed),
  .get_load_addr(LSB_out_mem_addr),
  .if_get_rob_to_store(ROB_if_out_mem),
  .get_store_size(ROB_out_mem_size),
  .get_store_addr(ROB_out_mem_addr),
  .get_store_data(ROB_out_mem_data),
  .if_get_io_to_load(ROB_if_out_mem_io),
  .clear(ROB_clear_mem),
  .if_out_inst_to_pc(MEM_if_out_inst_to_pc),
  .inst_out_to_pc(MEM_inst_out_to_pc),
  .if_out_io_to_rob(MEM_if_out_io_to_rob),
  .data_io(MEM_data_io),
  .if_out_to_lsb(MEM_if_out_to_lsb),
  .data_out_to_lsb(MEM_data_out_to_lsb),
  .if_uart_full(io_buffer_full),
  .if_rw(mem_wr),
  .addr_to_ram(mem_a),
  .data_to_ram(mem_dout),
  .get_data_ram(mem_din)
);

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

endmodule