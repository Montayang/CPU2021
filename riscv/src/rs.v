`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module rs (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear,
    //ports with decoder
    output wire if_idle,
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
    wire                ready_entry[`rsSize-1:0];

    reg [4:0] busy_entry;//the number of busy entry
    wire [4:0] pos_for_newInst;
    wire [4:0] pos_to_ex;
    assign if_idle = //busy_entry != `rsSize - 1;
                    pos_for_newInst != 0;

    integer i;
    always @(posedge clk) begin
                        for (i=1; i<4; i=i+1) $display($time," [RS]if_busy : ",if_busy_entry[i]," pc : %h",pc_entry[i]," tag : ",dest_entry[i]," Q1 : ",Q1_entry[i],"  ",i);
        if (rst || clear) begin
            for (i=0; i<`rsSize; i=i+1) begin
                if_busy_entry[i] <= `FALSE;
                Q1_entry[i] <= `emptyTag;
                Q2_entry[i] <= `emptyTag;
                op_entry[i] <= `emptyOp;
            end
        end else if (rdy) begin
            //recive from decoder
            if (if_issue_rs && if_idle) begin
                if_busy_entry[pos_for_newInst] <= `TRUE;
                dest_entry[pos_for_newInst] <= dest_rs;
                op_entry[pos_for_newInst] <= op_type_to_rs;
                V1_entry[pos_for_newInst] <= data_rs1_to_rs;
                V2_entry[pos_for_newInst] <= data_rs2_to_rs;
                Q1_entry[pos_for_newInst] <= tag_rs1_to_rs;
                Q2_entry[pos_for_newInst] <= tag_rs2_to_rs;
                imm_entry[pos_for_newInst] <= imm_to_rs;
                pc_entry[pos_for_newInst] <= pc_to_rs;
            end
            //recive from rob
            if (tag_renew != `emptyTag) begin
                for (i=0; i<`rsSize; i=i+1) begin
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
            if (pos_to_ex > 0 && pos_to_ex < `rsSize) begin
                if_busy_entry[pos_to_ex] <= `FALSE;
                op_type_to_ex  <=   op_entry[pos_to_ex];
                data_rs1_to_ex <=   V1_entry[pos_to_ex];
                data_rs2_to_ex <=   V2_entry[pos_to_ex];
                imm_to_ex      <=  imm_entry[pos_to_ex];
                pc_to_ex       <=   pc_entry[pos_to_ex];
                tag_in_rob     <= dest_entry[pos_to_ex];
            end
        end
    end
        
    // always @(*) begin
    //     busy_entry = `rsSize - 1;
    //     for (i=`rsSize; i>0; i=i-1) begin
    //         if(!if_busy_entry[i]) begin
    //             pos_for_newInst = i;
    //             busy_entry = busy_entry - 1;
    //         end
    //     end
    //     for (i=1; i<`rsSize; i=i+1) begin
    //         if (if_busy_entry[i] && Q1_entry[i] == `emptyTag && Q1_entry[i] == `emptyTag) ready_entry[i] =`TRUE;
    //         else ready_entry[i] =`FALSE;
    //     end
    //     for (i=`rsSize; i>0; i=i-1) begin
    //         if (ready_entry[i]) pos_to_ex = i;
    //     end
    // end
    assign pos_for_newInst = ~if_busy_entry[1] ? 1 :
                        ~if_busy_entry[2] ? 2 : 
                            ~if_busy_entry[3] ? 3 :
                                ~if_busy_entry[4] ? 4 :
                                    ~if_busy_entry[5] ? 5 : 
                                        ~if_busy_entry[6] ? 6 :
                                            ~if_busy_entry[7] ? 7 :
                                                ~if_busy_entry[8] ? 8 : 
                                                    ~if_busy_entry[9] ? 9 :
                                                        ~if_busy_entry[10] ? 10 :
                                                            ~if_busy_entry[11] ? 11 :
                                                                ~if_busy_entry[12] ? 12 :
                                                                    ~if_busy_entry[13] ? 13 :
                                                                        ~if_busy_entry[14] ? 14 : 
                                                                            ~if_busy_entry[15] ? 15 : 0;

    genvar j;
    generate
        for(j = 1;j < `rsSize;j=j+1) begin:issueCheck 
            assign ready_entry[j] = (if_busy_entry[j] == `TRUE) && (Q1_entry[j]==`emptyTag) && (Q2_entry[j]==`emptyTag);
        end
    endgenerate

    assign pos_to_ex = ready_entry[1] ? 1 : 
                        ready_entry[2] ? 2 : 
                            ready_entry[3] ? 3 :
                                ready_entry[4] ? 4 :
                                    ready_entry[5] ? 5 :
                                        ready_entry[6] ? 6 :
                                            ready_entry[7] ? 7 : 
                                                ready_entry[8] ? 8 : 
                                                    ready_entry[9] ? 9 :
                                                        ready_entry[10] ? 10 :
                                                            ready_entry[11] ? 11 :
                                                                ready_entry[12] ? 12 :
                                                                    ready_entry[13] ? 13 :
                                                                        ready_entry[14] ? 14 :
                                                                            ready_entry[15] ? 15 : 0;

endmodule