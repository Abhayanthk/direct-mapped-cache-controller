// Address splitter: cuts the 8-bit address into TAG (top 5 bits) and INDEX (bottom 3 bits).
//   address 13 = 00001 101  ->  tag = 00001 (1), index = 101 (5)

module addr_split (
    input  wire [7:0] addr,
    output wire [4:0] tag,
    output wire [2:0] index
);
    assign tag   = addr[7:3];
    assign index = addr[2:0];
endmodule
