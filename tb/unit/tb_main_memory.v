module tb_main_memory;
    reg         clk = 0;
    reg         rst = 1;
    reg         mem_req = 0, mem_we = 0;
    reg  [7:0]  mem_addr = 0;
    reg  [31:0] mem_wdata = 0;
    wire [31:0] mem_rdata;
    wire        mem_ready;
    integer     fails = 0;
    integer     cycles;
    reg  [31:0] result;

    main_memory u_mem (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we),
                       .mem_addr(mem_addr), .mem_wdata(mem_wdata),
                       .mem_rdata(mem_rdata), .mem_ready(mem_ready));

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

    task access(input is_write, input [7:0] addr, input [31:0] wdata);
        begin
            @(negedge clk); mem_req = 1; mem_we = is_write; mem_addr = addr; mem_wdata = wdata;
            cycles = 0;
            @(negedge clk); cycles = cycles + 1;
            while (!mem_ready) begin @(negedge clk); cycles = cycles + 1; end
            result = mem_rdata;
            mem_req = 0; mem_we = 0;
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("build/tb_main_memory.vcd");
        $dumpvars(0, tb_main_memory);

        @(negedge clk); @(negedge clk); rst = 0;

        access(0, 8'd5, 0);
        check("starting value: mem[5] = 0x1005", result, 32'h1005);
        check("memory is slow: answer after 4 cycles", cycles, 4);

        access(1, 8'd5, 32'hABCD1234);
        check("write takes 4 cycles too", cycles, 4);
        access(0, 8'd5, 0);
        check("read back what we wrote", result, 32'hABCD1234);
        access(0, 8'd6, 0);
        check("neighbour mem[6] unchanged", result, 32'h1006);
        check("mem_ready is low after the access", mem_ready, 0);

        // last address: write it and read it back
        access(1, 8'd255, 32'hDEADBEEF);
        access(0, 8'd255, 0);
        check("top address mem[255] write and read back", result, 32'hDEADBEEF);

        // two reads one after the other: each one waits the full 4 cycles
        access(0, 8'd10, 0);
        check("first back-to-back read takes 4 cycles", cycles, 4);
        access(0, 8'd11, 0);
        check("second back-to-back read takes 4 cycles", cycles, 4);
        check("second read returns mem[11] = 0x100B", result, 32'h100B);

        if (fails == 0) $display("ALL MAIN-MEMORY TESTS PASSED");
        else            $display("%0d MAIN-MEMORY TEST(S) FAILED", fails);
        $finish;
    end
endmodule
