// Tag comparator: decides HIT or MISS.
//   hit = 1 only when the line is valid AND the stored tag equals the address tag.

module tag_comparator (
    input  wire       valid,        // valid bit of the selected line
    input  wire [4:0] stored_tag,   // tag stored in the selected line
    input  wire [4:0] addr_tag,     // tag of the address the CPU asked for
    output wire       hit
);
    assign hit = valid && (stored_tag == addr_tag);
endmodule
