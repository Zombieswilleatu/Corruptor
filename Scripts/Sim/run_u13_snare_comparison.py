#!/usr/bin/env python3
"""Run/resume the fixed 16-game Snare V17/V18 experiment."""
import argparse
from pathlib import Path
from u13_doctrine.snare_comparison import run

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=2)
    args = parser.parse_args()
    result = run(Path(__file__).resolve().parents[2], args.output, args.workers)
    raise SystemExit(int(bool(result['summary']['failed'])))
