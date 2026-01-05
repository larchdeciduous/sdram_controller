`timescale 1ns/1ns
module top_tb();

wire SDRAM_CLK, SDRAM_CKE, SDRAM_RAS_N, SDRAM_CAS_N, SDRAM_DQML, SDRAM_DQMH;
wire [12:0] SDRAM_A;
wire [1:0] SDRAM_BA;
wire [15:0] SDRAM_DQ;
wire [2:0] led;
wire [7:0] debugline;

reg clk, clk180;
always begin
    clk = 0;
    #20;
    clk = 1'b1;
    #20;
end

wire SDRAM_WE_N, SDRAM_CS_N;

reg locked;
top top1 (
.clk(clk),
.led(led),
.debugline(debugline),

.SDRAM_CLK(SDRAM_CLK),
.SDRAM_CKE(SDRAM_CKE),
.SDRAM_RAS_N(SDRAM_RAS_N),
.SDRAM_CAS_N(SDRAM_CAS_N),
.SDRAM_WE_N(SDRAM_WE_N),
.SDRAM_CS_N(SDRAM_CS_N),
.SDRAM_A(SDRAM_A),
.SDRAM_BA(SDRAM_BA),
.SDRAM_DQ(SDRAM_DQ),
.SDRAM_DQML(SDRAM_DQML),
.SDRAM_DQMH(SDRAM_DQMH)
);

initial begin

    //$dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
    locked = 0;
    #50
    locked = 1'b1;
    #1000000
    $finish;
end


endmodule
