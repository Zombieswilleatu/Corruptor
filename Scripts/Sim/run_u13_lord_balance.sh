#!/usr/bin/env bash
# Usage: bash Scripts/Sim/run_u13_lord_balance.sh [python_or_pypy] [runner arguments...]
set -euo pipefail
balance_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
balance_python=${PYPY_BIN:-}
if [[ $# -gt 0 && "$1" != --* ]]; then
  balance_python=$1
  shift
elif [[ -z "$balance_python" ]]; then
  for candidate in pypy3 pypy "$HOME"/Downloads/pypy*/pypy3.exe "$HOME"/Downloads/pypy*/*/pypy3.exe; do
    if "$candidate" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      balance_python=$candidate
      break
    fi
  done
fi
if [[ -z "$balance_python" ]] || ! "$balance_python" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
  printf 'PyPy 3.10+ was not found. Set PYPY_BIN or pass its executable first.\nTo explicitly use CPython, pass python as the first argument.\n' >&2
  exit 2
fi
cd -- "$balance_root"
"$balance_python" -c 'import platform,sys; print("Simulation runtime:", platform.python_implementation(), platform.python_version(), sys.executable, flush=True)'
balance_runner=Scripts/Sim/run_u13_lord_balance.py
if [[ "${1:-}" == "--benchmark" ]]; then
  balance_runner=Scripts/Sim/run_u13_sim_performance.py
  shift
elif [[ "${1:-}" == "--memory-check" ]]; then
  balance_runner=Scripts/Sim/run_u13_sim_memory.py
  shift
elif [[ "${1:-}" == "--ward-experiment" ]]; then
  balance_runner=Scripts/Sim/run_u13_ward_experiment.py
  shift
fi
exec "$balance_python" -u "$balance_runner" "$@"
