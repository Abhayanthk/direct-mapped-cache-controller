module tb_traffic;
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
    integer     i, mode, start_time;

    cache_top dut (
        .clk(clk), .rst(rst), .write_through(write_through),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata), .cpu_ready(cpu_ready),
        .mem_read_count(mem_read_count), .mem_write_count(mem_write_count)
    );

    always #5 clk = ~clk;

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

    task start_workload(input integer m);
        begin
            write_through = m;
            rst = 1; @(negedge clk); @(negedge clk); rst = 0;
            start_time = $time;
        end
    endtask

    task report(input [8*70-1:0] workload, input integer m);
        begin
            $display("| %0s | %0s | %0d | %0d | %0d |", workload, m ? "write-through" : "write-back",
                     mem_read_count, mem_write_count, ($time - start_time) / 10);
        end
    endtask

    initial begin
        $display("| Workload | Policy | Memory reads | Memory writes | Clock cycles |");
        $display("| --- | --- | --- | --- | --- |");

        for (mode = 0; mode < 2; mode = mode + 1) begin
            start_workload(mode);
            for (i = 0; i < 20; i = i + 1)
                cpu_access(1, 8'd0, i);
            cpu_access(0, 8'd8, 0);
            report("W1: 20 writes to one address, then evict", mode);
        end

        for (mode = 0; mode < 2; mode = mode + 1) begin
            start_workload(mode);
            for (i = 0; i < 8; i = i + 1)
                cpu_access(1, i, i);
            for (i = 8; i < 16; i = i + 1)
                cpu_access(0, i, 0);
            report("W2: write 8 lines once each, then evict all", mode);
        end

        for (mode = 0; mode < 2; mode = mode + 1) begin
            start_workload(mode);
            for (i = 0; i < 16; i = i + 1)
                cpu_access(0, i % 8, 0);
            report("W3: read-only (8 addresses, twice)", mode);
        end

        for (mode = 0; mode < 2; mode = mode + 1) begin
            start_workload(mode);
            for (i = 0; i < 8; i = i + 1) begin
                cpu_access(1, 8'd40 + i, i);
                cpu_access(1, 8'd40 + i, i + 100);
                cpu_access(0, 8'd40 + i, 0);
            end
            for (i = 0; i < 8; i = i + 1)
                cpu_access(0, i, 0);
            report("W4: loop-like (write, rewrite, read 8 lines), then evict", mode);
        end

        $finish;
    end
endmodule
