`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module rob (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear,
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
    output reg [`dataWidth-1:0] out_mem_data,
    input wire if_stored,//to store
    output reg if_out_mem_io,
    input wire if_get_mem,
    input wire [`dataWidth-1:0] data_mem,//the data got with io
    //ports to clear
    output reg clear_reg,
    output reg clear_rs,
    output reg clear_lsb,
    output reg clear_mem,
    output reg clear_rob
);
    localparam IDLE = 1'b0, WAIT = 1'b1;
    reg status;
    reg if_busy_entry[`robSize-1:0];
    reg [`dataWidth-1:0] value_entry[`robSize-1:0];
    reg [`addrWidth-1:0] destination_entry[`robSize-1:0];//address(when S-type)
    reg ready_entry[`robSize-1:0];
    reg [`opTypeWidth-1:0] op_entry[`robSize-1:0];
    reg [`addrWidth-1:0] new_pc_entry[`robSize-1:0];
    reg if_IO[`robSize-1:0];

    reg [4:0] head, tail;
    reg if_empty;
    assign if_idle = if_empty || ((head != tail) && !((tail+1 == head) || (tail == `robSize && head == 1)));
    reg [2:0] count;

    //decoder wants to get the opration value
    assign data_rs1_to_decoder = value_entry[tag_rs1_decoder] ? value_entry[tag_rs1_decoder] : `emptyData;
    assign data_rs2_to_decoder = value_entry[tag_rs2_decoder] ? value_entry[tag_rs2_decoder] : `emptyData;
    assign tag_to_decoder = if_idle ? tail : `emptyTag;

            //integer rob_file;
            //initial rob_file = $fopen("rob1.txt");

    reg j;
    integer i;
    always @(*) begin
        j = `FALSE;
        for (i=1; i<`robSize; i=i+1) begin
            if ((op_entry[i] == `SB || op_entry[i] == `SH || op_entry[i] == `SW) && cur_inst_addr_lsb == destination_entry[i] && value_entry[i] != `emptyData) j = `TRUE; 
        end
        if (j || (cur_inst_addr_lsb == wb_addr_lsb)) if_addr_hzd_to_lsb = `TRUE;
        else if_addr_hzd_to_lsb = `FALSE;
    end

    integer k;
    always @(posedge clk) begin
                    //$fdisplay(rob_file,$time);
                    //for (i=1; i<16; i=i+1) $fdisplay(rob_file," [ROB]busy: ",if_busy_entry[i]," ready: ",ready_entry[i]," op : %h",op_entry[i]," addr : %h",destination_entry[i]," value : %h",value_entry[i]," jump",new_pc_entry[i],"  ",i);                   
        if (rst || clear) begin
            status <= IDLE;
            if_empty <= `TRUE;
            head <= 1;
            tail <= 1;
            if_jump <= `FALSE;
            pc_to_jump <= `emptyAddr;
            tag_renew_to_rs <= `emptyTag;
            tag_renew_to_lsb <= `emptyTag;
            count <= count + 1;
            if (rst || count == 2) begin
                clear_reg <= `FALSE;
                clear_rs <= `FALSE;
                clear_lsb <= `FALSE;
                clear_mem <= `FALSE;
                clear_rob <= `FALSE;
            end
            if_out_mem <= `FALSE;
            if_out_mem_io <= `FALSE;
            if_commit <= `FALSE;
            for (k = 0;k < `robSize; k=k+1) begin
                ready_entry[k] <= `FALSE;
                if_busy_entry[k] <= `FALSE;
                value_entry[k] <= `emptyData;
            end
        end else if (rdy) begin
            tag_renew_to_lsb <= `emptyTag;
            tag_renew_to_rs <= `emptyTag;
            if_commit <= `FALSE;
            if_out_mem <= `FALSE;
            if_out_mem_io <= `FALSE;
            if_jump <= `FALSE;
            //recive inst from decoder
            if (op_decoder != `emptyOp && if_idle) begin
                if_busy_entry[tail] <= `TRUE;
                op_entry[tail] <=  op_decoder;
                destination_entry[tail] <= rd_decoder;
                new_pc_entry[tail] <= `emptyAddr;
                ready_entry[tail] <= `FALSE;
                value_entry[tail] <= `emptyData;
                tail <= tail == `robSize-1 ? 1 : tail+1;
                if_empty <= `FALSE;
            end
            //renew data from ex and lsb and broadcast
            if (wb_pos_ex != `emptyTag && if_busy_entry[wb_pos_ex]) begin
                value_entry[wb_pos_ex] <= wb_data_ex;
                new_pc_entry[wb_pos_ex] <= pc_to_jump_ex;
                ready_entry[wb_pos_ex] <= `TRUE;
                tag_renew_to_rs <= wb_pos_ex;
                data_renew_to_rs <= wb_data_ex;
                tag_renew_to_lsb <= wb_pos_ex;
                data_renew_to_lsb <= wb_data_ex;
            end
            if (wb_pos_lsb != `emptyTag && if_busy_entry[wb_pos_lsb]) begin
                value_entry[wb_pos_lsb] <= wb_data_lsb;
                ready_entry[wb_pos_lsb] <= in_ioin ? `FALSE : `TRUE;
                if_IO[wb_pos_lsb] <= in_ioin ? `TRUE : `FALSE;
                if (op_entry[wb_pos_lsb] == `SB || op_entry[wb_pos_lsb] == `SH || op_entry[wb_pos_lsb] == `SW) destination_entry[wb_pos_lsb] <= wb_addr_lsb;
                tag_renew_to_rs <= wb_pos_lsb;
                data_renew_to_rs <= wb_data_lsb;
                tag_renew_to_lsb <= wb_pos_lsb;
                data_renew_to_lsb <= wb_data_lsb;
            end
            //commit
            if (!if_empty && ready_entry[head]) begin
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
                            `JALR, `JAL: begin
                                if_commit <= `TRUE;
                                pos_commit <= destination_entry[head][4:0];
                                data_commit <= value_entry[head];
                                tag_commit <= head;
                                clear_lsb <= `TRUE;
                                clear_reg <= `TRUE;
                                clear_rs <= `TRUE;
                                clear_mem <= `TRUE;
                                clear_rob <= `TRUE;
                                count <= 0;
                                if_jump <= `TRUE;
                                pc_to_jump <= new_pc_entry[head];
                                if (((head+1 == tail) || (head == `robSize-1 && tail == 1)) && !op_decoder) if_empty <= `TRUE;
                                head <= (head == `robSize-1) ? 1:head+1;
                                if_busy_entry[head] <= `FALSE;
                             end
                            `BEQ,`BNE,`BLT,`BGE,`BLTU,`BGEU : begin
                                if (new_pc_entry[head] != `emptyAddr) begin
                                    clear_lsb <= `TRUE;
                                    clear_reg <= `TRUE;
                                    clear_rs <= `TRUE;
                                    clear_mem <= `TRUE;
                                    clear_rob <= `TRUE;
                                    count <= 0;
                                    if_jump <= `TRUE;
                                    pc_to_jump <= new_pc_entry[head];
                                end
                                if (((head+1 == tail) || (head == `robSize-1 && tail == 1)) && !op_decoder) if_empty <= `TRUE;
                                head <= (head == `robSize-1) ? 1:head+1;
                                if_busy_entry[head] <= `FALSE;
                            end
                            default : begin
                                if_commit <= `TRUE;
                                pos_commit <= destination_entry[head][4:0];
                                data_commit <= value_entry[head];
                                tag_commit <= head;
                                if (((head+1 == tail) || (head == `robSize-1 && tail == 1)) && !op_decoder) if_empty <= `TRUE;
                                head <= (head == `robSize-1) ? 1:head+1;
                                if_busy_entry[head] <= `FALSE;
                            end
                        endcase
                    end
                end else begin
                    if (op_entry[head] == `SB || op_entry[head] == `SH || op_entry[head] == `SW) begin
                        if (if_stored == `TRUE) begin
                            status <= IDLE;
                            if (((head+1 == tail) || (head == `robSize-1 && tail == 1)) && !op_decoder) if_empty <= `TRUE;
                            head <= (head == `robSize-1) ? 1:head+1;
                            if_busy_entry[head] <= `FALSE;
                        end
                    end else begin
                        if (if_get_mem == `TRUE) begin
                            status <= IDLE;
                            if (((head+1 == tail) || (head == `robSize-1 && tail == 1)) && !op_decoder) if_empty <= `TRUE;
                            head <= (head == `robSize-1) ? 1:head+1;
                            if_busy_entry[head] <= `FALSE;
                        end
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