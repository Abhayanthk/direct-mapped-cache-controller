// Cache Tag RAM: 8 lines, each line keeps the 3-bit tag of the address
// that is currently stored in it.

module tag_ram (
    input  wire       clk,
    input  wire [2:0] index,
    input  wire       we,
    input  wire [2:0] wdata,
    output wire [2:0] rdata
);
    reg [2:0] lines [0:7];

    assign rdata = lines[index];

    always @(posedge clk) begin
        if (we)
            lines[index] <= wdata;
    end

endmodule
