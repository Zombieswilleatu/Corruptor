#!/usr/bin/env python3
"""Run/resume the predeclared 72-game Orias V15/V16 focal comparison."""
import argparse
from pathlib import Path
from u13_doctrine.orias_comparison import run

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=6)
    parser.add_argument('--pilot', action='store_true', help='Only first matched pair; counts toward campaign')
    parser.add_argument('--reuse-completed', type=Path, help='Preserve verified completed records from the original observer; records keep original identities')
    args = parser.parse_args()
    result = run(Path(__file__).resolve().parents[2], args.output, args.workers, args.pilot, args.reuse_completed)
    raise SystemExit(int(bool(result['summary']['failed'])))
