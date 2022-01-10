`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module pc (
    input wire clk,
    input wire rst,
    input wire rdy,
    //ports with mem_control
    output reg if_output_pc,
    output reg [`addrWidth-1:0] pc_to_getInst,
    input wire if_gotInst,
    input wire [`instWidth-1:0] inst_mem,
    //ports with decoder
    output reg if_to_decoder,
    output reg [`instWidth-1:0] inst_decoder,
    output reg [`addrWidth-1:0] pc_decoder,
    input if_station_idle,
    //ports with rob
    input wire if_jump,
    input wire [`addrWidth-1:0] pc_to_jump
);
    localparam IDLE = 2'b00 , WAIT_FOR_INST = 2'b01 , BUSY_STATION = 2'b10;
    reg [`addrWidth-1:0] PC;
    reg [2:0] status;
    wire [`opWidth-1:0] op;
    assign op = inst_mem[`opRange];

    always @(posedge clk) begin
        if (rst) begin
            PC <= `emptyAddr;
            status <= IDLE;
            if_output_pc <= `FALSE;
            pc_to_getInst <= `emptyAddr;
            inst_decoder <= `emptyInst;
            pc_decoder <= `emptyAddr;
            if_to_decoder <= `FALSE;
        end else if (rdy) begin
            if_to_decoder <= `FALSE;
            if (if_jump) begin
                pc_to_getInst <= pc_to_jump;
                PC <= pc_to_jump;
                status <= IDLE;
            end else begin
                if (status == IDLE) begin
                    pc_decoder <= PC;
                    if_output_pc <= `TRUE;
                    status <= WAIT_FOR_INST;
                end else if (status == WAIT_FOR_INST) begin
                    if (if_gotInst) begin
                        if (if_station_idle) begin
                            pc_to_getInst <= PC + 4;
                            PC <= PC + 4;
                            if_to_decoder <= `TRUE;
                            inst_decoder <= inst_mem;
                            if_output_pc <= `FALSE;
                            status <= IDLE;
                        end else status <= BUSY_STATION;
                    end
                end else if (status == BUSY_STATION) begin
                    if (if_station_idle) begin
                        pc_to_getInst <= PC + 4;
                        PC <= PC + 4;
                        if_to_decoder <= `TRUE;
                        inst_decoder <= inst_mem;
                        if_output_pc <= `FALSE;
                        status <= IDLE;
                    end
                end
            end 
        end
    end
endmodule