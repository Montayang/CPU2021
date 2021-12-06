`timescale 1ns/1ps

`include "defines.v"

module rob (
    input wire clk,
    input wire rst,
    input wire rdy,
    //ports with decoder
    output reg if_idle,
    input wire [`regWidth-1:0] tag_rs1_decoder,
    output reg [`dataWidth-1:0] data_rs1_to_decoder,
    input wire [`regWidth-1:0] tag_rs2_decoder,
    output reg [`dataWidth-1:0] data_rs2_to_decoder,
    output reg [`tagWidth-1:0] tag_to_decoder,
    input wire [`opTypeWidth-1:0] op_decoder,
    input wire [`regWidth-1:0] rd_decoder,
    //ports with pc
    output reg if_jump,
    output reg [`addrWidth-1:0] pc_to_jump,
    //ports with regfile
    output reg if_commit,
    output reg [`regWidth-1:0] pos_commit,
    output reg [`dataWidth-1:0] data_commit,
    output reg [`tagWidth-1:0] tag_commit
    
);
    reg busy_entry[`robSize-1:0];
    reg [`tagWidth-1:0] dest_entry[`robSize-1:0];

endmodule