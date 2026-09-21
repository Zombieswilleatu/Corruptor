#!/usr/bin/env bash
# Usage: bash Scripts/Sim/run_u13_lord_balance.sh [python_or_pypy] [runner arguments...]
set -euo pipefail
balance_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
balance_python=""
if [[ $# -gt 0 && "$1" != --* ]]; then
  balance_python=$1
  shift
else
  for candidate in pypy3 "$HOME"/Downloads/pypy3*/pypy3.exe python python3 py; do
    if "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then
      balance_python=$candidate
      break
    fi
  done
fi
if [[ -z "$balance_python" ]] || ! "$balance_python" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
  printf 'Python/PyPy 3.10+ is required; pass its executable as the first argument.\n' >&2
  exit 2
fi
cd -- "$balance_root"
exec "$balance_python" -u Scripts/Sim/run_u13_lord_balance.py "$@"
