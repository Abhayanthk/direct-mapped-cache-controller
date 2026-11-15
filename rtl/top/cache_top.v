// cache_top: the whole system = cache + controller + main memory + counters.
// Module, port and instance names (u_data, u_dirty, u_mem, ...) are used by
// the system testbench to look inside, so they must stay as they are.

module cache_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_through,   // 0 = write-back, 1 = write-through
    input  wire        cpu_req,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr,
    input  wire [31:0] cpu_wdata,
    output wire [31:0] cpu_rdata,
    output wire        cpu_ready,
    output wire [15:0] mem_read_count,
    output wire [15:0] mem_write_count
);
    // ---------- internal wires ----------
    wire [4:0]  addr_tag;      // tag part of cpu_addr
    wire [2:0]  index;         // index part of cpu_addr
    wire [4:0]  stored_tag;    // tag RAM output
    wire [31:0] line_data;     // data RAM output
    wire        line_valid;    // valid RAM output
    wire        line_dirty;    // dirty RAM output
    wire        hit;
    wire [31:0] mem_rdata;
    wire        mem_ready;
    wire        data_we, data_from_mem, tag_we, valid_we, dirty_we, dirty_wdata;
    wire        mem_req, mem_we;
    wire [2:0]  state;

    // ---------- the two MUXes ----------
    // MUX 1: what goes INTO the data RAM? memory data (refill) or CPU data (write hit)
    wire [31:0] data_wdata = data_from_mem ? mem_rdata : cpu_wdata;

    // MUX 2: which address goes to memory?
    //   memory WRITE -> the address of the block sitting in the line = {stored_tag, index}
    //   memory READ  -> the address the CPU asked for = cpu_addr
    wire [7:0]  mem_addr = mem_we ? {stored_tag, index} : cpu_addr;

    // the CPU always reads the word in the selected line
    assign cpu_rdata = line_data;

    // ---------- address split ----------
    addr_split u_split (.addr(cpu_addr), .tag(addr_tag), .index(index));

    // ---------- storage ----------
    data_ram  u_data  (.clk(clk), .index(index), .we(data_we),
                       .wdata(data_wdata), .rdata(line_data));

    tag_ram   u_tag   (.clk(clk), .index(index), .we(tag_we),
                       .wdata(addr_tag), .rdata(stored_tag));

    valid_ram u_valid (.clk(clk), .rst(rst), .index(index), .we(valid_we),
                       .wdata(1'b1), .rdata(line_valid));

    dirty_ram u_dirty (.clk(clk), .rst(rst), .index(index), .we(dirty_we),
                       .wdata(dirty_wdata), .rdata(line_dirty));

    // ---------- hit detection ----------
    tag_comparator u_cmp (.valid(line_valid), .stored_tag(stored_tag),
                          .addr_tag(addr_tag), .hit(hit));

    // ---------- controller (FSM) ----------
    cache_controller u_ctrl (
        .clk(clk),
        .rst(rst),
        .write_through(write_through),
        .cpu_req(cpu_req),
        .cpu_we(cpu_we),
        .hit(hit),
        .line_valid(line_valid),
        .line_dirty(line_dirty),
        .mem_ready(mem_ready),
        .cpu_ready(cpu_ready),
        .data_we(data_we),
        .data_from_mem(data_from_mem),
        .tag_we(tag_we),
        .valid_we(valid_we),
        .dirty_we(dirty_we),
        .dirty_wdata(dirty_wdata),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .state(state)
    );

    // ---------- main memory ----------
    // on a write the memory gets the word currently in the line (write-back / write-through)
    main_memory u_mem (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we),
                       .mem_addr(mem_addr), .mem_wdata(line_data),
                       .mem_rdata(mem_rdata), .mem_ready(mem_ready));

    // ---------- traffic counter ----------
    traffic_counter u_count (.clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we),
                             .mem_ready(mem_ready),
                             .read_count(mem_read_count), .write_count(mem_write_count));

endmodule
