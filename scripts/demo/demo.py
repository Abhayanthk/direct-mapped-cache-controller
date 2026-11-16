#!/usr/bin/env python3
"""Readable demo of the direct-mapped cache controller: traced workload, cache contents and traffic comparison.

Usage: python3 scripts/demo/demo.py [repo-root]   (or ./scripts/demo.sh)
"""
import os, re, subprocess, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(REPO, "build")
RTL = sorted(glob.glob(os.path.join(REPO, "rtl", "*", "*.v")))
if not RTL:
    sys.exit(f"RTL not found under {REPO}/rtl")

C = sys.stdout.isatty() or os.environ.get("FORCE_COLOR")
def col(code, s): return f"\033[{code}m{s}\033[0m" if C else s
bold = lambda s: col("1", s); dim = lambda s: col("2", s)
green = lambda s: col("32", s); yellow = lambda s: col("33", s)
red = lambda s: col("31", s); blue = lambda s: col("34", s); cyan = lambda s: col("36", s)

def sh(cmd, cwd=HERE):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr or r.stdout)
    return r.stdout

os.makedirs(BUILD, exist_ok=True)
sh(["iverilog", "-o", os.path.join(BUILD, "demo"), os.path.join(HERE, "tb_demo.v")] + RTL)
out = sh(["vvp", "-n", os.path.join(BUILD, "demo")])

STATE = {"0": "IDLE", "1": "COMPARE", "2": "WRITE_BACK", "3": "ALLOCATE", "4": "WRITE_MEM"}
NOTE_WB = {
    1: "cold miss: line empty, the whole 4-word block (addresses 0-3) is read in",
    2: "read hit: address 1 came in with address 0's block (spatial locality)",
    3: "cold miss: block 20-23 read into line 5",
    4: "write hit: only the cache changes, line marked DIRTY, memory untouched",
    5: "read hit: no memory access (temporal locality)",
    6: "conflict: 33 also maps to line 0; dirty block (4 words) saved FIRST, then refilled",
    7: "miss: the value written back earlier is read back correctly",
}
NOTE_WT = {
    1: "cold miss: whole block read in",
    2: "read hit: same block as address 0 (spatial locality)",
    3: "cold miss: block read in",
    4: "write hit: cache AND memory written together, so the CPU waits for memory",
    5: "read hit: no memory access",
    6: "conflict: line is clean, so no write-back needed",
    7: "miss: memory already held the new value",
}

mode = None; steps = {}; caches = {}
for line in out.splitlines():
    p = line.split("|")
    if p[0] == "M": mode = p[1]; steps[mode] = []; caches[mode] = []
    elif p[0] == "A": steps[mode].append(p[1:])
    elif p[0] == "S": caches[mode].append(p[1:])

def render(mode, notes):
    print()
    title = "WRITE-BACK" if mode == "write-back" else "WRITE-THROUGH"
    print(bold(f"  {title} MODE") + dim("   (8 lines x 4-word blocks, direct-mapped, memory takes 4 cycles per word)"))
    print()
    hdr = f"  {'#':>2}  {'Operation':<26} {'Tag':>3} {'Line':>4} {'Word':>4}  {'Result':<18} {'Cycles':>6}  {'Path through the controller':<44} {'Mem R/W':>8}"
    print(dim(hdr)); print(dim("  " + "-" * (len(hdr) - 2)))
    for i, s in enumerate(steps[mode], 1):
        is_w, addr, data, cycles, trail, rc, wc, dirty, _, _ = s
        addr = int(addr); tag, line, word = addr >> 5, (addr >> 2) & 7, addr & 3
        path = [STATE[c] for c in trail]
        if "WRITE_BACK" in path: res = red("MISS + evict")
        elif "ALLOCATE" in path: res = yellow("MISS")
        elif "WRITE_MEM" in path: res = blue("HIT + write-thru")
        else: res = green("HIT")
        txt = re.sub(r"\033\[[0-9;]*m", "", res)
        res_pad = res + " " * (18 - len(txt))
        op = ("WRITE" if is_w == "1" else "READ ") + f" addr {addr:>3}" + (f" = 0x{int(data,16):X}" if is_w == "1" else "")
        print(f"  {i:>2}  {op:<26} {tag:>3} {line:>4} {word:>4}  {res_pad} {cycles:>6}  {' > '.join(path):<44} {rc:>4} / {wc}")
        print(dim(f"      {notes[i]}"))
    print()
    print(bold("  Cache contents at the end"))
    print(dim("  line  valid  dirty  tag  words 0-3 of the block                    holds addresses"))
    for k, v, d, t, data in caches[mode]:
        if v == "1":
            base = int(t) * 32 + int(k) * 4
            dtxt = red("1") if d == "1" else "0"
            words = " ".join(f"{int(w, 16):08X}" for w in data.split())
            print(f"  {k:>4}   {v}      {dtxt}     {int(t):>3}  {words}   {base}-{base + 3}")
        else:
            print(dim(f"  {k:>4}   0      0       -   -" + " " * 40 + "-"))

print(); print(bold(cyan("  DIRECT-MAPPED CACHE CONTROLLER: LIVE DEMO")))
print(dim("  Same 7 accesses in both modes. Addresses 1 and 33 share line 0 (tags 0 and 1)."))
render("write-back", NOTE_WB)
render("write-through", NOTE_WT)

# traffic comparison from the project's own test bench
tb = os.path.join(REPO, "tb", "system", "tb_traffic.v")
sh(["iverilog", "-o", os.path.join(BUILD, "traffic"), tb] + RTL)
rows = {}
for line in sh(["vvp", "-n", os.path.join(BUILD, "traffic")]).splitlines():
    m = re.match(r"\| (W\d)[^|]*\| (write-\w+) \| (\d+) \| (\d+) \| (\d+) \|", line)
    if m: rows.setdefault(m.group(1), {})[m.group(2)] = (int(m.group(4)), int(m.group(5)))
NAME = {"W1": "20 writes to one address", "W2": "8 lines written once", "W3": "read-only", "W4": "write, rewrite, read"}
print(); print(bold(cyan("  MEMORY TRAFFIC: WRITE-BACK vs WRITE-THROUGH")))
print(dim("  Memory writes per workload (shorter bar = less traffic)"))
print()
mx = max(v["write-through"][0] for v in rows.values()) if rows else 1
for w in sorted(rows):
    wb, wt = rows[w]["write-back"], rows[w]["write-through"]
    print(f"  {bold(w)}  {NAME[w]}")
    print(f"      write-back     {green('#' * max(1, round(wb[0] / mx * 40))) if wb[0] else dim('')} {wb[0]} writes, {wb[1]} cycles")
    print(f"      write-through  {red('#' * max(1, round(wt[0] / mx * 40))) if wt[0] else dim('')} {wt[0]} writes, {wt[1]} cycles")
    print()
print(dim("  Write-back wins when one word is written many times (W1). A dirty line writes back all 4 words,"))
print(dim("  so write-through wins when lines are written only once or twice (W2, W4). Reads tie (W3)."))
print()
