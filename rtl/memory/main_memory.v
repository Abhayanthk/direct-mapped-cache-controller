// Main memory model: a slow DRAM in front of the cache.
//   256 words x 32 bits, 8-bit address.
//   Each read or write takes LATENCY = 4 clock cycles.
//   After reset every word holds 0x1000 + address (mem[8] = 0x1008).
//
// Handshake with the cache controller:
//   - controller raises mem_req (with mem_we, mem_addr, mem_wdata) and holds it
//   - wait_count counts 0, 1, 2, 3 on each clock
//   - on count 3 the access is done and mem_ready goes high for one cycle
//   - next cycle mem_ready drops back to 0

module main_memory (
    input  wire        clk,
    input  wire        rst,
    input  wire        mem_req,     // request from the cache
    input  wire        mem_we,      // 1 = write, 0 = read
    input  wire [7:0]  mem_addr,
    input  wire [31:0] mem_wdata,
    output reg  [31:0] mem_rdata,
    output reg         mem_ready    // one-cycle "done" pulse
);
    localparam LATENCY = 4;

    reg [31:0] mem [0:255];
    reg [2:0]  wait_count;          // synchronous latency counter
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            mem_ready  <= 1'b0;
            wait_count <= 3'd0;
            mem_rdata  <= 32'd0;
            for (i = 0; i < 256; i = i + 1)
                mem[i] <= 32'h1000 + i;

        end else if (mem_ready) begin
            // keep the done pulse to a single cycle
            mem_ready <= 1'b0;

        end else if (mem_req) begin
            if (wait_count == LATENCY - 1) begin
                wait_count <= 3'd0;
                mem_ready  <= 1'b1;
                if (mem_we) begin
                    mem[mem_addr] <= mem_wdata;
                    $display("%0t  MEMORY WRITE addr=%0d data=%h", $time, mem_addr, mem_wdata);
                end else begin
                    mem_rdata <= mem[mem_addr];
                    $display("%0t  MEMORY READ  addr=%0d data=%h", $time, mem_addr, mem[mem_addr]);
                end
            end else begin
                wait_count <= wait_count + 1'b1;
            end
        end
    end
endmodule
