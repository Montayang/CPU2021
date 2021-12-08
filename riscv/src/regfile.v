`include "defines.v"

module regfile(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear,
    //ports with decoder to get the value of rs1
    input wire [`regWidth-1:0] pos_rs1,
    output reg [`dataWidth-1:0] data_rs1,
    output reg [`tagWidth-1:0] tag_rs1,
    //ports with decoder to get the value of rs2 
    input wire [`regWidth-1:0] pos_rs2,
    output reg [`dataWidth-1:0] data_rs2,
    output reg [`tagWidth-1:0] tag_rs2,
    //ports with rob
    input wire if_commit,
    input wire [`regWidth-1:0] pos_commit,
    input wire [`dataWidth-1:0] data_commit,
    input wire [`tagWidth-1:0] tag_commit
);
    reg [`dataWidth-1:0] data[`regSize-1:0];
    reg [`tagWidth-1:0] tag[`regSize-1:0];

    always @(posedge clk) begin
        if (rst || clear) begin
            for (integer i = 0; i < `regSize; i = i + 1) begin
                if (!clear) data[i] = 0;
                tag[i] = `emptyTag;
            end
        end else if (rdy) begin
            if (if_commit) begin
                data[pos_commit] <= data_commit;
                if (tag[pos_commit] == tag_commit) tag[pos_commit] = `emptyTag;
            end
        end
    end

    always @(*) begin
        data_rs1 = `emptyData;
        tag_rs1 = `emptyTag;
        data_rs2 = `emptyData;
        tag_rs2 = `emptyTag;
        if (pos_rs1 != `emptyReg) begin
            data_rs1 = data[pos_rs1];
            tag_rs1 = tag[pos_rs1];
        end
        if (pos_rs2 != `emptyReg) begin
            data_rs2 = data[pos_rs2];
            tag_rs2 = tag[pos_rs2];
        end
    end
endmodule