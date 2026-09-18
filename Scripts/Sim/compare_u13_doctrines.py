#!/usr/bin/env python3
"""Compare current common doctrine against a frozen Git policy on current rules."""
import argparse
from pathlib import Path
from u13_doctrine.comparison import BASELINE, run
from u13_pysim.opening import LORDS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--repeats', type=int, default=1)
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--namespace', default='u13-rite-v4-2026-09-18')
    parser.add_argument('--lord', choices=LORDS, help='Only matchups containing this Lord, in both Lord and policy seats')
    args = parser.parse_args()
    if args.repeats < 1 or args.workers < 1: parser.error('Repeats and workers must be positive')
    result = run(Path(__file__).resolve().parents[2], args.output, args.repeats, args.workers, args.namespace, args.baseline, args.lord)
    return int(result['summary']['failed'] != 0)


if __name__ == '__main__': raise SystemExit(main())
