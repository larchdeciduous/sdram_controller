`default_nettype none
module sdram(
input clk,
input rst,
input enable,
input [24:0] addr,
input write,
input [31:0] write_data,
input [1:0] data_width, // 00byte 01halfword 10word
output [31:0] read_data,
output reg ready,

output SDRAM_CLK,
output reg SDRAM_CKE,
output SDRAM_RAS_N,
output SDRAM_CAS_N,
output SDRAM_WE_N,
output SDRAM_CS_N,
output reg [12:0] SDRAM_A,
output reg [1:0] SDRAM_BA,
inout [15:0] SDRAM_DQ,
output SDRAM_DQML,
output SDRAM_DQMH
);

reg odd_access;
reg [3:0] dqm_mask;
assign odd_access = addr[0];

// 00byte 01halfword 10 word / odd access: 00byte 01halfword
always @(*) begin
    case({ odd_access, data_width })
        3'b0_00: dqm_mask = 4'b1110;
        3'b0_01: dqm_mask = 4'b1100;
        3'b0_10: dqm_mask = 4'b0000;
        3'b1_00: dqm_mask = 4'b1101;
        3'b1_01: dqm_mask = 4'b1001;
        default: dqm_mask = 4'b1111;
    endcase
end
sdram_raw sdram_raw1 (
.clk(clk),
.rst(rst),
.enable(enable),
.addr(addr[24:1]), //24 bit for 16bit data
.dqm_mask(dqm_mask),
.write(write),
.write_data(write_data),
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
endmodule
