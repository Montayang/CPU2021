// testbench top module file
// for simulation only
`include "/mnt/f/Programming/CPU2021-main/riscv/src/riscv_top.v"

`timescale 1ns/1ps
module testbench;


reg clk;
reg rst;

riscv_top #(.SIM(1)) top(
    .EXCLK(clk),
    .btnC(rst),
    .Tx(),
    .Rx(),
    .led()
);

initial begin
  $dumpfile("/mnt/f/Programming/CPU2021-main/riscv/test/test1.vcd");
  $dumpvars();
  clk=0;
  rst=1;
  repeat(50) #1 clk=!clk;
  rst=0; 
  forever #1 clk=!clk;

  $finish;
end

endmodule