// Traffic counter: counts how many times main memory was READ and WRITTEN.
// These two numbers are the memory-traffic comparison of the project.
//
// A memory access is FINISHED in the clock cycle where mem_req == 1 AND mem_ready == 1.
//   finished + mem_we == 1  -> it was a WRITE
//   finished + mem_we == 0  -> it was a READ

module traffic_counter (
    input  wire        clk,
    input  wire        rst,
    input  wire        mem_req,
    input  wire        mem_we,
    input  wire        mem_ready,
    output reg  [15:0] read_count,
    output reg  [15:0] write_count
);
    wire access_done = mem_req && mem_ready;

    always @(posedge clk) begin
        if (rst) begin
            read_count  <= 0;
            write_count <= 0;
        end else if (access_done) begin
            if (mem_we)
                write_count <= write_count + 1;
            else
                read_count  <= read_count + 1;
        end
    end
endmodule
