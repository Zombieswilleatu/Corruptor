#!/usr/bin/env bash
# Local V21 calibration; reuse the uploaded V20 controls when supplied.
set -euo pipefail
if [[ $# -gt 3 || ${1:-} == --help ]]; then
  printf 'Usage: bash %s [pypy_executable] [report_directory] [previous_72_game_zip]\n' "$0"
  printf 'Optional variables: PYPY_BIN, U13_KANIFOUS_WORKERS, U13_KANIFOUS_CONTROL_ZIP.\n'
  exit 0
fi
u13_kc_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_kc_runtime=${1:-${PYPY_BIN:-}}
u13_kc_workers=${U13_KANIFOUS_WORKERS:-4}
u13_kc_control=${3:-${U13_KANIFOUS_CONTROL_ZIP:-}}
if [[ ! "$u13_kc_workers" =~ ^[1-9][0-9]?$ ]] || ((u13_kc_workers > 16)); then
  printf 'U13_KANIFOUS_WORKERS must be from 1 to 16.\n' >&2;exit 2
fi
if [[ -z "$u13_kc_runtime" ]]; then
  for u13_kc_try in pypy3 pypy "$HOME"/Downloads/pypy*/pypy3.exe "$HOME"/Downloads/pypy*/*/pypy3.exe; do
    if "$u13_kc_try" -c 'import sys;sys.exit(sys.implementation.name!="pypy" or sys.version_info<(3,10))' >/dev/null 2>&1; then
      u13_kc_runtime=$u13_kc_try;break
    fi
  done
fi
if [[ -z "$u13_kc_runtime" ]] || ! "$u13_kc_runtime" -c 'import sys;sys.exit(sys.implementation.name!="pypy" or sys.version_info<(3,10))'; then
  printf 'Pass your PyPy 3.10+ executable as the first argument.\n' >&2;exit 2
fi
if [[ -n "$u13_kc_control" && ! -f "$u13_kc_control" ]]; then
  printf 'Control ZIP not found: %s\n' "$u13_kc_control" >&2;exit 2
fi
cd -- "$u13_kc_root"
export PYTHONPATH=Scripts/Sim
u13_kc_downloads=${U13_REPORT_DOWNLOADS:-"$HOME/Downloads"}
mkdir -p -- "$u13_kc_downloads"
if [[ -n ${2:-} ]]; then
  mkdir -p -- "$2";u13_kc_reports=$(cd -- "$2" && pwd -P)
else
  u13_kc_reports=$(mktemp -d "$u13_kc_downloads/u13-kanifous-v21-calibration-XXXXXX")
fi
cleanup() {
  local status=$?;trap - EXIT
  printf 'exit_status=%s\n' "$status" >"$u13_kc_reports/run-status.txt"
  bash "$u13_kc_root/Scripts/Sim/package_u13_reports.sh" "$u13_kc_reports" "$u13_kc_downloads" || true
  exit "$status"
}
trap cleanup EXIT
git rev-parse HEAD >"$u13_kc_reports/revision.txt"
git diff HEAD >"$u13_kc_reports/worktree.diff"
"$u13_kc_runtime" --version >"$u13_kc_reports/runtime.txt" 2>&1
u13_kc_args=(--output "$u13_kc_reports" --workers "$u13_kc_workers")
if [[ -n "$u13_kc_control" ]]; then u13_kc_args+=(--control-zip "$u13_kc_control"); fi
printf 'V21 separate-factor comparison, %s workers. Reports: %s\n' "$u13_kc_workers" "$u13_kc_reports"
"$u13_kc_runtime" -u Scripts/Sim/run_u13_kanifous_calibration.py "${u13_kc_args[@]}" 2>&1 | tee -a "$u13_kc_reports/runner.log"
