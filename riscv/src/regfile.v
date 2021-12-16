`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module regfile(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear,
    //ports with decoder to get the value of rs1
    input wire [`regWidth-1:0] pos_rs1,
    output wire [`dataWidth-1:0] data_rs1,
    output wire [`tagWidth-1:0] tag_rs1,
    //ports with decoder to get the value of rs2 
    input wire [`regWidth-1:0] pos_rs2,
    output wire [`dataWidth-1:0] data_rs2,
    output wire [`tagWidth-1:0] tag_rs2,
    //ports to tag the objective reg
    input wire [`regWidth-1:0] reg_to_rename,
    input wire [`tagWidth-1:0] tag_rename,
    //ports with rob
    input wire if_commit,
    input wire [`regWidth-1:0] pos_commit,
    input wire [`dataWidth-1:0] data_commit,
    input wire [`tagWidth-1:0] tag_commit
);
    reg [`dataWidth-1:0] data[`regSize-1:0];
    reg [`tagWidth-1:0] tag[`regSize-1:0];

    integer i;
    always @(posedge clk) begin
                        //for (i=9; i<10; i=i+1) $display($time," [REG]data: ",data[i]," tag : ",tag[i],"  ",i);
        if (rst || clear) begin
            if (if_commit) begin
                if (tag[pos_commit] == tag_commit) begin
                    tag[pos_commit] <= `emptyTag;
                    data[pos_commit] <= data_commit;
                end
            end
            for (i = 0; i < `regSize; i = i + 1) begin
                if (!clear) data[i] <= 0;
                tag[i] <= `emptyTag;
            end
        end else if (rdy) begin
            if (if_commit) begin
                if (tag[pos_commit] == tag_commit) begin
                    tag[pos_commit] <= `emptyTag;
                    data[pos_commit] <= data_commit;
                end
            end
            //to rename the reg
            if (reg_to_rename != `emptyReg) begin
                tag[reg_to_rename] <= tag_rename;
            end
        end
    end
    assign data_rs1 = data[pos_rs1];
    assign data_rs2 = data[pos_rs2];
    assign tag_rs1 = tag[pos_rs1];
    assign tag_rs2 = tag[pos_rs2];
    // always @(*) begin
    //     //to get the opration value
    //     data_rs1 = `emptyData;
    //     tag_rs1 = `emptyTag;
    //     data_rs2 = `emptyData;
    //     tag_rs2 = `emptyTag;
    //     if (pos_rs1 != `emptyReg) begin
    //                 $display(" want pos: ", pos_rs1," tag: ", tag_rs1," data: ", data_rs1);
    //         if (tag[pos_rs1] == `emptyTag) data_rs1 = data[pos_rs1];
    //         tag_rs1 = tag[pos_rs1];
    //     end
    //     if (pos_rs2 != `emptyReg) begin
    //         if (tag[pos_rs2] == `emptyTag) data_rs2 = data[pos_rs2];
    //         tag_rs2 = tag[pos_rs2];
    //     end
    // end
endmodule