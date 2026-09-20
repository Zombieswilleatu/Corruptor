#!/usr/bin/env python3
"""Compare old/new/no-Rout policy against fixed V12 opponents on current rules."""
import argparse
from pathlib import Path
from u13_doctrine.rout_comparison import BASELINE, NAMESPACE, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=6)
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--namespace', default=NAMESPACE)
    args = parser.parse_args()
    if args.workers < 1: parser.error('Workers must be positive')
    result = run(Path(__file__).resolve().parents[2], args.output, args.workers, args.namespace, args.baseline)
    return int(result['summary']['failed'] != 0)


if __name__ == '__main__': raise SystemExit(main())
