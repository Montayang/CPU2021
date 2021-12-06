`timescale 1ns/1ps

`include "defines.v"

module ex (
    //ports with rs
    input wire [`opTypeWidth-1:0] op_type_ex,
    input wire [`dataWidth-1:0] rs1_data_ex,
    input wire [`dataWidth-1:0] rs2_data_ex,
    input wire [`immWidth-1:0] imm_ex,
    input wire [`addrWidth-1:0] pc_ex,
    input wire [`tagWidth-1:0] tag_in_rob,
    //ports with rob
    output reg [`dataWidth-1:0] wb_data,
    output reg [`addrWidth-1:0] pc_to_jump,
    output reg [`tagWidth-1:0] wb_pos_in_rob
);

always @(*) begin
    wb_pos_in_rob = tag_in_rob;
    pc_to_jump = `emptyAddr;
    wb_data = `emptyData;
    case (op_type_ex)
        `LUI :      wb_data = imm_ex;
        `AUIPC :    wb_data = $signed(pc_ex) + $signed(imm_ex);
        `JAL : begin
                    pc_to_jump = $signed(pc_ex) + $signed(imm_ex);
                    wb_data = $signed(pc_ex) + 4;
               end
        `JALR : begin
                    pc_to_jump = ($signed(data_rs1) + $signed(imm_ex)) & 32'hfffffffe;
                    wb_data = $signed(pc_ex) + 4;
                end
        `BEQ :  begin
                    if (data_rs1 == data_rs2)
                    pc_to_jump = pc_ex + imm_ex;
                end
        `BNE :  begin
                    if (data_rs1 != data_rs2)
                    pc_to_jump = pc_ex + imm_ex;
                end
        `BLT :  begin
                    if ($signed(data_rs1) < $signed(data_rs2))
                    pc_to_jump = pc_ex + imm_ex;
                end
        `BGE :  begin
                    if ($signed(data_rs1) >= $signed(data_rs2))
                    pc_to_jump = pc_ex + imm_ex;
                end
        `BLTU : begin
                    if (data_rs1 < data_rs2)
                    pc_to_jump = pc_ex + imm_ex;
                end
        `BGEU : begin
                    if (data_rs1 >= data_rs2)
                    pc_to_jump = pc_ex + imm_ex;
                end
        `ADDI :     wb_data = $signed(data_rs1) + $signed(imm_ex);
        `SLTI :     wb_data = $signed(data_rs1) < $signed(imm_ex) ? 1 : 0;
        `SLTIU :    wb_data = data_rs1 < imm_ex ? 1 : 0;
        `XORI :     wb_data = $signed(data_rs1) ^ $signed(imm_ex);
        `ORI :      wb_data = $signed(data_rs1) | $signed(imm_ex);
        `ANDI :     wb_data = $signed(data_rs1) & $signed(imm_ex);
        `SLLI :     wb_data = exsrc1 << exsrc2[4 : 0];
        `SRLI :     wb_data = exsrc1 >> exsrc2[4 : 0];
        `SRAI :     wb_data = $signed(exsrc1) >>> exsrc2[4 : 0];
        `ADD :      wb_data = $signed(exsrc1) + $signed(exsrc2);
        `SUB :      wb_data = $signed(exsrc1) - $signed(exsrc2);
        `SLL :      wb_data = exsrc1 << exsrc2[4 : 0];
        `SLT :      wb_data = $signed(exsrc1) < $signed(exsrc2) ? 1 : 0;
        `SLTU :     wb_data = exsrc1 < exsrc2 ? 1 : 0;
        `XOR :      wb_data = $signed(exsrc1) ^ $signed(exsrc2);
        `SRL :      wb_data = exsrc1 >> exsrc2[4 : 0];
        `SRA :      wb_data = $signed(exsrc1) >>> exsrc2[4 : 0];
        `OR :       wb_data = $signed(exsrc1) | $signed(imm_ex);
        `AND :      wb_data = $signed(exsrc1) & $signed(imm_ex);
    endcase
end
    
endmodule