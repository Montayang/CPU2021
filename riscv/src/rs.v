`timescale 1ns/1ps

`include "defines.v"

module rs (
    input wire clk,
    input wire rst,
    input wire rdy,
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
    input wire [`addrWidth-1:0] pc_to_rs
    //ports with ex
    
);
    reg busy_entry[`rsSize-1:0];
    reg [`tagWidth-1:0] dest_entry[`rsSize-1:0];
    
    
    
endmodule