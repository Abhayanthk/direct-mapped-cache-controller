// Valid RAM: one bit per line. 1 = the line holds real data.
// Reset clears all 8 bits so the cache starts empty.

module valid_ram (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] index,
    input  wire       we,
    input  wire       wdata,
    output wire       rdata
);
    // bits[0] is line 0 ... bits[7] is line 7
    reg [7:0] bits;

    assign rdata = bits[index];

    always @(posedge clk) begin
        if (rst)
            bits <= 8'b0;
        else if (we)
            bits[index] <= wdata;
    end

endmodule
