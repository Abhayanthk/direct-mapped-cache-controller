# Memory traffic: write-back vs write-through

The same four workloads were run on the same cache, once in write-back mode and once in write-through mode (`./scripts/run.sh traffic`). The cache is direct-mapped with 8 lines of 4-word blocks, and main memory takes 4 clock cycles per word. Memory reads and writes count words.

| Workload | Policy | Memory reads | Memory writes | Clock cycles |
| --- | --- | --- | --- | --- |
| W1: 20 writes to one address, then evict | write-back | 8 | 4 | 125 |
| W1: 20 writes to one address, then evict | write-through | 8 | 20 | 205 |
| W2: write 8 lines once each, then evict all | write-back | 64 | 32 | 544 |
| W2: write 8 lines once each, then evict all | write-through | 64 | 8 | 424 |
| W3: read-only (8 lines, twice) | write-back | 32 | 0 | 216 |
| W3: read-only (8 lines, twice) | write-through | 32 | 0 | 216 |
| W4: loop-like (write, rewrite, read 8 lines), then evict | write-back | 64 | 32 | 592 |
| W4: loop-like (write, rewrite, read 8 lines), then evict | write-through | 64 | 16 | 512 |

## What the table shows

- **Write-back** writes main memory only when a dirty line is evicted, and then it writes the whole 4-word block. **Write-through** writes one word to memory on every CPU write.
- **W1** writes one address 20 times. Write-back needed 4 memory writes (one block) and 125 cycles; write-through needed 20 writes and 205 cycles.
- **W2** writes one word in each of the 8 lines once. Write-back writes back 8 whole blocks (32 words), write-through only the 8 words the CPU wrote, so write-through wins by 120 cycles.
- **W3** only reads, so the two policies give identical numbers.
- **W4** writes each line twice. Write-back still moves 8 blocks (32 words) against 16 single-word writes, so write-through wins by 80 cycles.

Write-back pays off when the same words are written more often than the block size, as in W1. With one dirty bit per line, a lightly written line still costs a full block write-back. Per-word dirty bits would remove that cost, at 3 more bits per line.

## Reproduce

```bash
./scripts/run.sh traffic
```
