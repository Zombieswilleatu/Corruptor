#!/usr/bin/env bash
set -euo pipefail
u13_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export U13_DOCTRINE_GAMES=100
export U13_DOCTRINE_WORKERS=${U13_DOCTRINE_WORKERS:-4}
export U13_DOCTRINE_ROUND_LIMIT=${U13_DOCTRINE_ROUND_LIMIT:-40}
export U13_DOCTRINE_VERIFY_EVERY=${U13_DOCTRINE_VERIFY_EVERY:-5}
export U13_DOCTRINE_FIXTURES_ONLY=0
exec bash "$u13_script_dir/run_u13_doctrine.sh" "$@"
