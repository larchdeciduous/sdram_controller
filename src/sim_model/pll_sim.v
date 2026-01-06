module pll(
    input clkin, // 25 MHz, 0 deg
    output clkout0, // 25 MHz, 0 deg
    output reg clkout1, // 100 Mhz, 0 deg
    output reg locked
);

initial begin
    locked = 0;
    #100
    locked = 1;
end
assign clkout0 = clkin;
always @(posedge clkin) begin
   clkout1 <= 1;
   #5 clkout1 <= 0;

   #5 clkout1 <= 1;
   #5 clkout1 <= 0;

   #5 clkout1 <= 1;
   #5 clkout1 <= 0;

   #5 clkout1 <= 1;
   #5 clkout1 <= 0;
   end
endmodule
