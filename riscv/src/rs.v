`timescale 1ns/1ps

`include "defines.v"

module rs (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear, 
    //ports with decoder
    output reg if_idle,
    input wire if_issue_rs,
    input wire [`tagWidth-1:0] dest_rs,
    input wire [`opTypeWidth-1:0] op_type_to_rs,
    input wire [`tagWidth-1:0] tag_rs1_to_rs,
    input wire [`dataWidth-1:0] data_rs1_to_rs,
    input wire [`tagWidth-1:0] tag_rs2_to_rs,
    input wire [`dataWidth-1:0] data_rs2_to_rs,
    input wire [`immWidth-1:0] imm_to_rs,
    input wire [`addrWidth-1:0] pc_to_rs,
    //ports with ex
    output reg [`opTypeWidth-1:0] op_type_to_ex,
    output reg [`dataWidth-1:0] data_rs1_to_ex,
    output reg [`dataWidth-1:0] data_rs2_to_ex,
    output reg [`immWidth-1:0] imm_to_ex,
    output reg [`addrWidth-1:0] pc_to_ex,
    output reg [`tagWidth-1:0] tag_in_rob,
    //ports with rob
    input wire [`tagWidth-1:0] tag_renew,
    input wire [`dataWidth-1:0] data_renew
);
    reg               if_busy_entry[`rsSize-1:0];
    reg [`tagWidth-1:0]  dest_entry[`rsSize-1:0];
    reg [`opTypeWidth-1:0] op_entry[`rsSize-1:0];
    reg [`dataWidth-1:0]   V1_entry[`rsSize-1:0];
    reg [`dataWidth-1:0]   V2_entry[`rsSize-1:0];
    reg [`tagWidth-1:0]    Q1_entry[`rsSize-1:0];
    reg [`tagWidth-1:0]    Q2_entry[`rsSize-1:0];
    reg [`immWidth-1:0]   imm_entry[`rsSize-1:0];
    reg [`addrWidth-1:0]   pc_entry[`rsSize-1:0];
    reg                 ready_entry[`rsSize-1:0];

    reg [4:0] busy_entry;//the number of busy entry
    reg [4:0] pos_for_newInst;
    reg [4:0] pos_to_ex;

always @(posedge clk) begin
    if (rst || clear) begin
        for (integer i=0; i<`rsSize; i++) if_busy_entry[i] = `FALSE;
        busy_entry <= 0;
        if_idle = `FALSE;
    end else if (rdy) begin
        //recive from decoder
        if (busy_entry == `rsSize) if_idle = `FALSE;
        else if (if_issue_rs) begin
            for (integer i=`rsSize-1; i>=0; i--) begin
                if (!if_busy_entry[i]) pos_for_newInst <= i;
            end
            if_busy_entry[pos_for_newInst] <= `TRUE;
            busy_entry <= busy_entry + 1;
            dest_entry[pos_for_newInst] <= dest_rs;
            op_entry[pos_for_newInst] <= op_type_to_rs;
            V1_entry[pos_for_newInst] <= data_rs1_to_rs;
            V2_entry[pos_for_newInst] <= data_rs2_to_rs;
            Q1_entry[pos_for_newInst] <= tag_rs1_to_rs;
            Q2_entry[pos_for_newInst] <= tag_rs2_to_rs;
            imm_entry[pos_for_newInst] <= imm_to_rs;
            pc_entry[pos_for_newInst] <= pc_to_rs;
            if (busy_entry == `rsSize) if_idle = `FALSE;
            else if_idle = `TRUE;
        end
        //recive from rob
        for (integer i=0; i<`rsSize; i++) begin
            if (Q1_entry[i] == tag_renew) begin
                V1_entry[i] <= data_renew;
                Q1_entry[i] <= `emptyTag;
            end
            if (Q2_entry[i] == tag_renew) begin
                V2_entry[i] <= data_renew;
                Q2_entry[i] <= `emptyTag;
            end
        end
        //issue to ex
        if (pos_to_ex >= 0 && pos_to_ex < `rsSize) begin
            if_busy_entry[pos_to_ex] <= `FALSE;
            busy_entry <= busy_entry - 1;
            op_type_to_ex  =   op_entry[pos_to_ex];
            data_rs1_to_ex =   V1_entry[pos_to_ex];
            data_rs2_to_ex =   V2_entry[pos_to_ex];
            imm_to_ex      =  imm_entry[pos_to_ex];
            pc_to_ex       =   pc_entry[pos_to_ex];
            tag_in_rob     = dest_entry[pos_to_ex];
        end
    end
end
    
always @(*) begin
    for (integer i=0; i<`rsSize; i++) begin
        if (if_busy_entry[i] && Q1_entry[i] == `emptyTag && Q1_entry[i] == `emptyTag) ready_entry[i]=`TRUE;
        else ready_entry[i]=`FALSE;
    end
    for (integer i=0; i<`rsSize; i++) begin
        if (ready_entry[i]) pos_to_ex = i;
    end
end

endmodule