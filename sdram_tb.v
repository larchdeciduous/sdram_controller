`timescale 1ns/1ns
module sdram_tb (
);

reg clk, clk90;
initial begin
    clk = 0;
    clk90 = 0;
end
always begin
    #10 clk90 = ~clk90;
    #10 clk = ~clk;
end
reg locked, enable, write;
wire [31:0] read_data;
wire [12:0] SDRAM_A;
wire [1:0] SDRAM_BA;
wire [15:0] SDRAM_DQ;
wire ready;
sdram ram(
.clk(clk),
.clk90(clk90),
.rst(~locked),
.enable(enable),
.addr(24'h5555_55),
.write(write),
.write_data(32'h5555_5555),
.read_data(read_data),
.ready(ready),

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
	$dumpfile("sdram_tb.vcd");
    $dumpvars(0, sdram_tb);
    enable = 0;
    locked = 0;
    write = 0;
    #100
    locked = 1'b1;
    #220000;
    enable = 1'b1;
    //#80
    @(negedge ready);
    enable = 0;
//    @(posedge ready);
//    enable = 1'b1;
//    write = 1'b1;
//    @(negedge ready);
    #10000
    $finish;
end
endmodule
