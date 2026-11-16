// Cache Data RAM: 8 lines, each line holds a 4-word block (16 bytes): 32 words of 32 bits.
// A word is picked by {index, word}: index chooses the line, word chooses the word in the block.
// Read is combinational, write happens on the rising clock edge when we = 1.

module data_ram (
    input  wire        clk,
    input  wire [2:0]  index,   // which line (0 to 7)
    input  wire [1:0]  word,    // which word in the block (0 to 3)
    input  wire        we,      // write enable
    input  wire [31:0] wdata,   // word to store
    output wire [31:0] rdata    // word currently at {index, word}
);
    reg [31:0] words [0:31];

    assign rdata = words[{index, word}];

    always @(posedge clk) begin
        if (we)
            words[{index, word}] <= wdata;
    end

endmodule
