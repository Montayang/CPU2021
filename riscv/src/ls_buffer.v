`timescale 1ns/1ps

`include "defines.v"

module lsb (
    input wire clk,
    input wire rst,
    input wire rdy,
    //ports with decoder
    output reg if_idle,
    input wire if_issue_lsb,
    input wire [`tagWidth-1:0] dest_lsb,
    input wire [`opTypeWidth-1:0] op_type_to_lsb,
    input wire [`tagWidth-1:0] tag_rs1_to_lsb,
    input wire [`dataWidth-1:0] data_rs1_to_lsb,
    input wire [`tagWidth-1:0] tag_rs2_to_lsb,
    input wire [`dataWidth-1:0] data_rs2_to_lsb,
    input wire [`immWidth-1:0] imm_to_lsb,
    input wire [`addrWidth-1:0] pc_to_lsb
    //ports with ex
    
);
    reg busy_entry[`lsbSize-1:0];
    reg [`tagWidth-1:0] dest_entry[`lsbSize-1:0];

endmodule