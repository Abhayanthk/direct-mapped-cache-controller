module tb_cache_top;
    reg         clk = 0;
    reg         rst = 1;
    reg         write_through = 0;
    reg         cpu_req = 0, cpu_we = 0;
    reg  [7:0]  cpu_addr = 0;
    reg  [31:0] cpu_wdata = 0;
    wire [31:0] cpu_rdata;
    wire        cpu_ready;
    wire [15:0] mem_read_count, mem_write_count;

    reg  [31:0] got;
    reg  [15:0] reads_before;
    integer     fails = 0;
    integer     mode;

    cache_top dut (
        .clk(clk), .rst(rst), .write_through(write_through),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata), .cpu_ready(cpu_ready),
        .mem_read_count(mem_read_count), .mem_write_count(mem_write_count)
    );

    always #5 clk = ~clk;

    // ---------- helper tasks (given) ----------
    task cpu_access(input is_write, input [7:0] addr, input [31:0] wdata);
        begin
            @(negedge clk);
            cpu_req = 1; cpu_we = is_write; cpu_addr = addr; cpu_wdata = wdata;
            @(negedge clk);
            while (!cpu_ready) @(negedge clk);
            got = cpu_rdata;
            @(negedge clk);
            cpu_req = 0; cpu_we = 0;
        end
    endtask

    task cpu_read(input [7:0] addr);
        begin
            cpu_access(0, addr, 0);
            $display("%0t  CPU READ   addr=%0d -> %h", $time, addr, got);
        end
    endtask

    task cpu_write(input [7:0] addr, input [31:0] data);
        begin
            cpu_access(1, addr, data);
            $display("%0t  CPU WRITE  addr=%0d <- %h", $time, addr, data);
        end
    endtask

    task check(input [8*60-1:0] name, input [31:0] actual, input [31:0] expected);
        begin
            if (actual === expected) $display("        PASS  %0s", name);
            else begin
                $display("        FAIL  %0s: got %h, expected %h", name, actual, expected);
                fails = fails + 1;
            end
        end
    endtask

    task reset_system;
        begin
            rst = 1;
            @(negedge clk); @(negedge clk);
            rst = 0;
        end
    endtask

    // ---------- the tests ----------
    initial begin
        $dumpfile("build/cache_top.vcd");
        $dumpvars(0, tb_cache_top);

        for (mode = 0; mode < 2; mode = mode + 1) begin
            write_through = mode;
            reset_system;
            $display("\n===== MODE: %0s =====", mode ? "WRITE-THROUGH" : "WRITE-BACK");

            $display("T1 read miss");
            cpu_read(0);
            check("T1 data = starting value", got, 32'h1000);
            check("T1 one memory read", mem_read_count, 1);

            $display("T2 read hit");
            cpu_read(0);
            check("T2 same data", got, 32'h1000);
            check("T2 no new memory read", mem_read_count, 1);

            // addresses 0, 8 and 16 all map to line 0 (same index, different tag)

            $display("T3 write hit");
            cpu_write(0, 32'hAAAA);
            check("T3 cache line updated", dut.u_data.lines[0], 32'hAAAA);
            if (!write_through) begin
                check("T3 dirty bit = 1", dut.u_dirty.bits[0], 1);
                check("T3 memory NOT updated yet", dut.u_mem.mem[0], 32'h1000);
            end else begin
                check("T3 dirty bit stays 0", dut.u_dirty.bits[0], 0);
                check("T3 memory updated immediately", dut.u_mem.mem[0], 32'hAAAA);
            end

            $display("T4 eviction of line 0");
            cpu_read(8);
            check("T4 data = starting value of addr 8", got, 32'h1008);
            check("T4 old value is in memory", dut.u_mem.mem[0], 32'hAAAA);

            $display("T5 read back the evicted value");
            cpu_read(0);
            check("T5 written value survived", got, 32'hAAAA);

            $display("T6 write miss");
            cpu_write(16, 32'hBBBB);
            cpu_read(16);
            check("T6 read back written value", got, 32'hBBBB);

            // print traffic before T7, because reset clears the counters
            $display("Memory traffic in this mode: reads=%0d writes=%0d", mem_read_count, mem_write_count);

            $display("T7 reset empties the cache");
            reset_system;
            cpu_read(16);
            check("T7 read after reset is a miss", mem_read_count, 1);
            check("T7 memory back to starting value", got, 32'h1010);
        end

        if (fails == 0) $display("\nALL SYSTEM TESTS PASSED");
        else            $display("\n%0d SYSTEM TEST(S) FAILED", fails);
        $finish;
    end
endmodule
