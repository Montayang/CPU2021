`timescale 1ns/1ps

`include "/mnt/f/Programming/CPU2021-main/riscv/src/defines.v"

module mem_control (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clear,
    input wire if_uart_full,
    //ports with pc
    input wire if_get_pc,
    input wire [`addrWidth-1:0] pc_get,
    output reg if_out_inst_to_pc,
    output reg [`instWidth-1:0] inst_out_to_pc,
    //ports with rob
    input wire if_get_rob_to_store,
    input wire [5:0] get_store_size,
    input wire [`addrWidth-1:0] get_store_addr,
    input wire [`dataWidth-1:0] get_store_data,
    output reg if_stored,//to store
    input wire if_get_io_to_load,
    output reg if_out_io_to_rob,
    output reg [`dataWidth-1:0] data_io,//out the data got with io
    //ports with lsb
    input wire if_get_lsb_to_load,
    input wire [5:0] get_load_size,
    input wire if_load_signed,
    input wire [`addrWidth-1:0] get_load_addr,
    output reg if_out_to_lsb,
    output reg [`addrWidth-1:0] data_out_to_lsb,
    //ports with ram
    output reg if_rw, //false : read, true : write
    output reg [`addrWidth-1:0] addr_to_ram,
    output reg [7:0] data_to_ram,
    input [7:0] get_data_ram
);
    localparam IDLE = 3'b000, PC = 3'b001, LSB = 3'b010, ROB = 3'b011, IO_READ = 3'b100;
    reg [2:0] status;
    reg [5:0] stages;
    reg pc_flag;
    reg lsb_flag;
    reg rob_flag;
    reg io_flag;

    always @(posedge clk) begin
        if (rst || clear) begin
            status <= IDLE;
            stages <= 1;
            if_out_inst_to_pc <= `FALSE;
            if_out_io_to_rob <= `FALSE;
            if_out_to_lsb <= `FALSE;
            if_rw <= `FALSE;
            addr_to_ram <= `emptyAddr;
            data_to_ram <= `emptyData;
            pc_flag <= `FALSE;
            lsb_flag <= `FALSE;
            rob_flag <= `FALSE;
            io_flag <= `FALSE;
        end else if (rdy) begin
            if_out_inst_to_pc <= `FALSE;
            if_out_io_to_rob <= `FALSE;
            if_out_to_lsb <= `FALSE;
            if_stored <= `FALSE;
            if_rw <= 0;
            if (if_get_pc) pc_flag <= `TRUE;
            if (if_get_lsb_to_load) lsb_flag <= `TRUE;
            if (if_get_rob_to_store) rob_flag <= `TRUE;
            if (if_get_io_to_load) io_flag <= `TRUE;
            addr_to_ram <= addr_to_ram + 1;
            stages <= stages + 1;
            case(status)
                IDLE : begin
                    stages <= 1;
                    if (io_flag) begin
                        status <= IO_READ;
                        addr_to_ram <= `IO_ADDR;
                    end else if (rob_flag) begin
                        status <= ROB;
                        if_rw <= 1;
                        addr_to_ram <= get_store_addr;
                        data_to_ram <= get_store_data;
                    end else if (lsb_flag) begin
                        status <= LSB;
                        addr_to_ram <= get_load_addr;
                    end else if (pc_flag) begin
                        status <= PC;
                        addr_to_ram <= pc_get;
                    end
                end
                PC : begin
                    if (stages == 2) inst_out_to_pc[7:0] <= get_data_ram;
                    if (stages == 3) inst_out_to_pc[15:8] <= get_data_ram;
                    if (stages == 4) inst_out_to_pc[23:16] <= get_data_ram;
                    if (stages == 5) begin
                        inst_out_to_pc[31:24] <= get_data_ram;
                        if_out_inst_to_pc <= `TRUE;
                        pc_flag <= `FALSE;
                    end
                    if (stages == 6) begin
                        status <= IDLE;
                    end
                end
                LSB : begin
                    case (get_load_size)
                        1 : begin
                            if (stages == 2) begin 
                                if (if_load_signed) data_out_to_lsb <= $signed(get_data_ram);
                                else data_out_to_lsb <= get_data_ram;
                                if_out_to_lsb <= `TRUE;
                                status <= IDLE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                            end
                        end
                        2 : begin
                            if (stages == 2) data_out_to_lsb[7:0] <= get_data_ram;
                            if (stages == 3) begin
                                if (if_load_signed) data_out_to_lsb <= $signed({get_data_ram, data_out_to_lsb[7:0]});
                                else data_out_to_lsb <= {get_data_ram, data_out_to_lsb[7:0]};
                                if_out_to_lsb <= `TRUE;
                                status <= IDLE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                            end
                        end
                        4 : begin
                            if (stages == 2) data_out_to_lsb[7:0] <= get_data_ram;
                            if (stages == 3) data_out_to_lsb[15:8] <= get_data_ram;
                            if (stages == 4) data_out_to_lsb[23:16] <= get_data_ram;
                            if (stages == 5) begin
                                data_out_to_lsb[31:24] <= get_data_ram;
                                if_out_to_lsb <= `TRUE;
                                status <= IDLE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                            end
                        end
                    endcase
                end
                ROB : begin
                    if (stages > get_store_size) begin
                        status <= IDLE;
                        stages <= 1;
                        rob_flag <= `FALSE;
                        if_stored <= `TRUE;
                    end else begin
                        if_rw <= 1;
                        data_to_ram <= get_store_data;
                    end
                end
                IO_READ : begin
                    if (stages == 1) addr_to_ram <= `emptyAddr;
                    else if (stages == 2) begin
                        data_io <= get_data_ram;
                        if_out_io_to_rob <= `TRUE;
                        status <= IDLE;
                        stages <= 1;
                        io_flag <= `FALSE;
                    end
                end
            endcase
        end
    end
    
endmodule 