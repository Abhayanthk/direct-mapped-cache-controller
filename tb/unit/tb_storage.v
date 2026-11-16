module tb_storage;
    reg         clk = 0;
    reg         rst = 1;
    reg  [2:0]  index = 0;
    reg  [1:0]  word = 0;
    reg         we = 0;
    reg  [31:0] data_in = 0;
    reg  [2:0]  tag_in = 0;
    reg         bit_in = 0;
    wire [31:0] data_out;
    wire [2:0]  tag_out;
    wire        valid_out, dirty_out;
    integer     fails = 0;

    data_ram  u_data  (.clk(clk), .index(index), .word(word), .we(we), .wdata(data_in), .rdata(data_out));
    tag_ram   u_tag   (.clk(clk), .index(index), .we(we), .wdata(tag_in),  .rdata(tag_out));
    valid_ram u_valid (.clk(clk), .rst(rst), .index(index), .we(we), .wdata(bit_in), .rdata(valid_out));
    dirty_ram u_dirty (.clk(clk), .rst(rst), .index(index), .we(we), .wdata(bit_in), .rdata(dirty_out));

    always #5 clk = ~clk;

    task check(input [8*60-1:0] name, input [31:0] got, input [31:0] expected);
        begin
            if (got === expected) $display("PASS  %0s", name);
            else begin
                $display("FAIL  %0s: got %h, expected %h", name, got, expected);
                fails = fails + 1;
            end
        end
    endtask

    task write_line(input [2:0] i, input [31:0] d, input [2:0] t, input b);
        begin
            @(negedge clk); index = i; data_in = d; tag_in = t; bit_in = b; we = 1;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        $dumpfile("build/tb_storage.vcd");
        $dumpvars(0, tb_storage);

        @(negedge clk); @(negedge clk); rst = 0;

        index = 3; #1;
        check("valid bit is 0 after reset", valid_out, 0);
        check("dirty bit is 0 after reset", dirty_out, 0);

        write_line(3, 32'hCAFE0003, 3'd7, 1);
        index = 3; #1;
        check("data line 3 holds what we wrote", data_out, 32'hCAFE0003);
        check("tag line 3 holds what we wrote",  tag_out, 3'd7);
        check("valid line 3 is now 1", valid_out, 1);
        check("dirty line 3 is now 1", dirty_out, 1);

        write_line(5, 32'hBEEF0005, 3'd2, 1);
        index = 3; #1;
        check("writing line 5 does not change line 3", data_out, 32'hCAFE0003);

        @(negedge clk); index = 3; data_in = 32'hFFFFFFFF; we = 0;
        @(negedge clk); #1;
        check("we = 0 means no write", data_out, 32'hCAFE0003);

        write_line(3, 32'hCAFE0003, 3'd7, 0);
        index = 3; #1;
        check("dirty bit can be cleared back to 0", dirty_out, 0);

        @(negedge clk); rst = 1; @(negedge clk); rst = 0;
        index = 5; #1;
        check("reset clears valid of line 5", valid_out, 0);

        write_line(7, 32'h12345677, 3'd7, 1);
        index = 7; #1;
        check("last line 7 holds data", data_out, 32'h12345677);
        check("last line 7 holds max tag 7", tag_out, 3'd7);

        write_line(2, 32'hAAAA0002, 3'd4, 1);
        write_line(6, 32'hBBBB0006, 3'd1, 0);
        index = 2; #1;
        check("line 2 keeps its own data", data_out, 32'hAAAA0002);
        check("line 2 keeps its own tag", tag_out, 5'd4);
        index = 6; #1;
        check("line 6 keeps its own data", data_out, 32'hBBBB0006);
        check("line 6 dirty stays 0", dirty_out, 0);

        // a line holds a 4-word block: each word is stored separately
        word = 1; write_line(4, 32'hD0D00001, 3'd5, 0);
        word = 3; write_line(4, 32'hD0D00003, 3'd5, 0);
        index = 4; word = 1; #1;
        check("line 4 word 1 holds its own data", data_out, 32'hD0D00001);
        word = 3; #1;
        check("line 4 word 3 holds its own data", data_out, 32'hD0D00003);
        index = 7; word = 0; #1;
        check("block words do not touch other lines", data_out, 32'h12345677);
        index = 7; word = 3; #1;
        check("last word of the last line is word 31", u_data.words[31], data_out);

        if (fails == 0) $display("ALL STORAGE TESTS PASSED");
        else            $display("%0d STORAGE TEST(S) FAILED", fails);
        $finish;
    end
endmodule
