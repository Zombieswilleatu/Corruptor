#!/usr/bin/env python3
"""Run or resume a full-roster Python doctrine behavior survey."""
import argparse
import json
from pathlib import Path

from u13_doctrine.common import Weights
from u13_doctrine.survey import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeats', type=int, default=2, help='games per ordered matchup (81 total matchups)')
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--namespace', default='u13-common-v3-survey-2026-09-17')
    parser.add_argument('--weights', type=Path)
    args = parser.parse_args()
    if args.repeats < 1 or args.workers < 1: parser.error('repeats and workers must be positive')
    weights = Weights(**json.loads(args.weights.read_text())) if args.weights else None
    result = run(Path(__file__).resolve().parents[2], args.output, args.repeats, args.workers, args.namespace, weights)
    return int(bool(result['summary']['failed']))


if __name__ == '__main__': raise SystemExit(main())
