#!/usr/bin/env python3
"""Check doctrine instrumentation without changing rules or choosing new policy weights."""

import argparse
import json
from pathlib import Path
import platform
import sys
import unittest

from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.reference_probe import run
from u13_pysim.verify import same


def compare_reports(first, second):
    for report in (first, second):
        same(0, report["semantic"]["failures"], "report.failures")
        same(True, report["semantic"]["all_operations_and_final_digests_matched"], "report.exact")
        same(fingerprint(report["semantic"]), report["semantic_report_sha256"], "report.integrity")
    for key in ("source_revision", "engine_source_sha256", "harness_source_sha256", "inputs_sha256",
                "reference_revision", "reference_evidence_sha256", "semantic_report_sha256", "semantic"):
        same(first[key], second[key], "runtime_comparison." + key)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("check")
    check.add_argument("--report", type=Path, required=True)
    compare = commands.add_parser("compare")
    compare.add_argument("first", type=Path)
    compare.add_argument("second", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "compare":
            first, second = (json.loads(path.read_text(encoding="utf-8")) for path in (args.first, args.second))
            if {first["implementation"], second["implementation"]} != {"CPython", "PyPy"}:
                raise ValueError("comparison requires CPython and PyPy reports")
            compare_reports(first, second)
            print("CPython and PyPy diagnostic records, operations and final states match exactly.")
            print("U13 doctrine diagnostics comparison failures: 0")
            return 0
        tests = unittest.defaultTestLoader.loadTestsFromName("u13_doctrine.test_diagnostics")
        result = unittest.TextTestRunner(verbosity=2).run(tests)
        if not result.wasSuccessful() or result.testsRun == 0:
            return 1
        report = run(Path(__file__).resolve().parents[2])
        report.update(implementation=platform.python_implementation(), python=sys.version,
                      platform=platform.platform(), tests_passed=result.testsRun,
                      new_godot_acceptance=False)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False)+"\n", encoding="utf-8")
        for game in report["semantic"]["games"]:
            print(f"{game['match_id']}: {game['rounds']} rounds, {game['operations_matched']} unchanged operations; final digest matched")
        print("This reference observer does not measure power/paid-choice decisions or policy alternatives.")
        print("U13 doctrine diagnostics failures: 0")
        return 0
    except (ValueError, KeyError, TypeError, OSError) as error:
        print("FAIL U13 doctrine diagnostics:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
