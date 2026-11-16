// Hit/miss counter: counts how many CPU accesses were cache hits and how many were misses.
// These two numbers give the hit rate, the miss rate and the AMAT of a trace.
//
// The controller looks up every request in COMPARE.
//   COMPARE and hit == 0  -> this request is a MISS (counted once)
//   After the refill the controller returns to COMPARE and now sees a hit,
//   but that is the same request, so the "missed" flag stops it counting as a hit.
//   cpu_ready == 1        -> the request is finished; if it never missed, it was a HIT

module hit_miss_counter (
    input  wire        clk,
    input  wire        rst,
    input  wire        in_compare,  // controller is in the COMPARE state
    input  wire        hit,         // from the tag comparator
    input  wire        cpu_ready,   // the current request is finished
    output reg  [15:0] hit_count,
    output reg  [15:0] miss_count
);
    reg missed;  // the current request has already missed

    always @(posedge clk) begin
        if (rst) begin
            hit_count  <= 0;
            miss_count <= 0;
            missed     <= 0;
        end else begin
            if (in_compare && !hit) begin
                miss_count <= miss_count + 1;
                missed     <= 1;
            end
            if (cpu_ready) begin
                if (!missed)
                    hit_count <= hit_count + 1;
                missed <= 0;
            end
        end
    end
endmodule
