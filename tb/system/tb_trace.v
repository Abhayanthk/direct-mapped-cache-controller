// Trace test: runs each memory-access trace in traces/ through the cache and reports
// hits, misses, hit rate, miss rate and AMAT (average memory access time).
//
// Checks, for every trace:
//   1. each access is a hit or a miss exactly as a reference direct-mapped model predicts
//   2. the hardware hit/miss counters equal the reference counts
//   3. measured AMAT (total cycles / accesses) equals HIT_TIME + miss rate x MISS_PENALTY
//
// Timing (cycles from the request to cpu_ready, read accesses):
//   hit  = 1 cycle   (COMPARE)
//   miss = 22 cycles (COMPARE, ALLOCATE moving 4 words at 5 cycles each, COMPARE)
//   so HIT_TIME = 1 and MISS_PENALTY = 22 - 1 = 21

module tb_trace;
    localparam HIT_TIME     = 1;
    localparam MISS_PENALTY = 21;
    localparam END_MARKER   = 12'hFFF;

    reg         clk = 0, rst = 1, cpu_req = 0, cpu_we = 0;
    reg  [7:0]  cpu_addr = 0;
    wire [31:0] cpu_rdata;
    wire        cpu_ready;
    wire [15:0] mem_read_count, mem_write_count, hit_count, miss_count;

    reg  [11:0] trace [0:255];
    reg  [2:0]  ref_tag   [0:7];
    reg         ref_valid [0:7];
    integer     i, n, cycles, total_cycles, ref_hits, ref_misses, errors;
    reg         ref_hit;
    real        hit_rate, miss_rate, amat_measured, amat_formula;

    cache_top dut (
        .clk(clk), .rst(rst), .write_through(1'b0),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(32'd0),
        .cpu_rdata(cpu_rdata), .cpu_ready(cpu_ready),
        .mem_read_count(mem_read_count), .mem_write_count(mem_write_count),
        .hit_count(hit_count), .miss_count(miss_count)
    );

    always #5 clk = ~clk;

    task read_access(input [7:0] addr);
        begin
            @(negedge clk);
            cpu_req = 1; cpu_we = 0; cpu_addr = addr;
            @(negedge clk);
            cycles = 1;
            while (!cpu_ready) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            @(negedge clk);
            cpu_req = 0;
            total_cycles = total_cycles + cycles;
        end
    endtask

    // reference model: a direct-mapped cache with 8 lines of 4-word blocks,
    // tag = addr[7:5], index = addr[4:2], offset = addr[1:0]
    task reference_lookup(input [7:0] addr);
        begin
            ref_hit = ref_valid[addr[4:2]] && ref_tag[addr[4:2]] == addr[7:5];
            if (ref_hit) ref_hits = ref_hits + 1;
            else         ref_misses = ref_misses + 1;
            ref_valid[addr[4:2]] = 1;
            ref_tag[addr[4:2]]   = addr[7:5];
        end
    endtask

    // reads one hex word per line, skips "//" comment lines, stops at the end marker
    task load_trace(input [8*32-1:0] file);
        integer fd, k, got;
        reg [8*80-1:0] line;
        begin
            fd = $fopen(file, "r");
            if (fd == 0) begin
                $display("FAIL: cannot open %0s", file);
                $finish;
            end
            k = 0;
            trace[0] = END_MARKER;
            while (!$feof(fd) && k < 255) begin
                line = 0;
                got = $fgets(line, fd);
                if (got > 0 && $sscanf(line, "%h", trace[k]) == 1 && line[8*got-1 -: 8] != "/") begin
                    k = k + 1;
                    trace[k] = END_MARKER;
                end
            end
            $fclose(fd);
        end
    endtask

    task check(input cond, input [8*60-1:0] what);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL: %0s", what);
            end
        end
    endtask

    task run_trace(input [8*32-1:0] file, input [8*12-1:0] name);
        begin
            for (i = 0; i < 8; i = i + 1) begin ref_valid[i] = 0; ref_tag[i] = 0; end
            load_trace(file);
            rst = 1; @(negedge clk); @(negedge clk); rst = 0;
            total_cycles = 0; ref_hits = 0; ref_misses = 0;

            n = 0;
            while (trace[n] != END_MARKER) begin
                reference_lookup(trace[n][7:0]);
                read_access(trace[n][7:0]);
                check(cycles == (ref_hit ? HIT_TIME : HIT_TIME + MISS_PENALTY),
                      "access latency does not match the reference hit/miss");
                n = n + 1;
            end

            check(hit_count == ref_hits,     "hit_count differs from the reference model");
            check(miss_count == ref_misses,  "miss_count differs from the reference model");
            check(hit_count + miss_count == n, "hits + misses differ from the access count");

            hit_rate      = 100.0 * hit_count / n;
            miss_rate     = 1.0 * miss_count / n;
            amat_measured = 1.0 * total_cycles / n;
            amat_formula  = HIT_TIME + miss_rate * MISS_PENALTY;
            check(amat_measured == amat_formula, "measured AMAT differs from the formula");

            $display("| %0s | %0d | %0d | %0d | %0.1f%% | %0.1f%% | %0.2f | %0.2f |", name, n,
                     hit_count, miss_count, hit_rate, 100.0 * miss_rate, amat_measured, amat_formula);
        end
    endtask

    initial begin
        errors = 0;
        $display("HIT_TIME = %0d cycle, MISS_PENALTY = %0d cycles, AMAT = HIT_TIME + miss rate x MISS_PENALTY",
                 HIT_TIME, MISS_PENALTY);
        $display("| Trace | Accesses | Hits | Misses | Hit rate | Miss rate | AMAT measured | AMAT formula |");
        $display("| --- | --- | --- | --- | --- | --- | --- | --- |");
        run_trace("traces/sequential.trace", "sequential");
        run_trace("traces/repeated.trace",   "repeated");
        run_trace("traces/random.trace",     "random");
        run_trace("traces/conflict.trace",   "conflict");

        if (errors == 0) $display("ALL TRACE TESTS PASSED");
        else             $display("%0d TRACE CHECKS FAILED", errors);
        $finish;
    end
endmodule
