#!/usr/bin/env bash
# Export an entire run as one new ZIP directly in Downloads. Also accepts old runs.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -d "$1" ]]; then
  printf 'Usage: bash %s /path/to/report_folder [destination_directory]\n' "$0" >&2
  exit 2
fi
u13_package_source=$(cd -- "$1" && pwd -P)
u13_package_output=${2:-"${U13_REPORT_DOWNLOADS:-$HOME/Downloads}"}
mkdir -p -- "$u13_package_output"
u13_package_output=$(cd -- "$u13_package_output" && pwd -P)
if [[ "$u13_package_output/" == "$u13_package_source/"* ]]; then
  printf 'The ZIP destination must be outside the report folder. Reports: %s\n' "$u13_package_source" >&2
  exit 2
fi
u13_package_label=$(basename -- "$u13_package_source" | tr -c 'A-Za-z0-9._-' '-')
# basename prints a newline; remove its sanitized trailing dash.
u13_package_label=${u13_package_label%-}
u13_package_stamp=$(date '+%Y-%m-%d_%H-%M-%S')
u13_package_work=$(mktemp -d "$u13_package_output/.u13-package-XXXXXX")
u13_package_nonce=${u13_package_work##*-}
u13_package_temp="$u13_package_work/reports.zip"
u13_package_final="$u13_package_output/${u13_package_label}-${u13_package_stamp}-${u13_package_nonce}.zip"
cleanup() { rm -rf -- "$u13_package_work"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'Packing run reports into one ZIP...\n'
# Windows Git Bash has PowerShell and cygpath; no Python/zip installation needed.
# Paths are data passed through the environment, never interpolated into code.
if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  U13_ARCHIVE_SOURCE="$(cygpath -w "$u13_package_source")" \
  U13_ARCHIVE_DESTINATION="$(cygpath -w "$u13_package_temp")" \
    powershell.exe -NoLogo -NoProfile -NonInteractive -Command '
      $ErrorActionPreference = "Stop"
      try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
          $env:U13_ARCHIVE_SOURCE, $env:U13_ARCHIVE_DESTINATION,
          [System.IO.Compression.CompressionLevel]::Optimal, $false)
      } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
    '
elif command -v zip >/dev/null 2>&1; then
  (cd -- "$u13_package_source" && zip -q -r "$u13_package_temp" .)
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$u13_package_source" "$u13_package_temp" <<'PY'
import os
import sys
import zipfile

source, destination = sys.argv[1:]
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
    for folder, dirs, files in os.walk(source):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(folder, name)
            archive.write(path, os.path.relpath(path, source))
PY
else
  printf 'No ZIP writer available (PowerShell, zip, or python3). Reports: %s\n' "$u13_package_source" >&2
  exit 1
fi
# Never replace another run, including a same-second export. A failed pack leaves
# the original folder intact and never advertises a partial ZIP as complete.
mv -n -- "$u13_package_temp" "$u13_package_final"
if [[ -e "$u13_package_temp" || ! -s "$u13_package_final" ]]; then
  printf 'Could not publish a new ZIP. Reports: %s\n' "$u13_package_source" >&2
  exit 1
fi
printf '\nUPLOAD THIS FILE: %s\n' "$u13_package_final"
if command -v cygpath >/dev/null 2>&1; then
  printf 'Windows path: %s\n' "$(cygpath -w "$u13_package_final")"
fi
