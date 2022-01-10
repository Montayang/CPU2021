`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module decoder( 
    //ports with pc
    input wire if_get_inst,
    output reg if_station_idle, 
    input wire [`instWidth-1:0] inst_from_pc,
    input wire [`addrWidth-1:0] pc_inst,
    //ports with regfile
    output reg [`regWidth-1:0] pos_rs1_to_reg,
    input wire [`dataWidth-1:0] data_rs1_reg,
    input wire [`tagWidth-1:0] tag_rs1_reg,
    output reg [`regWidth-1:0] pos_rs2_to_reg,
    input wire [`dataWidth-1:0] data_rs2_reg,
    input wire [`tagWidth-1:0] tag_rs2_reg,
    output reg [`tagWidth-1:0] tag_rd_to_reg,//for regfile to rename the objective reg
    output reg [`regWidth-1:0] rd_to_rename,
    //ports with rob
    input wire if_rob_idle,
    output reg [`regWidth-1:0] tag_rs1_to_rob,
    input wire [`dataWidth-1:0] data_rs1_rob,
    output reg [`regWidth-1:0] tag_rs2_to_rob,
    input wire [`dataWidth-1:0] data_rs2_rob,
    input wire [`tagWidth-1:0] tag_rob, //the position in rob for the inst
    output reg [`opTypeWidth-1:0] op_to_rob,
    output reg [`regWidth-1:0] rd_to_rob,
    //ports with rs
    input wire if_rs_idle,
    output reg if_issue_rs,
    output reg [`tagWidth-1:0] dest_rs,
    output reg [`opTypeWidth-1:0] op_type_to_rs,
    output reg [`tagWidth-1:0] tag_rs1_to_rs,
    output reg [`dataWidth-1:0] data_rs1_to_rs,
    output reg [`tagWidth-1:0] tag_rs2_to_rs,
    output reg [`dataWidth-1:0] data_rs2_to_rs,
    output reg [`immWidth-1:0] imm_to_rs,
    output reg [`addrWidth-1:0] pc_to_rs,
    //ports with lsb
    input wire if_lsb_idle,
    output reg if_issue_lsb,
    output reg [`tagWidth-1:0] dest_lsb,
    output reg [`opTypeWidth-1:0] op_type_to_lsb,
    output reg [`tagWidth-1:0] tag_rs1_to_lsb,
    output reg [`dataWidth-1:0] data_rs1_to_lsb,
    output reg [`tagWidth-1:0] tag_rs2_to_lsb,
    output reg [`dataWidth-1:0] data_rs2_to_lsb,
    output reg [`immWidth-1:0] imm_to_lsb
);
    reg [`immWidth-1:0] imm;
    wire [`funct7Width-1:0] funct7;
    wire [`funct3Width-1:0] funct3;
    wire [`opWidth-1:0] op;
    wire [`regWidth-1:0] rd,rs1,rs2;
    reg [`dataWidth-1:0] data_rs1;
    reg [`tagWidth-1:0] tag_rs1;
    reg [`dataWidth-1:0] data_rs2;
    reg [`tagWidth-1:0] tag_rs2;

    reg [`opTypeWidth-1:0] op_type;

    assign funct7 = inst_from_pc[`funct7Range];
    assign funct3 = inst_from_pc[`funct3Range];
    assign op = inst_from_pc[`opRange];
    assign rd = inst_from_pc[`rdRange];
    assign rs1 = inst_from_pc[`rs1Range];
    assign rs2 = inst_from_pc[`rs2Range];

    always @(*) begin
        if_station_idle = `TRUE;
        if (!if_rob_idle) if_station_idle = `FALSE;
        else if (!if_lsb_idle) if_station_idle = `FALSE;
        else if (!if_rs_idle) if_station_idle = `FALSE;
        op_type = `emptyOp;
        pos_rs1_to_reg = `emptyReg;
        pos_rs2_to_reg = `emptyReg;
        tag_rs1_to_rob = `emptyTag;
        tag_rs2_to_rob = `emptyTag;
        op_to_rob = `emptyOp;
        rd_to_rob = `emptyAddr;
        rd_to_rename = `emptyReg;
        tag_rd_to_reg = `emptyTag;
        if_issue_lsb = `FALSE;
        if_issue_rs = `FALSE;
        dest_rs = `emptyTag;
        op_type_to_rs = `emptyOp;
        tag_rs1_to_rs = `emptyTag;
        data_rs1_to_rs = `emptyData;
        tag_rs2_to_rs = `emptyTag;
        data_rs2_to_rs = `emptyData;
        imm_to_rs = `emptyData;
        pc_to_rs = `emptyAddr;
        dest_lsb = `emptyTag;
        op_type_to_lsb = `emptyOp;
        tag_rs1_to_lsb = `emptyTag;
        data_rs1_to_lsb = `emptyData;
        tag_rs2_to_lsb = `emptyTag;
        data_rs2_to_lsb = `emptyData;
        imm_to_lsb = `emptyData;
        if (if_get_inst) begin
            case (op)
                7'b0110111 : begin
                    op_type = `LUI;
                    imm = {inst_from_pc[31:12], {12{1'b0}}};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    if_issue_rs = `TRUE;
                end
                7'b0010111 : begin
                    op_type = `AUIPC;
                    imm = {inst_from_pc[31:12], {12{1'b0}}};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    if_issue_rs = `TRUE;
                end
                7'b1101111 : begin
                    op_type = `JAL;
                    imm = {{12{inst_from_pc[31]}}, inst_from_pc[19:12], inst_from_pc[20], inst_from_pc[30:21], 1'b0};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    if_issue_rs = `TRUE;
                end
                7'b1100111 : begin
                    op_type = `JALR;
                    imm = {{20{inst_from_pc[31]}}, inst_from_pc[31:20]};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    pos_rs1_to_reg = rs1;
                    if_issue_rs = `TRUE;
                end
                7'b1100011 : begin
                    case (funct3)
                        3'b000 : op_type = `BEQ;
                        3'b001 : op_type = `BNE;
                        3'b100 : op_type = `BLT;
                        3'b101 : op_type = `BGE;
                        3'b110 : op_type = `BLTU;
                        3'b111 : op_type = `BGEU;
                    endcase
                    imm = {{20{inst_from_pc[31]}}, inst_from_pc[7], inst_from_pc[30:25], inst_from_pc[11:8], 1'b0};
                    pos_rs1_to_reg = rs1;
                    pos_rs2_to_reg = rs2;
                    if_issue_rs = `TRUE;
                end
                7'b0000011 : begin
                    case (funct3)
                        3'b000 : op_type = `LB;
                        3'b001 : op_type = `LH;
                        3'b010 : op_type = `LW;
                        3'b100 : op_type = `LBU;
                        3'b101 : op_type = `LHU;
                    endcase
                    imm = {{20{inst_from_pc[31]}}, inst_from_pc[31:20]};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    pos_rs1_to_reg = rs1;
                    if_issue_lsb = `TRUE;
                end
                7'b0100011 : begin
                    case (funct3)
                        3'b000 : op_type = `SB;
                        3'b001 : op_type = `SH;
                        3'b010 : op_type = `SW;
                    endcase
                    imm = {{20{inst_from_pc[31]}}, inst_from_pc[31:25], inst_from_pc[11:7]};
                    pos_rs1_to_reg = rs1;
                    pos_rs2_to_reg = rs2;
                    if_issue_lsb = `TRUE;
                end
                7'b0010011 : begin
                    case (funct3)
                        3'b000 : op_type = `ADDI;
                        3'b010 : op_type = `SLTI;
                        3'b011 : op_type = `SLTIU;
                        3'b100 : op_type = `XORI;
                        3'b110 : op_type = `ORI;
                        3'b111 : op_type = `ANDI;
                        3'b001 : op_type = `SLLI;
                        3'b101 : op_type = funct7 == 7'b0000000 ? `SRLI : `SRAI;
                    endcase
                    imm = {{20{inst_from_pc[31]}}, inst_from_pc[31:20]};
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    pos_rs1_to_reg = rs1;
                    if_issue_rs = `TRUE;
                end
                7'b0110011 : begin
                    case (funct3)
                        3'b000 : op_type = funct7 == 7'b0000000 ? `ADD : `SUB;
                        3'b001 : op_type = `SLL;
                        3'b010 : op_type = `SLT;
                        3'b011 : op_type = `SLTU;
                        3'b100 : op_type = `XOR;
                        3'b101 : op_type = funct7 == 7'b0000000 ? `SRL : `SRA;
                        3'b110 : op_type = `OR;
                        3'b111 : op_type = `AND;
                    endcase
                    imm = 32'b0;
                    rd_to_rob = {27'b0,rd[4:0]};
                    tag_rd_to_reg = tag_rob;
                    rd_to_rename = rd;
                    pos_rs1_to_reg = rs1;
                    pos_rs2_to_reg = rs2;
                    if_issue_rs = `TRUE;
                end
            endcase
            tag_rs1_to_rob = tag_rs1_reg;
            tag_rs2_to_rob = tag_rs2_reg;
            op_to_rob = op_type;
            //get the information of rs1 and rs2
            tag_rs1 = tag_rs1_reg;
            if (tag_rs1 == `emptyTag) data_rs1 = data_rs1_reg;
            else if (data_rs1_rob != `emptyData) begin
                data_rs1 = data_rs1_rob;
                tag_rs1 = `emptyTag;
            end else data_rs1 = `emptyData;  
            tag_rs2 = tag_rs2_reg;
            if (tag_rs2 == `emptyTag) data_rs2 = data_rs2_reg;
            else if (data_rs2_rob != `emptyData) begin
                data_rs2 = data_rs2_rob;
                tag_rs2 = `emptyTag;
            end else data_rs2 = `emptyData;
            //about shamt  data_rs2 := shamt
            if (op == 7'b0010011 && (funct3 == 3'b001 || funct3 == 3'b101)) begin
                data_rs2 = rs2;
                tag_rs2 = `emptyTag;
            end
            //issue
            dest_rs = tag_rob;
            op_type_to_rs = op_type;
            tag_rs1_to_rs = tag_rs1;
            data_rs1_to_rs = data_rs1;
            tag_rs2_to_rs = tag_rs2;
            data_rs2_to_rs = data_rs2;
            imm_to_rs = imm;
            pc_to_rs = pc_inst;
            dest_lsb = tag_rob;
            op_type_to_lsb = op_type;
            tag_rs1_to_lsb = tag_rs1;
            data_rs1_to_lsb = data_rs1;
            tag_rs2_to_lsb = tag_rs2;
            data_rs2_to_lsb = data_rs2;
            imm_to_lsb = imm;
        end
    end

endmodule