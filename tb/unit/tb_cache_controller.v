module tb_cache_controller;
    reg  clk = 0, rst = 1;
    reg  write_through = 0;
    reg  cpu_req = 0, cpu_we = 0, hit = 0, line_valid = 0, line_dirty = 0, mem_ready = 0;
    wire cpu_ready, data_we, data_from_mem, tag_we, valid_we, dirty_we, dirty_wdata, mem_req, mem_we;
    wire [2:0] state;
    integer fails = 0;

    localparam IDLE = 0, COMPARE = 1, WRITE_BACK = 2, ALLOCATE = 3, WRITE_MEM = 4;

    cache_controller u_ctrl (
        .clk(clk), .rst(rst), .write_through(write_through),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .hit(hit),
        .line_valid(line_valid), .line_dirty(line_dirty), .mem_ready(mem_ready),
        .cpu_ready(cpu_ready), .data_we(data_we), .data_from_mem(data_from_mem),
        .tag_we(tag_we), .valid_we(valid_we), .dirty_we(dirty_we), .dirty_wdata(dirty_wdata),
        .mem_req(mem_req), .mem_we(mem_we), .state(state)
    );

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

    task next_cycle;
        begin @(negedge clk); end
    endtask

    initial begin
        $dumpfile("build/tb_cache_controller.vcd");
        $dumpvars(0, tb_cache_controller);

        next_cycle; next_cycle; rst = 0;
        check("starts in IDLE", state, IDLE);

        // 1. Read hit
        cpu_req = 1; cpu_we = 0; next_cycle;
        check("request -> COMPARE", state, COMPARE);
        hit = 1; #1;
        check("read hit: cpu_ready = 1", cpu_ready, 1);
        check("read hit: no data write", data_we, 0);
        next_cycle;
        check("read hit -> back to IDLE", state, IDLE);
        cpu_req = 0; hit = 0; next_cycle;

        // 2. Write hit, write-back mode
        cpu_req = 1; cpu_we = 1; next_cycle;
        hit = 1; #1;
        check("WB write hit: data_we = 1", data_we, 1);
        check("WB write hit: dirty_we = 1", dirty_we, 1);
        check("WB write hit: dirty_wdata = 1", dirty_wdata, 1);
        check("WB write hit: cpu_ready = 1", cpu_ready, 1);
        check("WB write hit: NO memory access", mem_req, 0);
        next_cycle;
        check("WB write hit -> IDLE", state, IDLE);
        cpu_req = 0; cpu_we = 0; hit = 0; next_cycle;

        // 3. Read miss, old line clean -> ALLOCATE -> COMPARE
        cpu_req = 1; next_cycle;
        hit = 0; line_valid = 1; line_dirty = 0; next_cycle;
        check("clean miss -> ALLOCATE", state, ALLOCATE);
        check("ALLOCATE: mem_req = 1", mem_req, 1);
        check("ALLOCATE: mem_we = 0 (read)", mem_we, 0);
        check("ALLOCATE: nothing written while waiting", data_we, 0);
        next_cycle; next_cycle;
        check("ALLOCATE waits for memory", state, ALLOCATE);
        mem_ready = 1; #1;
        check("refill: data_we = 1", data_we, 1);
        check("refill: data_from_mem = 1", data_from_mem, 1);
        check("refill: tag_we = 1", tag_we, 1);
        check("refill: valid_we = 1", valid_we, 1);
        check("refill: dirty_we = 1", dirty_we, 1);
        check("refill: dirty_wdata = 0 (clean)", dirty_wdata, 0);
        next_cycle; mem_ready = 0; hit = 1;
        check("after refill -> COMPARE", state, COMPARE);
        #1; check("now it hits: cpu_ready = 1", cpu_ready, 1);
        next_cycle; cpu_req = 0; hit = 0; next_cycle;

        // 4. Miss, old line dirty -> WRITE_BACK first
        cpu_req = 1; next_cycle;
        line_valid = 1; line_dirty = 1; next_cycle;
        check("dirty miss -> WRITE_BACK", state, WRITE_BACK);
        check("WRITE_BACK: mem_req = 1", mem_req, 1);
        check("WRITE_BACK: mem_we = 1", mem_we, 1);
        mem_ready = 1; next_cycle; mem_ready = 0;
        check("WRITE_BACK done -> ALLOCATE (old block saved first)", state, ALLOCATE);
        mem_ready = 1; next_cycle; mem_ready = 0; line_dirty = 0; hit = 1;
        check("refill done -> COMPARE", state, COMPARE);
        next_cycle; cpu_req = 0; hit = 0; next_cycle;

        // 5. Write hit, write-through mode
        write_through = 1;
        cpu_req = 1; cpu_we = 1; next_cycle;
        hit = 1; #1;
        check("WT write hit: data_we = 1", data_we, 1);
        check("WT write hit: dirty NOT touched", dirty_we, 0);
        check("WT write hit: cpu must wait", cpu_ready, 0);
        next_cycle;
        check("WT write hit -> WRITE_MEM", state, WRITE_MEM);
        check("WRITE_MEM: mem_req = 1", mem_req, 1);
        check("WRITE_MEM: mem_we = 1", mem_we, 1);
        mem_ready = 1; #1;
        check("WRITE_MEM done: cpu_ready = 1", cpu_ready, 1);
        next_cycle; mem_ready = 0;
        check("WRITE_MEM -> IDLE", state, IDLE);

        next_cycle; write_through = 0; cpu_req = 0; cpu_we = 0; hit = 0; next_cycle;

        // 6. Miss on an EMPTY line: a stale dirty bit must not cause a write-back
        cpu_req = 1; next_cycle;
        line_valid = 0; line_dirty = 1; #1;
        check("empty line: no write-back request", mem_we, 0);
        next_cycle;
        check("empty-line miss -> ALLOCATE (not WRITE_BACK)", state, ALLOCATE);
        mem_ready = 1; next_cycle; mem_ready = 0; line_dirty = 0; hit = 1;
        next_cycle; cpu_req = 0; hit = 0; next_cycle;

        // 7. Write miss on a dirty line in write-back mode: full path
        //    COMPARE -> WRITE_BACK -> ALLOCATE -> COMPARE (hit) -> IDLE, line ends dirty
        cpu_req = 1; cpu_we = 1; next_cycle;
        line_valid = 1; line_dirty = 1; next_cycle;
        check("write miss, dirty line -> WRITE_BACK", state, WRITE_BACK);
        check("WRITE_BACK: CPU not answered yet", cpu_ready, 0);
        next_cycle;
        check("WRITE_BACK holds until mem_ready", state, WRITE_BACK);
        mem_ready = 1; next_cycle; mem_ready = 0;
        mem_ready = 1; next_cycle; mem_ready = 0; line_dirty = 0; hit = 1; #1;
        check("write after refill: data_we = 1", data_we, 1);
        check("write after refill: data_from_mem = 0 (CPU data)", data_from_mem, 0);
        check("write after refill: dirty_wdata = 1", dirty_wdata, 1);
        check("write after refill: cpu_ready = 1", cpu_ready, 1);
        next_cycle;
        check("write miss done -> IDLE", state, IDLE);
        cpu_req = 0; cpu_we = 0; hit = 0;

        if (fails == 0) $display("ALL CONTROLLER TESTS PASSED");
        else            $display("%0d CONTROLLER TEST(S) FAILED", fails);
        $finish;
    end
endmodule
