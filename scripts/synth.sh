#!/usr/bin/env bash
# Synthesize the cache (syn/cache_core.v) for a Lattice iCE40 HX8K FPGA and print
# resource use and maximum clock frequency. Needs yosys and nextpnr-ice40
# (macOS: brew install yosys nextpnr-ice40). Output files go to build/synth/.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/synth

yosys -q -p "read_verilog syn/cache_core.v rtl/hit_logic/addr_split.v rtl/hit_logic/tag_comparator.v \
    rtl/storage/*.v rtl/controller/cache_controller.v;
    synth_ice40 -top cache_core -json build/synth/cache_core.json;
    tee -q -o build/synth/stat.txt stat"

nextpnr-ice40 --hx8k --package ct256 --seed 1 --freq 50 --pcf-allow-unconstrained \
    --json build/synth/cache_core.json --asc build/synth/cache_core.asc 2> build/synth/pnr.log

echo "== Yosys cell counts (cache_core) =="
grep -E "SB_LUT4|SB_DFF|SB_CARRY|cells$" build/synth/stat.txt
echo "== nextpnr: device utilisation and timing (iCE40 HX8K) =="
grep -E "ICESTORM_LC:|ICESTORM_RAM:|SB_IO:" build/synth/pnr.log | tail -3
grep "Max frequency" build/synth/pnr.log | tail -1
