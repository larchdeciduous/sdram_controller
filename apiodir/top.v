module top ( // for on board verification
input clk,

output reg [2:0] led,
output reg [7:0] debugline,

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

wire ready;
wire locked;
wire [31:0] read_data;
reg enable, write, rst;
reg [31:0] write_data;
reg [24:0] addr;

pll pll1
(
.clkin(clk), // 25 MHz, 0 deg
.clkout0(clk25m), // 25 MHz, 0 deg
.clkout1(clk0), // 100 MHz, 0 deg
.locked(locked)
);

sdram ram(
.clk(clk0),
.rst(rst),
.enable(enable),
.addr(addr),
.write(write),
.write_data(write_data),
.data_width(2'b10),
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


reg [4:0] cnt32;
reg cnt32_en, cnt32_full;
always@(posedge clk) begin
    cnt32 <= (cnt32_en) ? cnt32 + 1'b1 : 5'd0;
    cnt32_full <= (cnt32 == 5'b11111);
end

localparam ADDR0 = 0,
        ADDR1 = 25'b0_1000_0000_0000_0000_0000_0010,
        ADDR2 = 25'b0_1000_0010_0000_0000_0000_0010,
        DATA0 = 32'b0001_0010_0011_0100_0101_0110_1000_1000,
        DATA1 = 32'b0001_0010_0011_0100_0101_0110_0000_0000,
        DATA2 = 32'b0001_0010_0011_0100_0101_0110_1110_1110;



reg [31:0] r_read_data;
reg [3:0] cnt;
always @(posedge clk) begin
    if(~locked) begin
        cnt <= 0;
        led <= 0;
        rst <= 1'b1;
    end
    else begin
        case(cnt)
            4'd0: begin
                rst <= 1'b1;
                r_read_data <= 0;
                led <= 0;
                enable <= 0;
                write <= 0;
                cnt <= 4'd1;
            end
            4'd1: begin
                cnt <= 4'd2;
                end
            4'd2: begin
                rst <= 0;
                if(ready == 1'b1)
                    cnt <= 4'd3;
            end
            4'd3:begin //write
                enable <= 1'b1;
                write <= 1'b1;
                addr <= 0;
                write_data <= DATA0;
                if(ready == 0)
                    cnt<= 4'd4;
            end
            4'd4: begin //wait
                enable <= 0;
                write <= 0;
                if(ready == 1'b1)
                    cnt <= 4'd5;
            end
            4'd5:begin //write
                enable <= 1'b1;
                write <= 1'b1;
                addr <= ADDR1;
                write_data <= DATA1;
                if(ready == 0)
                    cnt<= 4'd6;
            end
            4'd6: begin //wait
                enable <= 0;
                write <= 0;
                if(ready == 1'b1)
                    cnt<= 4'd7;
            end
            4'd7:begin //write
                enable <= 1'b1;
                write <= 1'b1;
                addr <= ADDR2;
                write_data <= DATA2;
                if(ready == 0)
                    cnt<= 4'd8;
            end
            4'd8: begin //wait
                enable <= 0;
                write <= 0;
                if(ready == 1'b1)
                    cnt <= 4'd9;
            end
            4'd9: begin //read 1
                enable <= 1'b1;
                addr <= 0;
                if(ready == 0)
                    cnt = 4'd10;
            end
            4'd10: begin //read_finish
                if(ready == 1) begin
                    //led[2] <= 1'b1;
                    r_read_data <= read_data;
                end
                enable <= 0;
                cnt32_en <= 1'b1;
                if(cnt32_full) begin
                    led[0] <= (r_read_data == DATA0);
                    cnt <= 4'd11;
                    cnt32_en <= 0;
                end
            end
            4'd11: begin //read 2
                enable <= 1'b1;
                addr <= ADDR1;
                if(ready == 0)
                    cnt = 4'd12;
            end
            4'd12: begin //read_finish
                if(ready == 1) begin
                    //led[2] <= 1'b1;
                    r_read_data <= read_data;
                end
                enable <= 0;
                cnt32_en <= 1'b1;
                if(cnt32_full) begin
                    led[1] <= (r_read_data == DATA1);
                    cnt <= 4'd13;
                    cnt32_en <= 0;
                end
            end
            4'd13: begin //read 3
                enable <= 1'b1;
                addr <= ADDR2;
                if(ready == 0)
                    cnt = 4'd14;
            end
            4'd14: begin //read_finish
                if(ready == 1) begin
                    //led[2] <= 1'b1;
                    r_read_data <= read_data;
                end
                enable <= 0;
                cnt32_en <= 1'b1;
                if(cnt32_full) begin
                    led[2] <= (r_read_data == DATA2);
                    cnt <= 4'd14;
                    cnt32_en <= 0;
                end
            end
                
        endcase
    end
end

reg [3:0] r_dq;
always @(SDRAM_DQ) begin
    r_dq <= SDRAM_DQ[3:0];
end

endmodule
