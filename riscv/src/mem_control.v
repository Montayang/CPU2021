`timescale 1ns/1ps

`include "defines.v"

module mem_control (
    input wire clk,
    input wire rst,
    inout wire rdy,
    
    //ports with pc
    output wire [`instWidth-1:0] instOut
);
    
endmodule