#!/usr/bin/env bash
# Fixed 72-game paired screen; Git Bash/PyPy; packages the result in Downloads.
set -euo pipefail
if [[ $# -gt 2 || ${1:-} == --help ]]; then
  printf 'Usage: bash %s [pypy_executable] [report_directory]\n' "$0"
  printf 'Defaults: detect PyPy in PATH/Downloads, four workers, new report folder in Downloads.\n'
  printf 'Override workers with U13_KANIFOUS_WORKERS; runtime with PYPY_BIN.\n'
  exit 0
fi
u13_kw_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_kw_runtime=${1:-${PYPY_BIN:-}}
u13_kw_workers=${U13_KANIFOUS_WORKERS:-4}
if [[ ! "$u13_kw_workers" =~ ^[1-9][0-9]?$ ]] || ((u13_kw_workers > 16)); then
  printf 'U13_KANIFOUS_WORKERS must be from 1 to 16.\n' >&2
  exit 2
fi
if [[ -z "$u13_kw_runtime" ]]; then
  for u13_kw_candidate in pypy3 pypy \
    "$HOME"/Downloads/pypy*/pypy3.exe "$HOME"/Downloads/pypy*/*/pypy3.exe; do
    if "$u13_kw_candidate" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3,10))' >/dev/null 2>&1; then
      u13_kw_runtime=$u13_kw_candidate
      break
    fi
  done
fi
if [[ -z "$u13_kw_runtime" ]] || ! "$u13_kw_runtime" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3,10))'; then
  printf 'PyPy 3.10+ not found. Pass the path to pypy3.exe as the first argument.\n' >&2
  exit 2
fi
cd -- "$u13_kw_root"
export PYTHONPATH=Scripts/Sim
u13_kw_downloads=${U13_REPORT_DOWNLOADS:-"$HOME/Downloads"}
mkdir -p -- "$u13_kw_downloads"
if [[ -n ${2:-} ]]; then
  mkdir -p -- "$2"
  u13_kw_reports=$(cd -- "$2" && pwd -P)
else
  u13_kw_reports=$(mktemp -d "$u13_kw_downloads/u13-kanifous-v19-v20-72-XXXXXX")
fi
cleanup() {
  local status=$?
  trap - EXIT
  printf 'exit_status=%s\n' "$status" >"$u13_kw_reports/run-status.txt"
  bash "$u13_kw_root/Scripts/Sim/package_u13_reports.sh" "$u13_kw_reports" "$u13_kw_downloads" || true
  exit "$status"
}
trap cleanup EXIT
git rev-parse HEAD >"$u13_kw_reports/revision.txt"
git diff HEAD >"$u13_kw_reports/worktree.diff"
"$u13_kw_runtime" --version >"$u13_kw_reports/runtime.txt" 2>&1
printf '72 paired games, %s workers. Reports: %s\n' "$u13_kw_workers" "$u13_kw_reports"
"$u13_kw_runtime" -u Scripts/Sim/run_u13_kanifous_comparison.py \
  --workers "$u13_kw_workers" --output "$u13_kw_reports" 2>&1 | tee -a "$u13_kw_reports/runner.log"
