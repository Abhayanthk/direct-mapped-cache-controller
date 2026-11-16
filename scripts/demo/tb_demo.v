// Demo testbench: runs a short workload and prints machine-readable lines
// for demo.py to format. One request at a time, same protocol as the system test.
module tb_demo;
    reg clk = 0, rst = 1, write_through = 0, cpu_req = 0, cpu_we = 0;
    reg [7:0] cpu_addr = 0;
    reg [31:0] cpu_wdata = 0;
    wire [31:0] cpu_rdata;
    wire cpu_ready;
    wire [15:0] rc, wc;
    integer cycles, k;
    reg [31:0] got;
    reg [8*8-1:0] trail;
    reg [2:0] last;

    cache_top dut (.clk(clk), .rst(rst), .write_through(write_through), .cpu_req(cpu_req),
        .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata), .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready), .mem_read_count(rc), .mem_write_count(wc));
    always #5 clk = ~clk;

    task show_cache;
        begin
            for (k = 0; k < 8; k = k + 1)
                $display("S|%0d|%b|%b|%0d|%h", k, dut.u_valid.bits[k], dut.u_dirty.bits[k],
                         dut.u_tag.lines[k], dut.u_data.lines[k]);
        end
    endtask

    task access(input is_write, input [7:0] addr, input [31:0] wdata);
        begin
            trail = ""; last = 7; cycles = 0;
            @(negedge clk); cpu_req = 1; cpu_we = is_write; cpu_addr = addr; cpu_wdata = wdata;
            @(negedge clk);
            cycles = 1;
            if (dut.state !== last) begin trail = {trail, 8'h30 + dut.state}; last = dut.state; end
            while (!cpu_ready) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (dut.state !== last) begin trail = {trail, 8'h30 + dut.state}; last = dut.state; end
            end
            got = cpu_rdata;
            @(negedge clk); cpu_req = 0; cpu_we = 0;
            @(negedge clk);
            $display("A|%0d|%0d|%h|%0d|%0s|%0d|%0d|%b|%0d|%h", is_write, addr, is_write ? wdata : got,
                     cycles, trail, rc, wc, dut.u_dirty.bits[addr[2:0]], dut.u_mem.mem[addr], dut.u_mem.mem[addr]);
        end
    endtask

    task run_workload;
        begin
            access(0, 16, 0);
            access(0, 1, 0);
            access(0, 21, 0);
            access(1, 1, 32'hAAAA);
            access(0, 21, 0);
            access(0, 9, 0);
            access(0, 1, 0);
        end
    endtask

    initial begin
        rst = 1; repeat (2) @(negedge clk); rst = 0;
        $display("M|write-back");
        run_workload;
        show_cache;
        write_through = 1; rst = 1; repeat (2) @(negedge clk); rst = 0;
        $display("M|write-through");
        run_workload;
        show_cache;
        $finish;
    end
endmodule
