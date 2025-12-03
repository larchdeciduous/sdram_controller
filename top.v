module top (
input clk,
output reg [2:0] led,

output SDRAM_CLK,
output SDRAM_CKE,
output SDRAM_RAS_N,
output SDRAM_CAS_N,
output SDRAM_WE_N,
output SDRAM_CS_N,
output [12:0] SDRAM_A,
output [1:0] SDRAM_BA,
inout [15:0] SDRAM_DQ,
output SDRAM_DQML,
output SDRAM_DQMH
);

wire ready, clk90, locked;
wire [31:0] read_data;
reg enable, write;
reg [31:0] write_data;

sdram ram(
.clk(clk),
.clk90(clk90),
.rst(~locked),
.enable(enable),
.addr(24'b0),
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

pll_phase_90 pll1
(
.clkin(clk), // 25 MHz, 0 deg
.clkout0(clk90), // 25 MHz, 90 deg
.locked(locked)
);


reg [8:0] cnt;
always @(posedge clk) begin
    if(~locked)
        cnt <= 0;
    else if(ready)
        cnt <= cnt + 1'b1;
    case(cnt)
        8'd0: begin
            enable <= 0;
            write <= 0;
        end
        8'd2: begin
            enable <= 1'b1;
            write <= 1'b1;
            write_data <= 32'hffff_ffff;
        end
        8'd4: begin
            enable <= 0;
            write <= 0;
        end
        8'd32: begin
            enable <= 1'b1;
        end
        8'd34: begin
            enable <= 0;
        end
            
    endcase
end

always @(posedge ready) begin
    led <= read_data[2:0];
end
    

endmodule
