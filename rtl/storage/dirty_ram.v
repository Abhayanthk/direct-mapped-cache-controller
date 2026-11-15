// Dirty-Bit RAM: one bit per line. 1 = the CPU changed this line and
// main memory still has the old value, so it must be written back on eviction.
// Reset clears all 8 bits.

module dirty_ram (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] index,
    input  wire       we,
    input  wire       wdata,
    output wire       rdata
);
    reg [7:0] bits;

    assign rdata = bits[index];

    always @(posedge clk) begin
        if (rst)
            bits <= 8'b0;
        else if (we)
            bits[index] <= wdata;
    end

endmodule
