module sdram (
input clk,
input clk90,
input rst,
input enable,
input [23:0] addr,
input write,
input [31:0] write_data,
output [31:0] read_data,
output reg ready,

output SDRAM_CLK,
output SDRAM_CKE,
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

localparam MODE_16X2_CAS3 = 13'b000_0_00_011_0_001;
localparam C_NOP = 		4'b0111,
	C_PRECHARGE = 		4'b0010,
	C_AUTO_REFRESH = 	4'b0001,
	C_LOAD_MODE = 		4'b0000,
	C_ACTIVE = 		    4'b0011,
	C_READ = 		    4'b0101,
	C_WRITE = 		    4'b0100;
localparam INIT_1 = 10'b00_0000_0000,
	INIT_2 = 	    10'b00_0000_0001,
	INIT_3 = 	    10'b00_0000_0010,
	AUTO_REFRESH = 	10'b00_0000_0100,
	IDLE = 		    10'b00_0000_1000,
	ACTIVE = 	    10'b00_0001_0000,
	READ = 		    10'b00_0010_0000,
	WRITE = 	    10'b00_0100_0000,
	ERROR = 	    10'b00_1000_0000;


reg cnt_en;
reg [5:0] cnt;
reg cntref_en;
reg [7:0] cntref;
reg cntlong_en;
reg [12:0] cntlong;

reg if_init_delay;
reg if_refresh;
always @(posedge clk) begin
    if_init_delay <= (cntlong == 13'd5009);
    if_refresh <= (cntref >= 8'd175);
end



assign SDRAM_CLK = clk90;
assign SDRAM_CKE = ~rst;
	
reg [9:0] status;
reg [3:0] command;
assign { SDRAM_CS_N, SDRAM_RAS_N, SDRAM_CAS_N, SDRAM_WE_N } = command;
reg [1:0] dqm;
assign { SDRAM_DQMH, SDRAM_DQML } = dqm;
reg [15:0] dq;
reg dq_en;
assign SDRAM_DQ = (dq_en) ? dq : 16'bz;
reg [12:0] active_row [3:0];
reg [3:0] active_flags;
wire if_actived;
assign if_actived = (active_row[SDRAM_BA] == SDRAM_A) & (active_flags[SDRAM_BA]);
reg r_write;
reg [15:0] r_write_data [1:0];
reg [15:0] r_read_data [1:0];
assign read_data = r_addr[0] ? { r_read_data[1], r_read_data[0] } : { r_read_data[0], r_read_data[1] };
reg [23:0] r_addr;

wire [1:0] addr_bank;
wire [12:0] addr_row;
wire [8:0] addr_col;
assign addr_bank = r_addr[23:22];
assign addr_row = r_addr[21:9];
assign addr_col = r_addr[8:0];
always @(posedge clk) begin
	if(rst) begin
        ready <= 0; r_write <= 0; dq <= 0; active_flags <= 0; r_read_data[1] <= 0; r_read_data[0] <= 0; dqm <= 0; command <= C_NOP; SDRAM_A <= 0; SDRAM_BA <= 0; status <= INIT_1; dq_en <= 0;
        cnt_en <= 0; cnt <= 0; cntref_en <= 0; cntref <= 0; cntlong_en <= 0; cntlong <= 0;
    end
	else begin
        cnt <= (cnt_en) ? cnt + 1'b1 : 4'b0 ;
        cntref <= (cntref_en) ? cntref + 1'b1 : 8'b0 ;
        cntlong <= (cntlong_en) ? cntlong + 1'b1 : 13'b0 ;
		case(status)
			INIT_1: begin
                cntlong_en <= 1'b1;
                if(if_init_delay) begin
						command <= C_PRECHARGE; SDRAM_BA <= 2'b11; SDRAM_A[10] <= 1'b1;
						status <= INIT_2;
                        cntlong_en <= 0;
                        cnt_en <= 1'b1;
                end // wait 200us 25mhz is 5000 cycles
                else begin
                    command <= C_NOP; dqm <= 2'b11;
                end
			end
			INIT_2: begin // wait 18ns 25mhz is 1 cycles after precharge
				case (cnt % 5)	
					6'd0: begin
						command <= C_AUTO_REFRESH;
					end 
					6'd1: begin
						command <= C_NOP;
					end // wait 60ns 25mhz is 3 cycles
					default: begin
						command <= command;
					end
				endcase
				if (cnt == 6'd44) begin // at least 8 auto refreash commands
                    cnt <= 0;
					status <= INIT_3;
				end
                else if ( cnt > 6'd44) 
                    status <= ERROR;
			end
			INIT_3: begin 
				case (cnt)
					6'd0: begin
						command <= C_LOAD_MODE;
						SDRAM_A <= MODE_16X2_CAS3;
						SDRAM_BA <= 0;
					end
					6'd1: begin
						command <= C_NOP;
					end
					6'd2:begin
                        cnt <= 0;
                        cntref_en <= 1'b1; // auto-refresh cnt start
						status <= IDLE;
					end // wait 12ns 25mhz is 1 cycles
					default: begin
						command <= C_NOP;
                        status <= ERROR;
					end
				endcase
                if (cnt > 6'd2)
                    status <= ERROR;
			end
			AUTO_REFRESH: begin
				case (cnt)
					6'd0: begin
						command <= C_PRECHARGE;
						SDRAM_A[10] <= 1'b1;
						active_flags <= 0;
                    end
					6'd1: begin // wait 18ns 25mhz is 1 cycle
						command <= C_AUTO_REFRESH;
					end
					6'd2: begin
						command <= C_NOP;
					end
					6'd5: begin
						status <= IDLE;
                        cnt <= 0;
					end // wait 60ns 25mhz is 3 cycles
					default: begin
						command <= C_NOP;
					end
				endcase
                if (cnt > 6'd5)
                    status <= ERROR;
			end


			IDLE: begin
				command <= C_NOP;

                if (if_refresh) begin
					status <= AUTO_REFRESH;
                    cntref <= 0;
                    cnt <= 0;
                end
				else begin 
					ready <= (enable) ? 1'b0 : 1'b1;
					if (enable) begin
                        cnt <= 0;
						r_write <= write;
						r_write_data[0] <= addr[0] ? write_data[31:16] : write_data[15:0];
						r_write_data[1] <= addr[0] ? write_data[15:0] : write_data[31:16];
						r_addr <= addr;
					end

					casez ({ enable, write, if_actived })
						3'b101:
							status <= READ;
						3'b111:
							status <= WRITE;
						3'b1z0:
							status <= ACTIVE;
						default:
							status <= IDLE;
					endcase
				end
			end
			ACTIVE: begin
				case (cnt) 
					6'd0: begin
						command <= C_PRECHARGE;
						SDRAM_BA <= addr_bank; 
						SDRAM_A[10] <= 0;
					end // wait 18ns 25mhz is 1 cycle
					6'd1: begin
						command <= C_ACTIVE;
						SDRAM_A <= addr_row;
						SDRAM_BA <= addr_bank; 
						active_row[addr_bank] <= addr_row;
						active_flags[addr_bank] <= 1'b1;
					
						status <= (r_write) ? WRITE : READ;
                        cnt <= 0;
					end // wait 18ns 25mhz is 1 cycle
					default: begin
						status <= ERROR;
					end
				endcase
			end
			READ: begin
				case (cnt)
					6'd0: begin
						command <= C_READ;
						SDRAM_A <= { 4'b0, addr_col };
						SDRAM_BA <= addr_bank;
						dq_en <= 0;
                        dqm <= 0;
					end
					6'd1: begin
						command <= C_NOP;
					end
					6'd3: begin
                        dqm <= 2'b11;
						r_read_data[0] <= SDRAM_DQ;
					end
					6'd4: begin
						r_read_data[1] <= SDRAM_DQ;
                        cnt <= 0;
						status <= IDLE;
					end
					default: begin
                        command <= C_NOP;
					end
				endcase
                if (cnt >6'd4)
                    status <= ERROR;
			end
			WRITE: begin
				case (cnt)
					6'd0: begin
						command <= C_WRITE;
						SDRAM_A <= { 4'b0, addr_col };
						SDRAM_BA <= addr_bank;
						dq <= write_data[0];
						dq_en <= 1'b1;
                        dqm <= 0;
					end
					6'd1: begin
						command <= C_NOP;
						dq <= write_data[1];
					end
					6'd2: begin
						dq_en <= 0;
                        dqm <= 2'b11;
						status <= IDLE;
                        cnt <= 0;
					end
					default: begin
                        status <= ERROR;
					end
				endcase
			end
            ERROR: begin
                status <= ERROR;
                cnt_en <= 0;
            end
			default:
				status <= ERROR;
		endcase
    end
end
						

					
					
endmodule
