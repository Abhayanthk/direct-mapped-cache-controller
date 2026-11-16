// Waveform stimulus for the hit-logic modules: one step every 10 ns.
module tb_hit_logic_wave;
    reg clk = 0, rst = 1;
    reg [7:0] addr = 0;
    reg [2:0] stored_tag = 0;
    reg valid = 0, mem_req = 0, mem_we = 0, mem_ready = 0;
    wire [2:0] tag;
    wire [2:0] index;
    wire [1:0] offset;
    wire hit;
    wire [15:0] read_count, write_count;

    addr_split      u_split (.addr(addr), .tag(tag), .index(index), .offset(offset));
    tag_comparator  u_cmp   (.valid(valid), .stored_tag(stored_tag), .addr_tag(tag), .hit(hit));
    traffic_counter u_count (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we),
                             .mem_ready(mem_ready), .read_count(read_count), .write_count(write_count));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/tb_hit_logic_wave.vcd");
        $dumpvars(0, tb_hit_logic_wave);
        #20 rst = 0;
        addr = 21; valid = 0; stored_tag = 0;  #10;   // 000 101 01, invalid line: miss
        valid = 1;                             #10;   // tag 0, index 5, offset 1: hit
        stored_tag = 1;                        #10;   // different tag: miss
        addr = 45;                             #10;   // 001 011 01: tag 1, index 3: hit
        addr = 255; stored_tag = 7;            #10;   // 111 111 11: tag 7, index 7, offset 3: hit
        mem_req = 1; mem_we = 0; mem_ready = 1; #10;  // memory read finishes
        mem_req = 0; mem_ready = 0;            #10;
        mem_req = 1; mem_we = 0; mem_ready = 1; #10;  // second read
        mem_req = 0; mem_ready = 0;            #10;
        mem_req = 1; mem_we = 1; mem_ready = 1; #10;  // memory write finishes
        mem_req = 0; mem_we = 0; mem_ready = 0; #10;
        mem_req = 1; mem_we = 1; mem_ready = 0; #10;  // memory still busy: no count
        mem_req = 0; mem_we = 0;               #10;
        $finish;
    end
endmodule
