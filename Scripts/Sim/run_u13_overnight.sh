#!/usr/bin/env bash
set -euo pipefail
balance_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
balance_python=${PYPY_BIN:-}
if [[ $# -gt 0 && "$1" != --* ]]; then
  balance_python=$1
  shift
fi
if [[ -z "$balance_python" ]]; then
  for candidate in pypy3 pypy "$HOME"/Downloads/pypy*/pypy3.exe "$HOME"/Downloads/pypy*/*/pypy3.exe; do
    if "$candidate" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3,10))' >/dev/null 2>&1; then balance_python=$candidate; break; fi
  done
fi
if [[ -z "$balance_python" ]]; then balance_python=python; fi
cd -- "$balance_root"
"$balance_python" -c 'import platform,sys; print("Runtime:",platform.python_implementation(),platform.python_version()); sys.exit(sys.version_info < (3,10))'
exec "$balance_python" -u Scripts/Sim/run_u13_overnight.py "$@"
