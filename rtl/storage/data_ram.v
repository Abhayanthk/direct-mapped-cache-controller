// Cache Data RAM: 8 lines, each line holds one 32-bit word.
// Read is combinational, write happens on the rising clock edge when we = 1.

module data_ram (
    input  wire        clk,
    input  wire [2:0]  index,   // which line (0 to 7)
    input  wire        we,      // write enable
    input  wire [31:0] wdata,   // word to store
    output wire [31:0] rdata    // word currently in line "index"
);
    reg [31:0] lines [0:7];

    assign rdata = lines[index];

    always @(posedge clk) begin
        if (we)
            lines[index] <= wdata;
    end

endmodule
