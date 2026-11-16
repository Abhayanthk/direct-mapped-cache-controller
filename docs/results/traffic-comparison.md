# Memory traffic: write-back vs write-through

The same four workloads were run on the same cache, once in write-back mode and once in write-through mode (`./scripts/run.sh traffic`). The cache is direct-mapped with 8 lines and 1-word blocks, and main memory takes 4 clock cycles per access.

| Workload | Policy | Memory reads | Memory writes | Clock cycles |
| --- | --- | --- | --- | --- |
| W1: 20 writes to one address, then evict | write-back | 2 | 1 | 80 |
| W1: 20 writes to one address, then evict | write-through | 2 | 20 | 175 |
| W2: write 8 lines once each, then evict all | write-back | 16 | 8 | 184 |
| W2: write 8 lines once each, then evict all | write-through | 16 | 8 | 184 |
| W3: read-only (8 addresses, twice) | write-back | 8 | 0 | 96 |
| W3: read-only (8 addresses, twice) | write-through | 8 | 0 | 96 |
| W4: loop-like (write, rewrite, read 8 lines), then evict | write-back | 16 | 8 | 232 |
| W4: loop-like (write, rewrite, read 8 lines), then evict | write-through | 16 | 16 | 272 |

## What the table shows

- **Write-back** writes main memory only when a dirty line is evicted. **Write-through** writes main memory on every CPU write.
- **W1** writes one address 20 times. Write-back needed 1 memory write and 80 cycles, write-through needed 20 memory writes and 175 cycles, because the repeated writes stay in the cache until the single eviction.
- **W2** writes each of the 8 lines once, so both policies need 8 memory writes (a dirty line still has to be written back once) and they tie at 184 cycles.
- **W3** only reads, so the two policies give identical numbers.
- **W4** rewrites each line, so write-back needs half the memory writes (8 against 16) and 40 fewer cycles (232 against 272).

Fewer memory writes mean fewer slow memory accesses, so write-back is faster whenever the same line is written more than once. When every line is written only once, or the program only reads, the policies are equal.

## Reproduce

```bash
./scripts/run.sh traffic
```
