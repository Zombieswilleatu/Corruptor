#!/usr/bin/env python3
"""CLI for bounded U13 parity gates; requires Python 3.10+, stdlib only."""

import argparse
import json
from pathlib import Path
import sys
import unittest

from u13_pysim import codec
from u13_pysim.verify import source_identity, verify, verify_rejections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("source-identity")
    commands.add_parser("self-test")
    commands.add_parser("self-test-planning")
    for command in ("verify", "verify-planning"):
        check = commands.add_parser(command)
        check.add_argument("trace", type=Path)
        check.add_argument("--diagnostic", action="store_true", help="Label local non-Windows/4.7.2 results diagnostic only")
        check.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.command in ("self-test", "self-test-planning"):
        modules = ["u13_pysim.test_foundation"]
        if args.command == "self-test-planning":
            modules.append("u13_pysim.test_planning")
        tests = unittest.defaultTestLoader.loadTestsFromNames(modules)
        result = unittest.TextTestRunner(verbosity=2).run(tests)
        return 0 if result.wasSuccessful() else 1
    revision, source_hash = source_identity(root)
    if args.command == "source-identity":
        print(revision)
        print(source_hash)
        return 0
    label = "planning" if args.command == "verify-planning" else "foundation"
    compare, reject = verify, verify_rejections
    if label == "planning":
        from u13_pysim.verify_planning import verify as compare, verify_rejections as reject
    try:
        suite = codec.loads(args.trace.read_text(encoding="utf-8"))
        result = compare(suite, revision, source_hash, diagnostic=args.diagnostic)
        result["deliberate_mismatches_rejected"] = reject(suite, revision, source_hash, diagnostic=args.diagnostic)
        if args.report:
            args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, indent=2))
        print(f"U13 PySim {label} Python failures: 0")
        return 0
    except (ValueError, TypeError, KeyError, OSError, UnicodeError) as error:
        print(f"FAIL U13 PySim {label}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    if sys.version_info < (3, 10):
        raise SystemExit("Python 3.10 or newer is required")
    raise SystemExit(main())
