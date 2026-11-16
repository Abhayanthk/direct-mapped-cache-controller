# Synthesis results

The cache was synthesized with Yosys 0.71 (`synth_ice40`) and placed and routed with nextpnr-ice40 0.11.1 for a Lattice iCE40 HX8K (CT256 package). Run it with `./scripts/synth.sh`.

The synthesis top is [`syn/cache_core.v`](../../syn/cache_core.v): the address split, the four storage RAMs, the tag comparator and the controller. The main-memory model is left out, because it stands in for external DRAM and is not chip logic; its request/ready interface becomes top-level ports. The hit/miss and traffic counters are left out because they only feed the testbenches.

## Resource use

| Resource | Used | Available | Use |
| --- | --- | --- | --- |
| Logic cells (LUT4 + flip-flop) | 2184 | 7680 | 28% |
| LUT4 | 1132 | | |
| Flip-flops | 1071 | | |
| Carry cells | 2 | | |
| Block RAM | 0 | 32 | 0% |
| I/O pins | 153 | 206 | 74% |

The flip-flops hold the cache storage and the controller: data 32 words × 32 bits = 1024, tag 8 × 3 = 24, valid 8, dirty 8, FSM state 3 and word counter 2, which is 1069; Yosys adds 2 more while mapping the logic. Most LUTs are the 32-to-1 word multiplexer on the data RAM read port. The data RAM is read in the same cycle (combinational read), and iCE40 block RAM reads only on a clock edge, so the cache words are built from flip-flops instead of block RAM.

## Timing

| Clock | Target | Maximum frequency |
| --- | --- | --- |
| `clk` | 50 MHz | **82.87 MHz** (passes; placement seed 1) |

The critical path (about 12 ns) starts at a stored tag in the tag RAM, goes through the tag comparator and the controller's `COMPARE` logic, and ends at the write enables of the cache RAMs: the lookup and the decision happen in one cycle. At 82.87 MHz a hit takes 1 cycle (12.1 ns) and a clean miss takes 22 cycles (265 ns).

## Reproduce

```bash
brew install yosys nextpnr-ice40   # macOS; Linux: the yosys and nextpnr packages
./scripts/synth.sh
```
