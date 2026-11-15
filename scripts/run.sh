#!/usr/bin/env bash
# Run the tests from the repo root:
#   ./scripts/run.sh storage | hit | memory | controller | unit | system | traffic | all
set -e
cd "$(dirname "$0")/.."
mkdir -p build

run() {
    local name=$1; shift
    echo ""
    echo "================ $name ================"
    iverilog -Wall -o "build/$name" "$@"
    vvp -n "build/$name"
}

case "${1:-all}" in
    storage)    run tb_storage          tb/unit/tb_storage.v          rtl/storage/*.v ;;
    hit)        run tb_hit_logic        tb/unit/tb_hit_logic.v        rtl/hit_logic/*.v ;;
    memory)     run tb_main_memory      tb/unit/tb_main_memory.v      rtl/memory/*.v ;;
    controller) run tb_cache_controller tb/unit/tb_cache_controller.v rtl/controller/*.v ;;
    unit)       for p in storage hit memory controller; do "$0" "$p"; done ;;
    system)     run tb_cache_top        tb/system/tb_cache_top.v      rtl/*/*.v ;;
    traffic)    run tb_traffic          tb/system/tb_traffic.v        rtl/*/*.v ;;
    all)        "$0" unit; "$0" system; "$0" traffic ;;
    *)          echo "unknown option: $1"; exit 1 ;;
esac
