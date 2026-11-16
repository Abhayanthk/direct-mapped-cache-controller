#!/usr/bin/env python3
"""Generate the memory-access traces in traces/ (read by tb/system/tb_trace.v).

Each line is one CPU read, written as a 3-digit hex word for $readmemh:
    bits [7:0] = word address (0 to 255), bit 8 = write (always 0 here)
The trace ends with the marker FFF. Re-running this script gives the same files.
"""
import random
from pathlib import Path

TRACES_DIR = Path(__file__).resolve().parent.parent / "traces"
END_MARKER = 0xFFF
LENGTH = 64


def sequential():
    return list(range(LENGTH))


def repeated():
    # one address per line (0, 4, ..., 28), looped: only temporal reuse, no block neighbours
    return [4 * (i % 8) for i in range(LENGTH)]


def random_reads():
    rng = random.Random(6)
    return [rng.randrange(128) for _ in range(LENGTH)]


def conflict():
    # address 1 (tag 0) alternates with addresses whose tag has exactly one bit set
    # (33, 65, 129 -> tags 1, 2, 4), all on line 0, so a comparator
    # that ignored any tag bit would report a false hit
    others = [33, 65, 129]
    return [1 if i % 2 == 0 else others[(i // 2) % len(others)] for i in range(LENGTH)]


TRACES = {
    "sequential": ("addresses 0, 1, 2 ... 63, each read once", sequential),
    "repeated": ("addresses 0, 4, 8 ... 28 (one per line) read in a loop, 8 times", repeated),
    "random": ("64 random reads from addresses 0 to 127 (seed 6)", random_reads),
    "conflict": ("address 1 alternating with 33, 65, 129 (all map to line 0)", conflict),
}


def write_trace(name, description, addresses):
    lines = [f"// {name}: {description}", "// format: bit 8 = write, bits 7:0 = word address"]
    lines += [f"{addr:03x}" for addr in addresses]
    lines.append(f"{END_MARKER:03x}")
    (TRACES_DIR / f"{name}.trace").write_text("\n".join(lines) + "\n")


def main():
    TRACES_DIR.mkdir(exist_ok=True)
    for name, (description, make) in TRACES.items():
        write_trace(name, description, make())
        print(f"traces/{name}.trace")


if __name__ == "__main__":
    main()
