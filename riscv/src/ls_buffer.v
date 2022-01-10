`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module lsb (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear, 
    //ports with decoder
    output wire if_idle,
    input wire if_issue_lsb,
    input wire [`tagWidth-1:0] dest_lsb,
    input wire [`opTypeWidth-1:0] op_type_to_lsb,
    input wire [`tagWidth-1:0] tag_rs1_to_lsb,
    input wire [`dataWidth-1:0] data_rs1_to_lsb,
    input wire [`tagWidth-1:0] tag_rs2_to_lsb,
    input wire [`dataWidth-1:0] data_rs2_to_lsb,
    input wire [`immWidth-1:0] imm_to_lsb,
    //ports with rob
    input wire [`tagWidth-1:0] tag_renew,
    input wire [`dataWidth-1:0] data_renew,
    output reg [`addrWidth-1:0] wb_addr,
    output reg [`dataWidth-1:0] wb_data,
    output reg [`tagWidth-1:0] wb_pos_in_rob,
    output reg out_ioin,
    output wire [`addrWidth-1:0] cur_inst_addr,//to avoid that mem[addr] haven't stored when load it
    input wire if_addr_hzd,
    //ports with mem_ctrl
    output reg if_out_mem,
    output reg [5:0] out_mem_size,
    output reg out_mem_signed,
    output reg [`addrWidth-1:0] out_mem_addr,
    input wire if_get_mem,
    input wire [`addrWidth-1:0] data_mem
);
    localparam IDLE = 1'b0, WAIT = 1'b1;
    reg status;
    reg               if_busy_entry[`lsbSize-1:0];
    reg [`tagWidth-1:0]  dest_entry[`lsbSize-1:0];
    reg [`opTypeWidth-1:0] op_entry[`lsbSize-1:0];
    reg [`addrWidth-1:0] addr_entry[`lsbSize-1:0];
    reg [`dataWidth-1:0]   V1_entry[`lsbSize-1:0];
    reg [`dataWidth-1:0]   V2_entry[`lsbSize-1:0];
    reg [`tagWidth-1:0]    Q1_entry[`lsbSize-1:0];
    reg [`tagWidth-1:0]    Q2_entry[`lsbSize-1:0];
    reg [`immWidth-1:0]   imm_entry[`lsbSize-1:0];
    reg to_cclate_addr_ready_entry[`lsbSize-1:0];//for S-type to cclate the addr
    reg         address_ready_entry[`lsbSize-1:0];
    reg                ready_entry[`lsbSize-1:0];//can be ex
    wire [5:0] pos_to_cclate_addr;

    reg [4:0] head, tail;
    reg if_empty;
    assign if_idle = if_empty || ((head != tail) && !((tail+1 == head) || (tail == `lsbSize-1 && head == 1)));
    assign cur_inst_addr = addr_entry[head];

    integer i;
    always @(*) begin
        for(i = 0; i < `lsbSize; i=i+1) begin
            ready_entry[i] = (if_busy_entry[i] == `TRUE) && (Q2_entry[i] == `emptyTag) && (address_ready_entry[i] == `TRUE);
            to_cclate_addr_ready_entry[i] = (if_busy_entry[i] == `TRUE) && (Q1_entry[i] == `emptyTag) && (address_ready_entry[i] == `FALSE);
        end
    end

            //integer lsb_file;
            //initial lsb_file = $fopen("lsb1.txt");

    integer j;
    always @(posedge clk) begin 
                //$fdisplay(lsb_file,$time);
                //for (i=1; i<16; i=i+1) $fdisplay(lsb_file," [LSB]if_busy : ",if_busy_entry[i]," ready : ",ready_entry[i]," op : ",op_entry[i]," addr : %h",addr_entry[i]," V1 : %h",V1_entry[i]," Q1 : %h",Q1_entry[i]," V2 : %h",V2_entry[i]," Q2 : %h",Q2_entry[i]," imm : %h",imm_entry[i],"  ",i);
        if (rst || clear) begin
            status <= IDLE;
            if_empty <= `TRUE;
            head <= 1;
            tail <= 1;
            wb_addr <= `emptyAddr;
            wb_data <= `emptyData;
            wb_pos_in_rob <= `emptyTag;
            if_out_mem <= `FALSE;
            out_ioin <= `FALSE;
            for (j = 0;j < `lsbSize; j=j+1) begin
                if_busy_entry[j] <= `FALSE;
                address_ready_entry[j] <= `FALSE;
                addr_entry[j] <= `emptyAddr;
            end
        end else if (rdy) begin
            //recive from decoder
            if (if_issue_lsb && if_idle) begin
                if_busy_entry[tail] <= `TRUE;
                dest_entry[tail] <= dest_lsb;
                op_entry[tail] <= op_type_to_lsb;
                if (tag_renew != `emptyTag && tag_rs1_to_lsb == tag_renew) begin
                    V1_entry[tail] <= data_renew;
                    Q1_entry[tail] <= `emptyTag;
                end else begin
                    V1_entry[tail] <= data_rs1_to_lsb;
                    Q1_entry[tail] <= tag_rs1_to_lsb;
                end
                if (tag_renew != `emptyTag && tag_rs2_to_lsb == tag_renew) begin
                    V2_entry[tail] <= data_renew;
                    Q2_entry[tail] <= `emptyTag;
                end else begin
                    V2_entry[tail] <= data_rs2_to_lsb;
                    Q2_entry[tail] <= tag_rs2_to_lsb;
                end
                imm_entry[tail] <= imm_to_lsb;
                if_empty <= `FALSE;
                tail <= tail == `lsbSize-1 ? 1 : tail+1;
            end
            //recive from rob
            if (tag_renew != `emptyTag) begin
                for (i=1; i<`lsbSize; i=i+1) begin
                    if (Q1_entry[i] == tag_renew) begin
                        V1_entry[i] <= data_renew;
                        Q1_entry[i] <= `emptyTag;
                    end
                    if (Q2_entry[i] == tag_renew) begin
                        V2_entry[i] <= data_renew;
                        Q2_entry[i] <= `emptyTag;
                    end
                end
            end
            //issue to ex
            out_ioin <= `FALSE;
            wb_pos_in_rob <= `emptyTag;
            if_out_mem <= `FALSE;
            wb_addr <= `emptyAddr;
            if (ready_entry[head]) begin
                if (status == IDLE) begin
                    case (op_entry[head])
                        `LB, `LBU : begin
                            if (addr_entry[head] == `IO_ADDR) begin
                                //ex load in rob
                                if_busy_entry[head] <= `FALSE;
                                address_ready_entry[head] <= `FALSE;
                                out_ioin <= `TRUE;
                                wb_pos_in_rob <= dest_entry[head];
                                wb_data <= `emptyData;
                                if ((head+1 == tail) || (head == `lsbSize-1 && tail == 1)) if_empty <= `TRUE;
                                head <= (head == `lsbSize-1) ? 1:head+1;
                            end else if (!if_addr_hzd && addr_entry[head] != wb_addr) begin
                                status <= WAIT;
                                if_out_mem <= `TRUE;
                                out_mem_addr <= addr_entry[head];
                                out_mem_signed <= op_entry[head] == `LB ? 1 : 0; 
                                out_mem_size <= 1;
                            end
                        end
                        `LH, `LHU : begin
                            if (!if_addr_hzd && addr_entry[head] != wb_addr) begin
                                status <= WAIT;
                                if_out_mem <= `TRUE;
                                out_mem_addr <= addr_entry[head];
                                out_mem_signed <= op_entry[head] == `LH ? 1 : 0; 
                                out_mem_size <= 2;
                            end
                        end
                        `LW : begin
                            if (!if_addr_hzd && addr_entry[head] != wb_addr) begin
                                status <= WAIT;
                                if_out_mem <= `TRUE;
                                out_mem_addr <= addr_entry[head];
                                out_mem_size <= 4;
                            end
                        end
                        `SB, `SH, `SW : begin
                            wb_addr <= addr_entry[head];
                            wb_data <= V2_entry[head];
                            if_busy_entry[head] <= `FALSE;
                            address_ready_entry[head] <= `FALSE;
                            wb_pos_in_rob <= dest_entry[head];
                            if ((head+1 == tail) || (head == `lsbSize-1 && tail == 1)) if_empty <= `TRUE;
                            head <= (head == `lsbSize-1) ? 1:head+1;
                        end
                    endcase
                end else begin
                    if (if_get_mem) begin
                        status <= IDLE;
                        wb_data <= data_mem;
                        if_busy_entry[head] <= `FALSE;
                        address_ready_entry[head] <= `FALSE;
                        wb_pos_in_rob <= dest_entry[head];
                        if ((head+1 == tail) || (head == `lsbSize-1 && tail == 1)) if_empty <= `TRUE;
                        head <= (head == `lsbSize-1) ? 1:head+1;
                    end
                end
            end
            //calculate address
            if (pos_to_cclate_addr > 0 && pos_to_cclate_addr < `lsbSize) begin
                addr_entry[pos_to_cclate_addr] <= V1_entry[pos_to_cclate_addr] + imm_entry[pos_to_cclate_addr];
                address_ready_entry[pos_to_cclate_addr] <= `TRUE;
            end
        end
    end

    assign pos_to_cclate_addr = to_cclate_addr_ready_entry[1] ? 1 : 
                        to_cclate_addr_ready_entry[2] ? 2 : 
                            to_cclate_addr_ready_entry[3] ? 3 :
                                to_cclate_addr_ready_entry[4] ? 4 :
                                    to_cclate_addr_ready_entry[5] ? 5 :
                                        to_cclate_addr_ready_entry[6] ? 6 :
                                            to_cclate_addr_ready_entry[7] ? 7 : 
                                                to_cclate_addr_ready_entry[8] ? 8 : 
                                                    to_cclate_addr_ready_entry[9] ? 9 :
                                                        to_cclate_addr_ready_entry[10] ? 10 :
                                                            to_cclate_addr_ready_entry[11] ? 11 :
                                                                to_cclate_addr_ready_entry[12] ? 12 :
                                                                    to_cclate_addr_ready_entry[13] ? 13 :
                                                                        to_cclate_addr_ready_entry[14] ? 14 :
                                                                            to_cclate_addr_ready_entry[15] ? 15 : 0;

endmodule