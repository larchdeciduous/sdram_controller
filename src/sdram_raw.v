`default_nettype none
module sdram_raw
#(
    parameter INIT_DELAY = 20_000, //200us, 100mhz is 20_000 cycle
    parameter INIT_DELAY_CNT_WIDTH = $clog2(INIT_DELAY),
    parameter AUTO_REF_DELAY = 750, // 64ms 8192 times, 100mhz is 781.25 cycle
    parameter AUTO_REF_DELAY_CNT_WIDTH = $clog2(AUTO_REF_DELAY),
)
(
input clk,
input rst,
input enable,
input [23:0] addr, //24 bit for 16bit data
input [3:0] dqm_mask,
input write,
input [31:0] write_data,
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

localparam MODE_16X2_CAS3 = 13'b000_0_00_011_0_001;
localparam MODE_16X2_CAS2 = 13'b000_0_00_010_0_001;
localparam C_NOP =              4'b0111,
        C_PRECHARGE =           4'b0010,
        C_AUTO_REFRESH =        4'b0001,
        C_LOAD_MODE =           4'b0000,
        C_ACTIVE =              4'b0011,
        C_READ =                4'b0101,
        C_WRITE =               4'b0100;
localparam INIT_1 =     10'b00_0000_0000,
        INIT_2 =        10'b00_0000_0001,
        INIT_3 =        10'b00_0000_0010,
        AUTO_REFRESH =  10'b00_0000_0100,
        IDLE =          10'b00_0000_1000,
        ACTIVE =        10'b00_0001_0000,
        READ =          10'b00_0010_0000,
        WRITE =         10'b00_0100_0000,
        ERROR =         10'b00_1000_0000;


reg cnt_en;
reg [2:0] cnt;
reg cntref_en;
reg [AUTO_REF_DELAY_CNT_WIDTH-1:0] cntref;
reg cntlong_en;
reg [INIT_DELAY_CNT_WIDTH-1:0] cntlong;
reg [3:0] cnt8ref;

reg if_init_delay;
reg if_refresh;
reg if_8ref;
always @(posedge clk) begin
    if_init_delay <= (cntlong >= INIT_DELAY); // wait 200us 25mhz is 5000 cycles 150mhz is 30_000
    if_refresh <= (cntref >= AUTO_REF_DELAY);
end
always @(posedge clk) begin
    cntlong <= (cntlong_en) ? cntlong + 1 : 1'b0;
    cntref <= (cntref_en) ? cntref + 1 : 1'b0;
end


assign SDRAM_CLK = ~clk;
	
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
assign if_actived = (active_row[addr[23:22]] == addr[21:9]) & (active_flags[addr[23:22]]);
reg r_write;
reg [15:0] r_write_data [1:0];
reg [15:0] r_read_data [1:0];
reg [15:0] r_dqdata [1:0];
reg [23:0] r_addr;
reg [3:0] r_dqm_mask;
//                                                a0=1 , 1-0        a0=0 , 0-1
//                                                [31:16]-[1]       [15:0]-0
//                                                for 32 bit order, it read
//                                                at col n , n+0 then n+1
//                                                but output 32 bit need 
//                                                {n+1, n+0} so it is reversed
//                                          
// original order: assign read_data = r_addr[0] ? { r_read_data[1], r_read_data[0] } : { r_read_data[0], r_read_data[1] };
assign read_data = r_addr[0] ? { r_read_data[0], r_read_data[1] } : { r_read_data[1], r_read_data[0] };

wire [1:0] dqm0, dqm1; // dqm in low active,2 cycle latency, before write need high-z 1 cycle
assign { dqm1, dqm0 } = r_dqm_mask;

wire [1:0] addr_bank;
wire [12:0] addr_row;
wire [8:0] addr_col;
assign addr_bank = r_addr[23:22];
assign addr_row = r_addr[21:9];
assign addr_col = r_addr[8:0];
always @(posedge clk) begin
    if(rst) begin
        SDRAM_CKE <= 0; command <= C_NOP; SDRAM_A <= 0; SDRAM_BA <= 0; SDRAM_CKE <= 0;
        ready <= 0; r_write <= 0; dq <= 0; active_flags <= 0; r_read_data[1] <= 0; r_read_data[0] <= 0; dqm <= 0; status <= INIT_1; dq_en <= 0;
        cnt_en <= 0; cnt <= 0;
        cntlong_en <= 0;cntref_en <= 0;
        active_row[0] <= 0; active_row[1] <= 0; active_row[2] <= 0; active_row[3] <= 0;
    end
    else begin
        cnt <= (cnt_en) ? cnt + 3'b1 : 3'b0;
        case(status)
            INIT_1: begin
                command <= C_NOP;
                SDRAM_BA <= 2'b11; SDRAM_A[10] <= 1'b1; SDRAM_CKE <= 1'b1;
                dqm <= 2'b11;
                cntlong_en <= 1'b1;

                SDRAM_A[9:0] <= 0; SDRAM_A[12:11] <= 0;
                ready <= 0; r_write <= 0; dq <= 0; active_flags <= 0; r_read_data[1] <= 0; r_read_data[0] <= 0; dq_en <= 0;
                cnt_en <= 0; cnt <= 0; cntref_en <= 0;
                active_row[0] <= 0; active_row[1] <= 0; active_row[2] <= 0; active_row[3] <= 0;
                cnt8ref <= 0; if_8ref <= 0;
                if(if_init_delay) begin
                    command <= C_PRECHARGE;
                    status <= INIT_2;
                    cntlong_en <= 0;
                    cnt_en <= 1'b1;
                end
            end
            INIT_2: begin
                // wait 18ns after precharge
                // at least 8 auto refreash commands
                command <= C_NOP;
                status <= INIT_2;
                case (cnt)	
                    3'd0: begin
                        cnt8ref <= 0;
                        if_8ref <= 0;
                    end
                    3'd1: begin
                        command <= C_AUTO_REFRESH;
                    end // wait 60ns 100mhz is 6 cycles
                    3'd6: begin
                        if_8ref <= (cnt8ref == 7) ? 1'b1 : 1'b0;
                        if(if_8ref) begin
                            cnt <= 0;
                            status <= INIT_3;
                        end
                        else begin
                            cnt <= 3'd1;
                            status <= INIT_2;
                            cnt8ref <= cnt8ref + 1;
                        end
                    end
                    default: begin
                    end
                endcase
            end
            INIT_3: begin 
                command <= C_NOP;
                case (cnt)
                    3'd0: begin
                        command <= C_LOAD_MODE;
                        SDRAM_A <= MODE_16X2_CAS2;
                        SDRAM_BA <= 0;
                    end
                    3'd2:begin
                        command <= C_NOP;
                        cnt <= 0;
                        cntref_en <= 1'b1; // auto-refresh cnt start
                        status <= IDLE;
                    end // wait 12ns after set mode reg, 100mhz is 2 cycles
                    default: begin
                    end
                endcase
                if (cnt > 3'd2)
                    status <= ERROR;
            end
            AUTO_REFRESH: begin
                command <= C_NOP;
                case (cnt)
                    3'd0: begin
                        command <= C_PRECHARGE;
                        SDRAM_A[10] <= 1'b1;
                        SDRAM_BA <= 2'b11;
                        active_flags <= 0;
                    end
                    3'd2: begin // wait 18ns 100mhz is 2 cycle
                        command <= C_AUTO_REFRESH;
                    end
                    3'd7: begin
                        status <= IDLE;
                        cnt <= 0;
                    end // wait 60ns 100mhz is 6 cycles
                    default: begin
                    end
                endcase
                if (cnt > 3'd5)
                    status <= ERROR;
            end
            IDLE: begin
                command <= C_NOP;
                dqm <= 2'b11;

                if (if_refresh & cntref_en) begin
                    status <= AUTO_REFRESH;
                    cntref_en <= 0;
                    cnt <= 0;
                    ready <= 1;
                end
                else begin 
                    cntref_en <= 1'b1;
                    ready <= (enable) ? 1'b0 : 1'b1;
                    if (enable) begin
                        cnt <= 0;
                        r_write <= write;          //  a0=1 , 1-0        a0=0 , 0-1
                        r_write_data[0] <= addr[0] ? write_data[31:16] : write_data[15:0];
                        r_write_data[1] <= addr[0] ? write_data[15:0] : write_data[31:16];
                        r_addr <= addr;
                        r_dqm_mask <= dqm_mask;
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
                command <= C_NOP;
                status <= ACTIVE; 
                case (cnt) 
                    3'd0: begin
                        command <= C_PRECHARGE;
                        SDRAM_BA <= addr_bank; 
                        SDRAM_A[10] <= 0;
                    end // wait 18ns, 100mhz is 2 cycle tRP
                    3'd2: begin
                        command <= C_ACTIVE;
                        SDRAM_A <= addr_row;
                        SDRAM_BA <= addr_bank; 
                        active_row[addr_bank] <= addr_row;
                        active_flags[addr_bank] <= 1'b1;
                    end
                    3'd3: begin
                        status <= (r_write) ? WRITE : READ;
                        cnt <= 0;
                    end // wait 18ns, 100mhz is 2 cycle tRCD
                    default: begin
                    end
                endcase
            end
            READ: begin
                command <= C_NOP;
                ready <= 0;
                dqm <= 2'b11;
                case (cnt)
                    3'd0: begin
                        command <= C_READ;
                        SDRAM_A <= { 4'b0, addr_col };
                        SDRAM_BA <= addr_bank;
                        dq_en <= 0;
                        dqm <= dqm0;
                    end
                    3'd1: begin
                        dqm <= dqm1;
                    end
                    // t3 finish read, t4 get data
                    3'd4: begin
                        cnt <= 0;
                        status <= IDLE;
                        r_read_data[0] <= r_dqdata[0];
                        r_read_data[1] <= r_dqdata[1];
                        ready <= 1;
                    end
                    default: begin
                    end
                endcase
                if (cnt >3'd4)
                    status <= ERROR;
            end
            WRITE: begin
                case (cnt)
                    3'd0: begin
                        command <= C_WRITE;
                        SDRAM_A <= { 4'b0, addr_col };
                        SDRAM_BA <= addr_bank;
                        dq <= r_write_data[0];
                        dq_en <= 1'b1;
                        //dqm <= 0;
                        dqm <= dqm0;
                    end
                    3'd1: begin
                        command <= C_NOP;
                        dq <= r_write_data[1];
                        dqm <= dqm1;
                        ready <= 1;
                        status <= IDLE;
                        cnt <= 0;
                    end
                    default: begin
                    end
                endcase
                if(cnt > 3'd1)
                    status <= ERROR;
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

always @(negedge clk) begin
    if(rst) begin
        r_dqdata[0] <= 0;
        r_dqdata[1] <= 0;
    end
    else begin
        r_dqdata[0] <= r_dqdata[1];
        r_dqdata[1] <= SDRAM_DQ;
    end
end
			
					
endmodule
