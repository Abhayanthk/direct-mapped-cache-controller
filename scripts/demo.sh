#!/usr/bin/env bash
# Readable demo: 7 accesses in both write modes, cache contents and the traffic chart.
# Needs iverilog, vvp and python3. Run from anywhere: ./scripts/demo.sh
exec python3 "$(dirname "$0")/demo/demo.py" "$@"
