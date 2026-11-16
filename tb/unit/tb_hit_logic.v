module tb_hit_logic;
    reg         clk = 0;
    reg         rst = 1;
    reg  [7:0]  addr = 0;
    reg         valid = 0;
    reg  [2:0]  stored_tag = 0;
    reg         mem_req = 0, mem_we = 0, mem_ready = 0;
    wire [2:0]  tag;
    wire [2:0]  index;
    wire [1:0]  offset;
    wire        hit;
    wire [15:0] read_count, write_count;
    integer     fails = 0;

    addr_split      u_split (.addr(addr), .tag(tag), .index(index), .offset(offset));
    tag_comparator  u_cmp   (.valid(valid), .stored_tag(stored_tag), .addr_tag(tag), .hit(hit));
    traffic_counter u_count (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we), .mem_ready(mem_ready),
                             .read_count(read_count), .write_count(write_count));

    always #5 clk = ~clk;

    task check(input [8*60-1:0] name, input [31:0] got, input [31:0] expected);
        begin
            if (got === expected) $display("PASS  %0s", name);
            else begin
                $display("FAIL  %0s: got %0d, expected %0d", name, got, expected);
                fails = fails + 1;
            end
        end
    endtask

    task memory_finishes(input is_write);
        begin
            @(negedge clk); mem_req = 1; mem_we = is_write; mem_ready = 1;
            @(negedge clk); mem_req = 0; mem_we = 0; mem_ready = 0;
        end
    endtask

    task addr_tag_bit_check(input [2:0] t);
        begin
            addr = {t, 5'b0}; #1;
            check("tags differing in one bit -> miss", hit, 0);
        end
    endtask

    initial begin
        $dumpfile("build/tb_hit_logic.vcd");
        $dumpvars(0, tb_hit_logic);

        // address = tag (3) | index (3) | offset (2)
        addr = 8'd21; #1;                       // 000 101 01
        check("addr 21 -> tag 0",    tag, 0);
        check("addr 21 -> index 5",  index, 5);
        check("addr 21 -> offset 1", offset, 1);
        addr = 8'd255; #1;                      // 111 111 11
        check("addr 255 -> tag 7",    tag, 7);
        check("addr 255 -> index 7",  index, 7);
        check("addr 255 -> offset 3", offset, 3);
        addr = 8'd22; #1;
        check("addr 22 -> same block as 21 (index 5)", index, 5);
        check("addr 22 -> next word (offset 2)",       offset, 2);

        addr = 8'd45; stored_tag = 1; valid = 1; #1;   // 45 = 001 011 01 -> tag 1
        check("valid + same tag = hit", hit, 1);
        valid = 0; #1;
        check("not valid = miss", hit, 0);
        valid = 1; stored_tag = 2; #1;
        check("different tag = miss", hit, 0);

        @(negedge clk); @(negedge clk); rst = 0;
        check("counters start at 0", read_count + write_count, 0);
        memory_finishes(0);
        memory_finishes(0);
        memory_finishes(1);
        check("2 memory reads counted",  read_count, 2);
        check("1 memory write counted", write_count, 1);
        @(negedge clk); mem_req = 1; mem_we = 1; mem_ready = 0;
        @(negedge clk); mem_req = 0; mem_we = 0;
        check("no count while memory still busy", write_count, 1);

        // conflict pair: addresses 0 and 32 fight for the same cache line
        addr = 8'd0; #1;
        check("addr 0 -> index 0", index, 0);
        check("addr 0 -> tag 0",   tag, 0);
        addr = 8'd32; #1;
        check("addr 32 -> same index 0 as addr 0", index, 0);
        check("addr 32 -> different tag 1",        tag, 1);

        // every tag bit counts: tags differing in one bit must miss
        valid = 1; stored_tag = 3'b000;
        addr_tag_bit_check(3'b001);
        addr_tag_bit_check(3'b010);
        addr_tag_bit_check(3'b100);

        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        check("reset clears both counters", read_count + write_count, 0);

        if (fails == 0) $display("ALL HIT-LOGIC TESTS PASSED");
        else            $display("%0d HIT-LOGIC TEST(S) FAILED", fails);
        $finish;
    end
endmodule
