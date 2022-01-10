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

    //icache
    reg [`addrWidth-1:0] index[`icacheSize-1:0];
    reg [`instWidth-1:0]   tag[`icacheSize-1:0];
    reg [7:0] position;
    reg hit;

    //write buffer
    reg [`addrWidth-1:0] buffer_addr[`bufferSize-1:0];
    reg [`dataWidth-1:0] buffer_data[`bufferSize-1:0];
    reg [4:0]             write_size[`bufferSize-1:0];
    reg [4:0] head, tail;
    reg wb_if_empty;
    wire wb_if_idle;
    wire disable_to_write;
    reg [1:0] wait_uart;
    assign wb_if_idle = wb_if_empty || ((head != tail) && !((tail+1 == head) || (tail == `bufferSize-1 && head == 1)));
    assign disable_to_write = (buffer_addr[head][17:16] == 2'b11) && (if_uart_full || wait_uart != 0);

    integer i;
    always @(*) begin
        hit = `FALSE;
        for (i=0; i<`icacheSize; i=i+1) 
            if (if_get_pc && index[i]==pc_get && pc_get != `emptyAddr) hit = `TRUE;
    end

    always @(posedge clk) begin
        if (rst) begin
            data_to_ram <= `emptyData;
            addr_to_ram <= `emptyAddr;
            if_rw <= `FALSE;
            status <= IDLE;
            stages <= 1;
            wait_uart <= 0;
            head <= 1;
            tail <= 1;
            wb_if_empty <= `TRUE;
            rob_flag <= `FALSE;
            for (i=0; i<`icacheSize; i=i+1) begin
                index[i] <= `emptyAddr;
                tag[i] <= `emptyData;
                position <= 0;
            end
            if_out_inst_to_pc <= `FALSE;
            if_out_io_to_rob <= `FALSE;
            if_out_to_lsb <= `FALSE;
            pc_flag <= `FALSE;
            lsb_flag <= `FALSE;
            io_flag <= `FALSE;
        end else if (rdy && (!clear || status == ROB)) begin
            if (clear) begin
                if_out_inst_to_pc <= `FALSE;
                if_out_io_to_rob <= `FALSE;
                if_out_to_lsb <= `FALSE;
                pc_flag <= `FALSE;
                lsb_flag <= `FALSE;
                io_flag <= `FALSE;
            end
            wait_uart <= wait_uart - ((wait_uart == 0) ? 0 : 1);
            if_out_inst_to_pc <= `FALSE;
            if_out_io_to_rob <= `FALSE;
            if_out_to_lsb <= `FALSE;
            if_stored <= `FALSE;
            if_rw <= 0;
            if (if_get_pc) begin
                if (!pc_flag && hit) begin
                    for (i=0; i<`icacheSize; i=i+1) 
                        if (if_get_pc && index[i]==pc_get) begin
                            if_out_inst_to_pc <= `TRUE;
                            inst_out_to_pc <= tag[i];
                        end
                end
                else pc_flag <= `TRUE;
            end
            if (if_get_lsb_to_load) lsb_flag <= `TRUE;
            if (if_get_rob_to_store || rob_flag) begin
                if (wb_if_idle) begin
                    wb_if_empty <= `FALSE;
                    buffer_addr[tail] <= get_store_addr;
                    buffer_data[tail] <= get_store_data;
                    write_size[tail] <= get_store_size;
                    if_stored <= `TRUE;
                    tail <= tail == `bufferSize-1 ? 1 : tail+1;
                    rob_flag <= `FALSE;
                end else rob_flag <= `TRUE;
            end
            if (if_get_io_to_load) io_flag <= `TRUE;
            addr_to_ram <= addr_to_ram + 1;
            stages <= stages + 1;
            case(status)
                IDLE : begin
                    stages <= 1;
                    if (io_flag) begin
                        status <= IO_READ;
                        addr_to_ram <= `IO_ADDR;
                    end else if (!wb_if_empty) begin
                        status <= ROB;
                        addr_to_ram <= `emptyAddr;
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
                        stages <= 1;
                        if(!wb_if_empty) begin 
                            status <= ROB;
                            addr_to_ram <= `emptyAddr;
                        end else if(lsb_flag == `TRUE) begin 
                            status <= LSB;
                            addr_to_ram <= get_load_addr; 
                        end else begin status <= IDLE; end
                        index[position] <= pc_get;
                        tag[position] <= inst_out_to_pc;
                        position <= position == `icacheSize-1 ? 0 : position + 1;
                    end
                end
                LSB : begin
                    case (get_load_size)
                        1 : begin
                            if (stages == 2) begin 
                                if (if_load_signed) data_out_to_lsb <= $signed(get_data_ram);
                                else data_out_to_lsb <= get_data_ram;
                                if_out_to_lsb <= `TRUE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                                if(!wb_if_empty) begin 
                                    status <= ROB;
                                    addr_to_ram <= `emptyAddr;
                                end else if(pc_flag == `TRUE) begin 
                                    status <= PC;
                                    addr_to_ram <= pc_get; 
                                end else begin status <= IDLE; end
                            end
                        end
                        2 : begin
                            if (stages == 2) data_out_to_lsb[7:0] <= get_data_ram;
                            if (stages == 3) begin
                                if (if_load_signed) data_out_to_lsb <= $signed({get_data_ram, data_out_to_lsb[7:0]});
                                else data_out_to_lsb <= {get_data_ram, data_out_to_lsb[7:0]};
                                if_out_to_lsb <= `TRUE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                                if(!wb_if_empty) begin 
                                    status <= ROB;
                                    addr_to_ram <= `emptyAddr;
                                end else if(pc_flag == `TRUE) begin 
                                    status <= PC;
                                    addr_to_ram <= pc_get; 
                                end else begin status <= IDLE; end
                            end
                        end
                        4 : begin
                            if (stages == 2) data_out_to_lsb[7:0] <= get_data_ram;
                            if (stages == 3) data_out_to_lsb[15:8] <= get_data_ram;
                            if (stages == 4) data_out_to_lsb[23:16] <= get_data_ram;
                            if (stages == 5) begin
                                data_out_to_lsb[31:24] <= get_data_ram;
                                if_out_to_lsb <= `TRUE;
                                stages <= 1;
                                lsb_flag <= `FALSE;
                                if(!wb_if_empty) begin 
                                    status <= ROB;
                                    addr_to_ram <= `emptyAddr;
                                end else if(pc_flag == `TRUE) begin 
                                    status <= PC;
                                    addr_to_ram <= pc_get; 
                                end else begin status <= IDLE; end
                            end
                        end
                    endcase
                end
                ROB : begin
                    if (disable_to_write) begin
                        stages <= 1;
                        data_to_ram <= `emptyData;
                        addr_to_ram <= `emptyAddr;
                    end else begin
                        if_rw <= 1;
                        if (stages == 0) data_to_ram <= `emptyData;
                        if (stages == 1) begin
                            addr_to_ram <= buffer_addr[head];
                            data_to_ram <= buffer_data[head][7:0];
                        end
                        if (stages == 2) data_to_ram <= buffer_data[head][15:8];
                        if (stages == 3) data_to_ram <= buffer_data[head][23:16];
                        if (stages == 4) data_to_ram <= buffer_data[head][31:24];
                        if (stages == write_size[head]) begin
                            head <= (head == `bufferSize-1) ? 1:head+1;
                            if (((head+1 == tail) || (head == `bufferSize-1 && tail == 1)) && !if_get_rob_to_store) begin
                                wb_if_empty <= `TRUE;
                                status <= IDLE;
                            end else begin 
                                status <= ROB;
                                if (buffer_addr[head] == `IO_ADDR) wait_uart <= 2;
                            end
                            stages <= 1;
                        end
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
        end else if (rdy && clear) begin
            if_out_inst_to_pc <= `FALSE;
            if_out_io_to_rob <= `FALSE;
            if_out_to_lsb <= `FALSE; 
            pc_flag <= `FALSE;
            lsb_flag <= `FALSE;
            io_flag <= `FALSE;
            status <= IDLE;
            stages <= 1;
            if_rw <= 0;
            addr_to_ram <= `emptyAddr;
            if (!wb_if_empty) stages <= ROB;
        end
    end
    
endmodule