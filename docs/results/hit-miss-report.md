# Hit/miss report and AMAT

Four memory-access traces were run through the cache with `./scripts/run.sh trace`. The cache is direct-mapped with 8 lines of 4-word (16-byte) blocks, and main memory takes 4 clock cycles per word. Each trace is 64 reads. The traces are in [`traces/`](../../traces) and are made by `scripts/gen_traces.py`.

## Timing

| Quantity | Value | Where it comes from |
| --- | --- | --- |
| Hit time | 1 cycle | `COMPARE` serves a hit in one cycle |
| Miss time | 22 cycles | `COMPARE` (1), `ALLOCATE` moving 4 words at 5 cycles each (4-cycle memory access + ready cycle) (20), `COMPARE` again (1) |
| Miss penalty | 21 cycles | miss time minus hit time |
| Dirty miss | 42 cycles | 4 words written back (20) before the 4-word refill (20) |

AMAT = hit time + miss rate × miss penalty = 1 + miss rate × 21

## Results

| Trace | Pattern | Accesses | Hits | Misses | Hit rate | Miss rate | AMAT (cycles) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| sequential | addresses 0, 1, 2 ... 63, each once | 64 | 48 | 16 | 75.0% | 25.0% | 6.25 |
| repeated | addresses 0, 4 ... 28 (one per line), looped 8 times | 64 | 56 | 8 | 87.5% | 12.5% | 3.62 |
| random | 64 random reads from addresses 0 to 127 | 64 | 18 | 46 | 28.1% | 71.9% | 16.09 |
| conflict | address 1 alternating with 33, 65, 129 (all line 0) | 64 | 0 | 64 | 0.0% | 100.0% | 22.00 |

The testbench checks three things for every trace:

1. Each access is a hit or a miss exactly as a reference direct-mapped model predicts, with the matching latency (1 or 22 cycles).
2. The hardware counters (`hit_count`, `miss_count` from `rtl/hit_logic/hit_miss_counter.v`) equal the reference counts.
3. The AMAT measured from the clock cycles equals the formula above.

## Analysis

- **Sequential (spatial locality).** The first read of each block misses and brings in all 4 words, so the next 3 reads hit: 16 misses, 48 hits. With 1-word blocks every read on this trace would miss.
- **Repeated (temporal locality).** The loop uses one address per line (stride 4), so block neighbours never help. The 8 addresses fit in the 8 lines: only the first pass misses, and the other 56 reads hit.
- **Random.** The trace covers 128 words, four times the 32 words the cache holds, so most blocks are replaced before they are used again.
- **Conflict (direct-mapped weakness).** Address 1 (tag 0) alternates with 33, 65 and 129 (tags 1, 2, 4). All map to line 0, so each read evicts the previous block, and every access misses while 7 lines stay empty. Address 1 is half the trace, so a 2-way set-associative cache could keep it in one way and hit on every return to it. Each tag differs from tag 0 in exactly one bit, so this trace also catches a tag comparator that ignores any tag bit.

| Miss type (3 Cs) | Seen in | Fix |
| --- | --- | --- |
| Compulsory (first use) | first word of each block in sequential, first pass of repeated | bigger blocks (spatial locality) |
| Capacity (working set too big) | random | bigger cache |
| Conflict (same line) | conflict | associativity |

**Block size trade-off.** Bigger blocks cut compulsory misses on sequential code (0% hits with 1-word blocks, 75% with 4-word blocks), but each miss costs more: 22 cycles instead of 7, because memory moves one word per access.

## Reproduce

```bash
python3 scripts/gen_traces.py   # only needed to regenerate the trace files
./scripts/run.sh trace
```
