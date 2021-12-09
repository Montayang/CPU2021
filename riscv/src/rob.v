`timescale 1ns/1ps

`include "defines.v"

module rob (
    input wire clk,
    input wire rst,
    input wire rdy,
    //ports with decoder
    output wire if_idle,
    input wire [`regWidth-1:0] tag_rs1_decoder,
    output wire [`dataWidth-1:0] data_rs1_to_decoder,
    input wire [`regWidth-1:0] tag_rs2_decoder,
    output wire [`dataWidth-1:0] data_rs2_to_decoder,
    output wire [`tagWidth-1:0] tag_to_decoder,
    input wire [`opTypeWidth-1:0] op_decoder,
    input wire [`regWidth-1:0] rd_decoder,
    //ports with pc
    output reg if_jump,
    output reg [`addrWidth-1:0] pc_to_jump,
    //ports with rs
    output reg [`tagWidth-1:0] tag_renew_to_rs,
    output reg [`dataWidth-1:0] data_renew_to_rs,
    //ports with lsb
    output reg [`tagWidth-1:0] tag_renew_to_lsb,
    output reg [`dataWidth-1:0] data_renew_to_lsb,
    input wire [`addrWidth-1:0] wb_addr_lsb,
    input wire [`dataWidth-1:0] wb_data_lsb,
    input wire [`tagWidth-1:0] wb_pos_lsb,
    input wire in_ioin,
    input wire [`addrWidth-1:0] cur_inst_addr_lsb,//to avoid that mem[addr] haven't stored when load it
    output reg if_addr_hzd_to_lsb,
    //ports with ex
    input wire [`dataWidth-1:0] wb_data_ex,
    input wire [`addrWidth-1:0] pc_to_jump_ex,
    input wire [`tagWidth-1:0] wb_pos_ex,
    //ports with regfile
    output reg if_commit,
    output reg [`regWidth-1:0] pos_commit,
    output reg [`dataWidth-1:0] data_commit,
    output reg [`tagWidth-1:0] tag_commit,
    //ports with mem_ctrl
    output reg if_out_mem,
    output reg [5:0] out_mem_size,
    output reg [`addrWidth-1:0] out_mem_addr,
    output reg [`dataWidth-1:0] out_mem_data,//the data to store
    output reg if_out_mem_io,
    input wire if_get_mem,
    input wire [`dataWidth-1:0] data_mem,//the data got with io
    //ports to clear
    output reg clear_reg,
    output reg clear_rs,
    output reg clear_lsb,
    output reg clear_mem
);
    localparam IDLE = 1'b0, WAIT = 1'b1;
    reg status;
    reg [`dataWidth-1:0] value_entry[`robSize-1:0];
    reg [`addrWidth-1:0] destination_entry[`robSize-1:0];//may be address(when S-type) or
    reg ready_entry [`robSize-1:0];
    reg [`opTypeWidth-1:0] op_entry[`robSize-1:0];
    reg [`addrWidth-1:0] new_pc_entry[`robSize-1:0];
    reg if_IO[`robSize-1:0];

    reg [4:0] head, tail;
    reg if_empty;
    assign if_idle = if_empty || ((head != tail) && !((tail+1 == head) || (tail == `lsbSize && head == 1)));

    //decoder wants to get the opration value
    assign data_rs1_to_decoder = ready_entry[tag_rs1_decoder] ? value_entry[tag_rs1_decoder] : `emptyData;
    assign data_rs2_to_decoder = ready_entry[tag_rs2_decoder] ? value_entry[tag_rs2_decoder] : `emptyData;
    assign tag_to_decoder = if_idle ? tail : `emptyTag;

    reg j;
    always @(*) begin
        j = `FALSE;
        for (integer i=1; i<`robSize; i++) begin
            if ((op_entry[i] == `SB || op_entry[i] == `SH || op_entry[i] == `SW) && cur_inst_addr_lsb == destination_entry[i]) j = `TRUE; 
        end
        if (j) if_addr_hzd_to_lsb = `TRUE;
        else if_addr_hzd_to_lsb = `FALSE;
    end

    always @(posedge clk) begin
        if (rst || clear_reg) begin
            status <= IDLE;
            if_empty <= `TRUE;
            head <= 1;
            tail <= 1;
            if_jump = `FALSE;
            pc_to_jump = `emptyAddr;
            tag_renew_to_rs = `emptyTag;
            tag_renew_to_lsb = `emptyTag;
            clear_reg = `FALSE;
            clear_rs = `FALSE;
            clear_lsb = `FALSE;
            clear_mem = `FALSE;
            if_out_mem = `FALSE;
            if_out_mem_io = `FALSE;
            if_commit = `FALSE;
            for (integer j = 0;j < `lsbSize; j++) begin
                ready_entry[j] <= `FALSE;
            end
        end else if (rdy) begin
            tag_renew_to_lsb = `emptyTag;
            tag_renew_to_rs = `emptyTag;
            if_commit = `FALSE;
            if_out_mem = `FALSE;
            if_out_mem_io = `FALSE;
            //recive inst from decoder
            if (op_decoder != `emptyOp && if_idle) begin
                op_entry[tail] <=  op_decoder;
                destination_entry[tail] <= rd_decoder;
                new_pc_entry[tail] <= `emptyAddr;
                ready_entry[tail] <= `FALSE;
                tail <= tail == `robSize ? 1 : tail+1;
                if_empty <= `FALSE;
            end
            //renew data from ex and lsb and broadcast
            if (wb_pos_ex != `emptyTag) begin
                value_entry[wb_pos_ex] <= wb_data_ex;
                new_pc_entry[wb_pos_ex] <= pc_to_jump_ex;
                ready_entry[wb_pos_ex] <= `TRUE;
                tag_renew_to_rs = wb_pos_ex;
                data_renew_to_rs = wb_data_ex;
                tag_renew_to_lsb = wb_pos_ex;
                data_renew_to_lsb <= wb_data_ex;
            end
            if (wb_pos_lsb != `emptyTag) begin
                value_entry[wb_pos_lsb] <= wb_data_lsb;
                ready_entry[wb_pos_lsb] <= in_ioin ? `FALSE : `TRUE;//load with load have not ex
                if_IO[wb_pos_lsb] <= in_ioin ? `TRUE : `FALSE;
                if (op_entry[wb_pos_lsb] == `SB || op_entry[wb_pos_lsb] == `SH || op_entry[wb_pos_lsb] == `SW) destination_entry[wb_data_lsb] <= wb_addr_lsb;
                tag_renew_to_rs = wb_pos_lsb;
                data_renew_to_rs = wb_data_lsb;
                tag_renew_to_lsb = wb_pos_lsb;
                data_renew_to_lsb <= wb_data_lsb;
            end
            //commit
            if (ready_entry[head] == `TRUE) begin
                if (status == IDLE) begin
                    if (op_entry[head] != `emptyOp) begin
                        case (op_entry[head])
                            `SB, `SH, `SW : begin
                                status <= WAIT;
                                if_out_mem <= `TRUE;
                                out_mem_addr <= destination_entry[head];
                                out_mem_data <= value_entry[head];
                                if (op_entry[head] == `SB) out_mem_size <= 1;
                                else if (op_entry[head] == `SH) out_mem_size <= 2;
                                else out_mem_size <= 4;
                            end
                            `JALR : begin
                                if_commit <= `TRUE;
                                pos_commit <= destination_entry[head][4:0];
                                data_commit <= value_entry[head];
                                tag_commit <= head;
                                clear_lsb <= `TRUE;
                                clear_reg <= `TRUE;
                                clear_rs <= `TRUE;
                                clear_mem <= `TRUE;
                                if_jump <= `TRUE;
                                pc_to_jump <= new_pc_entry[head];
                                if ((head+1 == tail) || (head == `lsbSize && tail == 1)) if_empty <= `TRUE;
                                head <= (head == `lsbSize) ? 1:head+1;
                            end
                            `BEQ,`BNE,`BLT,`BGE,`BLTU,`BGEU : begin
                                if (new_pc_entry[head] != `emptyAddr) begin
                                    clear_lsb <= `TRUE;
                                    clear_reg <= `TRUE;
                                    clear_rs <= `TRUE;
                                    clear_mem <= `TRUE;
                                    if_jump <= `TRUE;
                                    pc_to_jump <= new_pc_entry[head];
                                end
                                if ((head+1 == tail) || (head == `lsbSize && tail == 1)) if_empty <= `TRUE;
                                head <= (head == `lsbSize) ? 1:head+1;
                            end
                            default : begin
                                if_commit <= `TRUE;
                                pos_commit <= destination_entry[head][4:0];
                                data_commit <= value_entry[head];
                                tag_commit <= head;
                                if ((head+1 == tail) || (head == `lsbSize && tail == 1)) if_empty <= `TRUE;
                                head <= (head == `lsbSize) ? 1:head+1;
                            end
                        endcase
                    end
                end else begin
                    if (if_get_mem == `TRUE) begin
                        status = IDLE;
                        if ((head+1 == tail) || (head == `lsbSize && tail == 1)) if_empty <= `TRUE;
                        head <= (head == `lsbSize) ? 1:head+1;
                    end
                end
            end else if (if_IO[head]) begin
                //address is `IO_ADDR
                if (status == IDLE) begin
                    status <= WAIT;
                    if_out_mem_io <= `TRUE;
                end else begin
                    status <= IDLE;
                    if (if_get_mem) begin
                        value_entry[head] <= data_mem;
                        if_IO[head] <= `FALSE;
                        ready_entry[head] <= `TRUE;
                    end
                end
            end
        end
    end

endmodule