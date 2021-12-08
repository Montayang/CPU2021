`timescale 1ns/1ps

`include "defines.v"

module ex (
    //ports with rs
    input wire [`opTypeWidth-1:0] op_type_ex,
    input wire [`dataWidth-1:0] data_rs1_ex,
    input wire [`dataWidth-1:0] data_rs2_ex,
    input wire [`immWidth-1:0] imm_ex,
    input wire [`addrWidth-1:0] pc_ex,
    input wire [`tagWidth-1:0] tag_in_rob,
    //ports with rob
    output reg [`dataWidth-1:0] wb_data,
    output reg [`addrWidth-1:0] pc_to_jump,
    output reg [`tagWidth-1:0] wb_pos_in_rob
);

    always @(*) begin
        wb_pos_in_rob = `emptyTag;
        pc_to_jump = `emptyAddr;
        wb_data = `emptyData;
        if (op_type_ex != `emptyOp) begin
            wb_pos_in_rob = tag_in_rob;
            case (op_type_ex)
                `LUI :      wb_data = imm_ex;
                `AUIPC :    wb_data = $signed(pc_ex) + $signed(imm_ex);
                `JAL : begin
                            pc_to_jump = $signed(pc_ex) + $signed(imm_ex);
                            wb_data = $signed(pc_ex) + 4;
                    end
                `JALR : begin
                            pc_to_jump = ($signed(data_rs1_ex) + $signed(imm_ex)) & 32'hfffffffe;
                            wb_data = $signed(pc_ex) + 4;
                        end
                `BEQ :  begin
                            if (data_rs1_ex == data_rs2_ex)
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `BNE :  begin
                            if (data_rs1_ex != data_rs2_ex)
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `BLT :  begin
                            if ($signed(data_rs1_ex) < $signed(data_rs2_ex))
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `BGE :  begin
                            if ($signed(data_rs1_ex) >= $signed(data_rs2_ex))
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `BLTU : begin
                            if (data_rs1_ex < data_rs2_ex)
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `BGEU : begin
                            if (data_rs1_ex >= data_rs2_ex)
                            pc_to_jump = pc_ex + imm_ex;
                        end
                `ADDI :     wb_data = $signed(data_rs1_ex) + $signed(imm_ex);
                `SLTI :     wb_data = $signed(data_rs1_ex) < $signed(imm_ex) ? 1 : 0;
                `SLTIU :    wb_data = data_rs1_ex < imm_ex ? 1 : 0;
                `XORI :     wb_data = $signed(data_rs1_ex) ^ $signed(imm_ex);
                `ORI :      wb_data = $signed(data_rs1_ex) | $signed(imm_ex);
                `ANDI :     wb_data = $signed(data_rs1_ex) & $signed(imm_ex);
                `SLLI :     wb_data = data_rs1_ex << data_rs2_ex[4 : 0];
                `SRLI :     wb_data = data_rs1_ex >> data_rs2_ex[4 : 0];
                `SRAI :     wb_data = $signed(data_rs1_ex) >>> data_rs2_ex[4 : 0];
                `ADD :      wb_data = $signed(data_rs1_ex) + $signed(data_rs2_ex);
                `SUB :      wb_data = $signed(data_rs1_ex) - $signed(data_rs2_ex);
                `SLL :      wb_data = data_rs1_ex << data_rs2_ex[4 : 0];
                `SLT :      wb_data = $signed(data_rs1_ex) < $signed(data_rs2_ex) ? 1 : 0;
                `SLTU :     wb_data = data_rs1_ex < data_rs2_ex ? 1 : 0;
                `XOR :      wb_data = $signed(data_rs1_ex) ^ $signed(data_rs2_ex);
                `SRL :      wb_data = data_rs1_ex >> data_rs2_ex[4 : 0];
                `SRA :      wb_data = $signed(data_rs1_ex) >>> data_rs2_ex[4 : 0];
                `OR :       wb_data = $signed(data_rs1_ex) | $signed(data_rs2_ex);
                `AND :      wb_data = $signed(data_rs1_ex) & $signed(data_rs2_ex);
            endcase
        end
    end
    
endmodule