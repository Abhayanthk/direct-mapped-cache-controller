// cache_core: the synthesizable cache only, for the synthesis run (scripts/synth.sh).
// Same wiring as rtl/top/cache_top.v, without two parts that are not chip logic:
//   - main_memory is a simulation model of DRAM (4-cycle delay, $display), so its
//     request/ready interface becomes top-level ports here, as on a real chip
//   - the hit/miss and traffic counters only feed the testbenches
// Keep this file in step with cache_top.v when the wiring changes.

module cache_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_through,
    input  wire        cpu_req,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr,
    input  wire [31:0] cpu_wdata,
    output wire [31:0] cpu_rdata,
    output wire        cpu_ready,
    output wire        mem_req,
    output wire        mem_we,
    output wire [7:0]  mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        mem_ready
);
    wire [2:0]  addr_tag, stored_tag, index;
    wire [1:0]  offset, word_cnt;
    wire        burst;
    wire [31:0] line_data;
    wire        line_valid, line_dirty, hit;
    wire        data_we, data_from_mem, tag_we, valid_we, dirty_we, dirty_wdata;
    wire [2:0]  state;
    wire [1:0]  word_sel = burst ? word_cnt : offset;

    wire [31:0] data_wdata = data_from_mem ? mem_rdata : cpu_wdata;
    assign mem_addr  = mem_we ? {stored_tag, index, word_sel} : {addr_tag, index, word_sel};
    assign mem_wdata = line_data;
    assign cpu_rdata = line_data;

    addr_split     u_split (.addr(cpu_addr), .tag(addr_tag), .index(index), .offset(offset));
    data_ram       u_data  (.clk(clk), .index(index), .word(word_sel), .we(data_we), .wdata(data_wdata), .rdata(line_data));
    tag_ram        u_tag   (.clk(clk), .index(index), .we(tag_we), .wdata(addr_tag), .rdata(stored_tag));
    valid_ram      u_valid (.clk(clk), .rst(rst), .index(index), .we(valid_we), .wdata(1'b1), .rdata(line_valid));
    dirty_ram      u_dirty (.clk(clk), .rst(rst), .index(index), .we(dirty_we), .wdata(dirty_wdata), .rdata(line_dirty));
    tag_comparator u_cmp   (.valid(line_valid), .stored_tag(stored_tag), .addr_tag(addr_tag), .hit(hit));

    cache_controller u_ctrl (
        .clk(clk), .rst(rst), .write_through(write_through), .cpu_req(cpu_req), .cpu_we(cpu_we),
        .hit(hit), .line_valid(line_valid), .line_dirty(line_dirty), .mem_ready(mem_ready),
        .cpu_ready(cpu_ready), .data_we(data_we), .data_from_mem(data_from_mem), .tag_we(tag_we),
        .valid_we(valid_we), .dirty_we(dirty_we), .dirty_wdata(dirty_wdata),
        .mem_req(mem_req), .mem_we(mem_we), .state(state), .word_cnt(word_cnt), .burst(burst)
    );
endmodule
