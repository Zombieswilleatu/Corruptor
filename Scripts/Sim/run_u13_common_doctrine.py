#!/usr/bin/env python3
"""Dual-runtime check of the experimental bounded U13 doctrine alpha."""
import argparse
import json
from pathlib import Path
import platform
import sys
import unittest

from u13_doctrine.common import Weights
from u13_doctrine.planner_probe import run, compare_reports
from u13_doctrine.selection import PlanSelector, SelectionSettings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    check = sub.add_parser('check')
    check.add_argument('--report', type=Path, required=True)
    check.add_argument('--weights', type=Path)
    check.add_argument('--selection', type=Path, help='Optional selector JSON; defaults to deterministic best-plan selection')
    compare = sub.add_parser('compare'); compare.add_argument('first', type=Path); compare.add_argument('second', type=Path)
    rules = sub.add_parser('verify-rules'); rules.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'verify-rules':
            from u13_pysim.verify import same
            from u13_pysim.verify_veil import verify as veil
            from u13_pysim.verify_monsters import verify as monsters, verify_resurrections
            p = args.directory
            report = dict(veil=veil(p/'U13VeilBreaches.exact'), monsters=monsters(p/'U13Monster.exact'),
                resurrections=verify_resurrections(p/'U13MonsterResurrection.exact'), gravity=monsters(p/'U13MonsterGravity.exact'))
            same(19, report['monsters']['phases'], 'monster phase count')
            same(4, report['gravity']['phases'], 'gravity regression count')
            (p/(platform.python_implementation().lower()+'-native-comparison.json')).write_text(json.dumps(report, indent=2, sort_keys=True)+'\n')
            print(json.dumps(report, sort_keys=True)); return 0
        if args.command == 'compare':
            a, b = (json.loads(p.read_text()) for p in (args.first, args.second))
            if {a['implementation'], b['implementation']} != {'CPython', 'PyPy'}: raise ValueError('Both CPython and PyPy required')
            compare_reports(a, b)
            print('All decisions, final states and diagnostic reports match across CPython and PyPy.')
            print('U13 common doctrine comparison failures: 0'); return 0
        tests = unittest.defaultTestLoader.loadTestsFromNames(['u13_doctrine.test_diagnostics', 'u13_doctrine.test_common',
            'u13_doctrine.test_recipes_veil', 'u13_doctrine.test_rites', 'u13_doctrine.test_closing',
            'u13_doctrine.test_selection', 'u13_doctrine.test_coordination', 'u13_doctrine.test_odradek',
            'u13_doctrine.test_defensive_plans',
            'u13_doctrine.test_comparison', 'u13_pysim.test_marching'])
        result = unittest.TextTestRunner(verbosity=2).run(tests)
        if not result.wasSuccessful() or result.testsRun == 0: return 1
        weights = Weights(**json.loads(args.weights.read_text())) if args.weights else None
        selector = PlanSelector(SelectionSettings(**json.loads(args.selection.read_text()))) if args.selection else None
        args.report.parent.mkdir(parents=True, exist_ok=True)
        report = run(Path(__file__).resolve().parents[2], weights, args.report.with_suffix('.inputs.json'), selector)
        report.update(implementation=platform.python_implementation(), python=sys.version, platform=platform.platform(),
                      tests_passed=result.testsRun, new_godot_parity=False)
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True)+'\n', encoding='utf-8')
        print('U13 common doctrine failures: 0'); return 0
    except (ValueError, KeyError, TypeError, OSError) as error:
        print('FAIL U13 common doctrine:', error, file=sys.stderr); return 1


if __name__ == '__main__': raise SystemExit(main())
