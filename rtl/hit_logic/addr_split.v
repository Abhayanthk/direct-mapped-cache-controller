// Address splitter: cuts the 8-bit word address into TAG, INDEX and OFFSET.
//   tag    = addr[7:5] (3 bits): which block of memory is in the line
//   index  = addr[4:2] (3 bits): which of the 8 cache lines
//   offset = addr[1:0] (2 bits): which of the 4 words in the block
//   address 21 = 000 101 01  ->  tag 0, index 5, offset 1

module addr_split (
    input  wire [7:0] addr,
    output wire [2:0] tag,
    output wire [2:0] index,
    output wire [1:0] offset
);
    assign tag    = addr[7:5];
    assign index  = addr[4:2];
    assign offset = addr[1:0];
endmodule
