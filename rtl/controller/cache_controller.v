// Cache controller: the FSM that decides what the cache does every cycle.
// Serves hits, writes back a dirty line before a refill, and refills from memory.
// A block is 4 words and memory moves one word per access, so WRITE_BACK and ALLOCATE
// each run 4 memory accesses, counted by word_cnt.
// Mealy machine: in COMPARE the outputs depend on the state and on hit / cpu_we.

module cache_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       write_through,  // 0 = write-back mode, 1 = write-through mode
    input  wire       cpu_req,        // CPU wants something
    input  wire       cpu_we,         // 1 = CPU wants to write, 0 = read
    input  wire       hit,            // from the tag comparator
    input  wire       line_valid,     // valid bit of the selected line
    input  wire       line_dirty,     // dirty bit of the selected line
    input  wire       mem_ready,      // main memory finished
    output reg        cpu_ready,      // tell CPU "done"
    output reg        data_we,        // write the data RAM
    output reg        data_from_mem,  // 1 = data RAM gets memory data, 0 = gets CPU data
    output reg        tag_we,         // write the tag RAM
    output reg        valid_we,       // write the valid RAM (always writes 1)
    output reg        dirty_we,       // write the dirty RAM
    output reg        dirty_wdata,    // the value written into the dirty RAM
    output reg        mem_req,        // ask main memory
    output reg        mem_we,         // 1 = memory write, 0 = memory read
    output reg  [2:0] state,          // current state (shown in waveforms)
    output reg  [1:0] word_cnt,       // word of the block being moved in WRITE_BACK / ALLOCATE
    output wire       burst           // 1 while a block moves: the datapath uses word_cnt, not the CPU offset
);
    localparam IDLE       = 3'd0;
    localparam COMPARE    = 3'd1;
    localparam WRITE_BACK = 3'd2;
    localparam ALLOCATE   = 3'd3;
    localparam WRITE_MEM  = 3'd4;

    reg  [2:0] next_state;
    wire       last_word = (word_cnt == 2'd3);

    assign burst = (state == WRITE_BACK) || (state == ALLOCATE);

    // state register
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // word counter: one step per finished memory access in a block move, 3 wraps to 0
    always @(posedge clk) begin
        if (rst)
            word_cnt <= 2'd0;
        else if (burst && mem_ready)
            word_cnt <= word_cnt + 2'd1;
    end

    // next state + outputs
    always @(*) begin
        // defaults: stay in the same state, every output 0
        next_state    = state;
        cpu_ready     = 0;
        data_we       = 0;
        data_from_mem = 0;
        tag_we        = 0;
        valid_we      = 0;
        dirty_we      = 0;
        dirty_wdata   = 0;
        mem_req       = 0;
        mem_we        = 0;

        case (state)
            IDLE: begin
                if (cpu_req)
                    next_state = COMPARE;
            end

            COMPARE: begin
                if (hit && !cpu_we) begin
                    // read hit: data is already on cpu_rdata
                    cpu_ready  = 1;
                    next_state = IDLE;
                end else if (hit && cpu_we && !write_through) begin
                    // write hit, write-back: update cache only, mark line dirty
                    data_we     = 1;
                    dirty_we    = 1;
                    dirty_wdata = 1;
                    cpu_ready   = 1;
                    next_state  = IDLE;
                end else if (hit && cpu_we && write_through) begin
                    // write hit, write-through: update cache, then memory too
                    data_we    = 1;
                    next_state = WRITE_MEM;
                end else if (line_valid && line_dirty) begin
                    // miss on a dirty line: save the old block first
                    next_state = WRITE_BACK;
                end else begin
                    // miss on a clean or empty line: just refill
                    next_state = ALLOCATE;
                end
            end

            WRITE_BACK: begin
                // write the 4 words of the old dirty block to memory, then refill
                mem_req = 1;
                mem_we  = 1;
                if (mem_ready && last_word)
                    next_state = ALLOCATE;
            end

            ALLOCATE: begin
                // read the 4 words of the new block from memory, one per access
                mem_req = 1;
                if (mem_ready) begin
                    data_we       = 1;
                    data_from_mem = 1;
                end
                if (mem_ready && last_word) begin
                    // whole block is in: the line now belongs to the new tag
                    tag_we        = 1;
                    valid_we      = 1;
                    dirty_we      = 1;  // dirty_wdata stays 0: refilled line is clean
                    next_state    = COMPARE;
                end
            end

            WRITE_MEM: begin
                // write-through: wait for memory, then tell the CPU
                mem_req = 1;
                mem_we  = 1;
                if (mem_ready) begin
                    cpu_ready  = 1;
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end
endmodule
